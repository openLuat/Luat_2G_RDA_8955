/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    gps.c
 * Author:  zhutianhua
 * Version: V0.1
 * Date:    2014/8/6
 *
 * Description:
 *          lua.gpscore gpscore∑√Œ ø‚
 **************************************************************************/

#include <stdlib.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "platform.h"
#include "lrotable.h"
#include "platform_conf.h"
#include "platform_gps.h"

// gpscore.open()
static int l_gps_open(lua_State *L) {
    lua_pushinteger(L, platform_gps_open());    
    return 1; 
}

// gpscore.close()
static int l_gps_close(lua_State *L) {
    lua_pushinteger(L, platform_gps_close());
    return 1; 
}


#define MIN_OPT_LEVEL 2
#include "lrodefs.h"  

// Module function map
const LUA_REG_TYPE gpscore_map[] =
{ 
  { LSTRKEY( "open" ),  LFUNCVAL( l_gps_open ) },
  { LSTRKEY( "close" ),  LFUNCVAL( l_gps_close ) },
 
  { LNILKEY, LNILVAL }
};

LUALIB_API int luaopen_gpscore( lua_State *L )
{
    luaL_register( L, AUXLIB_GPSCORE, gpscore_map );
    return 1;
}  
