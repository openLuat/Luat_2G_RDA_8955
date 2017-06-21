/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    preload.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/7/1
 *
 * Description:
 *          预置文件解析处理
 **************************************************************************/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "type.h"
#include "assert.h"
#include "LzmaLib.h"
#include "preload.h"


#define ASSERT_LEN(len, defLen)     ((len) == (defLen) ? 0 : LUADB_ERR_TLV_LEN)

#define DBMAKEU16(d, p)             ((u16)(d[p]|((d[p+1])<<8)))
#define DBMAKEU32(d, p)             ((u32)(DBMAKEU16(d,p)|(DBMAKEU16(d,p+2)<<16)))

typedef struct DbHeadInfoTag
{
    u16         verNum;
    u16         filecount;
    u32         length;
}DbHeadInfo;

typedef struct DbFileInfoTag
{
    char       *name;
    u8          nameLen;
    u32         length;
    const u8   *data;
    /*+\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/
    #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
    u32 offset;
    #endif
    /*-\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/
}DbFileInfo;

typedef enum DbHeadTypeTag
{
    HeadInfoReserved0x00 = 0x00,
    HeadInfoMagicNumber,
    HeadInfoVersion,
    HeadInfoLength,
    HeadInfoFilecount,

    HeadInfoCRC = 0xFE,
    HeadInfoReserved0xFF = 0xFF
}DbHeadType;

typedef enum DbFileHeadTypeTag
{
    FileHeadReserved0x00 = 0x00,
    FileHeadMagicNumber = 0x01,
    FileHeadName,
    FileHeadLength,

    FileHeadCRC = 0xFE,
    FileHeadReserved0xFF = 0xFF
}DbFileHeadType;

/*+\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的LUA文件*/
#ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
char *fgets_ext(char *buf, int n, FILE *fp);
FILE *fopen_ext(const char *file, const char *mode);
int fclose_ext(FILE *fp);
int getc_ext(FILE *fp);
int ungetc_ext(int c, FILE *fp);
size_t fread_ext(void *buf, size_t size, size_t count, FILE *fp);
int fseek_ext(FILE *fp, long offset, int whence);
long ftell_ext(FILE *fp);
int feof_ext(FILE *fp);
#define EOF_EXT (-1)
typedef struct UNCOMPRESS_FILE_TABLE_ITEM_TAG
{
    char *pFile;
    s32 nOffset;
    s32 nLen;
    struct UNCOMPRESS_FILE_TABLE_ITEM_TAG *pNext;
}T_UNCOMPRESS_FILE_TABLE_ITEM;

static T_UNCOMPRESS_FILE_TABLE_ITEM *pUpdateFileTable = NULL;
static T_UNCOMPRESS_FILE_TABLE_ITEM *pFlashFileTable = NULL;

static BOOL AddUncompressFileItem(E_LUA_SCRIPT_TABLE_SECTION nSection, const char *pFile, s32 nOffset, s32 nLen)
{
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;
    
    /*begin\NEW\zhutianhua\2017.3.10 16:14\修正下载空文件后，开机一直重启的问题*/
    if((nSection >= LUA_SCRIPT_TABLE_MAX_SECTION) || (NULL == pFile) || (strlen(pFile) == 0) /*|| (nLen == 0)*/)
    /*end\NEW\zhutianhua\2017.3.10 16:14\修正下载空文件后，开机一直重启的问题*/
    {
        printf("[AddUncompressFileItem]: para error!\n");
        return FALSE;
    }

    pItem = calloc(1,sizeof(T_UNCOMPRESS_FILE_TABLE_ITEM));
    if(NULL == pItem)
    {
        printf("[AddUncompressFileItem]: malloc item error!\n");
        return FALSE;
    }
    pItem->pFile = calloc(1,strlen(pFile) + 1);
    if(NULL == pItem->pFile)
    {
        printf("[AddUncompressFileItem]: malloc file error!\n");
        free(pItem);
        pItem = NULL;
        return FALSE;
    }
    
    memcpy(pItem->pFile, pFile, strlen(pFile));
    pItem->nOffset = nOffset;
    pItem->nLen = nLen;

    if(LUA_SCRIPT_TABLE_UPDATE_SECTION == nSection)
    {
        if(NULL == pUpdateFileTable)
        {
            pUpdateFileTable = pItem;
            return TRUE;
        }
        pItem->pNext = pUpdateFileTable;
        pUpdateFileTable = pItem;
    }
    else if(LUA_SCRIPT_TABLE_FLASH_SECTION == nSection)
    {
        if(NULL == pFlashFileTable)
        {
            pFlashFileTable = pItem;
            return TRUE;
        }
        pItem->pNext = pFlashFileTable;
        pFlashFileTable = pItem;
    }

    return TRUE;
}

static BOOL FindUncompressFileItem(E_LUA_SCRIPT_TABLE_SECTION *pSection, T_UNCOMPRESS_FILE_TABLE_ITEM **ppItem, const char *pFile)
{
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;
    short idx = 0;
    
    if((!pSection) || (!ppItem) || (!pFile) || (strlen(pFile) == 0))
    {
        printf("[FindUncompressFileItem]: para error!\n");
        return FALSE;
    }

    if(pUpdateFileTable)
    {
        pItem = pUpdateFileTable;
        while(pItem)
        {
            if((strlen(pFile) == strlen(pItem->pFile)) && (memcmp(pFile, pItem->pFile, strlen(pFile)) == 0))
            {
                *pSection = LUA_SCRIPT_TABLE_UPDATE_SECTION;
                *ppItem = pItem;
                return TRUE;
            }
            idx++;
            pItem = pItem->pNext;
        }
    }

    if(pFlashFileTable)
    {
        pItem = pFlashFileTable;
        idx = 0;
        while(pItem)
        {
            if((strlen(pFile) == strlen(pItem->pFile)) && (memcmp(pFile, pItem->pFile, strlen(pFile)) == 0))
            {
                *pSection = LUA_SCRIPT_TABLE_FLASH_SECTION;
                *ppItem = pItem;
                return TRUE;
            }
            idx++;
            pItem = pItem->pNext;
        }
    }

    return FALSE;
}

static void PrintUncompressFileTable(void)
{
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;

    pItem = pUpdateFileTable;
    while(pItem)
    {
        printf("UD:file=%s,len=%d,offset=%d\n", pItem->pFile, pItem->nLen, pItem->nOffset);
        pItem = pItem->pNext;
    }

    pItem = pFlashFileTable;
    while(pItem)
    {
        printf("FH:file=%s,len=%d,offset=%d\n", pItem->pFile, pItem->nLen, pItem->nOffset);
        pItem = pItem->pNext;
    }
}

char *fgets_ext(char *buf, int n, FILE *fp)
{
    int character = 0;
    int idx = 0;
    
    if((NULL == buf) || (n <= 1) || (NULL == fp))
    {
        return NULL;
    }

    character = getc_ext(fp);

    if(EOF_EXT == character)
    {
        return NULL;
    }
    
    while(EOF_EXT != character)
    {
        if(idx >= (n-1))
        {
            break;
        }

        buf[idx] = character;
        if(0x0A == character)
        {
            buf[idx+1] = 0;
            break;
        }
        
        idx++;
        character = getc_ext(fp);
    }

    if(EOF_EXT == character)
    {
        buf[idx] = 0;
    }
    
    buf[n-1] = 0;
    return buf;
}


FILE *fopen_ext(const char *file, const char *mode)
{
    FILE *fp = NULL;
    E_LUA_SCRIPT_TABLE_SECTION section = LUA_SCRIPT_TABLE_MAX_SECTION;
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;
    int fileNameLen = strlen(file);
    
    if((!file) || (strlen(file) == 0))
    {
        printf("[fopen_ext]: para error!\n");
        return fp;
    }

    if(FindUncompressFileItem(&section, &pItem, file))
    {        
        fp = calloc(1,sizeof(FILE));
        if(fp)
        {
            fp->_flags = section;
            fp->_cookie = pItem;
        }
        fp->_type = LUA_UNCOMPRESS_FILE;

#ifdef AM_LUA_CRYPTO_SUPPORT
        if(strncmp(&file[fileNameLen - 5],".luae", 5) == 0)
        {
            fp->_type |= ENC_FILE;
        }
#endif

        printf("[fopen_ext]: %s %d!\n", file, fp->_type);
    }

    return fp;
}

int fclose_ext(FILE *fp)
{
    if(!fp)
    {
        return -1;
    }    

    free(fp);
    
    return 0;
}

int getc_ext(FILE *fp)
{
    char c;
    
    if(fread_ext((void *)&c, 1, 1, fp) != 1){
        return (EOF_EXT);
    }

    return c;
}

int ungetc_ext(int c, FILE *fp)
{
    fseek_ext(fp, -1, SEEK_CUR);

    return 0;
}

//#define CRYPTO_DEBUG
#define DEC_BUFF_SIZE 512
extern char _lua_script_section_start[];

static int decode_file(void *buf, size_t size, size_t count, FILE *fp)
{

    unsigned int act_low_boundary;  /*以512对齐的读取文件的起始位置*/
    unsigned int read_count;        /*需要从文件中读取的长度*/
    unsigned int act_up_boundary;   /*以512对齐的读取文件的结束位置*/
    unsigned int act_count;         /*读取到的有效数据长度*/
    unsigned char* temp;
    unsigned int* data = NULL;
    size_t resid;
    int len;
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;
    unsigned int offset  = ftell_ext(fp);

    int decCount;
    int i = 0;
    int real_size;

    resid = count * size;
    
    pItem = (T_UNCOMPRESS_FILE_TABLE_ITEM *)(fp->_cookie);

    act_low_boundary = (offset & 0xFFFFFE00);
    act_up_boundary = ((offset + resid + DEC_BUFF_SIZE - 1) & 0xFFFFFE00);
    read_count = act_up_boundary - act_low_boundary; 

    /*多申请8个字节的内存，以保证能4字节对齐*/
    data = (unsigned int*)malloc(4 + read_count + 4);
    
    /*保证4字节对齐*/
    temp = (unsigned char*)((((unsigned int)data + 3) >> 2) << 2);

    /*把文件指针移到以512对齐的位置*/
    fseek_ext(fp, act_low_boundary, SEEK_SET);

    len = ((pItem->nLen - offset) >= read_count) ? read_count : (pItem->nLen - offset);
    memcpy(temp, &_lua_script_section_start[pItem->nOffset + offset], len);
    
    
    act_count = resid;
    decCount = len / DEC_BUFF_SIZE;
   
    /*如果没有读到足够多的数据，意味着快到文件的末尾了*/
    if(read_count > len)
    {
        real_size = pItem->nLen;

        if(real_size - offset < resid)
        {
            act_count = real_size - offset;
        }
    }
    
    /*把文件指针移到真实的位置*/
    fseek_ext(fp, offset + act_count, SEEK_SET);

#ifdef CRYPTO_DEBUG
    printf("liulean decode info  %d %d %d %d %d %d\r\n", 
        act_low_boundary, 
        act_up_boundary, 
        offset + count,
        offset - act_low_boundary,
        count,
        decCount);
#endif

    while(i < decCount)
    {
        platform_decode((unsigned int*)(temp + DEC_BUFF_SIZE * i), -((DEC_BUFF_SIZE) / 4));
        i++;
    }

    platform_decode((unsigned int*)(temp + DEC_BUFF_SIZE * i), -((len % DEC_BUFF_SIZE) / 4));
    
    memcpy(buf, &temp[offset - act_low_boundary], act_count);
    free(data);

    return (act_count / size);

}

size_t fread_ext(void *buf, size_t size, size_t count, FILE *fp)
{
    size_t resid;
    int len;
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;

    if((!buf) || (!fp))
    {
        return 0;
    }

    if((resid = count * size) == 0)
    {
        printf("[fread_ext]: size 0!\n");
        return 0;
    }

    
    pItem = (T_UNCOMPRESS_FILE_TABLE_ITEM *)(fp->_cookie);
    len = ((pItem->nLen - fp->_offset) >= resid) ? resid : (pItem->nLen - fp->_offset);

    if(len <= 0)
    {
        return 0;
    }

    if(fp->_flags == LUA_SCRIPT_TABLE_UPDATE_SECTION)
    {
        #define LUA_UPDATE_FILE "/luazip/update.bin"
        FILE *fpUpd = NULL;        
    
        if((fpUpd = fopen(LUA_UPDATE_FILE, "rb")) == NULL)
        {
            printf("[fread_ext]: fpUpd open error!\n");
            return 0;
        }
        
        fseek(fpUpd, pItem->nOffset + fp->_offset, SEEK_CUR);        
        fread(buf, 1, len, fpUpd);
        fclose(fpUpd);
    }
    else if(fp->_flags == LUA_SCRIPT_TABLE_FLASH_SECTION)
    {
        //extern char _lua_script_section_start[LUA_SCRIPT_SIZE];
        //memcpy(buf, &_lua_script_section_start[pItem->nOffset + fp->_offset], len);

#ifdef AM_LUA_CRYPTO_SUPPORT
        if(fp->_type == LUA_UNCOMPRESS_ENC_FILE)
        {
            return decode_file(buf, size, count, fp);
        }
        else
#endif
        {
            memcpy(buf, &_lua_script_section_start[pItem->nOffset + fp->_offset], len);
        }
    }
    else
    {
        return 0;
    }

    fp->_offset += len;
    
    return (len/size);
}

int fseek_ext(FILE *fp, long offset, int whence)
{
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;

    if(!fp)
    {
        printf("[fseek_ext]: fp error!\n");
        return -1;
    }

    pItem = (T_UNCOMPRESS_FILE_TABLE_ITEM *)(fp->_cookie);
    
    if(SEEK_SET == whence)
    {
        if((offset > pItem->nLen) || (offset < 0))
        {
            printf("[fseek_ext]: set(%d) error!\n", offset);
            return -1;
        }
        fp->_offset = offset;
    }
    else if(SEEK_CUR == whence)
    {
        if(((fp->_offset + offset) > pItem->nLen) || ((fp->_offset + offset) < 0))
        {
            printf("[fseek_ext]: cur(%d) error!\n", (fp->_offset + offset));
            return -1;
        }
        fp->_offset += offset;
    }
    else if(SEEK_END == whence)
    {
        if((offset < -(pItem->nLen)) || (offset > 0))
        {
            printf("[fseek_ext]: end(%d),(%d) error!\n", offset,-(pItem->nLen));
            return -1;
        }
        fp->_offset = pItem->nLen - offset;
    }
    else
    {
        printf("[fseek_ext]: whence error!\n");
        return -1;
    }
    
    return 0;
}

long ftell_ext(FILE *fp)
{
    if(!fp)
    {
        printf("[ftell_ext]: fp error!\n");
        return -1;
    }

    return fp->_offset;    
}

int feof_ext(FILE *fp)
{
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;

    if(!fp)
    {
        printf("[feof_ext]: fp error!\n");
        return 0;
    }

    pItem = (T_UNCOMPRESS_FILE_TABLE_ITEM *)(fp->_cookie);

    if(fp->_offset >= pItem->nLen)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}
#endif
/*-\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的LUA文件*/

extern int file_exist(const char *name);

static u16 calcCheckCode(const u8 *data, u32 length)
{
    u32 checksum = 0;

    while(length--)
    {
        checksum += data[length];
    }

    return (u16)checksum;
}

static int decodeFile(const u8 *pData, DbFileInfo *pFileInfo, u32 *pOffset)
{
    u8 type;
    u8 length;
    int err = 0;
    u32 pos = 0;
    u16 checkCode = 0;
    BOOL loop = TRUE;
    u32 magic = 0;
    
    while(loop && !err)
    {
        type = pData[pos++];
        length = pData[pos++];
        
        switch(type)
        {
        case FileHeadReserved0x00:
        case FileHeadReserved0xFF:
            err = ASSERT_LEN(length, 0);
            break;
            
        case FileHeadMagicNumber:
            err = ASSERT_LEN(length, 4);
            magic = DBMAKEU32(pData, pos);
            break;
            
        case FileHeadName:
            pFileInfo->name = calloc(1, length+1);
            memcpy(pFileInfo->name, &pData[pos], length);
            pFileInfo->nameLen = length;
            break;
            
        case FileHeadLength:
            err = ASSERT_LEN(length, 4);
            pFileInfo->length = DBMAKEU32(pData, pos);
            break;

        case FileHeadCRC:
            err = ASSERT_LEN(length, 2);
            checkCode = DBMAKEU16(pData, pos);
            loop = FALSE;
            break;

        default:
            err = LUADB_ERR_UNKNOWN_TYPE;
            break;
        }
        
        pos += length;
    }
    
    if(err != 0)
    {
        goto decode_file_exit;
    }
    
    if(magic != 0xA55AA55A)
    {
        err = LUADB_ERR_MAGIC;
        goto decode_file_exit;
    }

    if(calcCheckCode(pData, pos - 2/*check data 2 byte*/) != checkCode)
    {
        err = LUADB_ERR_CHECK_FAIL;
        goto decode_file_exit;
    }
    
    pFileInfo->data = &pData[pos];
    /*+\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/
    #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
    pFileInfo->offset = *pOffset + pos;
    #endif
    /*-\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/

    // 计算偏移 +文件内容与填充内容
    pos += pFileInfo->length;
    *pOffset += pos;
    
decode_file_exit:
    return err;
}

static int decodeHeadInfo(const u8 *pData, DbHeadInfo *pHeadInfo, u32 *pOffset)
{
    u8 type;
    u8 length;
    int err = 0;
    u32 pos = 0;
    u16 checkCode = 0;
    BOOL loop = TRUE;
    u32 magic = 0;

    while(loop && !err)
    {
        type = pData[pos++];
        length = pData[pos++];

        switch(type)
        {
        case HeadInfoMagicNumber:
            err = ASSERT_LEN(length, 4);
            magic = DBMAKEU32(pData, pos);
            break;

        case HeadInfoVersion:
            err = ASSERT_LEN(length, 2);
            pHeadInfo->verNum = DBMAKEU16(pData, pos);
            break;
        
        case HeadInfoLength:
            err = ASSERT_LEN(length, 4);
            pHeadInfo->length = DBMAKEU32(pData, pos);
            break;

        case HeadInfoFilecount:
            /*begin\NEW\zhutianhua\2017.4.12 17:55\兼容IDE脚本打包协议，文件个数字段扩大为2个字节*/
            if(pHeadInfo->verNum==0)
            {
                err = ASSERT_LEN(length, 1);
                pHeadInfo->filecount = pData[pos];
            }
            else
            {
                err = ASSERT_LEN(length, 2);
                pHeadInfo->filecount = DBMAKEU16(pData, pos);
            }
            /*end\NEW\zhutianhua\2017.4.12 17:55\兼容IDE脚本打包协议，文件个数字段扩大为2个字节*/
            break;

        case HeadInfoReserved0x00:
        case HeadInfoReserved0xFF:
            err = ASSERT_LEN(length, 0);
            break;
        
        case HeadInfoCRC:
            err = ASSERT_LEN(length, 2);
            checkCode = DBMAKEU16(pData, pos);
            loop = FALSE;
            break;

        default:
            err = LUADB_ERR_UNKNOWN_TYPE;
            break;
        }

        pos += length;
    }

    if(err != 0)
    {
        goto decode_head_exit;
    }

    if(magic != 0xA55AA55A)
    {
        err = LUADB_ERR_MAGIC;
        goto decode_head_exit;
    }

    if(calcCheckCode(pData, pos - 2/*check data 2 byte*/) != checkCode)
    {
        err = LUADB_ERR_CHECK_FAIL;
        goto decode_head_exit;
    }

/*+\NEW\liweiqiang\2013.12.9\去掉luadb最多100个文件的限制 */
#if 0    
    if(pHeadInfo->filecount > 100)
    {
        err = LUADB_ERR_TOO_MANY_FILES;
        goto decode_head_exit;
    }
#endif
/*-\NEW\liweiqiang\2013.12.9\去掉luadb最多100个文件的限制 */

    *pOffset += pHeadInfo->length;

decode_head_exit:
    return err;
}

/*+\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
int parse_luadb_data(const u8 *pData, u32 length, BOOL override, E_LUA_SCRIPT_TABLE_SECTION section, BOOL *pRestart)
/*-\NEW\zhuth\2014.2.17\通过文件记录表访问luadb中未压缩的文件*/
{
#define LUA_UPDATE_FILE "/luazip/update.bin"
    int err;
    u32 offset = 0;
    DbHeadInfo headInfo;
    u16 fileIndex;
    DbFileInfo *pFileInfo = NULL;
    char filename[256];
    int lzmaRet = 0;
    /*+\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
    BOOL delupdpack = TRUE;
    #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
    E_LUA_SCRIPT_TABLE_SECTION nSection = LUA_SCRIPT_TABLE_MAX_SECTION;
    T_UNCOMPRESS_FILE_TABLE_ITEM *pItem = NULL;
    BOOL exist = FALSE;
    #endif    
    /*-\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
    /*+\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
    BOOL wrFile = FALSE;
    /*-\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/

    if(!(pData[0] == 0x01 || pData[1] == 0x04))
        return LUADB_ERR_NOT_DBDATA;

    memset(&headInfo, 0, sizeof(headInfo));

    //根据头信息得到总文件个数

    err = decodeHeadInfo(pData, &headInfo, &offset);

    if(0 != err)
    {
        goto decode_exit;
    }

    pFileInfo = calloc(1, sizeof(DbFileInfo)*headInfo.filecount);

    if(!pFileInfo)
        goto decode_exit;

    for(fileIndex = 0; fileIndex < headInfo.filecount && offset < length; fileIndex++)
    {
        //解析每个文件，文件数据地址，文件大小
        if((err = decodeFile(&pData[offset], &pFileInfo[fileIndex], &offset)) != LUADB_ERR_NONE)
        {
            goto decode_exit;
        }
    }

    if(offset > length)
    {
        err = LUADB_ERR_OUT_OF_RANGE;
        goto decode_exit;
    }

    if(fileIndex != headInfo.filecount)
    {
        err = LUADB_ERR_FILE_COUNT;
        goto decode_exit;
    }

    // write file to fs
    for(fileIndex = 0; fileIndex < headInfo.filecount; fileIndex++)
    {
        if(pFileInfo[fileIndex].nameLen > 4)
        {
            u8 withoutZipLen = pFileInfo[fileIndex].nameLen - 4;
/*+\NEW\liweiqiang\2013.10.25\lua脚本统一放在lua目录下,预置的非lua文件统一放在ldata文件下 */
            u8 withoutLuaLen = withoutZipLen - 4;
            memset(filename, 0, sizeof(filename));

            if(strcmp(&pFileInfo[fileIndex].name[withoutZipLen], ".zip") == 0)
            {
                if((strncmp(&pFileInfo[fileIndex].name[withoutLuaLen],".lua", 4) == 0)
                    ||
                    (strncmp(&pFileInfo[fileIndex].name[withoutLuaLen-1],".luae", 5) == 0))
                {
                    strcpy(filename, getenv("LUA_DIR"));
                }
                else
                {
                    strcpy(filename, getenv("LUA_DATA_DIR"));
                }
                strcat(filename,"/");
                strncat(filename, pFileInfo[fileIndex].name, withoutZipLen);

                /* 文件不存在或者强制覆盖时,解压数据 */
                /*+\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
                #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
                exist = FindUncompressFileItem(&nSection, &pItem, filename);
                if(((FALSE == file_exist(filename)) && !(exist && (nSection == LUA_SCRIPT_TABLE_UPDATE_SECTION)))
                    || (TRUE == override))
                #else
                if(FALSE == file_exist(filename) || TRUE == override)
                #endif
                /*-\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
                {
                    lzmaRet = LzmaDecodeBufToFile(pFileInfo[fileIndex].data, pFileInfo[fileIndex].length, filename);

                    if(lzmaRet != 0)
                    {
                        err = LUADB_ERR_UNZIP_FILE;
                        goto decode_exit;
                    }
                    /*+\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
                    wrFile = TRUE;
                    /*-\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
                }
                continue;
            }
            /*+\NEW\zhuth\2014.2.17\LuaDB下载时，非压缩的文件在开机时找不到*/
            else
            {
                /*+\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
                delupdpack = FALSE;
                /*-\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
                if((strncmp(&pFileInfo[fileIndex].name[pFileInfo[fileIndex].nameLen-4],".lua", 4) == 0)
                    ||
                    (strncmp(&pFileInfo[fileIndex].name[pFileInfo[fileIndex].nameLen-5],".luae", 5) == 0)
                    )
                {                    
                    strcpy(filename, getenv("LUA_DIR"));
                }
                else
                {
                    strcpy(filename, getenv("LUA_DATA_DIR"));
                }
                strcat(filename,"/");
                strncat(filename, pFileInfo[fileIndex].name, pFileInfo[fileIndex].nameLen);

                /*+\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/
                #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
                {
                    char *p = &pFileInfo[fileIndex].name[pFileInfo[fileIndex].nameLen-4];
                    char *luep = &pFileInfo[fileIndex].name[pFileInfo[fileIndex].nameLen-5];
                    if((strncmp(p,".lua", 4) == 0) || (strncmp(p,".bmp", 4) == 0) || (strncmp(p,".BMP", 4) == 0)
                        #ifdef AM_LPNG_SUPPORT
                        || (strncmp(p,".png", 4) == 0) || (strncmp(p,".PNG", 4) == 0)
                        #endif
					/*+\liulean\2015.9.9\MP3和AMR文件不放在文件系统中*/
                    #ifndef DSS_AMR_MP3_STORE_ON_FS
                         || (strncmp(p,".amr", 4) == 0) || (strncmp(p,".AMR", 4) == 0)
                        || (strncmp(p,".MP3", 4) == 0) || (strncmp(p,".mp3", 4) == 0)
                    #endif
					/*-\liulean\2015.9.9\MP3和AMR文件不放在文件系统中*/
					    ||(strncmp(luep, ".luae", 5) == 0)
                       )
                    {
                        //将文件放入pFlashFileTable队列
                        if(FALSE == AddUncompressFileItem(section, filename, pFileInfo[fileIndex].offset, pFileInfo[fileIndex].length))
                        {
                            err = LUADB_ERR_ADD_TABLE_ITEM;
                            goto decode_exit;
                        }
                        else
                        {
                            continue;
                        }
                    }
                }
                #endif
                /*-\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/

                /* 文件不存在或者强制覆盖时,解压数据 */
                #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
                exist = FindUncompressFileItem(&nSection, &pItem, filename);
                if(((FALSE == file_exist(filename)) && !(exist && (nSection == LUA_SCRIPT_TABLE_UPDATE_SECTION)))
                    || (TRUE == override))
                #else
                if(FALSE == file_exist(filename) || TRUE == override)
                #endif
                {
                    FILE *fout = fopen(filename, "wb");
                    if(!fout)
                    {
                        err = LUADB_ERR_WRITE_FILE;
                        goto decode_exit;
                    }
                    //将从flash区域取出的文件写入文件系统
                    if(fwrite(pFileInfo[fileIndex].data, 1, pFileInfo[fileIndex].length, fout) != pFileInfo[fileIndex].length)
                    {
                        printf("[parse_luadb_data]: write file(%s) error!\n", filename);
                        fclose(fout);
                        fout = NULL;
                        remove(filename); //写文件失败,删除已写的文件.
                        err = LUADB_ERR_WRITE_FILE;
                        goto decode_exit;
                    }
                    fclose(fout);
                    fout = NULL;   
                    /*+\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
                    wrFile = TRUE;
                    /*-\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
                }                
            }
            /*-\NEW\zhuth\2014.2.17\LuaDB下载时，非压缩的文件在开机时找不到*/
        }        
/*-\NEW\liweiqiang\2013.10.25\lua脚本统一放在lua目录下,预置的非lua文件统一放在ldata文件下 */
    }

decode_exit:
    if(pFileInfo)
    {
        for(fileIndex = 0; fileIndex < headInfo.filecount; fileIndex++)
        {
        /*+\NEW\liweiqiang\2013.10.9\修正luadb加载问题*/
            if(pFileInfo[fileIndex].name)
                free(pFileInfo[fileIndex].name);
        /*-\NEW\liweiqiang\2013.10.9\修正luadb加载问题*/
        }

        free(pFileInfo);
    }

    if(err != LUADB_ERR_NONE)
        printf("[parse_luadb_data]: luadb error %d\n", err);

    /*+\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/
    #ifdef AM_LUA_UNCOMPRESS_SCRIPT_TABLE_ACESS_SUPPORT
    PrintUncompressFileTable();
    #endif
    /*-\NEW\zhuth\2014.2.18\通过文件记录表访问luadb中未压缩的文件*/
    printf("parse_luadb_data:delupdpack=%d,err=%d,section=%d,wrFile=%d\n",delupdpack,err,section,wrFile);
    
    /*+\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/
    if(delupdpack && (err == LUADB_ERR_NONE) && (section == LUA_SCRIPT_TABLE_UPDATE_SECTION))
    {
        remove(LUA_UPDATE_FILE);
        *pRestart = TRUE;
    }    
    /*-\NEW\zhuth\2014.8.13\升级包解压缩成功后，删除升级包，并且重启*/

    /*+\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/
    if((err == LUADB_ERR_NONE) && wrFile && (section == LUA_SCRIPT_TABLE_UPDATE_SECTION))
    {
        *pRestart = TRUE;
    }
    /*-\NEW\zhuth\2014.8.14\开机如果成功执行了所有的写文件动作，则重启*/

    return err;
}
