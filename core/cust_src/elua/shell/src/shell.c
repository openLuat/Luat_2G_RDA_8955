
#include "lua.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "assert.h"
#include "devman.h"
#include "platform.h"
#include "platform_conf.h"
#include "platform_fs.h"
#include "platform_rtos.h"

/*+\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma*/
#if defined(AM_LZMA_SUPPORT)
#include "lzmalib.h"
#endif
/*-\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma*/

#include "preload.h"

/*+\NEW\liweiqiang\2013.10.25\lua脚本统一放在lua目录下,预置的非lua文件统一放在ldata文件下 */
/*+\NEW\liweqiang\2013.5.8\在文件系统存在main.lua文件时启动时自动加载文件系统文件*/
#define LUA_ENTRY_FILENAME "main.lua"
#define LUA_ENTRY_FILE "/lua/" LUA_ENTRY_FILENAME
/*-\NEW\liweqiang\2013.5.8\在文件系统存在main.lua文件时启动时自动加载文件系统文件*/

#define LUA_ENTRY_ENC_FILENAME "main.luae"
#define LUA_ENTRY_ENC_FILE "/lua/" LUA_ENTRY_ENC_FILENAME

/*+\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
#define LUA_CHECK_INTEGRITY_FILE "/integrity.bin"
#define LUA_INTEGRITY_FLAG 0xABCD8765
/*-\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/

/*+\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma*/
#define LUA_ENTRY_FILE_ZIP "/luazip/" LUA_ENTRY_FILENAME ".zip"
#define LUA_ENTRY_ENC_FILE_ZIP "/luazip/" LUA_ENTRY_ENC_FILENAME ".zip"

/*-\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma*/
/*-\NEW\liweiqiang\2013.10.25\lua脚本统一放在lua目录下,预置的非lua文件统一放在ldata文件下 */

extern char _lua_script_section_start[LUA_SCRIPT_SIZE];


/*+\NEW\rufei\2013.9.13\处理lua文件可能被破坏导致持续重启问题*/
void LuaDeleteMainFile(void)
{
    remove(LUA_ENTRY_FILE);
    remove(LUA_ENTRY_ENC_FILE);
}
/*-\NEW\rufei\2013.9.13\处理lua文件可能被破坏导致持续重启问题*/

/*+\NEW\liweiqiang\2013.10.25\lua脚本统一放在lua目录下,预置的非lua文件统一放在ldata文件下 */
int file_exist(const char *name)
{
    FILE *fp;
    if((fp = fopen(name, "rb")) == NULL)
        return FALSE;

    fclose(fp);
    return TRUE;
}

/*-\NEW\liweiqiang\2013.10.25\lua脚本统一放在lua目录下,预置的非lua文件统一放在ldata文件下 */

/*+\NEW\liweiqiang\2013.11.28\luadb方式远程升级支持 */
static int load_luadb(void)
{
#define LUA_UPDATE_FILE "/luazip/update.bin"
    
    FILE *fp;
    int size;
    u8 *buff;
/*+\NEW\liweiqiang\2013.12.6\默认不覆盖释放luadb文件,升级失败时覆盖释放rom的luadb */
    BOOL file_override = FALSE;
/*-\NEW\liweiqiang\2013.12.6\默认不覆盖释放luadb文件,升级失败时覆盖释放rom的luadb */
    /*+\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
    BOOL restart1 = FALSE;
    BOOL restart2 = FALSE;
    int result = 0;
    /*-\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/

    /*+\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
    unsigned int integrity_flag = LUA_INTEGRITY_FLAG;
    FILE *integrity_file = NULL;
    /*-\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/

    if((fp = fopen(LUA_UPDATE_FILE, "rb")) == NULL)
    {
        // 文件不存在 加载预置在rom的数据
        goto load_rom_luadb;
    }
    
    fseek(fp, 0, SEEK_END);
    size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    buff = malloc(size);
    fread(buff, 1, size, fp);
    fclose(fp);
    
/*+\NEW\liweiqiang\2013.12.6\默认不覆盖释放luadb文件,升级失败时覆盖释放rom的luadb */
    /*+\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
    if(LUADB_ERR_NONE != parse_luadb_data(buff, size, TRUE, LUA_SCRIPT_TABLE_UPDATE_SECTION, &restart1))
    /*-\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
    {
        // 升级文件解析失败 移除升级文件
        remove(LUA_UPDATE_FILE);
        // 以覆盖方式解压rom的luadb,以修正可能出现部分升级的情况
        file_override = TRUE;
    /*+\NEW\liweiqiang\2015.1.9\升级失败清除文件后立即重启 避免某些项目文件过多过大 导致之后系统运行内存不足 */
        // 自动重启以清除升级失败的文件内容
        restart1 = TRUE;
    /*-\NEW\liweiqiang\2015.1.9\升级失败清除文件后立即重启 避免某些项目文件过多过大 导致之后系统运行内存不足 */

        /*+\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
        free(buff);
        goto lua_db_script_parse;
        /*-\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
    }
/*-\NEW\liweiqiang\2013.12.6\默认不覆盖释放luadb文件,升级失败时覆盖释放rom的luadb */

    free(buff);

load_rom_luadb:

    /*+\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
    file_override = TRUE;

    if(file_exist(LUA_CHECK_INTEGRITY_FILE))
    {
        unsigned int integrity_context;
        integrity_file = fopen(LUA_CHECK_INTEGRITY_FILE, "rb");
        
        if(integrity_file)
        {
            fread(&integrity_context, 4, 1, integrity_file);
            
            if(integrity_context == LUA_INTEGRITY_FLAG)
            {
                file_override = FALSE;
                printf("INTEGRITY file correct!\r");
            }
            else
            {
                printf("INTEGRITY file wrong!\r");
            }

            fclose(integrity_file);
        }
        else
        {
            printf("INTEGRITY file can not open!\r");
        }
    }
    else
    {
        printf("INTEGRITY file not exist!\r");
    }
   
lua_db_script_parse:    
/*-\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
    /*+\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
    result = parse_luadb_data(_lua_script_section_start, LUA_SCRIPT_SIZE, file_override, LUA_SCRIPT_TABLE_FLASH_SECTION, &restart2);
    /*-\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/

    /*+\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/
    if(file_override == TRUE)
    {
        printf("INTEGRITY file write begin!\r");
        
        integrity_file = fopen(LUA_CHECK_INTEGRITY_FILE, "wb");
        
        if(integrity_file)
        {
            fwrite((const void*)&integrity_flag, 4, 1, integrity_file);
            fclose(integrity_file);
            printf("INTEGRITY file write success!\r");
        }
        else
        {
            printf("INTEGRITY file write failed!\r");
        }
    }
    /*-\NEW\liulean\2015.8.5\解决产线概率性MP3播放无声音的问题*/

    /*+\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
    if(restart1 || restart2)
    {
        platform_rtos_restart();
    }
    /*-\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
    
    return result;
}
/*-\NEW\liweiqiang\2013.11.28\luadb方式远程升级支持 */

int LuaAppTask(void)
{    
/*+\NEW\2013.7.11\liweiqiang\增加luadb预置文件处理*/
    int argc;
    char **argv;
    BOOL existScript = TRUE;
    BOOL existLuaDB = FALSE;
    int dbret;

    static const char *argv_null[] = {"lua", NULL};
    static const char *argv_script_const[] =
    {
        "lua",
        "-e",
        _lua_script_section_start,
        NULL
    };
/*+\NEW\liweqiang\2013.5.8\在文件系统存在main.lua文件时启动时自动加载文件系统文件*/
    static const char *argv_script_file[] =
    {
        "lua",
        LUA_ENTRY_FILE,
        NULL
    };
/*-\NEW\liweqiang\2013.5.8\在文件系统存在main.lua文件时启动时自动加载文件系统文件*/
    static const char *argv_enc_script_file[] =
    {
        "lua",
        LUA_ENTRY_ENC_FILE,
        NULL
    };

    if((unsigned char)_lua_script_section_start[0] == 0xff || _lua_script_section_start[0] == '\0')
    {
        argc = sizeof(argv_null)/sizeof(argv_null[0]);
        argv = (char **)argv_null;

        existScript = FALSE;
    }
    else
    {
        //存在预置脚本时使用debug口作为命令行输出
        platform_set_console_port(PLATFORM_PORT_ID_DEBUG);
    }

    //初始化设备 stdio\fs\...
    if(platform_init() != PLATFORM_OK)
    {
        ASSERT(0);
    }

    dm_init();

    // 注册平台文件系统接口
    dm_register(platform_fs_init());
    
    dbret = load_luadb();

    if(dbret != LUADB_ERR_NOT_DBDATA)
    {
        existLuaDB = TRUE;
    }

/*+\NEW\liweqiang\2013.5.8\在文件系统存在main.lua文件时启动时自动加载文件系统文件*/
    if(existScript || existLuaDB)
    {
        BOOL exitZipFile = FALSE;
        char* zipFileName;
        char* enterFile;
    /*+\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma*/
    #if defined(AM_LZMA_SUPPORT)
        // 保留旧的文件升级方式,以兼容旧版本
        if(file_exist(LUA_ENTRY_FILE_ZIP) == TRUE)
        {
            exitZipFile = TRUE;
            zipFileName = LUA_ENTRY_FILE_ZIP;
            enterFile = LUA_ENTRY_FILE;
        }
        else if(file_exist(LUA_ENTRY_ENC_FILE_ZIP) == TRUE)
        {
            exitZipFile = TRUE;
            zipFileName = LUA_ENTRY_ENC_FILE_ZIP;
            enterFile = LUA_ENTRY_ENC_FILE;
        }
        if(exitZipFile)
        {
            // 只有在存在升级包文件的情况下才处理解压
            int lzmaret = 0;    
            if((lzmaret = LzmaUncompressFile(zipFileName, enterFile)) == 0)
            {
                /*+\NEW\rufei\2013.9.13\处理lua文件可能被破坏导致持续重启问题*/
                // 解压缩成功,删除压缩文件
                /*+\NEW\zhuth\2014.8.11\升级包解压缩成功后，删除升级包，并且重启*/
                remove(zipFileName);
                /*-\NEW\zhuth\2014.8.11\升级包解压缩成功后，删除升级包，并且重启*/
                /*-\NEW\rufei\2013.9.13\处理lua文件可能被破坏导致持续重启问题*/
                printf("uncompress zip file success!\n", lzmaret);
                /*+\NEW\zhuth\2014.8.11\升级包解压缩成功后，删除升级包，并且重启*/
                platform_rtos_restart();
                /*-\NEW\zhuth\2014.8.11\升级包解压缩成功后，删除升级包，并且重启*/
            }
            else
            {
                printf("uncompress file error(%d)!\n", lzmaret);
            }
        }
    #endif   
    /*-\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma*/

        if(file_exist(LUA_ENTRY_FILE) == TRUE)
        {
            printf("\r\nRUN main.lua\r\n");
            argc = sizeof(argv_script_file)/sizeof(argv_script_file[0]);
            argv = (char **)argv_script_file;
        }
        else if(file_exist(LUA_ENTRY_ENC_FILE) == TRUE)
        {
            printf("\r\nRUN ENCRYPT main.lua\r\n");
            argc = sizeof(argv_enc_script_file)/sizeof(argv_enc_script_file[0]);
            argv = (char **)argv_enc_script_file;
        }
        else if(existLuaDB)
        {
            // 若从预置数据无法解析出文件则无法从预置脚本运行
            printf("[lua]: luadb parse ret %d\n", dbret);
            argc = sizeof(argv_null)/sizeof(argv_null[0]);
            argv = (char **)argv_null;
        }
        else
        {
            printf("[lua]: main.lua not exist, excute from const script.\n");
            argc = sizeof(argv_script_const)/sizeof(argv_script_const[0]);
            argv = (char **)argv_script_const;
        }
    }
/*-\NEW\liweqiang\2013.5.8\在文件系统存在main.lua文件时启动时自动加载文件系统文件*/
/*-\NEW\2013.7.11\liweiqiang\增加luadb预置文件处理*/

    return lua_main(argc, argv);
}

