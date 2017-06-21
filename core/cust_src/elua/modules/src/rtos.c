/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    rtos.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/3/7
 *
 * Description:
 *          lua.rtos库
 **************************************************************************/

#include <ctype.h>
#include <string.h>
#include <malloc.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "auxmods.h"
#include "lrotable.h"
#include "platform.h"
/*begin\NEW\zhutianhua\2017.2.28 14:38\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
#include "platform_conf.h"
/*end\NEW\zhutianhua\2017.2.28 14:38\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
#include "platform_rtos.h"
#include "platform_malloc.h"

static void setfieldInt(lua_State *L, const char *key, int value)
{
    lua_pushstring(L, key);
    lua_pushinteger(L, value);
    lua_rawset(L, -3);// 弹出key,value 设置到table中
}

static void setfieldBool(lua_State *L, const char *key, int value)
{
    if(value < 0) // invalid value
        return;

    lua_pushstring(L, key);
    lua_pushboolean(L, value);
    lua_rawset(L, -3);// 弹出key,value 设置到table中
}

static int handle_msg(lua_State *L, PlatformMessage *pMsg)
{    
    int ret = 1;
    
    switch(pMsg->id)
    {
    case RTOS_MSG_WAIT_MSG_TIMEOUT:
        lua_pushinteger(L, pMsg->id);
        // no error msg data.
        break;
        
    case RTOS_MSG_TIMER:
        lua_pushinteger(L, pMsg->id);
        lua_pushinteger(L, pMsg->data.timer_id);
        ret = 2;
        break;

    case RTOS_MSG_UART_RX_DATA:
    case RTOS_MSG_UART_TX_DONE:
        lua_pushinteger(L, pMsg->id);
        lua_pushinteger(L, pMsg->data.uart_id);
        ret = 2;
        break;

    case RTOS_MSG_KEYPAD:
        /* 以table方式返回消息内容 */
        lua_newtable(L);    
        setfieldInt(L, "id", pMsg->id);
        setfieldBool(L, "pressed", pMsg->data.keypadMsgData.bPressed);
        setfieldInt(L, "key_matrix_row", pMsg->data.keypadMsgData.data.matrix.row);
        setfieldInt(L, "key_matrix_col", pMsg->data.keypadMsgData.data.matrix.col);
        break;

/*+\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/
    case RTOS_MSG_INT:
        /* 以table方式返回消息内容 */
        lua_newtable(L);    
        setfieldInt(L, "id", pMsg->id);
        setfieldInt(L, "int_id", pMsg->data.interruptData.id);
        setfieldInt(L, "int_resnum", pMsg->data.interruptData.resnum);
        break;
/*-\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/

/*+\NEW\liweiqiang\2013.7.8\增加rtos.pmd消息*/
    case RTOS_MSG_PMD:
        /* 以table方式返回消息内容 */
        lua_newtable(L);    
        setfieldInt(L, "id", pMsg->id);
        setfieldBool(L, "present", pMsg->data.pmdData.battStatus);
        setfieldInt(L, "voltage", pMsg->data.pmdData.battVolt);
        setfieldInt(L, "level", pMsg->data.pmdData.battLevel);
        setfieldBool(L, "charger", pMsg->data.pmdData.chargerStatus);
        setfieldInt(L, "state", pMsg->data.pmdData.chargeState);
        break;
/*-\NEW\liweiqiang\2013.7.8\增加rtos.pmd消息*/

/*+\NEW\liweiqiang\2013.11.4\增加audio.core接口库 */
    case RTOS_MSG_AUDIO:
        /* 以table方式返回消息内容 */
        lua_newtable(L);    
        setfieldInt(L, "id", pMsg->id);
        if(pMsg->data.audioData.playEndInd == TRUE)
            setfieldBool(L,"play_end_ind",TRUE);
        else if(pMsg->data.audioData.playErrorInd == TRUE)
            setfieldBool(L,"play_error_ind",TRUE);
        break;
/*-\NEW\liweiqiang\2013.11.4\增加audio.core接口库 */

    default:
        ret = 0;
        break;
    }
    
    return ret;
}

static int l_rtos_receive(lua_State *L) 		/* rtos.receive() */
{
    u32 timeout = luaL_checkinteger( L, 1 );
    PlatformMessage *pMsg = NULL;
/*+\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
    static BOOL firstRecv = TRUE;
    int ret = 0;

    if(firstRecv)
    {
        // 第一次接收消息时尝试是否需要启动系统
        firstRecv = FALSE;
        platform_poweron_try();
    }
/*-\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */

    if(platform_rtos_receive((void**)&pMsg, timeout) != PLATFORM_OK)
    {
        return luaL_error( L, "rtos.receive error!" );
    }
    
    ret = handle_msg(L, pMsg);

    if(pMsg)
    {
    /*+\NEW\liweiqiang\2013.12.6\libc malloc走dlmalloc通道 */
        // 该消息内存由平台侧其他线程申请的,故用platform_free来释放
        platform_free(pMsg);
    /*-\NEW\liweiqiang\2013.12.6\libc malloc走dlmalloc通道 */
    }

    return ret;
}

static int l_rtos_sleep(lua_State *L)   /* rtos.sleep()*/
{
    int ms = luaL_checkinteger( L, 1 );

    platform_os_sleep(ms);
    
    return 0;
}

static int l_rtos_timer_start(lua_State *L)
{
    int timer_id = luaL_checkinteger(L,1);
    int ms = luaL_checkinteger(L,2);
    int ret;

    ret = platform_rtos_start_timer(timer_id, ms,FALSE);

    lua_pushinteger(L, ret);

    return 1;
}

static int l_rtos_timer_high_priority_start(lua_State *L)
{
    int timer_id = luaL_checkinteger(L,1);
    int ms = luaL_checkinteger(L,2);
    int ret;

    ret = platform_rtos_start_timer(timer_id, ms,TRUE);

    lua_pushinteger(L, ret);

    return 1;
}

static int l_rtos_timer_stop(lua_State *L)
{
    int timer_id = luaL_checkinteger(L,1);
    int ret;

    ret = platform_rtos_stop_timer(timer_id);

    lua_pushinteger(L, ret);

    return 1;
}

static int l_rtos_init_module(lua_State *L)
{
    int module_id = luaL_checkinteger(L, 1);
    int ret;

    switch(module_id)
    {
    case RTOS_MODULE_ID_KEYPAD:
        {
            PlatformKeypadInitParam param;

            int type = luaL_checkinteger(L, 2);
            int inmask = luaL_checkinteger(L, 3);
            int outmask = luaL_checkinteger(L, 4);

            param.type = type;
            param.matrix.inMask = inmask;
            param.matrix.outMask = outmask;

            ret = platform_rtos_init_module(RTOS_MODULE_ID_KEYPAD, &param);
        }
        break;

    default:
        return luaL_error(L, "rtos.init_module: module id must < %d", NumOfRTOSModules);
        break;
    }

    lua_pushinteger(L, ret);

    return 1;
}

/*+\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
static int l_rtos_poweron_reason(lua_State *L)
{
    lua_pushinteger(L, platform_get_poweron_reason());
    return 1;
}

static int l_rtos_poweron(lua_State *L)
{
    int flag = luaL_checkinteger(L, 1);
    platform_rtos_poweron(flag);
    return 0;
}
/*-\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */

static int l_rtos_poweroff(lua_State *L)
{
	platform_rtos_poweroff();	
	return 0;
}

/*-\NEW\zhuwangbin\2017.2.12\添加版本查询接口 */
static int l_get_version(lua_State *L)
{
	char *ver;

	ver = platform_rtos_get_version();
	lua_pushlstring(L, ver, strlen(ver));
	
	return 1;
}
/*-\NEW\zhuwangbin\2017.2.12\添加版本查询接口 */

static int l_get_env_usage(lua_State *L)
{
	lua_pushinteger(L,platform_get_env_usage());	
	return 1;
}

/*+\NEW\liweiqiang\2013.9.7\增加rtos.restart接口*/
static int l_rtos_restart(lua_State *L)
{
	platform_rtos_restart();	
	return 0;
}
/*-\NEW\liweiqiang\2013.9.7\增加rtos.restart接口*/

/*+\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/
static int l_rtos_tick(lua_State *L)
{
    lua_pushinteger(L, platform_rtos_tick());
    return 1;
}
/*-\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/

/*begin\NEW\zhutianhua\2017.2.28 14:12\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
static int l_set_trace(lua_State *L)
{
    u32 flag = luaL_optinteger(L, 1, 0);
    if(flag==1)
    {
        platform_set_console_port(luaL_optinteger(L, 2, PLATFORM_PORT_ID_DEBUG));
    }
    else
    {
        platform_set_console_port(NUM_UART);
    }
    lua_pushboolean(L,1);
    return 1;
}
/*end\NEW\zhutianhua\2017.2.28 14:12\新增rtos.set_trace接口，可控制是否输出Lua的trace*/

#define MIN_OPT_LEVEL 2
#include "lrodefs.h"
const LUA_REG_TYPE rtos_map[] =
{
    { LSTRKEY( "init_module" ),  LFUNCVAL( l_rtos_init_module ) },
/*+\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
    { LSTRKEY( "poweron_reason" ),  LFUNCVAL( l_rtos_poweron_reason ) },
    { LSTRKEY( "poweron" ),  LFUNCVAL( l_rtos_poweron ) },
/*-\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
    { LSTRKEY( "poweroff" ),  LFUNCVAL( l_rtos_poweroff ) },
/*+\NEW\liweiqiang\2013.9.7\增加rtos.restart接口*/
    { LSTRKEY( "restart" ),  LFUNCVAL( l_rtos_restart ) },
/*-\NEW\liweiqiang\2013.9.7\增加rtos.restart接口*/
    { LSTRKEY( "receive" ),  LFUNCVAL( l_rtos_receive ) },
    //{ LSTRKEY( "send" ), LFUNCVAL( l_rtos_send ) }, //暂不提供send接口
    { LSTRKEY( "sleep" ), LFUNCVAL( l_rtos_sleep ) },
    { LSTRKEY( "timer_start" ), LFUNCVAL( l_rtos_timer_start ) },
    { LSTRKEY( "timer_high_priority_start" ), LFUNCVAL( l_rtos_timer_high_priority_start ) },
    { LSTRKEY( "timer_stop" ), LFUNCVAL( l_rtos_timer_stop ) },
/*+\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/
    { LSTRKEY( "tick" ), LFUNCVAL( l_rtos_tick ) },
/*-\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/
    { LSTRKEY( "get_env_usage" ), LFUNCVAL( l_get_env_usage ) },
/*-\NEW\zhuwangbin\2017.2.12\添加版本查询接口 */
    { LSTRKEY( "get_version" ), LFUNCVAL( l_get_version ) },
/*-\NEW\zhuwangbin\2017.2.12\添加版本查询接口 */
    /*begin\NEW\zhutianhua\2017.2.28 14:4\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
    { LSTRKEY( "set_trace" ), LFUNCVAL( l_set_trace ) },
    /*end\NEW\zhutianhua\2017.2.28 14:4\新增rtos.set_trace接口，可控制是否输出Lua的trace*/

	{ LNILKEY, LNILVAL }
};

int luaopen_rtos( lua_State *L )
{
    luaL_register( L, AUXLIB_RTOS, rtos_map );

    // module id
    MOD_REG_NUMBER(L, "MOD_KEYPAD", RTOS_MODULE_ID_KEYPAD);

/*+\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
    // 开机原因
    #define REG_POWERON_RESON(rEASON) MOD_REG_NUMBER(L, #rEASON, PLATFORM_##rEASON)
    REG_POWERON_RESON(POWERON_KEY);
    REG_POWERON_RESON(POWERON_CHARGER);
    REG_POWERON_RESON(POWERON_ALARM);
    REG_POWERON_RESON(POWERON_RESTART);
    REG_POWERON_RESON(POWERON_OTHER);
    REG_POWERON_RESON(POWERON_UNKNOWN);
/*-\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
    /*+\NewReq NEW\zhuth\2014.6.18\增加开机原因值接口*/
    REG_POWERON_RESON(POWERON_EXCEPTION);
    REG_POWERON_RESON(POWERON_HOST);
    REG_POWERON_RESON(POWERON_WATCHDOG);
    /*-\NewReq NEW\zhuth\2014.6.18\增加开机原因值接口*/

    // msg id
    MOD_REG_NUMBER(L, "WAIT_MSG_TIMEOUT", RTOS_MSG_WAIT_MSG_TIMEOUT);
    MOD_REG_NUMBER(L, "MSG_TIMER", RTOS_MSG_TIMER);
    MOD_REG_NUMBER(L, "MSG_KEYPAD", RTOS_MSG_KEYPAD);
    MOD_REG_NUMBER(L, "MSG_UART_RXDATA", RTOS_MSG_UART_RX_DATA);
    MOD_REG_NUMBER(L, "MSG_UART_TX_DONE", RTOS_MSG_UART_TX_DONE);
/*+\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
    MOD_REG_NUMBER(L, "MSG_INT", RTOS_MSG_INT);
/*-\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
/*+\NEW\liweiqiang\2013.7.8\增加rtos.pmd消息*/
    MOD_REG_NUMBER(L, "MSG_PMD", RTOS_MSG_PMD);
/*-\NEW\liweiqiang\2013.7.8\增加rtos.pmd消息*/
/*+\NEW\liweiqiang\2013.11.4\增加audio.core接口库 */
    MOD_REG_NUMBER(L, "MSG_AUDIO", RTOS_MSG_AUDIO);
/*-\NEW\liweiqiang\2013.11.4\增加audio.core接口库 */
    //timeout
    MOD_REG_NUMBER(L, "INF_TIMEOUT", PLATFORM_RTOS_WAIT_MSG_INFINITE);

    // 进行必要的初始化
    platform_rtos_init();

    return 1;
}

