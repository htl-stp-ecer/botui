#include "iox2/iceoryx2.h"
#include <stdlib.h>
#include <string.h>

struct Iox2BridgeNode {
    iox2_node_h node;
};

struct Iox2BridgePublisher {
    iox2_publisher_h publisher;
};

struct Iox2BridgeSubscriber {
    iox2_subscriber_h subscriber;
};

int iox2_bridge_node_create(void** out_node, const char* name) {
    if (!out_node || !name) return -1;

    iox2_node_name_h name_h = NULL;
    int ret = iox2_node_name_new(NULL, name, strlen(name), &name_h);
    if (ret != IOX2_OK) return ret;

    iox2_node_name_ptr name_ptr = iox2_cast_node_name_ptr(name_h);

    iox2_node_builder_h builder = iox2_node_builder_new(NULL);

    iox2_node_builder_set_name(&builder, name_ptr);

    iox2_node_h node_h = NULL;
    ret = iox2_node_builder_create(builder, NULL, iox2_service_type_e_IPC, &node_h);
    if (ret != IOX2_OK) return ret;

    struct Iox2BridgeNode* node = malloc(sizeof(*node));
    if (!node) { iox2_node_drop(node_h); return -2; }
    node->node = node_h;
    *out_node = node;
    return 0;
}

void iox2_bridge_node_destroy(void* n) {
    if (!n) return;
    struct Iox2BridgeNode* node = n;
    iox2_node_drop(node->node);
    free(node);
}

static iox2_port_factory_pub_sub_h create_service(
    iox2_node_h node, const char* channel) {
    iox2_service_name_h svc_name_h = NULL;
    int ret = iox2_service_name_new(NULL, channel, strlen(channel), &svc_name_h);
    if (ret != IOX2_OK) return NULL;

    iox2_service_name_ptr svc_name_ptr = iox2_cast_service_name_ptr(svc_name_h);

    iox2_service_builder_h svc_builder =
        iox2_node_service_builder(&node, NULL, svc_name_ptr);

    iox2_service_builder_pub_sub_h pub_sub_builder =
        iox2_service_builder_pub_sub(svc_builder);

    iox2_service_builder_pub_sub_set_max_publishers(&pub_sub_builder, 8);
    iox2_service_builder_pub_sub_set_max_subscribers(&pub_sub_builder, 16);
    iox2_service_builder_pub_sub_set_history_size(&pub_sub_builder, 1);
    iox2_service_builder_pub_sub_set_subscriber_max_buffer_size(
        &pub_sub_builder, 64);

    iox2_port_factory_pub_sub_h factory = NULL;
    ret = iox2_service_builder_pub_sub_open_or_create(
        pub_sub_builder, NULL, &factory);
    if (ret != IOX2_OK) return NULL;

    return factory;
}

int iox2_bridge_publisher_create(void* n, const char* channel, void** out_pub) {
    if (!n || !channel || !out_pub) return -1;
    struct Iox2BridgeNode* node = n;

    iox2_port_factory_pub_sub_h factory = create_service(node->node, channel);
    if (!factory) return -2;

    iox2_port_factory_publisher_builder_h pub_builder =
        iox2_port_factory_pub_sub_publisher_builder(&factory, NULL);

    iox2_port_factory_publisher_builder_set_initial_max_slice_len(
        &pub_builder, 4096);
    iox2_port_factory_publisher_builder_set_allocation_strategy(
        &pub_builder, iox2_allocation_strategy_e_POWER_OF_TWO);

    iox2_publisher_h pub_h = NULL;
    int ret = iox2_port_factory_publisher_builder_create(
        pub_builder, NULL, &pub_h);
    if (ret != IOX2_OK) return ret;

    struct Iox2BridgePublisher* pub = malloc(sizeof(*pub));
    if (!pub) { iox2_publisher_drop(pub_h); return -3; }
    pub->publisher = pub_h;
    *out_pub = pub;
    return 0;
}

int iox2_bridge_publisher_send(void* p, const uint8_t* data, size_t len) {
    if (!p || !data || len == 0) return -1;
    struct Iox2BridgePublisher* pub = p;
    return iox2_publisher_send_copy(&pub->publisher, data, len, NULL);
}

void iox2_bridge_publisher_destroy(void* p) {
    if (!p) return;
    struct Iox2BridgePublisher* pub = p;
    iox2_publisher_drop(pub->publisher);
    free(pub);
}

int iox2_bridge_subscriber_create(void* n, const char* channel, void** out_sub) {
    if (!n || !channel || !out_sub) return -1;
    struct Iox2BridgeNode* node = n;

    iox2_port_factory_pub_sub_h factory = create_service(node->node, channel);
    if (!factory) return -2;

    iox2_port_factory_subscriber_builder_h sub_builder =
        iox2_port_factory_pub_sub_subscriber_builder(&factory, NULL);

    iox2_port_factory_subscriber_builder_set_buffer_size(&sub_builder, 64);

    iox2_subscriber_h sub_h = NULL;
    int ret = iox2_port_factory_subscriber_builder_create(
        sub_builder, NULL, &sub_h);
    if (ret != IOX2_OK) return ret;

    struct Iox2BridgeSubscriber* sub = malloc(sizeof(*sub));
    if (!sub) { iox2_subscriber_drop(sub_h); return -3; }
    sub->subscriber = sub_h;
    *out_sub = sub;
    return 0;
}

int iox2_bridge_subscriber_receive(
    void* s, uint8_t* buf, size_t* out_len, size_t max_len) {
    if (!s || !buf || !out_len) return -1;
    struct Iox2BridgeSubscriber* sub = s;

    iox2_sample_h sample = NULL;
    int ret = iox2_subscriber_receive(&sub->subscriber, NULL, &sample);
    if (ret != IOX2_OK) return ret;
    if (!sample) {
        *out_len = 0;
        return 1;
    }

    const void* payload = NULL;
    size_t num_elements = 0;
    iox2_sample_payload(&sample, &payload, &num_elements);

    if (num_elements > max_len) num_elements = max_len;
    memcpy(buf, payload, num_elements);
    *out_len = num_elements;

    iox2_sample_drop(sample);
    return 0;
}

void iox2_bridge_subscriber_destroy(void* s) {
    if (!s) return;
    struct Iox2BridgeSubscriber* sub = s;
    iox2_subscriber_drop(sub->subscriber);
    free(sub);
}
