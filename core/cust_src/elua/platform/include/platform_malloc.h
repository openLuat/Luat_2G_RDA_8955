/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_malloc.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/4/5
 *
 * Description:
 *     平台内存池接口
 **************************************************************************/
#ifndef __PLATFORM_MALLOC_H__
#define __PLATFORM_MALLOC_H__

// *****************************************************************************
// platform Allocator support
void* platform_malloc( size_t size );
void* platform_calloc( size_t nelem, size_t elem_size );
void platform_free( void* ptr );
void* platform_realloc( void* ptr, size_t size );

#endif //__PLATFORM_MALLOC_H__
