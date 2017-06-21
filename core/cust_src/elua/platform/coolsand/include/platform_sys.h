/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_sys.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/5/10
 *
 * Description:
 *   实现newlib中需要平台支持的一些system 接口
 **************************************************************************/

#ifndef _PLATFORM_SYS_H_
#define _PLATFORM_SYS_H_

int platform_sys_unlink(const char *path);
void platform_decode(unsigned int* data, int len);


#endif/*_PLATFORM_SYS_H_*/

