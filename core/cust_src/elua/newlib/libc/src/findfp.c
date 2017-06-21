/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    findfp.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/11/28
 *
 * Description:
 *    暂只支持静态分配文件指针, 静态空间不足后动态分配功能后续开发
 **************************************************************************/

#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include "local.h"
#include "glue.h"

#define FOPEN_MAX 20

#define	std(flags, file) {flags,file,__sF+file,__sclose,__sread,__sseek,__swrite,0}

FILE __sF[3] = {
    std(__SRD, STDIN_FILENO),          /* stdin */
    std(__SWR, STDOUT_FILENO),         /* stdout */
    std(__SWR|__SNBF, STDERR_FILENO)          /* stderr */
};

/* the usual - (stdin + stdout + stderr) */
static FILE usual[FOPEN_MAX - 3];
static struct glue uglue = { 0, FOPEN_MAX - 3, usual };

struct glue __sglue = { &uglue, 3, __sF };

/*
 * Find a free FILE for fopen et al.
 */
FILE *
__sfp(void)
{
	FILE *fp;
	int n;
	struct glue *g;

	for (g = &__sglue;; g = g->next) {
		for (fp = g->iobs, n = g->niobs; --n >= 0; fp++)
			if (fp->_flags == 0)
				goto found;
		if (g->next == NULL)
			break;
	}
	return (NULL);
    
found:
	fp->_flags = 1;		/* reserve this slot; caller sets real flags */

	return (fp);
}

