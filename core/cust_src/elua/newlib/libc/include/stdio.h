/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    stdio.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/15
 *
 * Description:
 * 
 **************************************************************************/
#ifndef __STDIO_H__
#define __STDIO_H__

#include "cdefs.h"
#include "_types.h"

/* va_list and size_t must be defined by stdio.h according to Posix */
//#define __need___va_list  in coolsand support ansi C
#include "stdarg.h"

#ifdef __CS_TYPE_H__
#define	_SIZE_T_DEFINED_
#endif

#ifndef _SIZE_T_DEFINED_
#define	_SIZE_T_DEFINED_
typedef	unsigned int    size_t;
#endif

typedef off_t fpos_t;		/* stdio file position type */

/*+\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/
#ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
typedef enum
{
    COMMON_FILE = 0,
    ENC_FILE = 1,
    LUA_UNCOMPRESS_FILE = 2,
    LUA_UNCOMPRESS_ENC_FILE = 3,
    MAX_EXT_FILE
}E_EXT_FILE_TYPE;
#endif
/*-\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/

#undef FILE
typedef	struct __sFILE {
    //unsigned char *_p;    /* current position in (some) buffer */
    //int	_r;		/* read space left for getc() */
    //int	_w;		/* write space left for putc() */
    short	_flags;		/* flags, below; this FILE is free if 0 */
    short	_file;		/* fileno, if Unix descriptor, else -1 */
    //struct	__sbuf _bf;	/* the buffer (at least 1 byte, if !NULL) */
    //int	_lbfsize;	/* 0 or -_bf._size, for inline putc */
    
    /* operations */
    void	*_cookie;	/* cookie passed to io functions */
    int	(*_close)(void *);
    int	(*_read)(void *, char *, int);
    fpos_t	(*_seek)(void *, fpos_t, int);
    int	(*_write)(void *, const char *, int);
    
    /* extension data, to avoid further ABI breakage */
    //struct	__sbuf _ext;
    /* data for long sequences of ungetc() */
    //unsigned char *_up;	/* saved _p when _p is doing ungetc data */
    //int	_ur;		/* saved _r when _r is counting ungetc data */

    /* tricks to meet minimum requirements even when malloc() fails */
    //unsigned char _ubuf[3];	/* guarantee an ungetc() buffer */
    //unsigned char _nbuf[1];	/* guarantee a getc() buffer */

    /* separate buffer for fgetln() when line crosses buffer boundary */
    //struct	__sbuf _lb;	/* buffer for fgetln() */

    /* Unix stdio files get aligned to block boundaries on fseek() */
    //int	_blksize;	/* stat.st_blksize (may be != _bf._size) */
    fpos_t	_offset;	/* current lseek offset */
    /*+\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/
    #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
    unsigned char _type;
    #endif
    /*-\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/
} FILE;

/*+\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/
#ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
char *fgets_ext(char *buf, int n, FILE *fp);
FILE *fopen_ext(const char *file, const char *mode);
int fclose_ext(FILE *fp);
int getc_ext(FILE *fp);
int ungetc_ext(int c, FILE *fp);
size_t fread_ext(void *buf, size_t size, size_t count, FILE *fp);
int fseek_ext(FILE *fp, long offset, int whence);
long ftell_ext(FILE *fp);
int feof_ext(FILE *fp);
#endif
/*-\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/


__BEGIN_DECLS
extern FILE __sF[];
__END_DECLS

#define	stdin	(&__sF[0])
#define	stdout	(&__sF[1])
#define	stderr	(&__sF[2])

#define	__SLBF	0x0001		/* line buffered */
#define	__SNBF	0x0002		/* unbuffered */
#define	__SRD	0x0004		/* OK to read */
#define	__SWR	0x0008		/* OK to write */
	/* RD and WR are never simultaneously asserted */
#define	__SRW	0x0010		/* open for reading & writing */
#define	__SEOF	0x0020		/* found EOF */
#define	__SERR	0x0040		/* found error */
#define	__SMBF	0x0080		/* _buf is from malloc */
#define	__SAPP	0x0100		/* fdopen()ed in append mode */
#define	__SSTR	0x0200		/* this is an sprintf/snprintf string */
#define	__SOPT	0x0400		/* do fseek() optimisation */
#define	__SNPT	0x0800		/* do not do fseek() optimisation */
#define	__SOFF	0x1000		/* set iff _offset is in fact correct */
#define	__SMOD	0x2000		/* true => fgetln modified _p text */
#define	__SALC	0x4000		/* allocate string space dynamically */

/*
 * The following three definitions are for ANSI C, which took them
 * from System V, which brilliantly took internal interface macros and
 * made them official arguments to setvbuf(), without renaming them.
 * Hence, these ugly _IOxxx names are *supposed* to appear in user code.
 *
 * Although numbered as their counterparts above, the implementation
 * does not rely on this.
 */
#define	_IOFBF	0		/* setvbuf should set fully buffered */
#define	_IOLBF	1		/* setvbuf should set line buffered */
#define	_IONBF	2		/* setvbuf should set unbuffered */

#define	BUFSIZ	1024		/* size of buffer used by setbuf */

#define	EOF	(-1)

/* System V/ANSI C; this is the wrong way to do this, do *not* use these. */
//#if __BSD_VISIBLE || __XPG_VISIBLE
//#define	P_tmpdir	"/tmp/"
//#endif
#define	L_tmpnam	1024	/* XXX must be == PATH_MAX */
#define	TMP_MAX		308915776

#ifndef SEEK_SET
#define	SEEK_SET	0	/* set file offset to offset */
#endif
#ifndef SEEK_CUR
#define	SEEK_CUR	1	/* set file offset to current plus offset */
#endif
#ifndef SEEK_END
#define	SEEK_END	2	/* set file offset to EOF plus offset */
#endif

/*
 * Functions defined in ANSI C standard.
 */
__BEGIN_DECLS

#undef printf
#define printf lualibc_printf
int  lualibc_printf(const char *, ...);

int  sprintf(char *, const char *, ...);

int sscanf(const char * buf, const char * fmt, ...);

#undef fputs
#define fputs lualibc_fputs
int	 lualibc_fputs(const char *, FILE *);

#undef fprintf
#define fprintf lualibc_fprintf
int	 lualibc_fprintf(FILE *, const char *, ...);

#undef fflush
#define fflush lualibc_fflush
int lualibc_fflush(FILE *);

#undef fread
#define fread lualibc_fread
size_t lualibc_fread(void *, size_t, size_t, FILE *);

#undef fwrite
#define fwrite lualibc_fwrite
size_t lualibc_fwrite(const void *, size_t, size_t, FILE *);

#undef fseek
#define fseek lualibc_fseek
int lualibc_fseek(FILE *, long, int);

#undef fgets
#define fgets lualibc_fgets
char *lualibc_fgets(char *, int, FILE *);

#undef fopen
#define fopen lualibc_fopen
FILE *lualibc_fopen(const char *, const char *);

#undef fclose
#define fclose lualibc_fclose
int	lualibc_fclose(FILE *);

#undef putc
#define putc lualibc_putc
int lualibc_putc(int, FILE *);

#define	putchar(x)	putc(x, stdout)

#undef getc
#define getc lualibc_getc
int lualibc_getc(FILE *);

#undef ungetc
#define ungetc lualibc_ungetc
int lualibc_ungetc(int, FILE *);

#undef freopen
#define freopen lualibc_freopen
FILE *lualibc_freopen(const char *, const char *, FILE *);

#undef tmpfile
#define tmpfile lualibc_tmpfile
FILE *lualibc_tmpfile(void);

#undef fscanf
#define fscanf lualibc_fscanf
int lualibc_fscanf(FILE *, const char *, ...);

#undef ftell
#define ftell lualibc_ftell
long lualibc_ftell(FILE *);

#undef setvbuf
#define setvbuf lualibc_setvbuf
int lualibc_setvbuf(FILE *, char *, int, size_t);

/*+\NEW\liweiqiang\2013.5.11\增加remove接口*/
#undef remove
#define remove lualibc_remove
int lualibc_remove(const char *);
/*-\NEW\liweiqiang\2013.5.11\增加remove接口*/

#undef rename
#define rename lualibc_rename
int	lualibc_rename(const char *, const char *);

#undef tmpnam
#define tmpnam lualibc_tmpnam
char* lualibc_tmpnam(char *);

/*+\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/
#ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
#define __sfeof(p)      ((((p)->_type == COMMON_FILE) && (((p)->_flags & __SEOF) != 0)) || (((p)->_type & LUA_UNCOMPRESS_FILE) && feof_ext(p)))
#else
#define __sfeof(p)      (((p)->_flags & __SEOF) != 0)
#endif
/*-\NEW\zhuth\2014.3.2\通过文件记录表访问luadb中未压缩的文件*/
#define __sferror(p)    (((p)->_flags & __SERR) != 0)
#define __sclearerr(p)  ((void)((p)->_flags &= ~(__SERR|__SEOF)))
#define __sfileno(p)    ((p)->_file)

#define feof(p)     __sfeof(p)
#define ferror(p)   __sferror(p)

#ifndef _POSIX_THREADS
#define clearerr(p) __sclearerr(p)
#endif

int _vfprintf_r(FILE *, const char *, va_list);
int vsnprintf(char *buf, size_t size, const char *fmt, va_list ap);
int snprintf(char * buf, size_t len, const char *fmt, ...);

__END_DECLS

#endif //__STDIO_H__
