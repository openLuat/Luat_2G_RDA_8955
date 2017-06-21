/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    time.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/14
 *
 * Description:
 * 
 **************************************************************************/
#ifndef __TIME_H__
#define __TIME_H__

#include "cdefs.h"
#include "_types.h"

#ifndef _CLOCKS_PER_SEC_
#define _CLOCKS_PER_SEC_ 1000
#endif

#define CLOCKS_PER_SEC _CLOCKS_PER_SEC_

__BEGIN_DECLS

#undef  time
#define time        lualibc_time
time_t lualibc_time(time_t *_timer);

struct tm {
   int     tm_sec;         /* seconds */
   int     tm_min;         /* minutes */
   int     tm_hour;        /* hours */
   int     tm_mday;        /* day of the month */
   int     tm_mon;         /* month */
   int     tm_year;        /* year */
   int     tm_wday;        /* day of the week */
   int     tm_yday;        /* day in the year */
   int     tm_isdst;       /* daylight saving time */
};

#undef  clock
#define clock       lualibc_clock
clock_t lualibc_clock(void);

#undef  difftime
#define difftime    lualibc_difftime
//double lualibc_difftime(time_t _time2, time_t _time1); // 标准定义 在本系统中裁剪为time_t返回值 即long型
time_t lualibc_difftime(time_t _time2, time_t _time1);

#undef  mktime
#define mktime      lualibc_mktime
time_t lualibc_mktime(struct tm *_timeptr);

#undef  asctime
#define asctime     lualibc_asctime
char* lualibc_asctime(const struct tm *_tblock);

#undef  ctime
#define ctime       lualibc_ctime
char* lualibc_ctime(const time_t *_time);

#undef  gmtime
#define gmtime      lualibc_gmtime
struct tm* lualibc_gmtime(const time_t *_timer);

#undef  localtime
#define localtime   lualibc_localtime
struct tm* lualibc_localtime(const time_t *_timer);

#undef strftime
#define strftime   lualibc_strfttime
size_t lualibc_strfttime(char *_s, size_t _maxsize, const char *_fmt, const struct tm *_t);

__END_DECLS

#endif //__TIME_H__
