
#include <windows.h>
#include "win_msg.h"
#include "win_trace.h"

#include "type.h"
#include "platform.h"
#include "platform_conf.h"
#include "platform_rtos.h"

#define RTOS_WAIT_MSG_TIMER_ID          (0xffffffff)
#define SEND_SOUND_END_TIMER_ID         (-2)

extern DWORD luaShellThreadId;

static BOOL startRtosSimulator = FALSE;

extern int win_start_timer(int timer_id, int milliSecond);
extern int win_stop_timer(int timerId);
extern void platform_sendsound_end(void);

void SendToLuaShellMessage(const MSG *msg) 
{
    //if(!startRtosSimulator)
    {
    //    winTrace("[SendToLuaShellMessage]: lost msg(%d)", msg->message);
    //    return;
    }

    PostThreadMessageA(luaShellThreadId, msg->message, msg->wParam, msg->lParam);
}

int platform_rtos_send(PlatformMessage *pMsg){
    MSG msg;

    msg.message = SIMU_RTOS_MSG_ID;
    msg.wParam = (WPARAM)pMsg;
    SendToLuaShellMessage(&msg);

    return PLATFORM_OK;
}

int platform_rtos_send_high_priority(PlatformMessage *pMsg){
    MSG msg;

    msg.message = SIMU_RTOS_MSG_ID;
    msg.wParam = (WPARAM)pMsg;
    SendToLuaShellMessage(&msg);

    return PLATFORM_OK;
}

int platform_rtos_receive(void **ppMessage, u32 timeout)
{
    MSG msg;
    PlatformMessage *platform_msg;
    int ret = PLATFORM_OK;

    if(timeout != 0)
    {
        win_start_timer(RTOS_WAIT_MSG_TIMER_ID, timeout);
    }

    /* 第一次调用该接口才允许其他线程发送消息 */
    if(!startRtosSimulator)
    {
        startRtosSimulator = TRUE;
    }

    while(1)
    {
        GetMessage(&msg, NULL, 0, 0);

        //printf("msg.message: %x\n", msg.message);

        if(msg.message == DAEMON_TIMER_MSG_ID)
        {
            static u8 count = 0;

            if(10 > count)
                continue;

            platform_msg = malloc(sizeof(PlatformMessage));

            if(count == 0)
            {
                platform_msg->id = RTOS_MSG_PMD;
            }
            else if(count >= 1 && count <= 4)
            {
                platform_msg->id = RTOS_MSG_KEYPAD;
                platform_msg->data.keypadMsgData.bPressed = count%2;
                platform_msg->data.keypadMsgData.data.matrix.row = count%5;
                platform_msg->data.keypadMsgData.data.matrix.col = count%3;
            }
            else
            {
                platform_msg->id = RTOS_MSG_UART_RX_DATA;
                platform_msg->data.uart_id = PLATFORM_UART_ID_ATC;
                if(count == 5)
                {
                    platform_msg->data.uart_id = 1;
                }
            }

            *ppMessage = platform_msg;
            
            count++;

            break;
        }
        else if(msg.message == SIMU_TIMER_MSG_ID)
        {
            platform_msg = malloc(sizeof(PlatformMessage));
            
            if(msg.wParam == RTOS_WAIT_MSG_TIMER_ID)
            {
                platform_msg->id = RTOS_MSG_WAIT_MSG_TIMEOUT;
            }
            else if(msg.wParam == SEND_SOUND_END_TIMER_ID)
            {
                platform_msg->id = RTOS_MSG_UART_RX_DATA;
                platform_msg->data.uart_id = PLATFORM_UART_ID_ATC;
                platform_sendsound_end();
            }
            else
            {
                platform_msg->id = RTOS_MSG_TIMER;
                
                platform_msg->data.timer_id = msg.wParam;
            }
            
            *ppMessage = platform_msg;

            break;
        }
        else if(msg.message == SIMU_UART_ATC_RX_DATA)
        {
            platform_msg = malloc(sizeof(PlatformMessage));

            platform_msg->id = RTOS_MSG_UART_RX_DATA;
            platform_msg->data.uart_id = PLATFORM_UART_ID_ATC;
            
            *ppMessage = platform_msg;
            break;
        }
        else if(msg.message == SIMU_RTOS_MSG_ID)
        {
            platform_msg = malloc(sizeof(PlatformMessage));
            memcpy(platform_msg, (void*)msg.wParam, sizeof(PlatformMessage));

            //printf("platform_msg.id: %d\n",platform_msg->id);

            free((void*)msg.wParam);

            *ppMessage = platform_msg;
            break;
        }
    }

    return ret;
}

int platform_rtos_start_timer(int timer_id, int milliSecond, BOOL high)
{
    win_start_timer(timer_id, milliSecond);
    return 1;
}

int platform_rtos_stop_timer(int timerId)
{
    return win_stop_timer(timerId);
}

int platform_rtos_init_module(int module, void *pParam)
{
    switch(module){
    case RTOS_MODULE_ID_KEYPAD:
        keypad_init(pParam);    
        break;
    }
    return PLATFORM_OK;
}

int platform_rtos_init(void)
{
    return PLATFORM_OK;
}

int platform_rtos_poweroff(void)
{
    return PLATFORM_OK;
}

int platform_rtos_tick(void)
{
    return GetTickCount();
}

int platform_rtos_restart(void)
{
    //exit(0);
    return PLATFORM_OK;
}

void platform_free(void *p)
{
    free(p);
}

/*+\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
int platform_get_poweron_reason(void)
{
    return PLATFORM_POWERON_KEY;
}

int platform_rtos_poweron(int flag)
{
    return PLATFORM_OK;
}

void platform_poweron_try(void)
{

}
/*-\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */

char *platform_rtos_get_version(void)
{
	return "Luat_Airm2m_V9999";
}

int platform_get_env_usage(void)
{
    return 50;
}