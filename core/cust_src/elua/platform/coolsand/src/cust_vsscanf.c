/******************************************************************\
 * This code is derived from NetBSD code, for which the following *
 * copyright notice applies.                                      *
 ******************************************************************/

/*-
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Chris Torek.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include "stddef.h"
#include "stdio.h"
#include "stdlib.h"
#include "ctype.h"


#define	BUF		513	/* Maximum length of numeric string. */

/*
 * Flags used during conversion.
 */
/*+\BUG WM-85\xiongjunqun\2012.01.16\清理编译过程中的warning*/ 
#define	LONG_FLAGS	0x0001	/* l: long or double */
/*-\BUG WM-85\xiongjunqun\2012.01.16\清理编译过程中的warning*/
#define	SHORT		0x0004	/* h: short */
#define	SHORTSHORT	0x0008	/* hh: short short */
#define	SUPPRESS	0x0200	/* suppress assignment */
#define	NOSKIP		0x0800	/* do not skip blanks */
 
/*
 * The following are used in numeric conversions only:
 * SIGNOK, NDIGITS, DPTOK, and EXPOK are for floating point;
 * SIGNOK, NDIGITS, PFXOK, and NZDIGITS are for integral.
 */
#define	SIGNOK		0x0800	/* +/- is (still) legal */
#define	HAVESIGN	0x1000	/* sign detected */
#define	NDIGITS		0x2000	/* no digits detected */

#define	PFXOK		0x4000	/* 0x prefix is (still) legal */
#define	NZDIGITS	0x8000	/* no zero digits detected */

/*
 * Conversion types.
 */
#define	CT_CHAR		0	/* %c conversion */
#define	CT_STRING	2	/* %s conversion */
#define	CT_INT		3	/* integer, i.e., strtol or strtoul */
#define	CT_FLOAT	4	/* floating, i.e., strtod */

/*
 * vsscanf
 * Derived from original NetBSD vfscanf
 */
int
vsscanf (const char *fp, const char *fmt0, va_list ap)
{
	const unsigned char *fmt = (const unsigned char *)fmt0;
	int c;		/* character from format, or conversion */
	size_t width;	/* field width, or 0 */
	char *p;	/* points into all kinds of strings */
	int n;		/* handy integer */
	int flags;	/* flags as defined above */
	char *p0;	/* saves original value of p when necessary */
	int nassigned;		/* number of fields assigned */
	int nread;		/* number of characters consumed from fp */
	int base;		/* base argument to strtol/strtoul */
	uintmax_t (*ccfn) __P((const char *, char **, int));
				/* conversion function (strtol/strtoul) */
	char buf[BUF];		/* buffer for numeric conversions */

	/* `basefix' is used to avoid `if' tests in the integer scanner */
	static const short basefix[17] =
		{ 10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

	nassigned = 0;
	nread = 0;
	base = 0;		/* XXX just to keep gcc happy */
	ccfn = NULL;		/* XXX just to keep gcc happy */
	for (;;) {
		c = *fmt++;
		if (c == 0) {
			return (nassigned);
		}
		if (isspace(c)) {
			while (isspace(*fp++))
				nread++;
			continue;
		}
		if (c != '%')
			goto literal;
		width = 0;
		flags = 0;
		/*
		 * switch on the format.  continue if done;
		 * break once format type is derived.
		 */
again:		c = *fmt++;
		switch (c) {
		/* This is for %% ... */
		case '%':
literal:
			if (!*fp)
				goto input_failure;
			if (*fp != c)
				goto match_failure;
			fp++;
			nread++;
			continue;

		case '*':
			flags |= SUPPRESS;
			goto again;
		case 'h':
			if (*fmt == 'h') {
				fmt++;
				flags |= SHORTSHORT;
			} else {
				flags |= SHORT;
			}
			goto again;
		case 'l':
			flags |= LONG_FLAGS;
			goto again;

		case '0': case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
			width = width * 10 + c - '0';
			goto again;

		case 'd':
			c = CT_INT;
			ccfn = (uintmax_t (*) __P((const char *, char **, int)))strtol;
			base = 10;
			break;

		case 'i':
			c = CT_INT;
			ccfn = (uintmax_t (*) __P((const char *, char **, int)))strtol;
			base = 0;
			break;

		case 'o':
			c = CT_INT;
			ccfn = strtoul;
			base = 8;
			break;

		case 'u':
			c = CT_INT;
			ccfn = strtoul;
			base = 10;
			break;

		case 'x':
			flags |= PFXOK;	/* enable 0x prefixing */
			c = CT_INT;
			ccfn = strtoul;
			base = 16;
			break;

		case 's':
			c = CT_STRING;
			break;

		case 'c':
			flags |= NOSKIP;
			c = CT_CHAR;
			break;

		case 'n':
			if (flags & SUPPRESS)	/* ??? */
				continue;
			if (flags & SHORT)
				*va_arg(ap, short *) = nread;
			else if (flags & SHORTSHORT)
				*va_arg(ap, char *) = nread;
			else if (flags & LONG_FLAGS)
				*va_arg(ap, long *) = nread;
			else
				*va_arg(ap, int *) = nread;
			continue;
			/* TODO : sensible default ?*/
		}

		/*
		 * We have a conversion that requires input.
		 */
		if (!*fp)
			goto input_failure;

		/*
		 * Consume leading white space, except for formats
		 * that suppress this.
		 */
		if ((flags & NOSKIP) == 0) {
			while (isspace(*fp)) {
				nread++;
				if (!(++fp < INT_MAX && (*fp)))
					goto input_failure;
			}
			/*
			 * Note that there is at least one character in
			 * the buffer, so conversions that do not set NOSKIP
			 * ca no longer result in an input failure.
			 */
		}

		/*
		 * Do the conversion.
		 */
		switch (c) {

		case CT_CHAR:
			/* scan arbitrary characters (sets NOSKIP) */
			if (width == 0)
				width = 1;
			if (flags & SUPPRESS) {
				size_t sum = 0;
				for (;(width && (fp++ < INT_MAX) && (*fp));) {
						++sum;
						--width;
				}
				if (width) {
						goto input_failure;
						break;
				}
				nread += sum;
			} else {
				p = (char *)va_arg(ap, char *);
				*p = *fp;
				nread++ ;
				nassigned++;
			}
			break;

		case CT_STRING:
			if (width == 0)
				width = ~0U;
			if (flags & SUPPRESS) {
				n = 0;
				while (!isspace(*fp) && (fp < INT_MAX)) {
					n++; 
					fp++;
					if (--width == 0)
						break;
					if (!*fp)
						break;
				}
				nread += n;
			} else {
				p0 = p = va_arg(ap, char *);
				while (!isspace(*fp) && (fp < INT_MAX)) {
					*p++ = *fp++;
					if (--width == 0)
						break;
					if (!*fp)
						break;
				}
				*p = 0;
				nread += p - p0;
				nassigned++;
			}
			continue;

		case CT_INT:
			/* scan an integer as if by strtol/strtoul */
			if (width == 0 || width > sizeof(buf) - 1)
				width = sizeof(buf) - 1;

			flags |= SIGNOK | NDIGITS | NZDIGITS;
			for (p = buf; width; width--) {
				c = *fp;
				/*
				 * Switch on the character; `goto ok'
				 * if we accept it as a part of number.
				 */
				switch (c) {

				/*
				 * The digit 0 is always legal, but is
				 * special.  For %i conversions, if no
				 * digits (zero or nonzero) have been
				 * scanned (only signs), we will have
				 * base==0.  In that case, we should set
				 * it to 8 and enable 0x prefixing.
				 * Also, if we have not scanned zero digits
				 * before this, do not turn off prefixing
				 * (someone else will turn it off if we
				 * have scanned any nonzero digits).
				 */
				case '0':
					if (base == 0) {
						base = 8;
						flags |= PFXOK;
					}
					if (flags & NZDIGITS)
					    flags &= ~(SIGNOK|NZDIGITS|NDIGITS);
					else
					    flags &= ~(SIGNOK|PFXOK|NDIGITS);
					goto ok;

				/* 1 through 7 always legal */
				case '1': case '2': case '3':
				case '4': case '5': case '6': case '7':
					base = basefix[base];
					flags &= ~(SIGNOK | PFXOK | NDIGITS);
					goto ok;

				/* digits 8 and 9 ok iff decimal or hex */
				case '8': case '9':
					base = basefix[base];
					if (base <= 8)
						break;	/* not legal here */
					flags &= ~(SIGNOK | PFXOK | NDIGITS);
					goto ok;

				/* letters ok iff hex */
				case 'A': case 'B': case 'C':
				case 'D': case 'E': case 'F':
				case 'a': case 'b': case 'c':
				case 'd': case 'e': case 'f':
					/* no need to fix base here */
					if (base <= 10)
						break;	/* not legal here */
					flags &= ~(SIGNOK | PFXOK | NDIGITS);
					goto ok;

				/* sign ok only as first character */
				case '+': case '-':
					if (flags & SIGNOK) {
						flags &= ~SIGNOK;
						flags |= HAVESIGN;
						goto ok;
					}
					break;

				/*
				 * x ok iff flag still set and 2nd char (or
				 * 3rd char if we have a sign).
				 */
				case 'x': case 'X':
					if (flags & PFXOK && p ==
					    buf + 1 + !!(flags & HAVESIGN)) {
						base = 16;	/* if %i */
						flags &= ~PFXOK;
						goto ok;
					}
				default:
					break;
				}

				/*
				 * If we got here, c is not a legal character
				 * for a number.  Stop accumulating digits.
				 */
				break;
		ok:
				/*
				 * c is legal: store it and look at the next.
				 */
				*p++ = c;
				fp++;
				/* 
				 * TODO I wish I knew why we need isspace here. 
				 * But Murphy won't tell me. Bastard.
				 */
				if (!*fp || isspace (*fp) ) break;

			} /* End for */
			/*
			 * If we had only a sign, it is no good; push
			 * back the sign.  If the number ends in `x',
			 * it was [sign] '0' 'x', so push back the x
			 * and treat it as [sign] '0'.
			 */
			/* Don't need to push back anything...*/
			if (flags & NDIGITS) {
				goto match_failure;
			}
			c = ((unsigned char *)p)[-1];
			if (c == 'x' || c == 'X') {
				--p;
			}
			if ((flags & SUPPRESS) == 0) {
				uintmax_t res;

				*p = 0;
				res = (*ccfn)(buf, (char **)NULL, base);
				if (flags & LONG_FLAGS)
					*va_arg(ap, long *) = (long)res;
				else if (flags & SHORT)
					*va_arg(ap, short *) = (short)res;
				else if (flags & SHORTSHORT)
					*va_arg(ap, char *) = (char)res;
				else
					*va_arg(ap, int *) = (int)res;
				nassigned++;
			}
			nread += p - buf;
			break;
		}
	}
input_failure:
	return (nassigned ? nassigned : -1);
match_failure:
	return (nassigned);
}

int sscanf(const char * buf, const char * fmt, ...)
{
	va_list args;
	int i;

	va_start(args,fmt);
	i = vsscanf(buf,fmt,args);
	va_end(args);
	return i;
}
