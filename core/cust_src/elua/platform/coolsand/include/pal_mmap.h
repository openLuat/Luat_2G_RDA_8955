/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    pal_mmap.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/5/4
 *
 * Description:
 *          适配dlmalloc使用的平台mmap接口
 **************************************************************************/

#ifndef _PAL_MMAP_H_
#define _PAL_MMAP_H_

#include "platform_malloc.h"

static FORCEINLINE void* palmmap(size_t size) {
  void* ptr = platform_malloc(size);
  return (ptr != 0)? ptr: MFAIL;
}

/* This function supports releasing coalesed segments */
static FORCEINLINE int palmunmap(void* ptr, size_t size) {
  platform_free(ptr);
  return 0;
}

#define MMAP_DEFAULT(s)             palmmap(s)
#define MUNMAP_DEFAULT(a, s)        palmunmap((a), (s))
#define DIRECT_MMAP_DEFAULT(s)      palmmap(s)

#endif/*_PAL_MMAP_H_*/

