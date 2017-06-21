/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    stdlib.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/15
 *
 * Description:
 * 
 **************************************************************************/

#include "stddef.h"
#include "stdlib.h"
#include "string.h"
#include "errno.h"
#include "assert.h"

void
lualibc_exit(int status)
{
    ASSERT(0);
}

int lualibc_system(const char *__string)
{
    errno = ENOSYS;
    return -1;
}


/*+\NEW\liweiqiang\2013.10.25\支持环境变量访问*/
extern char *getLuaPath(void);
extern char *getLuaDir(void);
extern char *getLuaDataDir(void);

char *lualibc_getenv(const char *name)
{
    if(strcmp(name, "LUA_PATH") == 0)
        return getLuaPath();

    if(strcmp(name, "LUA_DIR") == 0)
        return getLuaDir();
    
    if(strcmp(name, "LUA_DATA_DIR") == 0)
        return getLuaDataDir();

    return NULL;
}
/*-\NEW\liweiqiang\2013.10.25\支持环境变量访问*/

void lualibc_abort(void)
{
    ASSERT(0);
}

