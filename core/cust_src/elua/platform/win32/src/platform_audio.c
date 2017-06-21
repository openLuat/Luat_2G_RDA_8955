#include <STDIO.H>
#include <WINDOWS.H>
#include "win_msg.h"
#include "platform.h"
#include "platform_audio.h"

int platform_audio_play(AudioPlayParam *param)
{
    PlatformMessage *rtosmsg;
    MSG msg;
    
    rtosmsg = malloc(sizeof(PlatformMessage));
    rtosmsg->id = RTOS_MSG_AUDIO;
    rtosmsg->data.audioData.playEndInd = TRUE;

    msg.message = SIMU_RTOS_MSG_ID;
    msg.wParam = (WPARAM)rtosmsg;
    SendToLuaShellMessage(&msg);
    return PLATFORM_OK;
}

int platform_audio_stop(void)
{
    return PLATFORM_OK;
}

int platform_audio_set_channel(PlatformAudioChannel channel)
{
    return PLATFORM_OK;
}

int platform_audio_set_vol(PlatformAudioVol vol)
{
    return PLATFORM_OK;
}

int platform_audio_set_mic_vol(PlatformMicVol vol)
{
    return PLATFORM_OK;
}


int platform_audio_set_loopback(BOOL flag, PlatformAudioLoopback typ, BOOL setvol, u32 vol)
{
    return PLATFORM_OK;
}