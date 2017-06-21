/*********************************************************
  Copyright (C), AirM2M Tech. Co., Ltd.
  Author: lifei
  Description: AMOPENAT 开放平台
  Others:
  History: 
    Version： Date:       Author:   Modification:
    V0.1      2012.12.14  lifei     创建文件
*********************************************************/
#ifndef AM_OPENAT_VAT_H
#define AM_OPENAT_VAT_H

#include "am_openat_common.h"

typedef VOID (*PAT_MESSAGE)(UINT8 *pData, UINT16 length);
/*+\NEW\AMOPENAT-54\brezen\2013.7.18\添加CI和DTE之间AT过滤接口*/
#ifdef AM_DTE_AT_DATA_FILTER_SUPPORT	 
typedef enum
{
     OPENAT_DTE_UART,
     OPENAT_DTE_USB,          /*暂时不支持*/
     OPENAT_DTE_BT,           /*暂时不支持*/
     OPENAT_DTE_INVALID       /*没有DTE物理设备，设置该值*/
}E_AMOPENAT_DTE_TYPE;
typedef struct
{
     E_AMOPENAT_DTE_TYPE type;
     union
     {
         E_AMOPENAT_UART_PORT uart; /*支持UART1和UART2*/
     }port;
}T_AMOPENAT_DTE_DEVICE;

typedef INT16 (*PAT_FILTER_MESSAGE)(UINT8 channel,const UINT8 *pDataIn, INT16 dataInLen);

BOOL OPENAT_SendDataToCi(UINT8 channel, const UINT8* data, UINT16 dataLen);

BOOL OPENAT_SendDataToDte(UINT8 channel, const UINT8* data, UINT16 dataLen);

BOOL OPENAT_SetDteDevice(T_AMOPENAT_DTE_DEVICE device);

T_AMOPENAT_DTE_DEVICE OPENAT_GetDteDevice(void);


#endif													
/*-\NEW\AMOPENAT-54\brezen\2013.7.18\添加CI和DTE之间AT过滤接口*/

#endif /* AM_OPENAT_VAT_H */

