
#include <stdio.h>
#include <WINDOWS.H>
#include "assert.h"

#include "win_trace.h"

int winTrace(const char *fmt, ...)
{
    char buf[1024+1];
    int len;
    va_list ap;

    va_start(ap, fmt);
    len = vsprintf(buf, fmt, ap);
    va_end(ap);

    buf[len++] = '\r';
    buf[len++] = '\n';
    buf[len++] = '\0';

    ASSERT(len < sizeof(buf));

    OutputDebugString(buf);

    return len;
}