
#include "rda_pal.h"
#include "assert.h"

void platform_assert(const char *func, int line)
{
    IVTBL(assert)(FALSE, (char *)func, line);
}

