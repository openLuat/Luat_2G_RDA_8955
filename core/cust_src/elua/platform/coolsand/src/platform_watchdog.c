/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_watchdog.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2014/4/5
 *
 * Description:
 *          lua watchdog平台接口实现
 **************************************************************************/

#include <stdio.h>
#include <string.h>
#include "rda_pal.h"

#include "platform.h"
#include "platform_watchdog.h"

#ifdef DSS_CONFIG_EX_WATCH_DOG
extern E_AMOPENAT_GPIO_PORT platform_pio_get_gpio_port(int port_pin);

int platform_watchdog_open(watchdog_info_t *info){
    U_AMOPENAT_EX_WATCH_DOG_CFG config;

    if(info->mode != OPENAT_CUST_EX_WATCH_DOG_MODE_DEFAULT) return PLATFORM_ERR;

    memset(&config, 0, sizeof(config));
    config.defaultModeCfg.port = platform_pio_get_gpio_port(info->param.pin_ctl);
    
    return IVTBL(cus_config_ex_watch_dog)(OPENAT_CUST_EX_WATCH_DOG_MODE_DEFAULT, &config) ? PLATFORM_OK : PLATFORM_ERR;
}

int platform_watchdog_close(void){
    return IVTBL(cus_close_ex_watch_dog)(OPENAT_CUST_EX_WATCH_DOG_MODE_DEFAULT) ? PLATFORM_OK : PLATFORM_ERR;
}

int platform_watchdog_kick(void){
    return IVTBL(cus_reset_ex_watch_dog)() ? PLATFORM_OK : PLATFORM_ERR; 
}
#else
int platform_watchdog_open(watchdog_info_t *info){
    return PLATFORM_ERR;
}

int platform_watchdog_close(void){
    return PLATFORM_ERR;
}

int platform_watchdog_kick(void){
    return PLATFORM_ERR;
}
#endif

