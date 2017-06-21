/*
** $Id: linit.c,v 1.14.1.1 2007/12/27 13:02:25 roberto Exp $
** Initialization of libraries for lua.c
** See Copyright Notice in lua.h
*/


#define linit_c
#define LUA_LIB

#include "lua.h"

#include "lualib.h"
#include "lauxlib.h"

#if !defined(LUA_COMPILER)
#include "platform_conf.h"
#endif

static const luaL_Reg lualibs[] = {
  {"", luaopen_base},
  {LUA_LOADLIBNAME, luaopen_package},
  {LUA_TABLIBNAME, luaopen_table},
#if defined(LUA_IO_LIB)    
  {LUA_IOLIBNAME, luaopen_io},
#endif
#if defined(LUA_OS_LIB)
  {LUA_OSLIBNAME, luaopen_os},
#endif
  {LUA_STRLIBNAME, luaopen_string},
#if defined(LUA_MATH_LIB)    
  {LUA_MATHLIBNAME, luaopen_math},
#endif
#if defined(LUA_DEBUG_LIB)
  {LUA_DBLIBNAME, luaopen_debug},
#endif
#if defined(LUA_PLATFORM_LIBS_ROM)
#define _ROM( name, openf, table ) { name, openf },
  LUA_PLATFORM_LIBS_ROM
#endif
  {NULL, NULL}
};


LUALIB_API void luaL_openlibs (lua_State *L) {
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
}

