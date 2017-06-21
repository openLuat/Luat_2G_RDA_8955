
#include <stddef.h>
#include <malloc.h>
#include "event.h"
#include "list.h"

typedef struct{
    list_head           list;
    const char          *name;
    unsigned char       id;
    event_cb_t          cb;
}event_t;

static list_head event_list = {NULL, NULL};

extern void daemon_emit_event(unsigned char id, const char *data, int length);

event_handle_t add_event(const char *name, unsigned char id, event_cb_t cb){
    event_t *evt = (event_t *)calloc(sizeof(event_t), 1);

    evt->name = name;
    evt->id = id;
    evt->cb = cb;

    list_add_after(&evt->list, &event_list);

    return (event_handle_t)evt;
}

void remove_event(event_handle_t *handle){
    event_t **evt_pp = (event_t**)handle;

    if(*evt_pp == NULL) return;

    list_del(&(*evt_pp)->list);

    free(*evt_pp);
    *evt_pp = NULL;
}

void dispatch_event(const char *data, int length){
    list_head *list_pos;
    int evt_id;
    event_t *evt;

    if(length < 1) {
        return;
    }
    
    evt_id = data[0];

    list_for_each(list_pos, &event_list){
        evt = list_entry(list_pos, event_t, list);

        if(evt->id == evt_id && evt->cb){
            evt->cb(&data[1], length-1);
            break;
        }
    }
}

void send_event(event_handle_t handle, const char *data, int length){
    event_t *evt = (event_t *)handle;

    daemon_emit_event(evt->id, data, length);
}
