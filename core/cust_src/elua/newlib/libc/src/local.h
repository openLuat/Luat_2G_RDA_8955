/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    local.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/11/28
 *
 * Description:
 * 
 **************************************************************************/

#ifndef __LOCAL_H__
#define __LOCAL_H__

FILE	*__sfp(void);
int	__sread(void *, char *, int);
int	__swrite(void *, const char *, int);
fpos_t	__sseek(void *, fpos_t, int);
int	__sclose(void *);
int	__sflags(const char *, int *);

/*
 * Return true if the given FILE cannot be written now.
 */
#if 0
#define	cantwrite(fp) \
	((((fp)->_flags & __SWR) == 0 || (fp)->_bf._base == NULL) && \
	 __swsetup(fp))
#else
// 简易的stdio实现判断flags支持写即可
#define	cantwrite(fp) \
	(((fp)->_flags & (__SWR|__SRW)) == 0)
#endif

#endif //__LOCAL_H__

