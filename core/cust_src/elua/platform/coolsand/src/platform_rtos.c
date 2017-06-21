/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_rtos.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/3/7
 *
 * Description:
 *          lua rtos平台接口实现
 **************************************************************************/

#include "rda_pal.h"
#include "assert.h"

#include "platform.h"
#include "platform_rtos.h"

#define DEBUG_RTOS

#if defined(DEBUG_RTOS)
#define DEBUG_RTOS_TRACE(fmt, ...)      PUB_TRACE(fmt, ##__VA_ARGS__)
#else
#define DEBUG_RTOS_TRACE(fmt, ...)
#endif

#define MAX_LUA_TIMERS              30

typedef struct LuaTimerParamTag
{
    HANDLE              hOsTimer;
    int                 luaTimerId;
}LuaTimerParam;

static LuaTimerParam luaTimerParam[MAX_LUA_TIMERS];
static HANDLE hLuaTimerSem = 0;

static HANDLE           hRTOSWaitMsgTimer;

extern HANDLE g_LuaShellTaskHandle;

int platform_rtos_send(PlatformMessage *pMsg)
{
    IVTBL(send_message)(g_LuaShellTaskHandle, (PVOID)pMsg);

    return PLATFORM_OK;
}

int platform_rtos_send_high_priority(PlatformMessage *pMsg)
{
    IVTBL(send_high_priority_message)(g_LuaShellTaskHandle, (PVOID)pMsg);

    return PLATFORM_OK;
}


int platform_rtos_receive(void **ppMessage, u32 timeout)
{
    BOOL ret;

    if(timeout == PLATFORM_RTOS_WAIT_MSG_INFINITE)
    {
        IVTBL(stop_timer)(hRTOSWaitMsgTimer);
    }
    else
    {
        // start timer接口会自动重启定时器 故不需要stop_timer
        IVTBL(start_timer)(hRTOSWaitMsgTimer, timeout);
    }
    
    ret = IVTBL(wait_message)(g_LuaShellTaskHandle, ppMessage, 0);

    return ret == TRUE ? PLATFORM_OK : PLATFORM_ERR;
}

void platform_rtos_timer_callback(T_AMOPENAT_TIMER_PARAMETER *pParameter)
{
    int timer_id = (int)(pParameter->pParameter);
    u8 index;    
    PlatformMessage *pMsg = IVTBL(malloc)(sizeof(PlatformMessage));

    pMsg->id = RTOS_MSG_TIMER;
    pMsg->data.timer_id = timer_id;

    platform_rtos_send(pMsg);
    
    IVTBL(wait_semaphore)(hLuaTimerSem, 0);

    for(index = 0; index < MAX_LUA_TIMERS; index++)
    {
        if(luaTimerParam[index].hOsTimer == pParameter->hTimer)
        {
            if(timer_id != luaTimerParam[index].luaTimerId)
            {
                DEBUG_RTOS_TRACE("[platform_rtos_timer_callback]: warning dismatch timer %d <-> %d", timer_id, luaTimerParam[index].luaTimerId);
            }
            
            IVTBL(delete_timer)(luaTimerParam[index].hOsTimer);
            luaTimerParam[index].hOsTimer = OPENAT_INVALID_HANDLE;
            break;
        }
    }
    
    IVTBL(release_semaphore)(hLuaTimerSem);
}

void platform_rtos_timer_high_priority_callback(T_AMOPENAT_TIMER_PARAMETER *pParameter)
{
    int timer_id = (int)(pParameter->pParameter);
    u8 index;    
    PlatformMessage *pMsg = IVTBL(malloc)(sizeof(PlatformMessage));

    pMsg->id = RTOS_MSG_TIMER;
    pMsg->data.timer_id = timer_id;

    platform_rtos_send_high_priority(pMsg);
    
    IVTBL(wait_semaphore)(hLuaTimerSem, 0);

    for(index = 0; index < MAX_LUA_TIMERS; index++)
    {
        if(luaTimerParam[index].hOsTimer == pParameter->hTimer)
        {
            if(timer_id != luaTimerParam[index].luaTimerId)
            {
                DEBUG_RTOS_TRACE("[platform_rtos_timer_high_priority_callback]: warning dismatch timer %d <-> %d", timer_id, luaTimerParam[index].luaTimerId);
            }
            
            IVTBL(delete_timer)(luaTimerParam[index].hOsTimer);
            luaTimerParam[index].hOsTimer = OPENAT_INVALID_HANDLE;
            break;
        }
    }
    
    IVTBL(release_semaphore)(hLuaTimerSem);
}

int platform_rtos_start_timer(int timer_id, int milliSecond, BOOL high)
{
    u8 index;
    HANDLE hTimer = OPENAT_INVALID_HANDLE;
    
    if(!hLuaTimerSem)
    {
        hLuaTimerSem = IVTBL(create_semaphore)(1);
    }

    for(index = 0; index < MAX_LUA_TIMERS; index++)
    {
        if(luaTimerParam[index].hOsTimer != OPENAT_INVALID_HANDLE &&
            luaTimerParam[index].luaTimerId == timer_id)
        {
            platform_rtos_stop_timer(timer_id);
            break;
        }
    }

    IVTBL(wait_semaphore)(hLuaTimerSem, 0);

    for(index = 0; index < MAX_LUA_TIMERS; index++)
    {
        if(luaTimerParam[index].hOsTimer == NULL)
        {
            break;
        }
    }

    if(index >= MAX_LUA_TIMERS)
    {
        DEBUG_RTOS_TRACE("[platform_rtos_start_timer]: no timer resource.");
        goto start_timer_error;
    }

    hTimer = IVTBL(create_timer)(high ? platform_rtos_timer_high_priority_callback : platform_rtos_timer_callback, (PVOID)timer_id);

    if(OPENAT_INVALID_HANDLE == hTimer)
    {
        DEBUG_RTOS_TRACE("[platform_rtos_start_timer]: create timer failed.");
        goto start_timer_error;
    }

    if(!IVTBL(start_timer)(hTimer, milliSecond))
    {
        DEBUG_RTOS_TRACE("[platform_rtos_start_timer]: start timer failed.");
        goto start_timer_error;
    }
    
    luaTimerParam[index].hOsTimer = hTimer;
    luaTimerParam[index].luaTimerId = timer_id;
    
    IVTBL(release_semaphore)(hLuaTimerSem);
    
    return PLATFORM_OK;

start_timer_error:
    IVTBL(release_semaphore)(hLuaTimerSem);

/*+\NEW\liweiqiang\2014.7.22\修正启动定时器失败把定时器资源耗尽的问题 */
    if(OPENAT_INVALID_HANDLE != hTimer)
/*-\NEW\liweiqiang\2014.7.22\修正启动定时器失败把定时器资源耗尽的问题 */
    {
        IVTBL(delete_timer)(hTimer);
    }
    
    return PLATFORM_ERR;
}

int platform_rtos_stop_timer(int timer_id)
{
    u8 index;
    
    if(OPENAT_INVALID_HANDLE == hLuaTimerSem)
    {
        hLuaTimerSem = IVTBL(create_semaphore)(1);
    }

    IVTBL(wait_semaphore)(hLuaTimerSem, 0);

    for(index = 0; index < MAX_LUA_TIMERS; index++)
    {
        if(luaTimerParam[index].hOsTimer != OPENAT_INVALID_HANDLE &&
            luaTimerParam[index].luaTimerId == timer_id)
        {
            IVTBL(stop_timer)(luaTimerParam[index].hOsTimer);
            IVTBL(delete_timer)(luaTimerParam[index].hOsTimer);

            luaTimerParam[index].hOsTimer = OPENAT_INVALID_HANDLE;
            break;
        }
    }
    
    IVTBL(release_semaphore)(hLuaTimerSem);
    
    return PLATFORM_OK;
}

void platform_keypad_message(T_AMOPENAT_KEYPAD_MESSAGE *pKeypadMessage)
{
    PlatformMessage *pMsg = IVTBL(malloc)(sizeof(PlatformMessage));
    
    /*
    DEBUG_RTOS_TRACE("[platform_keypad_message]: p(%d) r(%d) c(%d)", 
                    pKeypadMessage->bPressed, 
                    pKeypadMessage->data.matrix.r, 
                    pKeypadMessage->data.matrix.c);
    */
    
    pMsg->id = RTOS_MSG_KEYPAD;
    pMsg->data.keypadMsgData.bPressed = pKeypadMessage->bPressed;
    pMsg->data.keypadMsgData.data.matrix.row = pKeypadMessage->data.matrix.r;
    pMsg->data.keypadMsgData.data.matrix.col = pKeypadMessage->data.matrix.c;

    platform_rtos_send(pMsg);
}

int platform_rtos_init_module(int module, void *pParam)
{
    int ret = PLATFORM_OK;
    
    switch(module)
    {
    case RTOS_MODULE_ID_KEYPAD:
        {
            T_AMOPENAT_KEYPAD_CONFIG keypadConfig;
            PlatformKeypadInitParam *pKeypadParam = (PlatformKeypadInitParam *)pParam;

            keypadConfig.type = OPENAT_KEYPAD_TYPE_MATRIX;

            keypadConfig.pKeypadMessageCallback = platform_keypad_message;
            
            keypadConfig.config.matrix.keyInMask = pKeypadParam->matrix.inMask;
            keypadConfig.config.matrix.keyOutMask = pKeypadParam->matrix.outMask;

            IVTBL(init_keypad)(&keypadConfig);
        }
        break;

    default:
        DEBUG_RTOS_TRACE("[platform_rtos_init_module]: unknown module(%d)", module);
        ret = PLATFORM_ERR;
        break;
    }
    
    return ret;
}

static void rtos_wait_message_timeout(T_AMOPENAT_TIMER_PARAMETER *pParameter)
{
    PlatformMessage *pMsg = IVTBL(malloc)(sizeof(PlatformMessage));

    pMsg->id = RTOS_MSG_WAIT_MSG_TIMEOUT;
    
    platform_rtos_send(pMsg);
}

int platform_rtos_init(void)
{
    hRTOSWaitMsgTimer = IVTBL(create_timer)(rtos_wait_message_timeout, NULL);
    
    return PLATFORM_OK;
}

/*+\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */
extern int cust_get_poweron_reason(void);
extern void cust_poweron_system(void);

int platform_get_poweron_reason(void)
{
    /*+\NEW\zhuth\2014.7.25\修改开机原因值实现*/
    return (int)IVTBL(get_poweronCasue)();
    /*-\NEW\zhuth\2014.7.25\修改开机原因值实现*/
}

static int poweron_flag = -1;/*-1: 未设置 0: 不启动 1:启动*/
/*+\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
static BOOL cust_sys_flag = FALSE; 
/*-\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/

int platform_rtos_poweron(int flag)
{
    poweron_flag = flag;

    if(1 == poweron_flag)
    {
        cust_poweron_system();
        /*+\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
        cust_sys_flag = TRUE;
        /*-\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
    }
    
    return PLATFORM_OK;
}

void platform_poweron_try(void)
{
    // 为兼容旧脚本,在未设置开机标志时自动启动系统
    if(-1 == poweron_flag)
    {
        cust_poweron_system();    
        /*+\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
        cust_sys_flag = TRUE;
        /*-\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
    }
}
/*-\NEW\liweiqiang\2013.12.12\增加充电开机时由用户自行决定是否启动系统 */



int platform_get_env_usage(void)
{
    return IVTBL(get_env_usage)();
}

int platform_rtos_poweroff(void)
{
    /*+\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
    if((platform_get_poweron_reason() == OPENAT_PM_POWERON_BY_CHARGER)
        && !cust_sys_flag)
    {
        IVTBL(shut_down)();
    }
    else
    {
        IVTBL(poweroff_system)();
    }
    /*-\NEW\zhuth\2014.2.14\充电开机并且用户没有启动协议栈的情况下使用shutdown关机，其余情况使用poweroff_system关机*/
    
    return PLATFORM_OK;
}

/*+\NEW\liweiqiang\2013.9.7\增加rtos.restart接口*/
int platform_rtos_restart(void)
{
    IVTBL(restart)();
    return PLATFORM_OK;
}
/*-\NEW\liweiqiang\2013.9.7\增加rtos.restart接口*/

/*+\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/
int platform_rtos_tick(void)
{
    return (int)IVTBL(get_system_tick)();
}
/*-\NEW\liweiqiang\2013.4.5\增加rtos.tick接口*/

/*-\NEW\zhuwangbin\2017.2.12\添加版本查询接口 */
extern char * cust_luaInfo_version(void);
char *platform_rtos_get_version(void)
{
	return cust_luaInfo_version();
}
/*-\NEW\zhuwangbin\2017.2.12\添加版本查询接口 */