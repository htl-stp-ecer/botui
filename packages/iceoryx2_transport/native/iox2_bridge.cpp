// iox2_bridge.cpp — Dart FFI shim around raccoon_ring (the SHM ring
// buffer that replaced iceoryx2 in raccoon-transport).
//
// History: this was originally a thin pure-C wrapper around the iceoryx2
// C API; then a C++ wrapper around raccoon::Transport (which itself
// wrapped iceoryx2); now a direct wrapper around raccoon_ring. Each
// step gained reliability — the iceoryx2 backend reproducibly broke
// new-node creation on the Pi once the reader had ~100 publishers open,
// and frames sporadically didn't reach subscribers. raccoon_ring is a
// fileless-per-channel SHM ring buffer: no daemon, no service
// descriptors, no state machine to wedge.
//
// We deliberately keep the exact same iox2_bridge_* C ABI that
// iox2_bridge_ffi.dart expects — no Dart-side changes needed.

#include "iox2_bridge.h"
#include "raccoon_ring.h"

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

void log_line(const char* fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "iox2_bridge: %s\n", buf);
    fflush(stderr);
}

struct SubChannelState {
    rrb_reader_t* reader = nullptr;
    std::mutex mtx;
    std::deque<std::vector<uint8_t>> queue;
    static constexpr size_t kMaxQueue = 64;
};

struct BridgeNode {
    // Background thread polls every subscribed reader and pushes frames
    // into per-channel queues. Dart's subscriber_receive then drains the
    // queue without blocking on the actual SHM read.
    std::thread poll_thread;
    std::atomic<bool> stop{false};

    // Channel name → shared subscriber state. Multiple Iox2BridgeSubscriber
    // handles on the same channel reuse the same state + queue, matching
    // the previous bridge's semantics. Held under subs_mtx for inserts
    // and lookups; the poll thread takes it briefly to snapshot the
    // current channel set.
    std::mutex subs_mtx;
    std::unordered_map<std::string, std::shared_ptr<SubChannelState>> subs;

    // Per-channel publisher writers. Lazy-create on first publish, then
    // reused (raccoon_ring is single-producer per channel, so multiple
    // Dart Iox2BridgePublisher handles on the same channel must share
    // one rrb_writer).
    std::mutex pubs_mtx;
    std::unordered_map<std::string, rrb_writer_t*> pubs;
};

struct BridgePublisher {
    BridgeNode* node;
    std::string channel;
};

struct BridgeSubscriber {
    BridgeNode* node;
    std::string channel;
    std::shared_ptr<SubChannelState> state;
};

// Background poll loop: scratch buffer big enough for any ring writerFor
// would have sized in raccoon-transport (max 512 KiB for camera frames).
void poll_loop(BridgeNode* node) {
    std::vector<uint8_t> scratch(512u * 1024u);
    while (!node->stop.load(std::memory_order_relaxed)) {
        // Snapshot the channel set so we don't hold subs_mtx during the
        // (potentially blocking) reads.
        std::vector<std::shared_ptr<SubChannelState>> states;
        {
            std::lock_guard<std::mutex> lk(node->subs_mtx);
            states.reserve(node->subs.size());
            for (auto& [_, s] : node->subs) states.push_back(s);
        }

        bool any = false;
        for (auto& s : states) {
            for (;;) {
                size_t out_len = 0;
                int rc = rrb_reader_recv(s->reader,
                                         scratch.data(),
                                         scratch.size(),
                                         &out_len);
                if (rc != 0) break;
                any = true;
                std::lock_guard<std::mutex> lk(s->mtx);
                if (s->queue.size() >= SubChannelState::kMaxQueue) {
                    s->queue.pop_front();
                }
                s->queue.emplace_back(scratch.begin(),
                                      scratch.begin() + out_len);
            }
        }

        // Idle sleep when no data — caps poll CPU at ~1 kHz, plenty of
        // headroom for UI's 30-60 Hz consumption.
        if (!any) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
}

} // namespace

extern "C" {

int iox2_bridge_node_create(void** out_node, const char* name) {
    if (!out_node || !name) return -1;
    try {
        auto* node = new BridgeNode();
        node->poll_thread = std::thread(poll_loop, node);
        log_line("node_create('%s') ok (rrb backend)", name);
        *out_node = node;
        return 0;
    } catch (const std::exception& e) {
        log_line("node_create('%s') threw: %s", name, e.what());
        return -2;
    } catch (...) {
        return -3;
    }
}

void iox2_bridge_node_destroy(void* n) {
    if (!n) return;
    auto* node = static_cast<BridgeNode*>(n);
    node->stop.store(true);
    if (node->poll_thread.joinable()) node->poll_thread.join();
    {
        std::lock_guard<std::mutex> lk(node->subs_mtx);
        for (auto& [_, s] : node->subs) {
            if (s->reader) rrb_reader_close(s->reader);
        }
        node->subs.clear();
    }
    {
        std::lock_guard<std::mutex> lk(node->pubs_mtx);
        for (auto& [_, w] : node->pubs) {
            if (w) rrb_writer_destroy(w);
        }
        node->pubs.clear();
    }
    delete node;
}

int iox2_bridge_publisher_create(void* n, const char* channel, void** out_pub) {
    if (!n || !channel || !out_pub) return -1;
    auto* node = static_cast<BridgeNode*>(n);
    try {
        auto* pub = new BridgePublisher{node, std::string(channel)};
        *out_pub = pub;
        return 0;
    } catch (...) {
        return -2;
    }
}

int iox2_bridge_publisher_send(void* p, const uint8_t* data, size_t len) {
    if (!p || !data || len == 0) return -1;
    auto* pub = static_cast<BridgePublisher*>(p);
    rrb_writer_t* w;
    {
        std::lock_guard<std::mutex> lk(pub->node->pubs_mtx);
        auto it = pub->node->pubs.find(pub->channel);
        if (it == pub->node->pubs.end()) {
            // Size the ring on first publish: 2× the first payload as
            // headroom, ~128 KiB total memory budget, ≥4 slots. Matches
            // the policy in raccoon::Transport::Impl::writerFor so a
            // bridge-published channel ends up with the same shape a
            // reader-published one would.
            size_t want = len * 2;
            if (want < RRB_DEFAULT_MAX_PAYLOAD) want = RRB_DEFAULT_MAX_PAYLOAD;
            want = ((want + 255) / 256) * 256;
            size_t slots = (128u * 1024u) / want;
            if (slots < 4) slots = 4;
            if (slots > RRB_DEFAULT_SLOT_COUNT) slots = RRB_DEFAULT_SLOT_COUNT;
            w = rrb_writer_create(pub->channel.c_str(),
                                  (uint32_t)slots, (uint32_t)want);
            if (!w) {
                log_line("publisher_send: rrb_writer_create('%s') failed",
                         pub->channel.c_str());
                return -2;
            }
            pub->node->pubs[pub->channel] = w;
        } else {
            w = it->second;
        }
    }
    int rc = rrb_writer_publish(w, data, len);
    if (rc != 0) {
        log_line("publisher_send('%s') rejected %zu-byte payload",
                 pub->channel.c_str(), len);
        return -3;
    }
    return 0;
}

void iox2_bridge_publisher_destroy(void* p) {
    if (!p) return;
    delete static_cast<BridgePublisher*>(p);
    // The underlying rrb_writer stays alive — multiple Dart publishers
    // can share one writer, and the node teardown is what closes them.
}

int iox2_bridge_subscriber_create(void* n, const char* channel, void** out_sub) {
    if (!n || !channel || !out_sub) return -1;
    auto* node = static_cast<BridgeNode*>(n);
    try {
        std::shared_ptr<SubChannelState> state;
        {
            std::lock_guard<std::mutex> lk(node->subs_mtx);
            auto& slot = node->subs[channel];
            if (!slot) {
                slot = std::make_shared<SubChannelState>();
                slot->reader = rrb_reader_open(channel);
                if (!slot->reader) {
                    node->subs.erase(channel);
                    log_line("subscriber_create('%s') — rrb_reader_open failed",
                             channel);
                    return -2;
                }
                log_line("subscriber_create('%s') ok", channel);
            }
            state = slot;
        }
        auto* sub = new BridgeSubscriber{node, std::string(channel), state};
        *out_sub = sub;
        return 0;
    } catch (const std::exception& e) {
        log_line("subscriber_create('%s') threw: %s", channel, e.what());
        return -3;
    } catch (...) {
        return -4;
    }
}

int iox2_bridge_subscriber_receive(void* s, uint8_t* buf,
                                   size_t* out_len, size_t max_len) {
    if (!s || !buf || !out_len) return -1;
    auto* sub = static_cast<BridgeSubscriber*>(s);
    if (!sub->state) { *out_len = 0; return 1; }
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
    delete static_cast<BridgeSubscriber*>(s);
    // Same as publisher_destroy: SubChannelState stays alive until node
    // teardown so other Dart subscribers on the same channel keep getting
    // frames.
}

} // extern "C"
