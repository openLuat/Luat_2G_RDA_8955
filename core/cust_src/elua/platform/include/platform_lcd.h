/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_lcd.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/3/26
 *
 * Description:
 *          platform lcd ½Ó¿Ú
 **************************************************************************/

#ifndef _PLATFORM_LCD_H_
#define _PLATFORM_LCD_H_

#if defined LUA_DISP_LIB

#include "platform_disp.h"

void platform_lcd_init(const PlatformDispInitParam *pParam);

void platform_lcd_update(PlatformRect *pRect, u8 *buffer);

#endif

#endif//_PLATFORM_LCD_H_