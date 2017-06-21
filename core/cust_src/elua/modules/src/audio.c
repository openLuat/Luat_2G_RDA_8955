/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    audio.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/10/21
 *
 * Description:
 *          audio.core
 **************************************************************************/

#include <stdlib.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "platform.h"
#include "lrotable.h"
#include "platform_conf.h"
#include "platform_audio.h"

static int l_audio_play_file(lua_State *L) {
    const char *name = luaL_checkstring(L,1);
    AudioPlayParam param;
    
	/*+\liulean\2015.9.9\MP3和AMR文件不放在文件系统中*/
    int len = 0;
    FILE *file;
    PlatformAudioFormat audioformat = NumOfPlatformAudFormats;
    u8 * playBuffer;
	/*-\liulean\2015.9.9\MP3和AMR文件不放在文件系统中*/

    param.isBuffer = FALSE;
    param.filename = name;

/*+\liulean\2015.9.9\MP3和AMR文件不放在文件系统中*/
#ifndef DSS_AMR_MP3_STORE_ON_FS
	file  = fopen(name, "rb");
    if(!file)
    {
        printf("l_audio_play_file:open file failed!");
        return PLATFORM_ERR;
    }

    fseek(file, 0, SEEK_END);
    len = ftell(file);

    if(strstr(name,".amr") || strstr(name,".AMR"))
        audioformat = PLATFORM_AUD_AMR122;
    else if(strstr(name,".mp3") || strstr(name,".MP3"))
        audioformat = PLATFORM_AUD_MP3;

    printf("l_audio_play_file format %d", audioformat);
    
    if(audioformat == PLATFORM_AUD_AMR122)
    {     
        fseek(file, 6, SEEK_SET);
        len -= 6;
    }
    else if(audioformat == PLATFORM_AUD_MP3)
    {
        fseek(file, 0, SEEK_SET);
    }

    if(audioformat == PLATFORM_AUD_AMR122 || audioformat == PLATFORM_AUD_MP3)
    {
        playBuffer = malloc(len);
        
        if(playBuffer == NULL)
        {
            printf("l_audio_play_file:not enough memory");
            fclose(file);
            return PLATFORM_ERR;
        }
        
        if(fread(playBuffer, 1, len, file) != len)
        {
            printf("[l_audio_play_file]: read file error!\n");
            platform_free(playBuffer);
            fclose(file);
            return PLATFORM_ERR;
        }
        
        fclose(file);

        param.isBuffer = TRUE;
        param.buffer.data = playBuffer;
        param.buffer.len = len;
        param.buffer.format = audioformat;
        param.buffer.loop = FALSE;

        printf("start  platform_audio_play\n");

        lua_pushboolean(L, platform_audio_play(&param) == PLATFORM_OK);
        free(playBuffer);
        
        return 1;
    }
#endif
/*-\liulean\2015.9.9\MP3和AMR文件不放在文件系统中*/
	
    lua_pushboolean(L, platform_audio_play(&param) == PLATFORM_OK);
    return 1;
}

static int l_audio_play_data(lua_State *L) {
    const char *data;
    int l;
    AudioPlayParam param;
    
    data = luaL_checklstring(L, 1, &l);
    param.isBuffer = TRUE;
    param.buffer.format = luaL_checkinteger(L, 2);
    param.buffer.loop = luaL_optinteger(L, 3, 0);
    param.buffer.data = data;
    param.buffer.len = l;
    
    lua_pushboolean(L, platform_audio_play(&param) == PLATFORM_OK);
    return 1;
}

static int l_audio_stop(lua_State *L) {
    platform_audio_stop();
    return 0;
}

/*+\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/
static int l_audio_set_channel(lua_State *L) {
    u32 channel = luaL_checkinteger(L,1);
    u32 res;
    
    res = platform_audio_set_channel(channel);
    lua_pushinteger(L, res);
    
    return 1;
}

static int l_audio_set_vol(lua_State *L) {
    u32 vol = luaL_checkinteger(L,1);
    u32 res;
    
    res = platform_audio_set_vol(vol);
    lua_pushinteger(L, res);
    
    return 1;
}

static int l_audio_set_mic_vol(lua_State *L) {
    u32 vol = luaL_checkinteger(L,1);
    u32 res;
    
    res = platform_audio_set_mic_vol(vol);
    lua_pushinteger(L, res);
    
    return 1;
}

static int l_audio_set_loopback(lua_State *L) {
    u32 flag = luaL_checkinteger(L,1);
    u32 typ = luaL_checkinteger(L,2);
    u32 setvol = luaL_checkinteger(L,3);
    u32 vol = luaL_checkinteger(L,4);
    u32 res;
    
    res = platform_audio_set_loopback(flag,typ,setvol,vol);
    lua_pushinteger(L, res);
    
    return 1;
}
/*-\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/

#define MIN_OPT_LEVEL 2
#include "lrodefs.h"  

// Module function map
const LUA_REG_TYPE audiocore_map[] =
{ 
  { LSTRKEY( "play" ),  LFUNCVAL( l_audio_play_file ) },
  { LSTRKEY( "playdata" ),  LFUNCVAL( l_audio_play_data ) },
  { LSTRKEY( "stop" ),  LFUNCVAL( l_audio_stop ) },
  /*+\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/
  { LSTRKEY( "setchannel" ),  LFUNCVAL( l_audio_set_channel ) },
  { LSTRKEY( "setvol" ),  LFUNCVAL( l_audio_set_vol ) },
  { LSTRKEY( "setmicvol" ),  LFUNCVAL( l_audio_set_mic_vol ) },
  { LSTRKEY( "setloopback" ),  LFUNCVAL( l_audio_set_loopback ) },
  /*-\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/

  { LNILKEY, LNILVAL }
};

LUALIB_API int luaopen_audiocore( lua_State *L )
{
    luaL_register( L, AUXLIB_AUDIOCORE, audiocore_map );
    MOD_REG_NUMBER(L, "AMR122", PLATFORM_AUD_AMR122);
    MOD_REG_NUMBER(L, "MP3", PLATFORM_AUD_MP3);
    MOD_REG_NUMBER(L, "PCM", PLATFORM_AUD_PCM);
    MOD_REG_NUMBER(L, "WAV", PLATFORM_AUD_WAV);
    MOD_REG_NUMBER(L, "MIDI", PLATFORM_AUD_MIDI);

    /*+\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/
    #define REG_AUD_CHANNEL(CHANNEL) MOD_REG_NUMBER(L, #CHANNEL, PLATFORM_AUD_CHANNEL_##CHANNEL)
    REG_AUD_CHANNEL(HANDSET);
    REG_AUD_CHANNEL(EARPIECE);
    REG_AUD_CHANNEL(LOUDSPEAKER);
    REG_AUD_CHANNEL(BLUETOOTH);
    REG_AUD_CHANNEL(FM);
    REG_AUD_CHANNEL(FM_LP);
    REG_AUD_CHANNEL(TV);
    REG_AUD_CHANNEL(AUX_HANDSET);
    REG_AUD_CHANNEL(AUX_LOUDSPEAKER);
    REG_AUD_CHANNEL(AUX_EARPIECE);
    REG_AUD_CHANNEL(DUMMY_HANDSET);
    REG_AUD_CHANNEL(DUMMY_AUX_HANDSET);
    REG_AUD_CHANNEL(DUMMY_LOUDSPEAKER);    
    REG_AUD_CHANNEL(DUMMY_AUX_LOUDSPEAKER);

    #define REG_AUD_VOL(VOL) MOD_REG_NUMBER(L, #VOL, PLATFORM_AUD_##VOL)
    REG_AUD_VOL(VOL0);
    REG_AUD_VOL(VOL1);
    REG_AUD_VOL(VOL2);
    REG_AUD_VOL(VOL3);
    REG_AUD_VOL(VOL4);
    REG_AUD_VOL(VOL5);
    REG_AUD_VOL(VOL6);
    REG_AUD_VOL(VOL7);   

    #define REG_MIC_VOL(VOL) MOD_REG_NUMBER(L, #VOL, PLATFORM_##VOL)
    REG_MIC_VOL(MIC_VOL0);
    REG_MIC_VOL(MIC_VOL1);
    REG_MIC_VOL(MIC_VOL2);
    REG_MIC_VOL(MIC_VOL3);
    REG_MIC_VOL(MIC_VOL4);
    REG_MIC_VOL(MIC_VOL5);
    REG_MIC_VOL(MIC_VOL6);
    REG_MIC_VOL(MIC_VOL7); 
    REG_MIC_VOL(MIC_VOL8);
    REG_MIC_VOL(MIC_VOL9);
    REG_MIC_VOL(MIC_VOL10);
    REG_MIC_VOL(MIC_VOL11);
    REG_MIC_VOL(MIC_VOL12);
    REG_MIC_VOL(MIC_VOL13);
    REG_MIC_VOL(MIC_VOL14);
    REG_MIC_VOL(MIC_VOL15); 

    #define REG_AUD_LOOPBACK(TYPE) MOD_REG_NUMBER(L, #TYPE, PLATFORM_AUD_##TYPE)
    REG_AUD_LOOPBACK(LOOPBACK_HANDSET);
    REG_AUD_LOOPBACK(LOOPBACK_EARPIECE);
    REG_AUD_LOOPBACK(LOOPBACK_LOUDSPEAKER);
    REG_AUD_LOOPBACK(LOOPBACK_AUX_HANDSET);
    REG_AUD_LOOPBACK(LOOPBACK_AUX_LOUDSPEAKER);
    /*-\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/
	
    return 1;
}  

