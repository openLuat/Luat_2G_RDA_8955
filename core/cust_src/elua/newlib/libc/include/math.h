/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    math.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/8/1
 *
 * Description:
 * 
 **************************************************************************/

#ifndef __MATH_H__
#define __MATH_H__

#include "cdefs.h"

#define	HUGE_VAL	__builtin_huge_val()

#undef pow
#define pow lualibc_pow
double lualibc_pow(double x, double y);

#undef floor
#define floor lualibc_floor
double lualibc_floor(double x);

#endif //__MATH_H__

