/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    malloc.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/15
 *
 * Description:
 * 
 **************************************************************************/
#ifndef __MALLOC_H__
#define __MALLOC_H__

#undef realloc
#define realloc  lualibc_realloc

#undef malloc
#define malloc   lualibc_malloc

#undef calloc
#define calloc   lualibc_calloc

#undef free
#define free     lualibc_free

void *lualibc_calloc(size_t, size_t);
void  lualibc_free(void *);
void *lualibc_malloc(size_t);
void *lualibc_realloc(void *, size_t);

void *_calloc_r(size_t, size_t);
void  _free_r(void *);
void *_malloc_r(size_t);
void *_realloc_r(void *, size_t);

#endif //__MALLOC_H__
