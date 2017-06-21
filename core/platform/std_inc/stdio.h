#ifndef STDIO_H
#define	STDIO_H

#ifdef __cplusplus
extern "C" {
#endif


#include "stddef.h"
// Don't touch the next line. This is to use the compiler
// dependent header
#include <stdarg.h>

/* Standard sprintf() function. Work as the libc one. */
int sprintf(char * buf, const char *fmt, ...);
/* Standard snprintf() function from BSD, more secure... */
int snprintf(char * buf, size_t len, const char *fmt, ...);
/* Standard sscanf() function. Work as the libc one. */
int sscanf(const char * buf, const char * fmt, ...);
/*+\NewReq NEW\zhuth\2013.8.16\实现mysscanf函数（平台提供的sscanf函数有问题，不能正常使用）*/
int mysscanf(const char *buf, const char *fmt, ...);
/*-\NewReq NEW\zhuth\2013.8.16\实现mysscanf函数（平台提供的sscanf函数有问题，不能正常使用）*/
/* If you need to code your own printf... */
int vsprintf(char *buf, const char *fmt, va_list ap);
int vsnprintf(char *buf, size_t size, const char *fmt, va_list ap);
int vsscanf (const char *fp, const char *fmt0, va_list ap);
/*+\BUG WM-85\xiongjunqun\2012.01.16\清理编译过程中的warning*/  
int printf(const char* fmt, ...);
/*-\BUG WM-85\xiongjunqun\2012.01.16\清理编译过程中的warning*/  
#ifdef __cplusplus
}
#endif

#endif /* STDIO_H */



