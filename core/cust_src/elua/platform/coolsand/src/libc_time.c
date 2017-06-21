/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    time.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/6/17
 *
 * Description:
 *          c库函数time接口实现
 **************************************************************************/

#include "stdio.h"
#include "string.h"
#include "errno.h"
#include "limits.h"
#include "time.h"
#include "rda_pal.h"

extern time_t _gmtotime_t (
        int yr,     /* 0 based */
        int mo,     /* 1 based */
        int dy,     /* 1 based */
        int hr,
        int mn,
        int sc
        );

time_t lualibc_time(time_t *_timer)
{
    T_AMOPENAT_SYSTEM_DATETIME sysDateTime;

    if(!IVTBL(get_system_datetime)(&sysDateTime))
        return (time_t)-1;

    return _gmtotime_t( sysDateTime.nYear, 
                        sysDateTime.nMonth, 
                        sysDateTime.nDay, 
                        sysDateTime.nHour, 
                        sysDateTime.nMin, 
                        sysDateTime.nSec);
}

