/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    locale.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/13
 *
 * Description:
 * 
 **************************************************************************/
#ifndef __LOCALE_H__
#define __LOCALE_H__

/* Locale categories */

#define LC_ALL          0
#define LC_COLLATE      1
#define LC_CTYPE        2
#define LC_MONETARY     3
#define LC_NUMERIC      4
#define LC_TIME         5

#define LC_MIN          LC_ALL
#define LC_MAX          LC_TIME

/* Locale convention structure */

#ifndef _LCONV_DEFINED
struct lconv {
        char *decimal_point;
        char *thousands_sep;
        char *grouping;
        char *int_curr_symbol;
        char *currency_symbol;
        char *mon_decimal_point;
        char *mon_thousands_sep;
        char *mon_grouping;
        char *positive_sign;
        char *negative_sign;
        char int_frac_digits;
        char frac_digits;
        char p_cs_precedes;
        char p_sep_by_space;
        char n_cs_precedes;
        char n_sep_by_space;
        char p_sign_posn;
        char n_sign_posn;
        };
#define _LCONV_DEFINED
#endif

/* ANSI: char lconv members default is CHAR_MAX which is compile time
   dependent. Defining and using _charmax here causes CRT startup code
   to initialize lconv members properly */

#ifdef  _CHAR_UNSIGNED
extern int _charmax;
extern __inline int __dummy() { return _charmax; }
#endif

/* function prototypes */

#undef setlocale
#define setlocale lualibc_setlocale
char * lualibc_setlocale(int, const char *);

#undef localeconv
#define localeconv lualibc_localeconv
struct lconv * lualibc_localeconv(void);

#endif //__LOCALE_H__