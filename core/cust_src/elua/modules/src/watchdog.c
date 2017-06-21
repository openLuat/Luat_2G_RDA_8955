/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    watchdog.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2014/4/5
 *
 * Description:
 *          lua.watchdog watchdog∑√Œ ø‚
 **************************************************************************/

#include <stdlib.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "platform.h"
#include "lrotable.h"
#include "platform_conf.h"
#include "platform_watchdog.h"

// watchdog.open(mode[,io])
static int l_watchdog_open(lua_State *L) {
    watchdog_info_t info;

    info.mode = luaL_checkinteger(L, 1);
    info.param.pin_ctl = luaL_checkinteger(L, 2);
    
    lua_pushinteger(L, platform_watchdog_open(&info));
    
    return 1; 
}

// watchdog.close()
static int l_watchdog_close(lua_State *L) {
    lua_pushinteger(L, platform_watchdog_close());
    return 1; 
}

// watchdog.kick()
static int l_watchdog_kick(lua_State *L) {
    lua_pushinteger(L, platform_watchdog_kick());
    return 1; 
}

#define MIN_OPT_LEVEL 2
#include "lrodefs.h"  

// Module function map
const LUA_REG_TYPE watchdog_map[] =
{ 
  { LSTRKEY( "open" ),  LFUNCVAL( l_watchdog_open ) },
  { LSTRKEY( "close" ),  LFUNCVAL( l_watchdog_close ) },
  { LSTRKEY( "kick" ),  LFUNCVAL( l_watchdog_kick ) },

  { LNILKEY, LNILVAL }
};

LUALIB_API int luaopen_watchdog( lua_State *L )
{
    luaL_register( L, AUXLIB_WATCHDOG, watchdog_map );
    
    MOD_REG_NUMBER(L, "DEFAULT", WATCHDOG_DEFAULT_MODE);

    return 1;
}  
