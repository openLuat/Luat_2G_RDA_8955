/*********************************************************
  Copyright (C), AirM2M Tech. Co., Ltd.
  Author: lifei
  Description: AMOPENAT 开放平台
  Others:
  History: 
    Version： Date:       Author:   Modification:
    V0.1      2012.12.14  lifei     创建文件
*********************************************************/
#ifndef AM_OPENAT_SYSTEM_H
#define AM_OPENAT_SYSTEM_H

#include "am_openat_common.h"

/****************************** SYSTEM ******************************/
#define OPENAT_CUST_TASKS_PRIORITY_BASE 235
#define OPENAT_SEMAPHORE_TIMEOUT_MIN_PERIOD 5 //5ms

/* 线程主入口函数，参数 pParameter 为 create_task 接口传入的参数 */
typedef VOID (*PTASK_MAIN)(PVOID pParameter);

typedef enum E_AMOPENAT_OS_CREATION_FLAG_TAG
{
    OPENAT_OS_CREATE_DEFAULT = 0,   /* 线程创建后，立即启动 */
    OPENAT_OS_CREATE_SUSPENDED = 1, /* 线程创建后，先挂起 */
}E_AMOPENAT_OS_CREATION_FLAG;

typedef struct T_AMOPENAT_TASK_INFO_TAG
{
    UINT16 nStackSize;
    UINT16 nPriority;
    CONST UINT8 *pName;
}T_AMOPENAT_TASK_INFO;

/*+\NEW\liweiqiang\2013.7.1\[OpenAt]增加系统主频设置接口*/
typedef enum E_AMOPENAT_SYS_FREQ_TAG
{
    OPENAT_SYS_FREQ_32K    = 32768,
    OPENAT_SYS_FREQ_13M    = 13000000,
    OPENAT_SYS_FREQ_26M    = 26000000,
    OPENAT_SYS_FREQ_39M    = 39000000,
    OPENAT_SYS_FREQ_52M    = 52000000,
    OPENAT_SYS_FREQ_78M    = 78000000,
    OPENAT_SYS_FREQ_104M   = 104000000,
    OPENAT_SYS_FREQ_156M   = 156000000,
    OPENAT_SYS_FREQ_208M   = 208000000,
    OPENAT_SYS_FREQ_250M   = 249600000,
    OPENAT_SYS_FREQ_312M   = 312000000,
}E_AMOPENAT_SYS_FREQ;
/*-\NEW\liweiqiang\2013.7.1\[OpenAt]增加系统主频设置接口*/

/****************************** TIME ******************************/
typedef struct T_AMOPENAT_SYSTEM_DATETIME_TAG
{
    UINT16 nYear;
    UINT8  nMonth;
    UINT8  nDay;
    UINT8  nHour;
    UINT8  nMin;
    UINT8  nSec;
    UINT8  DayIndex; /* 0=Sunday */
}T_AMOPENAT_SYSTEM_DATETIME;

typedef struct
{
  uint8               alarmIndex;
  bool                alarmOn; /* 1 set,0 clear*/
  uint8               alarmRecurrent; /* 1 once,bit1:Monday...bit7:Sunday */
  T_AMOPENAT_SYSTEM_DATETIME alarmTime;
}T_AMOPENAT_ALARM_PARAM;

/****************************** TIMER ******************************/
#define OPENAT_TIMER_MIN_PERIOD 5 //5ms

typedef struct T_AMOPENAT_TIMER_PARAMETER_TAG
{
    HANDLE hTimer;      /* create_timer 接口返回的 HANDLE */
    UINT32 period;      /* start_timer 接口传入的 nMillisecondes */
    PVOID  pParameter;  /* create_timer 接口传入的 pParameter */
}T_AMOPENAT_TIMER_PARAMETER;

/* 定时器到时回调函数，参数 pParameter 为栈变量指针，客户程序中不需要释放该指针 */
typedef VOID (*PTIMER_EXPFUNC)(T_AMOPENAT_TIMER_PARAMETER *pParameter);

typedef VOID (*PMINUTE_TICKFUNC)(VOID);


int OPENAT_GetEnvUsage(void);
void OPENAT_Decode(UINT32* v, INT32 n);

#define OPENAT_GSM_ISP_LENGTH (64)
#define OPENAT_GSM_IMSI_LENGHT (64)
#define OPENAT_GSM_APN_LENGTH (64)
#define OPENAT_GSM_PASSWORD_LENGTH	(64)
#define OPENAT_GSM_USER_NAME_LENGTH (64)

typedef enum
{
    /* state with no link. */
	OPENAT_GSM_STATE_NOLINK            		= 0x00,
    /* state with linking to station. */
	OPENAT_GSM_STATE_LINKING,
    /* state with have linked. */
	OPENAT_GSM_STATE_LINKED
}T_OPENAT_GSM_LINK_STATE;

typedef struct
{
	BOOL connected;							/*< is connected to data link 	*/
	BOOL roam;							
	UINT8 signal;							
	UINT8 gen;							
	char isp[OPENAT_GSM_ISP_LENGTH];	
	char imsi[OPENAT_GSM_IMSI_LENGHT]; 
}T_OPENAT_GSM_STATUS;

typedef struct
{
	char apn[OPENAT_GSM_APN_LENGTH];
	char username[OPENAT_GSM_USER_NAME_LENGTH];
	char password[OPENAT_GSM_PASSWORD_LENGTH];
}T_OPENAT_GSM_CONNECT;

typedef struct _GsmState{
	T_OPENAT_GSM_LINK_STATE 	old_state;
	T_OPENAT_GSM_LINK_STATE 	new_state;
	BOOL                result;
}T_OPENAT_GSM_STATE;

typedef VOID(*F_OPENAT_GSM_IND_CB)(T_OPENAT_GSM_STATE*);


#endif /* AM_OPENAT_SYSTEM_H */

