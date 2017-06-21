/******************************************************************************/
/*              Copyright (C) 2003, Coolsand Technologies, Inc.               */
/*                            All Rights Reserved                             */
/******************************************************************************/
/* Filename:  setjmp.h														  */
/* Description:                                                               */
/*   Setjmp and longjmp prototype. POSIX standard.                            */
/*   Define jump buffer layout for MIPS setjmp/longjmp.                       */
/********************************a**********************************************/

// Attention: these functions are implemented in HAL

#ifndef SETJMP_H
#define SETJMP_H
#ifdef __cplusplus
extern "C" {
#endif


#ifdef FPU
typedef unsigned long jmp_buf[22];

#else
typedef unsigned long jmp_buf[12];
#endif

int  setjmp (jmp_buf env);
 
volatile void longjmp (jmp_buf env,  int value);
 
#ifdef __cplusplus
}
#endif
#endif //SETJMP_H

