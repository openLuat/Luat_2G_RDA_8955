/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    auxmods.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/8
 *
 * Description:
 * 
 **************************************************************************/
// Auxiliary Lua modules. All of them are declared here, then each platform
// decides what module(s) to register in the src/platform/xxxxx/platform_conf.h file

#ifndef __AUXMODS_H__
#define __AUXMODS_H__

#include "lua.h"

#define AUXLIB_PIO      "pio"
LUALIB_API int ( luaopen_pio )( lua_State *L );

#define AUXLIB_SPI      "spi"
LUALIB_API int ( luaopen_spi )( lua_State *L );

#define AUXLIB_CAN      "can"
LUALIB_API int ( luaopen_can )( lua_State *L );

#define AUXLIB_TMR      "tmr"
LUALIB_API int ( luaopen_tmr )( lua_State *L );

#define AUXLIB_PD       "pd"
LUALIB_API int ( luaopen_pd )( lua_State *L );

#define AUXLIB_UART     "uart"
LUALIB_API int ( luaopen_uart )( lua_State *L );

#define AUXLIB_TERM     "term"
LUALIB_API int ( luaopen_term )( lua_State *L );

#define AUXLIB_PWM      "pwm"
LUALIB_API int ( luaopen_pwm )( lua_State *L );

#define AUXLIB_PACK     "pack"
LUALIB_API int ( luaopen_pack )( lua_State *L );

#define AUXLIB_BIT      "bit"
LUALIB_API int ( luaopen_bit )( lua_State *L );

#define AUXLIB_NET      "net"
LUALIB_API int ( luaopen_net )( lua_State *L );

#define AUXLIB_CPU      "cpu"
LUALIB_API int ( luaopen_cpu )( lua_State* L );

#define AUXLIB_ADC      "adc"
LUALIB_API int ( luaopen_adc )( lua_State *L );

#define AUXLIB_RPC   "rpc"
LUALIB_API int ( luaopen_rpc )( lua_State *L );

#define AUXLIB_BITARRAY "bitarray"
LUALIB_API int ( luaopen_bitarray )( lua_State *L );

#define AUXLIB_I2C  "i2c"
LUALIB_API int ( luaopen_i2c )( lua_State *L );

#define AUXLIB_RTOS     "rtos"
LUALIB_API int ( luaopen_rtos )( lua_State *L );

#if defined LUA_DISP_LIB
#define AUXLIB_DISP     "disp"
LUALIB_API int ( luaopen_disp )( lua_State *L );
#endif
#define AUXLIB_JSON     "json"
LUALIB_API int ( luaopen_cjson)( lua_State *L );

#define AUXLIB_PMD     "pmd"
LUALIB_API int ( luaopen_pmd )( lua_State *L );

/*+\NEW\liweiqiang\2013.7.16\增加iconv字符编码转换库 */
#define AUXLIB_ICONV     "iconv"
LUALIB_API int ( luaopen_iconv)( lua_State *L );
/*-\NEW\liweiqiang\2013.7.16\增加iconv字符编码转换库 */

/*+\NEW\liweiqiang\2013.11.4\增加audio.core接口库 */
#define AUXLIB_AUDIOCORE "audiocore"
LUALIB_API int ( luaopen_audiocore)( lua_State *L );
/*-\NEW\liweiqiang\2013.11.4\增加audio.core接口库 */

/*+\NEW\liweiqiang\2014.2.9\增加zlib库 */
#define AUXLIB_ZLIB "zlib"
LUALIB_API int ( luaopen_zlib)( lua_State *L );
/*-\NEW\liweiqiang\2014.2.9\增加zlib库 */

/*+\NEW\liweiqiang\2014.4.8\watchdog库 */
#define AUXLIB_WATCHDOG      "watchdog"
LUALIB_API int ( luaopen_watchdog )( lua_State *L );
/*-\NEW\liweiqiang\2014.4.8\watchdog库 */

/*+\NEW\zhuth\2014.8.6\增加gpscore接口库*/
#define AUXLIB_GPSCORE      "gpscore"
LUALIB_API int ( luaopen_gpscore )( lua_State *L );
/*-\NEW\zhuth\2014.8.6\增加gpscore接口库*/

/*+\NEW\liulean\2015.6.15\增加获取默认APN的库 */
#define  AUXLIB_APN               "apn"
LUALIB_API int ( luaopen_apn )( lua_State *L );
/*-\NEW\liulean\2015.6.15\增加获取默认APN的库 */

/*begin\NEW\zhutianhua\2017.4.17 15:8\新增crypto算法库*/
#define  AUXLIB_CRYPTO               "crypto"
LUALIB_API int ( luaopen_crypto )( lua_State *L );
/*end\NEW\zhutianhua\2017.4.17 15:8\新增crypto算法库*/


// Helper macros
#define MOD_CHECK_ID( mod, id )\
  if( !platform_ ## mod ## _exists( id ) )\
    return luaL_error( L, #mod" %d does not exist", ( unsigned )id )

#define MOD_CHECK_RES_ID( mod, id, resmod, resid )\
  if( !platform_ ## mod ## _check_ ## resmod ## _id( id, resid ) )\
    return luaL_error( L, #resmod" %d not valid with " #mod " %d", ( unsigned )resid, ( unsigned )id )

#define MOD_REG_NUMBER( L, name, val )\
  lua_pushnumber( L, val );\
  lua_setfield( L, -2, name )


#endif //__AUXMODS_H__

