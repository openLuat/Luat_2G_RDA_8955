/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    fcntl.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/11/27
 *
 * Description:
 * 
 **************************************************************************/

#ifndef __FCNTL_H__
#define __FCNTL_H__

#define O_ACCMODE 00000003
#define O_RDONLY 00000000
#define O_WRONLY 00000001
#define O_RDWR 00000002

#ifndef O_CREAT
#define O_CREAT 00000100  
#endif

#ifndef O_EXCL
#define O_EXCL 00000200  
#endif

#ifndef O_TRUNC
#define O_TRUNC 00001000  
#endif

#ifndef O_APPEND
#define O_APPEND 00002000
#endif

#endif //__FCNTL_H__