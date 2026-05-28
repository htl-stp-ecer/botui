#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int iox2_bridge_node_create(void** out_node, const char* name);
void iox2_bridge_node_destroy(void* node);

int iox2_bridge_publisher_create(void* node, const char* channel, void** out_pub);
int iox2_bridge_publisher_send(void* pub, const uint8_t* data, size_t len);
void iox2_bridge_publisher_destroy(void* pub);

int iox2_bridge_subscriber_create(void* node, const char* channel, void** out_sub);
int iox2_bridge_subscriber_receive(void* sub, uint8_t* buf, size_t* out_len, size_t max_len);
void iox2_bridge_subscriber_destroy(void* sub);

#ifdef __cplusplus
}
#endif
