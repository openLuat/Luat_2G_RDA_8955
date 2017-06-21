/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    time.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/6/17
 *
 * Description:
 *          c time library internal file 
 *          porting from VC
 **************************************************************************/

#ifndef _CTIME_H_
#define _CTIME_H_

#define _DAY_SEC           (24L * 60L * 60L)    /* secs in a day */

#define _YEAR_SEC          (365L * _DAY_SEC)    /* secs in a year */

#define _FOUR_YEAR_SEC     (1461L * _DAY_SEC)   /* secs in a 4 year interval */

#define _DEC_SEC           315532800L           /* secs in 1970-1979 */

#define _BASE_YEAR         70L                  /* 1970 is the base year */

#define _BASE_DOW          4                    /* 01-01-70 was a Thursday */

#define _LEAP_YEAR_ADJUST  17L                  /* Leap years 1900 - 1970 */

#define _MAX_YEAR          138L                 /* 2038 is the max year */

#endif/*_CTIME_H_*/

