/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    reent.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/20
 *
 * Description:
 * 
 **************************************************************************/

#ifndef __REENT_H__
#define __REENT_H__

#include "_types.h"
#include "stddef.h"

int _open_r( const char *name, int flags, int mode );
int _close_r( int file );
_ssize_t _write_r( int file, const void *ptr, size_t len );
_ssize_t _read_r( int file, void *ptr, size_t len );
off_t _lseek_r( int file, off_t off, int whence );

/*+\NEW\liweiqiang\2013.5.11\增加remove接口*/
int _unlink_r(const char *path);
/*-\NEW\liweiqiang\2013.5.11\增加remove接口*/

#endif //__REENT_H__
