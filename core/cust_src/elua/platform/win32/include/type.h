
//如果已经包含cs_types.h 则不再重复包含这个文件
#ifdef __CS_TYPE_H__
#define __TYPE_H__
#endif

#ifndef __TYPE_H__
#define __TYPE_H__

#ifndef NULL
#define NULL    ((void *)0)
#endif

#ifndef FALSE
#define FALSE   (0)
#endif

#ifndef TRUE
#define TRUE    (1)
#endif

#ifndef MAX
#define MAX(a,b)                        (((a) > (b)) ? (a) : (b))
#endif

#ifndef MIN
#define MIN(a,b)                        (((a) < (b)) ? (a) : (b))
#endif

typedef unsigned char   BYTE;
typedef unsigned short  WORD;

#ifndef DWORD
#define DWORD unsigned int
#endif

#ifndef BOOL
#define BOOL unsigned char
#endif

typedef unsigned char u8;
typedef signed char s8;
typedef unsigned short u16;
typedef signed short s16;
typedef unsigned int u32;
typedef signed int s32;
typedef unsigned long u64;
typedef long s64;

#ifndef _ssize_t
typedef int                         _ssize_t;
#endif

typedef long		off_t;

typedef char                        ascii;
typedef unsigned char               byte;           /*  unsigned 8-bit data     */
typedef unsigned short              word;           /*  unsigned 16-bit data    */
typedef unsigned long               dword;          /*  unsigned 32-bit data    */
typedef unsigned char               uint8;
typedef signed char                 int8;
typedef unsigned short int          uint16;
typedef signed short int            int16;
typedef unsigned int                uint32;
typedef signed int                  int32;
typedef char                        boolean;

#endif
