/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    _types.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/24
 *
 * Description:
 * 
 **************************************************************************/
#ifndef ___TYPES_H__
#define ___TYPES_H__

//#if defined(__INT_MAX__) && __INT_MAX__ == 2147483647
typedef int _ssize_t;
//#else
//typedef long _ssize_t;
//#endif

typedef long		off_t;

typedef long _off_t;

#if !defined(__time_t_defined)
typedef long time_t;
#define __time_t_defined
#endif

#if !defined(__clock_t_defined)
typedef long clock_t;
#define __clock_t_defined
#endif

#endif //___TYPES_H__

