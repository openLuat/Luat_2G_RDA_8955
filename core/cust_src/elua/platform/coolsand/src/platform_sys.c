/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_sys.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/5/10
 *
 * Description:
 *   实现newlib中需要平台支持的一些system 接口
 **************************************************************************/

#include <string.h>
#include "rda_pal.h"

extern WCHAR* strtows(WCHAR* dst, const char* src);

int platform_sys_unlink(const char *path)
{
    int ret;
    int length;
    WCHAR *unicode_path;

    length = strlen(path);

    unicode_path = IVTBL(malloc)((length+1)*sizeof(WCHAR));
    strtows(unicode_path, path);

    ret = IVTBL(delete_file)(unicode_path);

    if(unicode_path)
        IVTBL(free)(unicode_path);

    return ret;
}

void platform_decode(unsigned int* data, int len)
{
    IVTBL(decode)((UINT32*)data, len);
}

