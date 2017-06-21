
#ifndef _EVENT_H_
#define _EVENT_H_

#include "type.h"

#define EVENT_CTRL_CONSOLE  0x00
#define EVENT_KEY           0x10
#define EVENT_GPIO          0x11

typedef int event_handle_t;
typedef void (*event_cb_t)(const uint8 *data, uint32 length);

#define INVALID_EVENT_HANDLE    ((event_handle_t)0)

event_handle_t add_event(const char *name, uint8 id, event_cb_t cb);

void remove_event(event_handle_t *handle);

void dispatch_event(const char *data, int length);

void send_event(event_handle_t handle, const char *data, int length);

#endif