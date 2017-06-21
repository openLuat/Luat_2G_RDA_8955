/* fpconv - Floating point conversion routines
 *
 * Copyright (c) 2011-2012  Mark Pulford <mark@kyne.com.au>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/* JSON uses a '.' decimal separator. strtod() / sprintf() under C libraries
 * with locale support will break when the decimal separator is a comma.
 *
 * fpconv_* will around these issues with a translation buffer if required.
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <malloc.h>
#include "fpconv.h"

#define assert(x) ASSERT(x)
#define L_MALLOC  malloc
#define L_FREE    free

#ifdef WIN32
#define snprintf _snprintf
#endif

/* Lua CJSON assumes the locale is the same for all threads within a
 * process and doesn't change after initialisation.
 *
 * This avoids the need for per thread storage or expensive checks
 * for call. */
static char locale_decimal_point = '.';

/* In theory multibyte decimal_points are possible, but
 * Lua CJSON only supports UTF-8 and known locales only have
 * single byte decimal points ([.,]).
 *
 * localconv() may not be thread safe (=>crash), and nl_langinfo() is
 * not supported on some platforms. Use sprintf() instead - if the
 * locale does change, at least Lua CJSON won't crash. */

#if 0
void    printch(char *trace_buf,int *trace_num, char ch)
{
    trace_buf[(*trace_num)++] = ch;
}

void    printdec(char *trace_buf,int *trace_num,int dec)
{
    if(dec==0)
    {
        return;
    }
    printdec(trace_buf,trace_num,dec/10);
    printch(trace_buf,trace_num,(char)(dec%10 + '0'));
}

void    printdec_zero(char *trace_buf,int *trace_num,int dec)
{
    if(dec==0)
    	printch(trace_buf,trace_num,'0');
	else
		printdec(trace_buf,trace_num,dec);

}

void printflt(char *trace_buf,int *trace_num, double flt)
{
    int tmpint = 0;
    int precision = 1000000;
    int bit = 0;
    
    tmpint = (int)flt;
    printdec_zero(trace_buf,trace_num,tmpint);
    printch(trace_buf,trace_num,'.');
    flt = flt - tmpint;
    tmpint = (int)(flt * precision);
    precision = precision/10;
    while(precision != 0 && (tmpint/precision) == 0)
    {
        printdec_zero(trace_buf,trace_num,0);
        precision = precision/10;
    }
    //去掉多余的0
    while(tmpint != 0 && ((tmpint%10) == 0))
    {
        tmpint = tmpint/10;
    } 
    printdec_zero(trace_buf,trace_num, tmpint);
 }

void    printstr(char *trace_buf,int *trace_num,char* str)
{
    while(*str)
    {
        printch(trace_buf,trace_num,*str++);
    }
 }

void    printbin(char *trace_buf,int *trace_num,int bin)
{
    
    if(bin == 0)
    {
        printstr(trace_buf,trace_num,"0b");
        return;
    }
    printbin(trace_buf,trace_num,bin/2);
    printch( trace_buf,trace_num,(char)(bin%2 + '0'));
}

void    printhex(char *trace_buf,int *trace_num,int hex)
{
    if(hex==0)
    {
        printstr(trace_buf,trace_num,"0x");
        return;
    }
    printhex(trace_buf,trace_num,hex/16);
    if(hex < 10)
    {
        printch(trace_buf,trace_num,(char)(hex%16 + '0'));
    }
    else
    {
        printch(trace_buf,trace_num,(char)(hex%16 - 10 + 'a' ));
    }
}

int mysnprintf(char* buf, int len, char* fmt, ...)
{
    double vargflt = 0;
    int  vargint = 0;
    char* vargpch = NULL;
    char vargch = 0;
    char* pfmt = NULL;
    va_list vp;
	int index = 0;

	
    va_start(vp, fmt);
    pfmt = fmt;
		
    while(*pfmt)
    {
        if(*pfmt == '%')
        {
            switch(*(++pfmt))
            {
                
                case 'c':
                    vargch = va_arg(vp, int); 
                    printch(buf,&index,vargch);
                    break;
                case 'd':
                case 'i':
                    vargint = va_arg(vp, int);
                    printdec_zero(buf,&index,vargint);
                    break;
                case 'f':
                    vargflt = va_arg(vp, double);
                    printflt(buf,&index,vargflt);
                    break;
                case 's':
                    vargpch = va_arg(vp, char*);
                    printstr(buf,&index,vargpch);
                    break;
                case 'b':
                case 'B':
                    vargint = va_arg(vp, int);
                    printbin(buf,&index,vargint);
                    break;
                case 'x':
                case 'X':
                    vargint = va_arg(vp, int);
                    printhex(buf,&index,vargint);
                    break;
                case '%':
                    printch(buf,&index,'%');
                    break;
                case '.':
                    if(strchr(pfmt, 'g'))
                    {
                        pfmt = strchr(pfmt, 'g');
                    }
                    else
                    {
                        break;
                    }
                case 'g':
                    vargflt = va_arg(vp, double);
                    vargint = (int)vargflt;
                    if(vargflt - vargint == 0)
                    {
                        printdec_zero(buf,&index,(int)vargflt);
                    }
                    else
                    {
                        printflt(buf,&index,vargflt);
                    }
                    break;
                default:
                    break;
            }
            pfmt++;
        }
        else
        {
            printch(buf,&index,*pfmt++);
        }
    }

    buf[index] = 0;
		
    va_end(vp);
    return index;
} 
#endif
static void fpconv_update_locale()
{    
    char buf[8];
    //mysnprintf(buf, sizeof(buf), "%g", 0.5);
    snprintf(buf, sizeof(buf), "%d", 0);

    /* Failing this test might imply the platform has a buggy dtoa
     * implementation or wide characters */
    //if (buf[0] != '1' || buf[2] != '5' || buf[3] != 0) {
    if(buf[0] != '0' || buf[1] != 0) {
        fprintf(stderr, "Error: wide characters found or printf() bug.");
        abort();
    }

    locale_decimal_point = buf[1];
}

/* Check for a valid number character: [-+0-9a-yA-Y.]
 * Eg: -0.6e+5, infinity, 0xF0.F0pF0
 *
 * Used to find the probable end of a number. It doesn't matter if
 * invalid characters are counted - strtod() will find the valid
 * number if it exists.  The risk is that slightly more memory might
 * be allocated before a parse error occurs. */
static inline int valid_number_character(char ch)
{
    char lower_ch;

    if ('0' <= ch && ch <= '9')
        return 1;
    if (ch == '-' || ch == '+' || ch == '.')
        return 1;

    /* Hex digits, exponent (e), base (p), "infinity",.. */
    lower_ch = ch | 0x20;
    if ('a' <= lower_ch && lower_ch <= 'y')
        return 1;

    return 0;
}
#if 0
/* Calculate the size of the buffer required for a strtod locale
 * conversion. */
static int strtod_buffer_size(const char *s)
{
    const char *p = s;

    while (valid_number_character(*p))
        p++;

    return p - s;
}

/* Similar to strtod(), but must be passed the current locale's decimal point
 * character. Guaranteed to be called at the start of any valid number in a string */
double fpconv_strtod(const char *nptr, char **endptr)
{
    char localbuf[FPCONV_G_FMT_BUFSIZE];
    char *buf, *endbuf, *dp;
    int buflen;
    double value;

    /* System strtod() is fine when decimal point is '.' */
    if (locale_decimal_point == '.')
        return strtod(nptr, endptr);

    buflen = strtod_buffer_size(nptr);
    if (!buflen) {
        /* No valid characters found, standard strtod() return */
        *endptr = (char *)nptr;
        return 0;
    }

    /* Duplicate number into buffer */
    if (buflen >= FPCONV_G_FMT_BUFSIZE) {
        /* Handle unusually large numbers */
        buf = (char *)L_MALLOC(buflen + 1);
        if (!buf) {
            fprintf(stderr, "Out of memory");
            abort();
        }
    } else {
        /* This is the common case.. */
        buf = localbuf;
    }
    memcpy(buf, nptr, buflen);
    buf[buflen] = 0;

    /* Update decimal point character if found */
    dp = strchr(buf, '.');
    if (dp)
        *dp = locale_decimal_point;

    value = strtod(buf, &endbuf);
    *endptr = (char *)&nptr[endbuf - buf];
    if (buflen >= FPCONV_G_FMT_BUFSIZE)
        L_FREE(buf);

    return value;
}
#endif

/* "fmt" must point to a buffer of at least 6 characters */
static void set_number_format(char *fmt, double num, int precision)
{
#if 0    
    int d1, d2, i;

    assert(1 <= precision && precision <= 14);


    /* Create printf format (%.14g) from precision */
    d1 = precision / 10;
    d2 = precision % 10;
    fmt[0] = '%';
    fmt[1] = '.';
    i = 2;
    if (d1) {
        fmt[i++] = '0' + d1;
    }
    fmt[i++] = '0' + d2;
    fmt[i++] = 'g';
    fmt[i] = 0;
#else
    fmt[0] = '%';
#if 0 //不支持浮点输出   
    if(num - d1 != 0)
    {
        fmt[1] = 'f';
    }
    else
#endif    
    {
        fmt[1] = 'd';
    }
    fmt[2] = 0;
#endif    
}

/* Assumes there is always at least 32 characters available in the target buffer */
int fpconv_g_fmt(char *str, double num, int precision)
{
    char buf[FPCONV_G_FMT_BUFSIZE];
    char fmt[6];
    int len;
    char *b;

    set_number_format(fmt, num, precision);

    /* Pass through when decimal point character is dot. */
    if (locale_decimal_point == '.')
        //return mysnprintf(str, FPCONV_G_FMT_BUFSIZE, fmt, num);
        //不支持浮点，将num直接转化成int类型
        return snprintf(str, FPCONV_G_FMT_BUFSIZE, fmt, (int)num);

    /* snprintf() to a buffer then translate for other decimal point characters */
    //len = mysnprintf(buf, FPCONV_G_FMT_BUFSIZE, fmt, num);
    len = snprintf(buf, FPCONV_G_FMT_BUFSIZE, fmt, (int)num);

    /* Copy into target location. Translate decimal point if required */
    b = buf;
    do {
        *str++ = (*b == locale_decimal_point ? '.' : *b);
    } while(*b++);

    return len;
}

void fpconv_init()
{
    fpconv_update_locale();
}

/* vi:ai et sw=4 ts=4:
 */
