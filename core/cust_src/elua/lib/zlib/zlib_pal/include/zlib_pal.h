#ifndef _ZLIB_PAL_H_
#define _ZLIB_PAL_H_

#include "reent.h"
#include "assert.h"

#define open _open_r
#define read _read_r
#define write _write_r
#define close _close_r
#define lseek _lseek_r

#define zlib_assert ASSERT 

#endif
