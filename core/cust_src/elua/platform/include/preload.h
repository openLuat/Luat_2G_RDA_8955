/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    preload.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/7/1
 *
 * Description:
 *          预置文件解析处理
 **************************************************************************/

#ifndef _PRELOAD_H_
#define _PRELOAD_H_

#define LUADB_ERR_NONE              0
#define LUADB_ERR_TLV_LEN           -1
#define LUADB_ERR_CHECK_FAIL        -2
#define LUADB_ERR_TOO_MANY_FILES    -3
#define LUADB_ERR_FILE_COUNT        -4
#define LUADB_ERR_MAGIC             -5
#define LUADB_ERR_OUT_OF_RANGE      -6
#define LUADB_ERR_UNKNOWN_TYPE      -7
#define LUADB_ERR_UNZIP_FILE        -8
#define LUADB_ERR_WRITE_FILE        -9
#define LUADB_ERR_ADD_TABLE_ITEM        -10

#define LUADB_ERR_NOT_DBDATA        -100 //非luadb数据

/*+\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
typedef enum
{
    LUA_SCRIPT_TABLE_UPDATE_SECTION,
    LUA_SCRIPT_TABLE_FLASH_SECTION,

    LUA_SCRIPT_TABLE_MAX_SECTION
}E_LUA_SCRIPT_TABLE_SECTION;
/*-\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/

/*+\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
int parse_luadb_data(const u8 *pData, u32 length, BOOL override, E_LUA_SCRIPT_TABLE_SECTION section, BOOL *pRestart);
/*-\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/

#endif/*_PRELOAD_H_*/