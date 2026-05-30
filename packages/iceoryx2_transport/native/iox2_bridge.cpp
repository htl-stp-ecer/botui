// iox2_bridge.cpp — thin C ABI shim around raccoon::Transport for Dart FFI.
//
// Background: the previous pure-C bridge (iox2_bridge.c) talked directly to
// the iceoryx2 C API. On the deployed Pi every subscribe came back with
// OpenIsMarkedForDestruction (error 19) even though python+raccoon-lib's
// C++ Transport could subscribe to the same channels fine. We never tracked
// down the exact iox2 C-vs-C++ ABI discrepancy that made the bridge see
// tombstones the C++ wrapper transparently recovers from. Since the cli on
// Pi proves raccoon::Transport works against the live reader, just reuse
// that implementation here.
//
// Threading model: subscribeRaw callbacks fire from raccoon::Transport's
// spin loop, which we own. Each subscribe handler pushes the bytes onto a
// per-channel mutex-protected vector. Dart polls via subscriber_receive at
// its 10 ms spin tick and dequeues a single frame per call (matches the
// previous per-frame iox2 receive semantics).
//
// Public C ABI exactly matches the previous bridge (return codes, struct
// pointers, fn names) so iox2_bridge_ffi.dart needs no changes.

#include "iox2_bridge.h"

#include "raccoon/Transport.h"

#include <atomic>
#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace {

// One-line stderr log helper. Keeps prefix consistent so users grep
// "iox2_bridge" in flutter-pi journal output the same as before.
void log_line(const char* fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "iox2_bridge: %s\n", buf);
    fflush(stderr);
}

struct SubscriberState {
    std::mutex mtx;
    // Bounded queue — drop oldest on overflow so a slow Dart consumer
    // doesn't grow memory unboundedly. 64 matches the iox2 subscriber
    // buffer the previous bridge requested; same Hz tolerance for the UI.
    std::deque<std::vector<uint8_t>> queue;
    static constexpr size_t kMaxQueue = 64;
};

struct BridgeNode {
    // shared_ptr so subscribers/publishers can hold a back-ref without
    // worrying about the node going away under them. We control the only
    // shared_ptr from C-land (the Dart Iox2Node) and drop it on destroy.
    std::shared_ptr<raccoon::Transport> transport;

    // Background thread that drives Transport::spinOnce so subscribe
    // callbacks fire while Dart is between its own poll ticks.
    std::thread spin_thread;
    std::atomic<bool> stop_spin{false};

    // We keep per-channel SubscriberState refs alive on the node so the
    // Transport callback lambda can capture them safely even if the Dart
    // subscriber handle outlives any single call. Indexed by channel name.
    std::mutex subs_mtx;
    std::unordered_map<std::string, std::shared_ptr<SubscriberState>> subs;
};

struct BridgePublisher {
    std::shared_ptr<raccoon::Transport> transport;
    std::string channel;
};

struct BridgeSubscriber {
    std::shared_ptr<raccoon::Transport> transport;
    std::string channel;
    std::shared_ptr<SubscriberState> state;
};

} // namespace

extern "C" {

int iox2_bridge_node_create(void** out_node, const char* name) {
    if (!out_node || !name) return -1;

    try {
        auto node = std::make_unique<BridgeNode>();
        node->transport = std::make_shared<raccoon::Transport>(
            raccoon::Transport::create());

        // Spin daemon: pump callbacks at ~10 ms. raccoon::Transport's
        // spinOnce is already adaptive (sleeps longer when idle) so this
        // is safe to leave running.
        BridgeNode* raw_node = node.get();
        node->spin_thread = std::thread([raw_node]() {
            while (!raw_node->stop_spin.load(std::memory_order_relaxed)) {
                raw_node->transport->spinOnce(10);
            }
        });

        log_line("node_create('%s') ok", name);
        *out_node = node.release();
        return 0;
    } catch (const std::exception& e) {
        log_line("node_create('%s') threw: %s", name, e.what());
        return -2;
    } catch (...) {
        log_line("node_create('%s') threw unknown", name);
        return -3;
    }
}

void iox2_bridge_node_destroy(void* n) {
    if (!n) return;
    auto* node = static_cast<BridgeNode*>(n);
    node->stop_spin.store(true, std::memory_order_relaxed);
    if (node->transport) {
        // stop() flips the spin loop's internal stop flag too — defensive
        // in case our atomic check is read after the next iteration starts.
        node->transport->stop();
    }
    if (node->spin_thread.joinable()) {
        node->spin_thread.join();
    }
    delete node;
}

int iox2_bridge_publisher_create(void* n, const char* channel, void** out_pub) {
    if (!n || !channel || !out_pub) return -1;
    auto* node = static_cast<BridgeNode*>(n);

    try {
        auto pub = std::make_unique<BridgePublisher>();
        pub->transport = node->transport;
        pub->channel = channel;
        *out_pub = pub.release();
        return 0;
    } catch (...) {
        log_line("publisher_create('%s') threw", channel);
        return -2;
    }
}

int iox2_bridge_publisher_send(void* p, const uint8_t* data, size_t len) {
    if (!p || !data || len == 0) return -1;
    auto* pub = static_cast<BridgePublisher*>(p);
    if (!pub->transport) return -2;
    try {
        bool ok = pub->transport->publishRaw(
            pub->channel, data, static_cast<int>(len));
        return ok ? 0 : -3;
    } catch (...) {
        return -4;
    }
}

void iox2_bridge_publisher_destroy(void* p) {
    if (!p) return;
    delete static_cast<BridgePublisher*>(p);
}

int iox2_bridge_subscriber_create(void* n, const char* channel, void** out_sub) {
    if (!n || !channel || !out_sub) return -1;
    auto* node = static_cast<BridgeNode*>(n);

    try {
        std::string ch = channel;

        // Reuse a single SubscriberState per channel so callers that wrap
        // the same channel get the same in-flight queue. raccoon::Transport
        // already coalesces underlying iox2 ports per channel; we mirror
        // that here to avoid double-buffering.
        std::shared_ptr<SubscriberState> state;
        bool already_attached = false;
        {
            std::lock_guard<std::mutex> lk(node->subs_mtx);
            auto& slot = node->subs[ch];
            if (!slot) {
                slot = std::make_shared<SubscriberState>();
            } else {
                already_attached = true;
            }
            state = slot;
        }

        if (!already_attached) {
            // request_retained=true matches the previous bridge's default
            // semantics — UI widgets expect the last value when they first
            // subscribe (e.g. servo position, motor enable). The reader's
            // retain machinery will replay it.
            raccoon::SubscribeOptions options{};
            options.requestRetained = true;
            std::weak_ptr<SubscriberState> weak_state = state;
            bool ok = node->transport->subscribeRaw(
                ch,
                [weak_state](const void* data, int data_len) {
                    auto s = weak_state.lock();
                    if (!s) return;
                    std::lock_guard<std::mutex> lk(s->mtx);
                    if (s->queue.size() >= SubscriberState::kMaxQueue) {
                        s->queue.pop_front();
                    }
                    auto& dest = s->queue.emplace_back();
                    dest.resize(static_cast<size_t>(data_len));
                    std::memcpy(dest.data(), data, static_cast<size_t>(data_len));
                },
                options);
            if (!ok) {
                std::lock_guard<std::mutex> lk(node->subs_mtx);
                node->subs.erase(ch);
                log_line("subscriber_create('%s') — subscribeRaw rejected",
                         ch.c_str());
                return -2;
            }
            log_line("subscriber_create('%s') ok", ch.c_str());
        } else {
            log_line("subscriber_create('%s') ok (shared)", ch.c_str());
        }

        auto sub = std::make_unique<BridgeSubscriber>();
        sub->transport = node->transport;
        sub->channel = ch;
        sub->state = state;
        *out_sub = sub.release();
        return 0;
    } catch (const std::exception& e) {
        log_line("subscriber_create('%s') threw: %s", channel, e.what());
        return -3;
    } catch (...) {
        log_line("subscriber_create('%s') threw unknown", channel);
        return -4;
    }
}

int iox2_bridge_subscriber_receive(
    void* s, uint8_t* buf, size_t* out_len, size_t max_len) {
    if (!s || !buf || !out_len) return -1;
    auto* sub = static_cast<BridgeSubscriber*>(s);
    if (!sub->state) {
        *out_len = 0;
        return 1; // no data — same as old bridge's "ret == 1"
    }
    std::vector<uint8_t> frame;
    {
        std::lock_guard<std::mutex> lk(sub->state->mtx);
        if (sub->state->queue.empty()) {
            *out_len = 0;
            return 1;
        }
        frame = std::move(sub->state->queue.front());
        sub->state->queue.pop_front();
    }
    size_t n = frame.size();
    if (n > max_len) n = max_len;
    std::memcpy(buf, frame.data(), n);
    *out_len = n;
    return 0;
}

void iox2_bridge_subscriber_destroy(void* s) {
    if (!s) return;
    // We intentionally do NOT unsubscribe at the underlying Transport level
    // here: raccoon::Transport doesn't expose a per-handler unsubscribe and
    // tearing down the iox2 port would also kill any other Dart Iox2Subscriber
    // for the same channel. The state stays alive (held by the node's map)
    // until node destroy, mirroring the previous bridge's lifecycle.
    delete static_cast<BridgeSubscriber*>(s);
}

} // extern "C"
