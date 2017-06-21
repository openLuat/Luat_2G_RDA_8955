/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:   crypto.c
 * Author:  zhutianhua
 * Date:    2017/4/17
 *
 * Description:
 *          lua.crypto¿â
 **************************************************************************/
#include "crypto.h"
#include "assert.h"


static int l_crypto_base64_encode(lua_State *L)
{
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    u8 *outputData = NULL;
    u32 outputLen = 0;
    u32 outputLenMax = (inputLen/3+1)*4;

    luaL_Buffer b;
    luaL_buffinit( L, &b );
    
    if(outputLenMax > LUAL_BUFFERSIZE)
    {
        outputData = malloc(outputLenMax+1);
        memset(outputData,0,outputLenMax+1);
        aliyun_iot_common_base64encode(inputData, inputLen, outputLenMax, outputData, &outputLen);
        luaL_addlstring(&b,outputData,outputLen);
        free(outputData);
        outputData = NULL;
    }
    else
    {
        aliyun_iot_common_base64encode(inputData, inputLen, LUAL_BUFFERSIZE, b.p, &outputLen);
        b.p += outputLen;
    }
    
    luaL_pushresult( &b );
    return 1;
}


static int l_crypto_base64_decode(lua_State *L)
{
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    u8 *outputData = NULL;
    u32 outputLen = 0;
    u32 outputLenMax = inputLen*3/4+1;

    luaL_Buffer b;
    luaL_buffinit( L, &b );
    
    if(outputLenMax > LUAL_BUFFERSIZE)
    {
        outputData = malloc(outputLenMax+1);
        memset(outputData,0,outputLenMax+1);
        aliyun_iot_common_base64decode(inputData, inputLen, outputLenMax, outputData, &outputLen);
        luaL_addlstring(&b,outputData,outputLen);
        free(outputData);
        outputData = NULL;
    }
    else
    {
        aliyun_iot_common_base64decode(inputData, inputLen, LUAL_BUFFERSIZE, b.p, &outputLen);
        b.p += outputLen;
    }
    
    luaL_pushresult( &b );
    return 1;
}


static int l_crypto_hmac_md5(lua_State *L)
{
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    const char *signKey = luaL_checkstring(L,3);
    int signKeyLen = luaL_checkinteger(L, 4);    

    luaL_Buffer b;
    luaL_buffinit( L, &b );    

    memset(b.buffer,0,LUAL_BUFFERSIZE);
    aliyun_iot_common_hmac_md5(inputData, inputLen, b.p, signKey, signKeyLen);
    b.p += strlen(b.buffer);
    
    luaL_pushresult( &b );
    return 1;
}


static int l_crypto_md5(lua_State *L)
{
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);

    luaL_Buffer b;
    luaL_buffinit( L, &b );    

    memset(b.buffer,0,LUAL_BUFFERSIZE);
    aliyun_iot_common_md5(inputData, inputLen, b.p);
    b.p += strlen(b.buffer);
    
    luaL_pushresult( &b );
    return 1;
}

static int l_crypto_crc16_modbus(lua_State *L)
{
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);

    lua_pushinteger(L, calcCRC16(inputData, inputLen));
    return 1;
}

static int l_crypto_crc32(lua_State *L)
{
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);

    lua_pushinteger(L, calcCRC32(inputData, inputLen));
    return 1;
}


static int l_crypto_aes128_ecb_encrypt(lua_State *L)
{
    #define BYTE_LEN 16
    char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    const char *key = luaL_checkstring(L,3);
    int keyLen = luaL_checkinteger(L, 4);

    //assert(keyLen==16);

    u8 *outputData = NULL;
    u32 outputLenMax = inputLen+BYTE_LEN;

    u8 inputItem[BYTE_LEN+1];
    u8 outputItem[BYTE_LEN+1];
    luaL_Buffer b;
    u32 rmnLen = inputLen;

    memset(b.buffer,0,LUAL_BUFFERSIZE);
    luaL_buffinit( L, &b );

    while(1)
    {
        if(rmnLen>BYTE_LEN)
        {
            memset(inputItem,0,sizeof(inputItem));
            memcpy(inputItem,inputData,BYTE_LEN);
            inputData += BYTE_LEN;
            rmnLen -= BYTE_LEN;
            memset(outputItem,0,sizeof(outputItem));
            AES128_ECB_encrypt(inputItem, key, outputItem);
            luaL_addlstring(&b,outputItem,BYTE_LEN);
        }
        else if(rmnLen!=0)
        {
            memset(inputItem,0,sizeof(inputItem));
            memcpy(inputItem,inputData,rmnLen);
            inputData += rmnLen;
            rmnLen -= rmnLen;
            memset(outputItem,0,sizeof(outputItem));
            AES128_ECB_encrypt(inputItem, key, outputItem);
            luaL_addlstring(&b,outputItem,BYTE_LEN);
        }
        else
        {
            break;
        }
    }        

    luaL_pushresult( &b );
    return 1;
}


static int l_crypto_aes128_ecb_decrypt(lua_State *L)
{
    #define BYTE_LEN 16
    char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    const char *key = luaL_checkstring(L,3);
    int keyLen = luaL_checkinteger(L, 4);

    //assert(keyLen==16);

    u8 *outputData = NULL;
    u32 outputLenMax = inputLen+BYTE_LEN;

    u8 inputItem[BYTE_LEN+1];
    u8 outputItem[BYTE_LEN+1];
    luaL_Buffer b;
    u32 rmnLen = inputLen;

    memset(b.buffer,0,LUAL_BUFFERSIZE);
    luaL_buffinit( L, &b );

    while(1)
    {
        if(rmnLen>BYTE_LEN)
        {
            memset(inputItem,0,sizeof(inputItem));
            memcpy(inputItem,inputData,BYTE_LEN);
            inputData += BYTE_LEN;
            rmnLen -= BYTE_LEN;
            memset(outputItem,0,sizeof(outputItem));
            AES128_ECB_decrypt(inputItem, key, outputItem);
            luaL_addlstring(&b,outputItem,BYTE_LEN);
        }
        else if(rmnLen!=0)
        {
            memset(inputItem,0,sizeof(inputItem));
            memcpy(inputItem,inputData,rmnLen);
            inputData += rmnLen;
            rmnLen -= rmnLen;
            memset(outputItem,0,sizeof(outputItem));
            AES128_ECB_decrypt(inputItem, key, outputItem);
            luaL_addlstring(&b,outputItem,BYTE_LEN);
        }
        else
        {
            break;
        }
    }        

    luaL_pushresult( &b );
    return 1;
}

#if 0
void AES128_ECB_encrypt(const uint8_t* input, const uint8_t* key, uint8_t *output);
void AES128_ECB_decrypt(const uint8_t* input, const uint8_t* key, uint8_t *output);
void AES128_CBC_encrypt_buffer(uint8_t* output, uint8_t* input, uint32_t length, const uint8_t* key, const uint8_t* iv);
void AES128_CBC_decrypt_buffer(uint8_t* output, uint8_t* input, uint32_t length, const uint8_t* key, const uint8_t* iv);
#endif

static int l_crypto_aes128_cbc_encrypt(lua_State *L)
{
    #define BYTE_LEN 16
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    const char *key = luaL_checkstring(L,3);
    int keyLen = luaL_checkinteger(L, 4);
    const char *iv = luaL_checkstring(L,5);
    int ivLen = luaL_checkinteger(L, 6);

    //assert(keyLen==16);

    u8 *outputData = NULL;
    u32 outputLenMax = inputLen+BYTE_LEN;

    luaL_Buffer b;
    memset(b.buffer,0,LUAL_BUFFERSIZE);
    luaL_buffinit( L, &b );
    
    //printf("l_crypto_aes128_cbc_encrypt %d %d %d\n",outputLenMax,inputLen,(inputLen%BYTE_LEN==0) ? inputLen : ((inputLen/BYTE_LEN+1)*BYTE_LEN));
    if(outputLenMax > LUAL_BUFFERSIZE)
    {
        outputData = malloc(outputLenMax+1);
        memset(outputData,0,outputLenMax+1);
        AES128_CBC_encrypt_buffer(outputData, inputData, inputLen, key, iv);
        luaL_addlstring(&b,outputData,(inputLen%BYTE_LEN==0) ? inputLen : ((inputLen/BYTE_LEN+1)*BYTE_LEN));
        free(outputData);
        outputData = NULL;
    }
    else
    {
        AES128_CBC_encrypt_buffer(b.p, inputData, inputLen, key, iv);
        b.p += (inputLen%BYTE_LEN==0) ? inputLen : (((inputLen/BYTE_LEN)+1)*BYTE_LEN);
    }
    
    luaL_pushresult( &b );
    return 1;
}

static int l_crypto_aes128_cbc_decrypt(lua_State *L)
{
    #define BYTE_LEN 16
    const char *inputData = luaL_checkstring(L,1);
    int inputLen = luaL_checkinteger(L, 2);
    const char *key = luaL_checkstring(L,3);
    int keyLen = luaL_checkinteger(L, 4);
    const char *iv = luaL_checkstring(L,5);
    int ivLen = luaL_checkinteger(L, 6);

    //assert(keyLen==16);

    u8 *outputData = NULL;
    u32 outputLenMax = inputLen+BYTE_LEN;

    luaL_Buffer b;
    memset(b.buffer,0,LUAL_BUFFERSIZE);
    luaL_buffinit( L, &b );
    
    
    if(outputLenMax > LUAL_BUFFERSIZE)
    {
        outputData = malloc(outputLenMax+1);
        memset(outputData,0,outputLenMax+1);
        AES128_CBC_decrypt_buffer(outputData, inputData, inputLen, key, iv);
        luaL_addlstring(&b,outputData,(inputLen%BYTE_LEN==0) ? inputLen : ((inputLen/BYTE_LEN+1)*BYTE_LEN));
        free(outputData);
        outputData = NULL;
    }
    else
    {
        AES128_CBC_decrypt_buffer(b.p, inputData, inputLen, key, iv);
        b.p += (inputLen%BYTE_LEN==0) ? inputLen : ((inputLen/BYTE_LEN+1)*BYTE_LEN);
    }
    
    luaL_pushresult( &b );
    return 1;
}



#define MIN_OPT_LEVEL 2
#include "lrodefs.h"
const LUA_REG_TYPE crypto_map[] =
{
    { LSTRKEY( "base64_encode" ),  LFUNCVAL( l_crypto_base64_encode ) },
    { LSTRKEY( "base64_decode" ),  LFUNCVAL( l_crypto_base64_decode ) },
    { LSTRKEY( "hmac_md5" ),  LFUNCVAL( l_crypto_hmac_md5 ) },
    { LSTRKEY( "md5" ),  LFUNCVAL( l_crypto_md5 ) },
    { LSTRKEY( "crc16_modbus" ),  LFUNCVAL( l_crypto_crc16_modbus ) },
    { LSTRKEY( "crc32" ),  LFUNCVAL( l_crypto_crc32 ) },
    { LSTRKEY( "aes128_ecb_encrypt" ),  LFUNCVAL( l_crypto_aes128_ecb_encrypt ) },
    { LSTRKEY( "aes128_ecb_decrypt" ),  LFUNCVAL( l_crypto_aes128_ecb_decrypt ) },
    //{ LSTRKEY( "aes128_cbc_encrypt" ),  LFUNCVAL( l_crypto_aes128_cbc_encrypt ) },
    //{ LSTRKEY( "aes128_cbc_decrypt" ),  LFUNCVAL( l_crypto_aes128_cbc_decrypt ) },

    { LNILKEY, LNILVAL }
};

int luaopen_crypto( lua_State *L )
{
    luaL_register( L, AUXLIB_CRYPTO, crypto_map );
    return 1;
}

