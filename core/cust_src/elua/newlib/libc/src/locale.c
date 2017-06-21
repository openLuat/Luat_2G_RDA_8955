/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    locale.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/16
 *
 * Description:
 * 
 **************************************************************************/

#include "stddef.h"
#include "errno.h"
#include "locale.h"

struct lconv *lualibc_localeconv(void)
{
    errno = ENOSYS;
    return NULL;
}

char* lualibc_setlocale(int category, const char *locale)
{
    errno = ENOSYS;
    return NULL;
}

