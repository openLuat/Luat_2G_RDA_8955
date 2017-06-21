/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    disp.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/3/26
 *
 * Description:
 *          lua.disp库
 **************************************************************************/

#if defined LUA_DISP_LIB

#include <stdlib.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "platform.h"
#include "lrotable.h"
#include "platform_conf.h"
#include "platform_disp.h"

int checkFiledInt(lua_State *L, int index, const char *key)
{
    int d;
    lua_getfield(L, index, key);
    d = luaL_checkinteger(L, -1);
    lua_remove(L, -1);
    return d;
}

int getFiledInt(lua_State *L, int index, const char *key)
{
    int d;
    lua_getfield(L, index, key);
    d = lua_tointeger(L, -1);
    lua_remove(L, -1);
    return d;
}

static int optFiledInt(lua_State *L, int index, const char *key, int defval)
{
    int d;
    lua_getfield(L, index, key);
    d = luaL_optint(L, -1, defval);
    lua_remove(L, -1);
    return d;
}

// disp.init
static int disp_init(lua_State *L) {

    PlatformDispInitParam param;
    int cmdTableIndex;

    luaL_checktype(L, 1, LUA_TTABLE);

    memset(&param, 0, sizeof(param));

    param.width = getFiledInt(L, 1, "width");
    param.height = getFiledInt(L, 1, "height");
    
    if(param.width == 0 || param.height == 0)
    {
        return luaL_error(L, "disp.init: error param width(%d) height(%d)", 
                                param.width, param.height);
    }
    
    param.bpp = getFiledInt(L, 1, "bpp");

/*+\NEW\2013.4.10\增加黑白屏显示支持 */
    //16位色彩屏or黑白屏
    if(!(param.bpp == 16 || param.bpp == 1))
    {
        return luaL_error(L, "disp.init: pixel depth must be 16 or 1!"); 
    }
    
    // lcd传输接口
    param.bus = getFiledInt(L, 1, "bus");

    /*+\new\liweiqiang\2014.10.22\lcd不同接口信息定义 */
    // 不同传输接口定义
    if(param.bus == PLATFORM_LCD_BUS_I2C || param.bus == PLATFORM_LCD_BUS_SPI){
        lua_getfield(L, 1, "interface");
        luaL_checktype(L, -1, LUA_TTABLE);

        if(param.bus == PLATFORM_LCD_BUS_I2C){
            param.lcd_itf.bus_i2c.bus_id = checkFiledInt(L, -1, "bus_id");
            param.lcd_itf.bus_i2c.freq = checkFiledInt(L, -1, "freq");
            param.lcd_itf.bus_i2c.slave_addr = checkFiledInt(L, -1, "slave_addr");
            param.lcd_itf.bus_i2c.cmd_addr = checkFiledInt(L, -1, "cmd_addr");
            param.lcd_itf.bus_i2c.data_addr = checkFiledInt(L, -1, "data_addr");
        } else if(param.bus == PLATFORM_LCD_BUS_SPI){
            param.lcd_itf.bus_spi.bus_id = checkFiledInt(L, -1, "bus_id");
            param.lcd_itf.bus_spi.pin_rs = checkFiledInt(L, -1, "pin_rs");
            param.lcd_itf.bus_spi.pin_cs = optFiledInt(L, -1, "pin_cs", PLATFORM_IO_UNKNOWN_PIN);
            param.lcd_itf.bus_spi.freq = checkFiledInt(L, -1, "freq");
        }
    }
    /*-\new\liweiqiang\2014.10.22\lcd不同接口信息定义 */    

    // lcd rst脚必须定义
    param.pin_rst = checkFiledInt(L, 1, "pinrst");

    lua_getfield(L, 1, "pincs");

    if(lua_type(L,-1) != LUA_TNUMBER)
        param.pin_cs = PLATFORM_IO_UNKNOWN_PIN;
    else
        param.pin_cs = lua_tonumber(L,-1);

    // 不设偏移则默认0
    param.x_offset = getFiledInt(L, 1, "xoffset");
    param.y_offset = getFiledInt(L, 1, "yoffset");
    
    /*+\new\liweiqiang\2014.10.21\增加不同黑白屏填充色处理 */
    param.hwfillcolor = optFiledInt(L, 1, "hwfillcolor", -1);
    /*-\new\liweiqiang\2014.10.21\增加不同黑白屏填充色处理 */

    // .initcmd 初始化指令表
    lua_getfield(L, 1, "initcmd");
    luaL_checktype(L, -1, LUA_TTABLE);
    param.tableSize = luaL_getn(L, -1);
    param.pLcdCmdTable = malloc(sizeof(int)*param.tableSize);
    
    for(cmdTableIndex = 0; cmdTableIndex < param.tableSize; cmdTableIndex++)
    {
        lua_rawgeti(L, -1, cmdTableIndex+1);
        param.pLcdCmdTable[cmdTableIndex] = lua_tointeger(L, -1);
        lua_remove(L,-1);
    }
/*-\NEW\2013.4.10\增加黑白屏显示支持 */

/*+\NEW\liweiqiang\2013.12.18\增加lcd睡眠命令支持 */
    lua_getfield(L, 1, "sleepcmd");
    if(lua_type(L, -1) == LUA_TTABLE)
    {
        param.sleepCmdSize = luaL_getn(L, -1);
        param.pLcdSleepCmd = malloc(sizeof(int)*param.sleepCmdSize);

        for(cmdTableIndex = 0; cmdTableIndex < param.sleepCmdSize; cmdTableIndex++)
        {
            lua_rawgeti(L, -1, cmdTableIndex+1);
            param.pLcdSleepCmd[cmdTableIndex] = lua_tointeger(L, -1);
            lua_remove(L,-1);
        }
    }

    lua_getfield(L, 1, "wakecmd");
    if(lua_type(L, -1) == LUA_TTABLE)
    {
        param.wakeCmdSize = luaL_getn(L, -1);
        param.pLcdWakeCmd = malloc(sizeof(int)*param.wakeCmdSize);
        
        for(cmdTableIndex = 0; cmdTableIndex < param.wakeCmdSize; cmdTableIndex++)
        {
            lua_rawgeti(L, -1, cmdTableIndex+1);
            param.pLcdWakeCmd[cmdTableIndex] = lua_tointeger(L, -1);
            lua_remove(L,-1);
        }
    }
/*-\NEW\liweiqiang\2013.12.18\增加lcd睡眠命令支持 */

    platform_disp_init(&param);

    free(param.pLcdCmdTable);

    /*+\NEW\liweiqiang\2013.12.18\增加lcd睡眠命令支持 */
    if(param.pLcdSleepCmd)
        free(param.pLcdSleepCmd);

    if(param.pLcdWakeCmd)
        free(param.pLcdWakeCmd);
    /*-\NEW\liweiqiang\2013.12.18\增加lcd睡眠命令支持 */

    return 0;
}

static int disp_close(lua_State *L) {
    platform_disp_close();
    return 0;
}
// disp.clear
static int disp_clear(lua_State *L) {    
  platform_disp_clear();
  return 0; 
}

static int disp_update(lua_State *L){
    platform_disp_update();
    return 0;
}
   
// disp.puttext
static int disp_puttext(lua_State *L) {
  const char *str;
  u16 x, y;
  
  str   = luaL_checkstring(L, 1);
  x     = cast(u16,luaL_checkinteger(L, 2));
  y     = cast(u16,luaL_checkinteger(L, 3));

  platform_disp_puttext(str, x, y);

  return 0; 
}

/*+\NEW\liweiqiang\2013.11.4\增加BMP图片显示支持 */
//disp.putimage
static int disp_putimage(lua_State *L) {
    const char *filename;
    /*+\NewReq NEW\zhutianhua\2013.12.24\显示图片的指定区域*/
    u16 x, y, left, top, right, bottom;
    /*-\NewReq NEW\zhutianhua\2013.12.24\显示图片的指定区域*/
    int transcolor;

    filename   = luaL_checkstring(L, 1);
    x     = luaL_optint(L, 2, 0);
/*+\NEW\liweiqiang\2013.11.12\修正显示图片y坐标无法设置 */
    y     = luaL_optint(L, 3, 0);
/*-\NEW\liweiqiang\2013.11.12\修正显示图片y坐标无法设置 */

/*+\NEW\liweiqiang\2013.12.6\增加图片透明色设置 */
    /*+\NewReq NEW\zhutianhua\2013.12.24\显示图片的指定区域*/
    transcolor = luaL_optint(L, 4, -1); //默认不透明
    left = luaL_optint(L, 5, 0);
    top = luaL_optint(L, 6, 0);
    right = luaL_optint(L, 7, 0);
    bottom = luaL_optint(L, 8, 0);

    platform_disp_putimage(filename, x, y, transcolor, left, top, right, bottom);
    /*-\NewReq NEW\zhutianhua\2013.12.24\显示图片的指定区域*/
/*-\NEW\liweiqiang\2013.12.6\增加图片透明色设置 */
    
    return 0; 
}
/*-\NEW\liweiqiang\2013.11.4\增加BMP图片显示支持 */

/*+\NEW\liweiqiang\2013.12.7\增加矩形显示支持 */
static int disp_drawrect(lua_State *L)
{
    int left = luaL_checkinteger(L, 1);
    int top = luaL_checkinteger(L, 2);
    int right = luaL_checkinteger(L, 3);
    int bottom = luaL_checkinteger(L, 4);
    int color = luaL_optint(L, 5, -1);

    platform_disp_drawrect(left, top, right, bottom, color);

    return 0;
}
/*-\NEW\liweiqiang\2013.12.7\增加矩形显示支持 */

/*+\NEW\liweiqiang\2013.12.9\增加前景色\背景色设置 */
static int disp_setcolor(lua_State *L)
{
    int color = luaL_checkinteger(L, 1);
    int retcolor = platform_disp_setcolor(color);
    lua_pushinteger(L, retcolor);
    return 1;
}

static int disp_setbkcolor(lua_State *L)
{
    int color = luaL_checkinteger(L, 1);
    int retcolor = platform_disp_setbkcolor(color);
    lua_pushinteger(L, retcolor);
    return 1;
}
/*-\NEW\liweiqiang\2013.12.9\增加前景色\背景色设置 */

/*+\NEW\liweiqiang\2013.12.9\增加非中文字体设置 */
static int disp_loadfont(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    int fontid = platform_disp_loadfont(filename); 
   
    lua_pushinteger(L, fontid);
    return 1;
}

static int disp_setfont(lua_State *L)
{
    int fontid = luaL_checkinteger(L, 1);
    int oldfontid = platform_disp_setfont(fontid);

    lua_pushinteger(L, oldfontid);
    return 1;
}
/*-\NEW\liweiqiang\2013.12.9\增加非中文字体设置 */

/*+\NewReq NEW\zhutianhua\2014.11.14\增加disp.sleep接口*/
extern void platform_lcd_powersave(int sleep_wake);
static int disp_sleep(lua_State *L) {    
    int sleep = luaL_checkinteger(L,1);

    platform_lcd_powersave(sleep);
    return 0; 
}
/*-\NewReq NEW\zhutianhua\2014.11.14\增加disp.sleep接口*/

#define MIN_OPT_LEVEL 2
#include "lrodefs.h"  

// Module function map
const LUA_REG_TYPE disp_map[] =
{ 
  { LSTRKEY( "init" ),  LFUNCVAL( disp_init ) },
  { LSTRKEY( "close" ),  LFUNCVAL( disp_close ) },
  { LSTRKEY( "clear" ), LFUNCVAL( disp_clear ) },
  { LSTRKEY( "update" ), LFUNCVAL( disp_update ) },
  { LSTRKEY( "puttext" ), LFUNCVAL( disp_puttext ) },
/*+\NEW\liweiqiang\2013.11.4\增加BMP图片显示支持 */
  { LSTRKEY( "putimage" ), LFUNCVAL( disp_putimage ) },
/*-\NEW\liweiqiang\2013.11.4\增加BMP图片显示支持 */

/*+\NEW\liweiqiang\2013.12.7\增加矩形显示支持 */
  { LSTRKEY( "drawrect" ), LFUNCVAL( disp_drawrect ) },
/*-\NEW\liweiqiang\2013.12.7\增加矩形显示支持 */

/*+\NEW\liweiqiang\2013.12.9\增加前景色\背景色设置 */
  { LSTRKEY( "setcolor" ), LFUNCVAL( disp_setcolor ) },
  { LSTRKEY( "setbkcolor" ), LFUNCVAL( disp_setbkcolor ) },
/*-\NEW\liweiqiang\2013.12.9\增加前景色\背景色设置 */

/*+\NEW\liweiqiang\2013.12.9\增加非中文字体设置 */
  { LSTRKEY( "loadfont" ), LFUNCVAL( disp_loadfont ) },
  { LSTRKEY( "setfont" ), LFUNCVAL( disp_setfont ) },
/*-\NEW\liweiqiang\2013.12.9\增加非中文字体设置 */

  /*+\NewReq NEW\zhutianhua\2014.11.14\增加disp.sleep接口*/
  { LSTRKEY( "sleep" ), LFUNCVAL( disp_sleep ) },
  /*-\NewReq NEW\zhutianhua\2014.11.14\增加disp.sleep接口*/

  { LNILKEY, LNILVAL }
};

LUALIB_API int luaopen_disp( lua_State *L )
{
  luaL_register( L, AUXLIB_DISP, disp_map );

  MOD_REG_NUMBER(L, "BUS_SPI4LINE", PLATFORM_LCD_BUS_SPI4LINE);
  MOD_REG_NUMBER(L, "BUS_PARALLEL", PLATFORM_LCD_BUS_PARALLEL);
/*+\new\liweiqiang\2014.10.22\lcd不同接口信息定义 */
  MOD_REG_NUMBER(L, "BUS_I2C", PLATFORM_LCD_BUS_I2C);
  MOD_REG_NUMBER(L, "BUS_SPI", PLATFORM_LCD_BUS_SPI);
/*-\new\liweiqiang\2014.10.22\lcd不同接口信息定义 */
  
  return 1;
}  
#endif
