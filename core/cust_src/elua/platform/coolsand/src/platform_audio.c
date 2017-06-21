/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_audio.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/10/21
 *
 * Description:
 *          音频接口
 **************************************************************************/

#include "rda_pal.h"
#include "string.h"

#include "platform.h"
#include "platform_malloc.h"
#include "platform_audio.h"

static BOOL isPlaying = FALSE;
static u8 *audplaybuffer = NULL;

extern WCHAR* strtows(WCHAR* dst, const char* src);

static void audio_play_callback(E_AMOPENAT_PLAY_ERROR result)
{
    PlatformMessage *rtosmsg;
    
    if(audplaybuffer)
    {
        platform_free(audplaybuffer);
        audplaybuffer = NULL;
    }
    isPlaying = FALSE;
    
    rtosmsg = platform_calloc(1, sizeof(PlatformMessage));
    rtosmsg->id = RTOS_MSG_AUDIO;

    if(OPENAT_AUD_PLAY_ERR_NO == result || OPENAT_AUD_PLAY_ERR_END_OF_FILE == result)
        rtosmsg->data.audioData.playEndInd = TRUE;
    else
    {
        PUB_TRACE("audio play error: %d", result);
        rtosmsg->data.audioData.playErrorInd = TRUE;
    }

    platform_rtos_send(rtosmsg);
}

static E_AMOPENAT_PLAY_FILE_FORMAT getFileFormat(const char *filename)
{
    if(strstr(filename,".amr") || strstr(filename,".AMR"))
        return OPENAT_AUD_PLAY_FILE_FORMAT_AMR;

    if(strstr(filename,".mp3") || strstr(filename,".MP3"))
        return OPENAT_AUD_PLAY_FILE_FORMAT_MP3;

    if(strstr(filename,".mid") || strstr(filename,".MID"))
        return OPENAT_AUD_PLAY_FILE_FORMAT_MIDI;

    return -1;
}

static E_AMOPENAT_PLAY_MODE getDataFormat(PlatformAudioFormat audFormat)
{
    static const E_AMOPENAT_PLAY_MODE mode[NumOfPlatformAudFormats] =
    {
        OPENAT_AUD_PLAY_MODE_AMR122,
        OPENAT_AUD_PLAY_MODE_MP3,
        OPENAT_AUD_PLAY_MODE_PCM,
        OPENAT_AUD_PLAY_MODE_WAV,
        OPENAT_AUD_PLAY_MODE_MIDI,
    };

    if(audFormat < NumOfPlatformAudFormats)
        return mode[audFormat];
    else
        return OPENAT_AUD_PLAY_MODE_QTY;
}

int platform_audio_play(AudioPlayParam *param)
{
    T_AMOPENAT_PLAY_PARAM playParam;
    static WCHAR uniFileName[100];

    if(isPlaying)
    {
        PUB_TRACE("platform_audio_play: playing.");
        return PLATFORM_ERR;
    }

    if(param->isBuffer)
    {
        E_AMOPENAT_PLAY_MODE dataFormat;
    
        if(audplaybuffer)
        {
            PUB_TRACE("platform_audio_play:buffer not free");
            return PLATFORM_ERR;
        }

        if(OPENAT_AUD_PLAY_MODE_QTY == (dataFormat = getDataFormat(param->buffer.format)))
        {
            PUB_TRACE("platform_audio_play:unkonwn data format");
            return PLATFORM_ERR;
        }
        
        audplaybuffer = platform_malloc(param->buffer.len);
        
        if(audplaybuffer == NULL)
        {
            PUB_TRACE("platform_audio_play:not enough memory");
            return PLATFORM_ERR;
        }

        memcpy(audplaybuffer, param->buffer.data, param->buffer.len);
        
        playParam.playBuffer = TRUE;
        playParam.playBufferParam.callback = audio_play_callback;
        playParam.playBufferParam.pBuffer = (INT32 *)audplaybuffer;
        playParam.playBufferParam.len = param->buffer.len;
        playParam.playBufferParam.format = dataFormat;
        playParam.playBufferParam.loop = FALSE;
    }
    else
    {
        E_AMOPENAT_PLAY_FILE_FORMAT fileformat;
        
        if(strlen(param->filename) > sizeof(uniFileName)/sizeof(uniFileName[0])-1)
        {
            PUB_TRACE("platform_audio_play:filename too long");
            return PLATFORM_ERR;
        }

        fileformat = getFileFormat(param->filename);

        if(fileformat == -1)
        {
            PUB_TRACE("platform_audio_play:unknown format");
            return PLATFORM_ERR;
        }
    
        strtows(uniFileName, param->filename);
        
        playParam.playBuffer = FALSE;
        playParam.playFileParam.fileFormat = fileformat;
        playParam.playFileParam.fileNameUniLe = uniFileName;
        playParam.playFileParam.callback = audio_play_callback;
    }

    if(IVTBL(play_music)(&playParam) == FALSE)
    {
        PUB_TRACE("platform_audio_play:play_music failed");
        if(audplaybuffer)
        {
            platform_free(audplaybuffer);
            audplaybuffer = NULL;
        }
        return PLATFORM_ERR;
    }

    isPlaying = TRUE;
    
    return PLATFORM_OK;
}

int platform_audio_stop(void)
{
    if(FALSE == isPlaying)
        return PLATFORM_OK;

    IVTBL(stop_music)();
    if(audplaybuffer)
    {
        platform_free(audplaybuffer);
        audplaybuffer = NULL;
    }
    isPlaying = FALSE;
    return PLATFORM_OK;
}

/*+\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/
int platform_audio_set_channel(PlatformAudioChannel channel)
{
    if(channel >= NumOfPlatformAudChannels)
    {
        return PLATFORM_ERR;
    }
    IVTBL(set_channel)(channel);
    return PLATFORM_OK;
}

int platform_audio_set_vol(PlatformAudioVol vol)
{
    if(vol >= NumOfPlatformAudVols)
    {
        return PLATFORM_ERR;
    }
    IVTBL(set_speaker_gain)(vol);
    return PLATFORM_OK;
}

int platform_audio_set_mic_vol(PlatformMicVol vol)
{
    if(vol >15)
    {
        return PLATFORM_ERR;
    }
    IVTBL(set_mic_gain)(vol);
    return PLATFORM_OK;
}


int platform_audio_set_loopback(BOOL flag, PlatformAudioLoopback typ, BOOL setvol, u32 vol)
{
    if(typ >= NumOfPlatformAudLoopbacks)
    {
        return PLATFORM_ERR;
    }
    IVTBL(audio_loopback)(flag, typ, setvol, vol);
    return PLATFORM_OK;
}
/*-\NEW\zhuth\2014.7.25\新增设置音频通道和音量的同步接口*/

