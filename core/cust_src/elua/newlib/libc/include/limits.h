/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    limits.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/8/1
 *
 * Description:
 * 
 **************************************************************************/
#ifndef __LIMITS_H__
#define __LIMITS_H__

#define	CHAR_BIT	8		/* number of bits in a char */

#define	SCHAR_MAX	0x7f		/* max value for a signed char */
#define SCHAR_MIN	(-0x7f-1)	/* min value for a signed char */

#ifndef UCHAR_MAX
#define	UCHAR_MAX	0xffU		/* max value for an unsigned char */
#endif

#ifdef __machine_has_unsigned_chars
# define CHAR_MIN	0		/* min value for a char */
# define CHAR_MAX	0xff		/* max value for a char */
#else
# define CHAR_MAX	0x7f
# define CHAR_MIN	(-0x7f-1)
#endif

#ifndef USHRT_MAX
#define	USHRT_MAX	0xffffU		/* max value for an unsigned short */
#endif

#define	SHRT_MAX	0x7fff		/* max value for a short */
#define SHRT_MIN        (-0x7fff-1)     /* min value for a short */

#define	UINT_MAX	0xffffffffU	/* max value for an unsigned int */

//cs_types.h 加了void *强转会导致luaconf.h定义出现问题
#undef INT_MAX
#define	INT_MAX		0x7fffffff	/* max value for an int */

#ifndef INT_MIN
#define	INT_MIN		(-0x7fffffff-1)	/* min value for an int */
#endif

#ifndef ULONG_MAX
# define ULONG_MAX	0xffffffffUL	/* max value for an unsigned long */
#endif

#ifndef LONG_MAX
# define LONG_MAX	0x7fffffffL	/* max value for a long */
#endif

#ifndef LONG_MIN
# define LONG_MIN	(-0x7fffffffL-1)/* min value for a long */
#endif

# define LONG_BIT	32

#endif //__LIMITS_H__
