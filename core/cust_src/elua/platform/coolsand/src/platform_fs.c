/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_fs.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/11/27
 *
 * Description:
 * 
 **************************************************************************/

#include "string.h"
#include "rda_pal.h"

#include "devman.h"
#include "platform_fs.h"
#include "assert.h"

WCHAR* strtows(WCHAR* dst, const char* src)
{
    while(*src)
    {
        *dst++ = *src++;
    }
    *dst = 0;
    
    return (dst);
}

static int platformfs_open_r( const char *path, int flags, int mode )
{
    int fd;
    int length;
    WCHAR *unicode_path;

    length = strlen(path);

    unicode_path = IVTBL(malloc)((length+1)*sizeof(WCHAR));
    strtows(unicode_path, path);

    fd = IVTBL(open_file)(unicode_path, flags, mode);

    if(unicode_path)
    {
        IVTBL(free)(unicode_path);
    }

    return fd;
}

static int platformfs_close_r( int fd )
{
    return IVTBL(close_file)(fd);
}

static _ssize_t platformfs_write_r( int fd, const void* ptr, size_t len )
{
    int ret = 0;

    ret = IVTBL(write_file)(fd, (UINT8 *)ptr, len);

    return ret < 0 ? 0 : ret;
}

static _ssize_t platformfs_read_r( int fd, void* ptr, size_t len )
{
    int ret = 0;

    ret = IVTBL(read_file)(fd, ptr, len);

    return ret < 0 ? 0 : ret;
}

static off_t platformfs_lseek_r( int fd, off_t off, int whence )
{
    int ret = 0;

    ret = IVTBL(seek_file)(fd, off, whence);

    return ret < 0 ? -1 : ret;
}

static const DM_DEVICE platform_fs_device = 
{
  "/",
  platformfs_open_r,         // open
  platformfs_close_r,        // close
  platformfs_write_r,        // write
  platformfs_read_r,         // read
  platformfs_lseek_r,        // lseek
  NULL,      // opendir
  NULL,      // readdir
  NULL      // closedir
};

const DM_DEVICE* platform_fs_init(void)
{
    return &platform_fs_device;
}

