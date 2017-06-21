/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    signal.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/9/14
 *
 * Description:
 * 
 **************************************************************************/
#ifndef __SIGNAL_H__
#define __SIGNAL_H__

#include "compiler.h"
#include "cdefs.h"

__BEGIN_DECLS

#define SIGINT          2       /* interrupt */

#ifndef __ASSEMBLY__
    typedef void __signalfn_t(int);
    typedef __signalfn_t __user *__sighandler_t;
    
    typedef void __restorefn_t(void);
    typedef __restorefn_t __user *__sigrestore_t;
    
#define SIG_DFL ((__force __sighandler_t)0)  
#define SIG_IGN ((__force __sighandler_t)1)  
#define SIG_ERR ((__force __sighandler_t)-1)  
#endif

/* compatibility types */
typedef void  (*sig_t)(int);
typedef sig_t sighandler_t;

#undef signal
#define signal lualibc_signal
__sighandler_t lualibc_signal(int s, __sighandler_t f);

__END_DECLS

#endif //__SIGNAL_H__
