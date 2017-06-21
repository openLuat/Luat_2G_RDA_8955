#include "platform.h"
#include "platform_watchdog.h"

int platform_watchdog_open(watchdog_info_t *info){
    return PLATFORM_ERR;
}

int platform_watchdog_close(void){
    return PLATFORM_ERR;
}

int platform_watchdog_kick(void){
    return PLATFORM_ERR;
}
