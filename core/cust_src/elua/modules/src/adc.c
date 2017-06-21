/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    adc.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/6/6
 *
 * Description:
 *          lua.adc adc∑√Œ ø‚
 **************************************************************************/

#include <stdlib.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "platform.h"
#include "lrotable.h"
#include "platform_conf.h"
#include "platform_pmd.h"

// adc.open(id)
static int adc_open(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    int ret;

    MOD_CHECK_ID(adc, id);

    ret = platform_adc_open(id);

    lua_pushinteger(L, ret);

    return 1; 
}

// adc.read(id)
static int adc_read(lua_State *L) {    
    int id = luaL_checkinteger(L,1);
    int adc, volt;

    MOD_CHECK_ID(adc, id);

    platform_adc_read(id, &adc, &volt);

    lua_pushinteger(L, adc);
    lua_pushinteger(L, volt);
   
    return 2; 
}

#define MIN_OPT_LEVEL 2
#include "lrodefs.h"  

// Module function map
const LUA_REG_TYPE adc_map[] =
{ 
  { LSTRKEY( "open" ),  LFUNCVAL( adc_open ) },
  { LSTRKEY( "read" ),  LFUNCVAL( adc_read ) },

  { LNILKEY, LNILVAL }
};

LUALIB_API int luaopen_adc( lua_State *L )
{
    luaL_register( L, AUXLIB_ADC, adc_map );

    return 1;
}  
