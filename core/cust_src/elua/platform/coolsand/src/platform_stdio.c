/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_stubs.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/11/29
 *
 * Description:
 *   实现newlib/stubs.c中需要平台支持的一些stdio.c的接口
 **************************************************************************/

#include "../../newlib/libc/include/stdio.h" //需要FILE类型定义
#include "assert.h"

static char iobuf_temp[2048];

extern int vsnprintf(char *buf, size_t size, const char *fmt, va_list ap);

int platform_vfprintf(FILE *fp, const char *fmt, va_list ap)
{
    int len;

    len = vsnprintf(iobuf_temp, sizeof(iobuf_temp), fmt, ap);

    ASSERT(len < sizeof(iobuf_temp));

    return (*fp->_write)(fp->_cookie, iobuf_temp, len);
}

