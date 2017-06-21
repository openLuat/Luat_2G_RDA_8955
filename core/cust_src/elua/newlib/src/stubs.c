// Newlib stubs implementation

#include <reent.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#include "devman.h"
#include "ioctl.h"
#include "platform.h"
#include "platform_conf.h"
#include "platform_stubs.h"
#include "platform_sys.h"
#include "genstd.h"
#include "utils.h"
#include "assert.h"

// Utility function: look in the device manager table and find the index
// for the given name. Returns an index into the device structure, -1 if error.
// Also returns a pointer to the actual file name (without the device part)
static int find_dm_entry( const char* name, char **pactname )
{
  int i;
  const DM_DEVICE* pdev;
  const char* preal;
  char tempname[ DM_MAX_DEV_NAME + 1 ];
  int devrootIndex = -1;
  
  // Sanity check for name
  if( name == NULL || *name == '\0' || *name != '/' )
    return -1;
    
  // Find device name
  preal = strchr( name + 1, '/' );
  if( preal == NULL )
  {
    // This shortcut allows to register the "/" filesystem and use it like "/file.ext"
    strcpy( tempname, "/" );
    preal = name;
  }
  else
  {
    if( ( preal - name > DM_MAX_DEV_NAME ) || ( preal - name == 1 ) ) // name too short/too long
      return -1;
    memcpy( tempname, name, preal - name );
    tempname[ preal - name ] = '\0';
  }
    
/*+\NEW\liweiqiang\2013.5.11\目录下文件无法正常访问*/
  // Find device
  for( i = 0; i < dm_get_num_devices(); i ++ )
  {
    pdev = dm_get_device_at( i );
    if( !strcasecmp( tempname, pdev->name ) )
      break;

    if(pdev->name[0] == '/' && pdev->name[1] == 0x00)
      devrootIndex = i;
  }
  
  if( i == dm_get_num_devices())
  {
    if(devrootIndex == -1)
        return -1;
    
    i = devrootIndex;
    preal = name;
  }
/*-\NEW\liweiqiang\2013.5.11\目录下文件无法正常访问*/
    
  // Find the actual first char of the name
  preal ++;
  if( *preal == '\0' )
    return -1;
  *pactname = ( char * )preal;
  return i;  
}

// *****************************************************************************
// _open_r
int _open_r( const char *name, int flags, int mode )
{
  char* actname;
  int res, devid;
  const DM_DEVICE* pdev;
 
  // Look for device, return error if not found or if function not implemented
  if( ( devid = find_dm_entry( name, &actname ) ) == -1 )
  {
    errno = ENODEV;
    return -1; 
  }
  pdev = dm_get_device_at( devid );
  if( pdev->p_open_r == NULL )
  {
    errno = ENOSYS;
    return -1;   
  }
  
  // Device found, call its function
  if( ( res = pdev->p_open_r( actname, flags, mode ) ) < 0 )
  {
/*+\NEW\liweiqiang\2014.2.13\增加fopen error值设置 */
    errno = res;
/*-\NEW\liweiqiang\2014.2.13\增加fopen error值设置 */
    return res;
  }
  return DM_MAKE_DESC( devid, res );
}

// *****************************************************************************
// _close_r
int _close_r( int file )
{
  const DM_DEVICE* pdev;
  
  // Find device, check close function
  pdev = dm_get_device_at( DM_GET_DEVID( file ) );
  if( pdev->p_close_r == NULL )
  {
    errno = ENOSYS;
    return -1; 
  }
  
  // And call the close function
  return pdev->p_close_r( DM_GET_FD( file ) );
}

#if 0
// *****************************************************************************
// _fstat_r (not implemented)
int _fstat_r( int file, struct stat *st )
{
  if( ( file >= DM_STDIN_NUM ) && ( file <= DM_STDERR_NUM ) )
  {
    st->st_mode = S_IFCHR;
    return 0;
  }
  errno = ENOSYS;
  return -1;
}
#endif

// *****************************************************************************
// _lseek_r
off_t _lseek_r( int file, off_t off, int whence )
{
  const DM_DEVICE* pdev;
  
  // Find device, check close function
  pdev = dm_get_device_at( DM_GET_DEVID( file ) );
  if( pdev->p_lseek_r == NULL )
  {
    errno = ENOSYS;
    return -1; 
  }
  
  // And call the close function
  return pdev->p_lseek_r( DM_GET_FD( file ), off, whence );
}

// *****************************************************************************
// _read_r 
_ssize_t _read_r( int file, void *ptr, size_t len )
{
  const DM_DEVICE* pdev;
  
  // Find device, check read function
  pdev = dm_get_device_at( DM_GET_DEVID( file ) );
  if( pdev->p_read_r == NULL )
  {
    errno = ENOSYS;
    return -1; 
  }
  
  // And call the read function
  return pdev->p_read_r( DM_GET_FD( file ), ptr, len );  
}

// *****************************************************************************
// _write_r 
_ssize_t _write_r( int file, const void *ptr, size_t len )
{
  const DM_DEVICE* pdev;
  
  // Find device, check write function
  pdev = dm_get_device_at( DM_GET_DEVID( file ) );
  if( pdev->p_write_r == NULL )
  {
    errno = ENOSYS;
    return -1; 
  }
  
  // And call the write function
  return pdev->p_write_r( DM_GET_FD( file ), ptr, len );  
}

/*+\NEW\liweiqiang\2013.5.11\增加remove接口*/
int _unlink_r(const char *path)
{
  return platform_sys_unlink(path);
}
/*-\NEW\liweiqiang\2013.5.11\增加remove接口*/

// ****************************************************************************
// Miscalenous functions

int _isatty_r( int fd )
{
  return 1;
}

int _vfprintf_r(FILE *fp, const char *fmt, va_list ap)
{
    return platform_vfprintf(fp, fmt, ap);
}

/*+\NEW\liweiqiang\2013.12.6\对于超过500K的dl内存池,那么伪libc的malloc从dlmalloc分配 */
#if defined(USE_DLMALLOC_ALLOCATOR)
#include "dlmalloc.h"
#define CNAME(func) dl##func
#elif defined(USE_PLATFORM_ALLOCATOR)
#define CNAME(func) platform_##func
#endif
/*-\NEW\liweiqiang\2013.12.6\对于超过500K的dl内存池,那么伪libc的malloc从dlmalloc分配 */

// Redirect all allocator calls to platform memory function
void* _malloc_r( size_t size )
{
    return CNAME( malloc )( size );
}

void* _calloc_r( size_t nelem, size_t elem_size )
{
    return CNAME( calloc )( nelem, elem_size );
}

void _free_r( void* ptr )
{
    CNAME( free )( ptr );
}

void* _realloc_r( void* ptr, size_t size )
{
    return CNAME( realloc )( ptr, size );
}

// *****************************************************************************
// eLua stubs (not Newlib specific)

#if !defined( BUILD_CON_GENERIC ) && !defined( BUILD_CON_TCP )

// Set send/recv functions
void std_set_send_func( p_std_send_char pfunc )
{
}

void std_set_get_func( p_std_get_char pfunc )
{
}

const DM_DEVICE* std_get_desc()
{
  return NULL;
}

#endif // #if !defined( BUILD_CON_GENERIC ) && !defined( BUILD_CON_TCP )

