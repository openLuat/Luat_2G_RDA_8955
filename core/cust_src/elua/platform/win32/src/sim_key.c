
#include <stdio.h>
#include <malloc.h>
#include "type.h"
#include "platform.h"
#include "platform_rtos.h"
#include "event.h"
//#include "keypad.h"

static event_handle_t keypad_event = INVALID_EVENT_HANDLE;

void keypad_event_cb(const uint8 *data, uint32 length){
    PlatformMessage *message = malloc(sizeof(PlatformMessage));

    message->id = RTOS_MSG_KEYPAD;
    message->data.keypadMsgData.type = data[0];
    message->data.keypadMsgData.bPressed = data[1];
    message->data.keypadMsgData.data.matrix.col = data[2];
    message->data.keypadMsgData.data.matrix.row = data[3];

    platform_rtos_send(message);
}

void keypad_init(PlatformKeypadInitParam *param){
    keypad_event = add_event("KEYPAD", EVENT_KEY, keypad_event_cb);
    send_event(keypad_event, (const char*)param, sizeof(PlatformKeypadInitParam));
}
