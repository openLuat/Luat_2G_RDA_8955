
#ifndef _RDA_PAL_H_
#define _RDA_PAL_H_

#include "am_openat.h"

extern T_AMOPENAT_INTERFACE_VTBL * g_s_InterfaceVtbl;

#define IVTBL(func) (g_s_InterfaceVtbl->func)

#define PUB_TRACE(pFormat, ...)  IVTBL(print)(pFormat, ##__VA_ARGS__)

#endif

