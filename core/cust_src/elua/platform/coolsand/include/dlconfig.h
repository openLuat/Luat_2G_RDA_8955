/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    dlconfig.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/5/4
 *
 * Description:
 *          dlmalloc配置文件
 **************************************************************************/

#if !defined(_DL_CONFIG_H_)
#define _DL_CONFIG_H_

#define HAVE_MMAP 1
#define HAVE_MORECORE 0

#define LACKS_SYS_PARAM_H
#define LACKS_SYS_MMAN_H
#define LACKS_TIME_H

#define LACKS_STRINGS_H
#define LACKS_SYS_TYPES_H
#include "stddef.h"

#define USE_LOCKS 0

#define LACKS_SCHED_H
#ifndef MALLOC_FAILURE_ACTION
#define MALLOC_FAILURE_ACTION
#endif

#if defined(DLMALLOC_DEFAULT_GRANULARITY)
#define DEFAULT_GRANULARITY ((size_t)(DLMALLOC_DEFAULT_GRANULARITY))
#else
/*定义mmap从系统堆中一次分配的内存大小为256K*/
#define DEFAULT_GRANULARITY ((size_t)256U * (size_t)1024U)
#endif

#define DEBUG 1
#define ABORT_ON_ASSERT_FAILURE 0
#define assert              ASSERT
#define ABORT

#endif/*_DL_CONFIG_H_*/
