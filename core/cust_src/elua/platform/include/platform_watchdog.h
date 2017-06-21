/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_watchdog.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2014/4/5
 *
 * Description:
 *          platform watchdog ½Ó¿Ú
 **************************************************************************/

#ifndef _PLATFORM_WATCHDOG_H_
#define _PLATFORM_WATCHDOG_H_

#define WATCHDOG_DEFAULT_MODE       0

typedef struct{
    int     mode;
    union{
        int pin_ctl;
    }param;
}watchdog_info_t;

int platform_watchdog_open(watchdog_info_t *info);

int platform_watchdog_close(void);

int platform_watchdog_kick(void);

#endif//_PLATFORM_WATCHDOG_H_

