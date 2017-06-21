
#include "rda_pal.h"
#include "string.h"
#include "assert.h"

void* platform_malloc( size_t size )
{
    return IVTBL(malloc)( size );
}

void* platform_calloc( size_t nelem, size_t elem_size )
{
    void *p;

    ASSERT(nelem*elem_size);

    p = IVTBL(malloc)(nelem*elem_size);

    memset(p, 0, nelem*elem_size);

    return p;
}

void platform_free( void* ptr )
{
    IVTBL(free)( ptr );
}

void* platform_realloc( void* ptr, size_t size )
{
    return IVTBL(realloc)( ptr, size );
}

