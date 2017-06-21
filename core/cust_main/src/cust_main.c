/*******************************************************
**
** This is just demo code for custom application.
** Your can implement your own main entry file instead 
** of this demo file, but two things you must pay attention
** 1. disable cust_main module compilation
**     modify module_list.mk, remark LOCAL_MODULE_DEPENDS += cust_main
** 2. copy code from this file
**     pls find "ATTENTION" in this file.
*******************************************************/
/*******************************************************
* Date        What
* 2013.01.15  SPI测试代码用宏 SPI_TEST_SUPPORT 控制
*             (因为与LCD的PIN存在冲突)
* 2013.01.15  匹配新的LCD初始化接口
*
* 2013.01.15  增加 AUDIO 接口测试例程
* 2013.01.17  增加T卡测试代码
* 2013.01.17  合并彩屏与黑白屏测试代码,触摸屏测试代码
* 2013.01.30  add psam card test code with PSAM_TEST_SUPPORT
* 2013.02.03  add camera test code with CAMERA_TEST_SUPPORT
* 2013.02.06  Adapte to new power on interface
* 2013.02.10  add video play test code with VIDEO_PLAYER_TEST_SUPPORT
* 2013.03.05  add GPIO keypad support
* 2013.03.21  adapte GPIO keypad support
* 2013.03.21  adapte default lcd cs pin to  unkown
* 2013.03.30  adapte pmd cfg  support
* 2013.04.10  adapte pmd default type and add  UART_PRINT_SUPPORT
* 2013.04.12  adapte pmd signal handle
* 2013.04.19  adapte pmd cfg
* 2013.05.20  adapte pmd cfg
* 2013.07.15  添加uart口cfg.uartMsgHande = NULL;，防止客户遗漏，导致程序死机
* 2013.07.18  add  audio hw channel interface  with set_hw_channel
* 2013.08.08  add adc key report data
* 2013.09.24  添加NV接口，使用该接口需要8K的空间
********************************************************/

#define CUST_MONO_LCD 0
#define CUST_COLOR_LCD 1
#define CUST_NONE_LCD  0xff

#define SPI_TEST_SUPPORT 0
#define TFLASH_TEST      0
#define TOUCH_SCREEN_SUPORT 0
#define CUST_LCD_SUPPORT CUST_MONO_LCD
#define PSAM_TEST_SUPPORT 0
#define CAMERA_TEST_SUPPORT 0
#define VIDEO_PLAYER_TEST_SUPPORT 0
#define UART_PRINT_SUPPORT  0
#define NV_SUPPORT        0


#include "string.h"
#include "stdio.h"

#include "am_openat.h"

#if CUST_LCD_SUPPORT == CUST_MONO_LCD
#define LCD_WIDTH 128
#define LCD_HEIGHT 64
#endif

#define AT_MESSAGE 0
#define KEY_MESSAGE 1
#define SPI_MESSAGE 2
#define TOUCHSCREEN_MESSAGE 3

typedef struct {
    UINT8 type;
    UINT16 len;
    PVOID data;
}CUST_MESSAGE;

#define IVTBL(func) (g_s_InterfaceVtbl->func)
#define ASSERT(condition) IVTBL(assert)(condition, (CHAR*)__FUNCTION__, __LINE__)
#define PUB_TRACE(pFormat, ...)  IVTBL(print)(pFormat, ##__VA_ARGS__)

#if CUST_LCD_SUPPORT == CUST_COLOR_LCD
extern VOID cust_color_lcd_init(VOID);
extern VOID cust_color_lcd_test(VOID);
#endif

static VOID cust_at_message(UINT8 *pData, UINT16 length);
static VOID cust_key_message(T_AMOPENAT_KEYPAD_MESSAGE *pKeypadMessage);
#if TOUCH_SCREEN_SUPORT==1
static VOID cust_touchscreen_message(T_AMOPENAT_TOUCHSCREEN_MESSAGE *pTouchScreenMessage);
#endif
static VOID cust_task_main(PVOID pParameter);
static VOID cust_lcd_init(VOID);
#if PSAM_TEST_SUPPORT==1
static VOID cust_psam_test(VOID);
#endif
static void cust_pm_message(T_AMOPENAT_PM_MSG* pmMessage);
static VOID cust_poweron_reason_init(VOID);

static VOID cust_uart_print(CHAR * fmt, ...);

#if CAMERA_TEST_SUPPORT == 1
extern void cust_camera_test(void);
#endif

#if NV_SUPPORT == 1
UINT32 flashNvAddr1 [1024]  __attribute__((section (".am_openat_nv1")))= 
{
#include "flash_nv_map.bin"
};
UINT32 flashNvAddr2 [1024] __attribute__((section (".am_openat_nv2"))) = 
{
#include "flash_nv_map.bin"  
};
#endif

/* 加密卡密钥等信息 */
UINT8 enc_data[] = {
    0,/* 加密卡类型 0-一般v4加密卡 1-v4加密卡(不进行sim卡refresh) 2-一般v2加密卡 ) 3-江苏v2 4-江苏鉴权卡 */
    0x03,/* 厂商代码 */
    0x01,/* 密钥版本号 */
    1,/* 是否支持普通卡 */
    0,/* 是否只发送一次terminal profile */
    
    /* 密钥 */
    0xC0,0x7A,0x82,0x09,0xB9,0x58,0x5C,0x8D,0x36,0x42,0xF5,0x0A,0xAA,0x01,0xCE,0x85,
    0xA4,0xC9,0xA8,0x50,0x94,0x9A,0x22,0x78,0xBD,0x67,0xCD,0x07,0x11,0x47,0xD4,0x12,
    0xB1,0x09,0x47,0xA6,0x24,0x64,0x67,0xF5,0x66,0x10,0x34,0x7B,0xB8,0x15,0xA5,0x83,
    0xF1,0x3A,0xE6,0x3C,0x1B,0xEB,0x06,0x6D,0x2A,0x0C,0x7F,0x33,0x04,0x1C,0x55,0x61,
    0x6B,0xFA,0xEE,0x2B,0x4F,0xF2,0x74,0x2C,0x3A,0xB0,0xA1,0xBA,0x3A,0xBC,0x4B,0x85,

    /* 江苏鉴权卡密钥 */
	0x11,0x60,0x59,0x04,0x9B,0x8C,0x75,0x1B,0x5A,0x7E,0xB9,0x54,0xC0,0xA7,0x2D,0xFB,
    0x72,0x7D,0xE5,0x8B,0xDA,0x56,0x3A,0xF7,0x48,0x9A,0x0A,0xDE,0xAA,0x49,0x58,0x51,
    0xAC,0x58,0x33,0xF7,0xCF,0x24,0x89,0x3B,0xDD,0xEF,0xFF,0x68,0xB8,0xED,0x4A,0xC6,
    0xE6,0x5E,0xB2,0xC5,0x7C,0xCD,0x00,0xDA,0xDB,0x34,0xA9,0x82,0x0B,0xD8,0x00,0x63,
    0x6A,0x0A,0x8B,0x5B,0x86,0x78,0xA9,0xF7,0x3B,0xEB,0xBD,0x9E,0xD3,0xD5,0x99,0xBE,
    0x09,0xDE,0x1E,0x3A,0xD5,0xC6,0xB5,0xBC,0x39,0xBA,0x51,0x75,0x7A,0x6B,0x73,0x50,
    0x81,0x79,0x41,0x68,0xA8,0x69,0x80,0x07,0x78,0x02,0x09,0x53,0x1C,0x76,0x3B,0x97,
    0x24,0xD6,0x78,0x13,0x91,0xBC,0xE1,0x05,0x11,0x31,0x13,0x9E,0xDF,0x7B,0xA6,0xDB,
    0x61,0xB7,0x7F,0x22,0xB8,0x9B,0x19,0x5C,0x30,0x74,0x1D,0x11,0x3A,0xFB,0x30,0xF3,
    0x8A,0xA0,0x34,0xE2,0x37,0x97,0xD1,0x67,0xAA,0x36,0x11,0xD1,0xC2,0x0C,0x9F,0x97,
    0x5E,0x5A,0xE5,0x6D,0x8F,0xB2,0xFF,0x4E,0x5D,0x2F,0x3A,0x81,0x56,0x02,0xAA,0x42,
    0x39,0x49,0x7A,0xC3,0x7E,0x42,0xD9,0xD2,0x46,0x4B,0xB4,0xA2,0x06,0x0C,0xE6,0x6B,
    0xE9,0x6F,0xC7,0xEA,0xED,0xF2,0x93,0xB1,0x15,0x5D,0xBC,0xB3,0xAF,0x7B,0xB3,0x24,
    0x0E,0x8C,0x50,0xCA,0x89,0x69,0x82,0xF5,0x25,0x17,0xA3,0x45,0x55,0xC8,0x9A,0xF6,
    0xD7,0xD0,0x92,0x26,0x3B,0x47,0x00,0xBF,0x91,0xDC,0x81,0xF6,0xDF,0x35,0xB1,0xF5,
    0x06,0x43,0xB7,0x8D,0x3A,0x9A,0x13,0x8C,0x36,0x15,0xFC,0x22,0x15,0xF1,0xD8,0x00
};
/*******************************************************
** ATTENTION: For our cust, this part must used. If you 
** have your own main entry file(instead of cust_main.c),
** pls copy this part!
**
** START .. START .. START .. START .. START .. START ..
********************************************************/
/* CUSTOM APP CODE INFOMATION */
UINT8 cust_init(T_AMOPENAT_INTERFACE_VTBL *pVtable);
VOID cust_main(VOID);
extern char _am_openat_ro_lma;
extern char _am_openat_ro_vma;
extern char _am_openat_ro_size;
extern char _am_openat_rw_lma;
extern char _am_openat_rw_vma;
extern char _am_openat_rw_size;
extern char _am_openat_zi_base;
extern char _am_openat_zi_size;
static const volatile T_AMOPENAT_CUST_VTBL __attribute__((section (".am_openat_custvtbl")))
    g_s_AMOpenAtCustVtbl =
{
    0x87654321,
    (UINT32)&_am_openat_ro_lma,
    (UINT32)&_am_openat_ro_vma,
    (UINT32)&_am_openat_ro_size,
    (UINT32)&_am_openat_rw_lma,
    (UINT32)&_am_openat_rw_vma,
    (UINT32)&_am_openat_rw_size,
    (UINT32)&_am_openat_zi_base,
    (UINT32)&_am_openat_zi_size,

    cust_init,  /* cannot changed to other name */
    cust_main,  /* cannot changed to other name */
};
/*******************************************************
** ATTENTION:
** END .. END .. END .. END .. END .. END .. END ..
********************************************************/

/* Function table from OpenAT platform */
T_AMOPENAT_INTERFACE_VTBL * g_s_InterfaceVtbl = 0;
HANDLE g_CustTaskHandle;

#if CUST_LCD_SUPPORT == CUST_MONO_LCD
UINT8 g_LcdFrameBuffer[(LCD_WIDTH*LCD_HEIGHT)/8];
#endif

struct
{
    HANDLE poweronSyncSemaphore;
    E_AMOPENAT_POWERON_REASON reason;
}g_PowronInfo;

/* The first function called by OpenAT platform */
/* Return value see more E_AMOPENAT_CUST_INIT_RESUL */
UINT8 cust_init(T_AMOPENAT_INTERFACE_VTBL *pVtable)
{
    g_s_InterfaceVtbl = pVtable;
    g_PowronInfo.reason = OPENAT_PM_POWERON_BY_INVALID;
    g_PowronInfo.poweronSyncSemaphore = 0;
    
    return (UINT8)OPENAT_CUST_INIT_RES_OK;
}

/* never removed even if not used */
const T_AMOPENAT_CUST_VTBL* cust_getcustvtbl(VOID)
{
    return (const T_AMOPENAT_CUST_VTBL*)&g_s_AMOpenAtCustVtbl;
}

/* Main function call by OpenAT platform */
VOID cust_main(VOID)
{
#if SPI_TEST_SUPPORT==1
    T_AMOPENAT_SPI_PARAM spiParam;
    spiParam.fullDuplex = TRUE;
    spiParam.cpol = FALSE;
    spiParam.cpha = 0;
    spiParam.dataBits = 8;
    spiParam.clock = 200000;
#endif
    
    /* 更新加密卡密钥信息 长度必须为341*/
    IVTBL(set_encinfo)(enc_data, sizeof(enc_data));

    /* 密钥已经准备好 需要发出通知 */
    IVTBL(set_enc_data_ok)();
	
	/* 获取加密卡密钥信息 长度至少为341*/
    //IVTBL(get_encinfo)(enc_data, sizeof(enc_data));
	
	/* 获取加密卡校验结果 0通过  1进行中  2失败*/
    //IVTBL(get_encresult)();

    /* 读取卡类型 0未知  1加密卡  2普通卡  */
    //IVTBL(get_cardtype)();                         
    
    cust_poweron_reason_init();
    
    IVTBL(init_at)(cust_at_message);
    cust_lcd_init();

    // 注意触摸屏与ADC键盘只能选择一种
#if TOUCH_SCREEN_SUPORT == 1
    IVTBL(init_touchScreen)(cust_touchscreen_message);
#else
    T_AMOPENAT_KEYPAD_CONFIG keypadConfig;
    /* ADC */
#if 1
    keypadConfig.type = OPENAT_KEYPAD_TYPE_ADC;
    keypadConfig.pKeypadMessageCallback = cust_key_message;
    keypadConfig.config.adc.isreportData = FALSE;
#endif
#if 0
    /* MATRIX */
    keypadConfig.type = OPENAT_KEYPAD_TYPE_MATRIX;
    keypadConfig.pKeypadMessageCallback = cust_key_message;
    keypadConfig.config.matrix.keyInMask = 0x1F;
    keypadConfig.config.matrix.keyOutMask = 0x1F;
#endif
#if 0
    /* GPIO */
    /****************************************************
     说明 :  keypadConfig.config.gpio.gpiofirstcfg
     gpiofirstcfg标志位只在第一次初始化GPIO键盘的时候打开，并且配置
     gpioInMask 和gpioOutMask；

     在后面切换 gpio.mode 时，关闭标志位 gpiofirstcfg(FALSE)
     gpioInMask 和gpioOutMask 可以不配置。
     例:
     #define SET_GPIOKEY_MODE(mode)\
     do{\
         T_AMOPENAT_KEYPAD_CONFIG keypadConfig;\
         keypadConfig.type = OPENAT_KEYPAD_TYPE_GPIO;\
         keypadConfig.pKeypadMessageCallback = cust_key_message;\
         keypadConfig.config.gpio.gpiofirstcfg = FALSE;\
         keypadConfig.config.gpio.mode = mode;\
         IVTBL(init_keypad)(&keypadConfig);\
     }while(0)
    *****************************************************/
    #define SET_USED_GPIO(value, gpio) value |= (1<<gpio)
    keypadConfig.type = OPENAT_KEYPAD_TYPE_GPIO;
    keypadConfig.pKeypadMessageCallback = cust_key_message;
    keypadConfig.config.gpio.gpiofirstcfg = TRUE;  
    keypadConfig.config.gpio.mode = OPENAT_GPIOKEY_IRQ;  
    keypadConfig.config.gpio.gpioInMask = 0;  
    SET_USED_GPIO(keypadConfig.config.gpio.gpioInMask, OPENAT_GPIO_3);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioInMask, OPENAT_GPIO_5);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioInMask, OPENAT_GPIO_7);/*在*/
    keypadConfig.config.gpio.gpioOutMask = 0;
    SET_USED_GPIO(keypadConfig.config.gpio.gpioOutMask, OPENAT_GPIO_8);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioOutMask, OPENAT_GPIO_9);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioOutMask, OPENAT_GPIO_11);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioOutMask, OPENAT_GPIO_13);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioOutMask, OPENAT_GPIO_14);
    SET_USED_GPIO(keypadConfig.config.gpio.gpioOutMask, OPENAT_GPIO_25);
#endif
    IVTBL(init_keypad)(&keypadConfig);
#endif

    /* FOR power on reason and charging messages */
    T_AMOPENAT_PMD_CFG pmdcfg;
    E_AMOPENAT_PM_CHR_MODE pmdmode;

    memset(&pmdcfg, 0, sizeof(T_AMOPENAT_PMD_CFG));
#if 1  /*模块内置充电方案*/
    pmdmode = OPENAT_PM_CHR_BY_DEFAULT;
    /*和硬件设计有关*/
    pmdcfg.deFault.batdetectEnable = TRUE;
    
    pmdcfg.deFault.tempdetectEnable = FALSE;
    pmdcfg.deFault.templowLevel = 0;
    pmdcfg.deFault.temphighLevel = 0;

    pmdcfg.deFault.batLevelEnable = FALSE;
    pmdcfg.deFault.batfullLevel = 4200;
    pmdcfg.deFault.batPreChargLevel = 4050;
    pmdcfg.deFault.poweronLevel = 3450;
    pmdcfg.deFault.poweroffLevel = 3400;
    pmdcfg.deFault.batAdc = OPENAT_ADC_7;/*adc_sense  or adc_vbat:OPENAT_ADC_0*/
    pmdcfg.deFault.tempAdc = OPENAT_ADC_1;
    
    /*level:  poweron-----levelFirst-----levelSecond-----levelFull*/
    /*current:----currentFirst----currentSecond---currentThird----*/
    pmdcfg.deFault.currentControlEnable = FALSE; 
    pmdcfg.deFault.currentFirst = OPENAT_PM_CHARGER_500MA;
    pmdcfg.deFault.intervalTimeFirst = 9*60; /*9分钟*/
    pmdcfg.deFault.batLevelFirst = 4150;
    pmdcfg.deFault.currentSecond = OPENAT_PM_CHARGER_300MA;
    pmdcfg.deFault.intervalTimeSecond = 6*60;/*6分钟*/
    pmdcfg.deFault.batLevelSecond = 4190;
    pmdcfg.deFault.currentThird = OPENAT_PM_CHARGER_100MA;
    pmdcfg.deFault.intervalTimeThird = 3*60; /*3分钟*/  

    pmdcfg.deFault.chargTimeOutEnable = FALSE;
    pmdcfg.deFault.TimeOutMinutes = 240;
#endif
#if 0
    pmdmode = OPENAT_PM_CHR_BY_IC;
    /*和硬件设计有关*/
    pmdcfg.ic.batdetectEnable = TRUE;
    pmdcfg.ic.tempdetectEnable = FALSE;
    pmdcfg.ic.templowLevel = 0;
    pmdcfg.ic.temphighLevel = 0;
    
    pmdcfg.ic.chrswitchport = OPENAT_GPIO_8;
    pmdcfg.ic.batstatusport = OPENAT_GPIO_1;
    
    pmdcfg.ic.batLevelEnable = FALSE;
    pmdcfg.ic.batfullLevel = 4200;
    pmdcfg.ic.poweronLevel = 3450;
    pmdcfg.ic.poweroffLevel = 3400;
    pmdcfg.ic.batAdc = OPENAT_ADC_7;/*adc_sense  or adc_vbat:OPENAT_ADC_0*/
    pmdcfg.ic.tempAdc = OPENAT_ADC_1;/*adc_battemp*/

    pmdcfg.ic.chargTimeOutEnable = FALSE;
    pmdcfg.ic.TimeOutMinutes = 240;
#endif
    ASSERT(IVTBL(init_pmd)(pmdmode, &pmdcfg, cust_pm_message));
#if SPI_TEST_SUPPORT==1
    IVTBL(config_spi)(OPENAT_SPI_1,&spiParam);
#endif

#if PSAM_TEST_SUPPORT==1
    cust_psam_test();
#endif
    IVTBL(set_hw_channel)(OPENAT_AUD_CHANNEL_HANDSET, OPENAT_AUD_CHANNEL_EARPIECE, OPENAT_AUD_CHANNEL_LOUDSPEAKER);
    
    /* 创建custom app线程 */
    g_CustTaskHandle = IVTBL(create_task)((PTASK_MAIN)cust_task_main, NULL, NULL, 15/*8*/*1024, OPENAT_CUST_TASKS_PRIORITY_BASE, OPENAT_OS_CREATE_DEFAULT, 0, "cust task");

    if(OPENAT_INVALID_HANDLE == g_CustTaskHandle)
    {
        ASSERT(0);
    }
}

/* AT message from OpenAT platform */
static VOID cust_at_message(UINT8 *pData, UINT16 length)
{
    CUST_MESSAGE *pMessage;
    
    pMessage = IVTBL(malloc)(sizeof(CUST_MESSAGE));
    
    if(NULL != pMessage)
    {
        pMessage->type = AT_MESSAGE;
        //copy data
        pMessage->data = IVTBL(malloc)(length);
        if(NULL != pMessage->data)
        {
            memcpy(pMessage->data, pData, length);
            pMessage->len = length;
        }
        IVTBL(send_message)(g_CustTaskHandle, pMessage);
    }
}

/* KEY message from OpenAT platform */
static VOID cust_key_message(T_AMOPENAT_KEYPAD_MESSAGE *pKeypadMessage)
{
    CUST_MESSAGE *pMessage;
    
    pMessage = IVTBL(malloc)(sizeof(CUST_MESSAGE));
    
    if(NULL != pMessage)
    {
        pMessage->type = KEY_MESSAGE;
        //copy data
#if 0
        CUST_KEY_MESSAGE *pKeyMsg = IVTBL(malloc)(sizeof(CUST_KEY_MESSAGE));
        if(NULL != pKeyMsg)
        {
            switch(pKeypadMessage->nType)
            {
                case OPENAT_KEYPAD_TYPE_MATRIX:
                    pKeyMsg->key = covert_matrix_key(pKeypadMessage->data.matrix.r, pKeypadMessage->data.matrix.c);
                    break;
                    
                case OPENAT_KEYPAD_TYPE_ADC:
                    pKeyMsg->key = covert_adc_key(pKeypadMessage->data.adc);
                    break;
            }
            pMessage->data = pKeyMsg;
            pMessage->len = sizeof(CUST_KEY_MESSAGE);
        }
#endif
        IVTBL(send_message)(g_CustTaskHandle, pMessage);
    }
}

/* touchscreen message from OpenAT platform */
#if TOUCH_SCREEN_SUPORT==1
static VOID cust_touchscreen_message(T_AMOPENAT_TOUCHSCREEN_MESSAGE *pTouchScreenMessage)
{
    CUST_MESSAGE *pMessage;
    
    pMessage = IVTBL(malloc)(sizeof(CUST_MESSAGE));
    
    if(NULL != pMessage)
    {
        T_AMOPENAT_TOUCHSCREEN_MESSAGE *pMsgData = IVTBL(malloc)(sizeof(T_AMOPENAT_TOUCHSCREEN_MESSAGE));
        
        pMessage->type = TOUCHSCREEN_MESSAGE;
        //copy data
        if(NULL != pMsgData)
        {
            memcpy(pMsgData, pTouchScreenMessage, sizeof(T_AMOPENAT_TOUCHSCREEN_MESSAGE));
            pMessage->data = pMsgData;
            pMessage->len = sizeof(T_AMOPENAT_TOUCHSCREEN_MESSAGE);
        }
        IVTBL(send_message)(g_CustTaskHandle, pMessage);
    }
}
#endif

static void cust_pm_message(T_AMOPENAT_PM_MSG* pmMessage)
{
    switch(pmMessage->evtId)
    {
        case OPENAT_DRV_EVT_PM_POWERON_ON_IND:
            if(OPENAT_PM_POWERON_BY_INVALID == g_PowronInfo.reason)
            {
                g_PowronInfo.reason = pmMessage->param.poweronind.powerOnReason;
                if(0 != g_PowronInfo.poweronSyncSemaphore)
                {
                    IVTBL(release_semaphore)(g_PowronInfo.poweronSyncSemaphore);
                }
            }
            else
            {
                /* received poweron reason message again */
            }
            IVTBL(print)("[custPM]:poweron reason: %d",pmMessage->param.poweronind.powerOnReason);
            break;
        case OPENAT_DRV_EVT_CHR_PRESENT_IND:
            IVTBL(print)("[custPM]:chr present: %d",pmMessage->param.chrpresentind.present);
            break;
        case OPENAT_DRV_EVT_BAT_PRESENT_IND:
            IVTBL(print)("[custPM]:bat present: %d",pmMessage->param.batpresentind.present);
            break;
        case OPENAT_DRV_EVT_BAT_LEVEL_IND:
            IVTBL(print)("[custPM]:bat level: %d",pmMessage->param.batlevelind.batteryLevel);
            break;
        case OPENAT_DRV_EVT_BAT_CHARGING:
            IVTBL(print)("[custPM]:charging level: %d",pmMessage->param.chargingind.batteryLevel);
            break;
        case OPENAT_DRV_EVT_BAT_CHR_FULL:
            IVTBL(print)("[custPM]:full level: %d",pmMessage->param.chrfullind.batteryLevel);
            break;
        case OPENAT_DRV_EVT_BAT_CHR_STOP:
            IVTBL(print)("[custPM]:chr stop reason: %d",pmMessage->param.chrstopind.chrStopReason);
            break;
        default:
            break;
    }
}

#if CUST_LCD_SUPPORT == CUST_MONO_LCD
static VOID cust_lcd_reset(void)
{
    IVTBL(send_mono_lcd_command)(0xe2);
    IVTBL(send_mono_lcd_command)(0xa3);
    IVTBL(send_mono_lcd_command)(0xa0);
    IVTBL(send_mono_lcd_command)(0xc8);
    IVTBL(send_mono_lcd_command)(0xa6);
    IVTBL(send_mono_lcd_command)(0x2f);
    IVTBL(send_mono_lcd_command)(0x23);
    IVTBL(send_mono_lcd_command)(0x81);
    IVTBL(send_mono_lcd_command)(0x2e);
    IVTBL(send_mono_lcd_command)(0x60);
    IVTBL(send_mono_lcd_command)(0xaf);  //lcd on      
    IVTBL(send_mono_lcd_command)(0x01);
    IVTBL(send_mono_lcd_command)(0x81);
    IVTBL(send_mono_lcd_command)(45);

    memset(g_LcdFrameBuffer, 0x00, sizeof(g_LcdFrameBuffer));

#if 0
    T_AMOPENAT_LCD_RECT_T rect;
    rect.ltX = 0;
    rect.ltY = 0;
    rect.rbX = LCD_WIDTH - 1;
    rect.rbY = LCD_HEIGHT - 1;
    IVTBL(update_mono_lcd_screen)(&rect);
#endif
    IVTBL(clear_mono_lcd)(64, 132);
}

static VOID cust_lcd_poweron(void)
{
    const unsigned char 	Digtal[11][17]=
    {//
    	{0x30,0xF0,0xF8,0x0C,0xC4,0x0C,0xF8,0xF0,0x00,0x03,0x07,0x0C,0x08,0x0C,0x07,0x03,0x00},// 0
        {0x31,0x00,0x10,0x18,0xFC,0xFC,0x00,0x00,0x00,0x00,0x08,0x08,0x0F,0x0F,0x08,0x08,0x00},// 1
        {0x32,0x08,0x0C,0x84,0xC4,0x64,0x3C,0x18,0x00,0x0E,0x0F,0x09,0x08,0x08,0x0C,0x0C,0x00},// 2
        {0x33,0x08,0x0C,0x44,0x44,0x44,0xFC,0xB8,0x00,0x04,0x0C,0x08,0x08,0x08,0x0F,0x07,0x00},// 3
        {0x34,0xC0,0xE0,0xB0,0x98,0xFC,0xFC,0x80,0x00,0x00,0x00,0x00,0x08,0x0F,0x0F,0x08,0x00},// 4
        {0x35,0x7C,0x7C,0x44,0x44,0x44,0xC4,0x84,0x00,0x04,0x0C,0x08,0x08,0x08,0x0F,0x07,0x00},// 5
        {0x36,0xF0,0xF8,0x4C,0x44,0x44,0xC0,0x80,0x00,0x07,0x0F,0x08,0x08,0x08,0x0F,0x07,0x00},// 6
        {0x37,0x0C,0x0C,0x04,0x84,0xC4,0x7C,0x3C,0x00,0x00,0x00,0x0F,0x0F,0x00,0x00,0x00,0x00},// 7
        {0x38,0xB8,0xFC,0x44,0x44,0x44,0xFC,0xB8,0x00,0x07,0x0F,0x08,0x08,0x08,0x0F,0x07,0x00},// 8
        {0x39,0x38,0x7C,0x44,0x44,0x44,0xFC,0xF8,0x00,0x00,0x08,0x08,0x08,0x0C,0x07,0x03,0x00},// 9
    	{0},
    };

    UINT8 x, y, number;
    UINT16 data_offset;
    T_AMOPENAT_LCD_RECT_T rect;

    x = (LCD_WIDTH-8)/2;
    y = LCD_HEIGHT/2;

    switch(g_PowronInfo.reason)
    {
        case OPENAT_PM_POWERON_BY_KEY:
            number = 1;
            break;
        case OPENAT_PM_POWERON_BY_CHARGER:
            number = 2;
            break;
        case OPENAT_PM_POWERON_BY_ALARM:
            number = 3;
            break;
        case OPENAT_PM_POWERON_BY_RESET:
            number = 4;
            break;
        case OPENAT_PM_POWERON_BY_OTHER:
            number = 5;
            break;
        default:
            number = 0;
            break;
    }

    data_offset = (y/8)*(LCD_WIDTH) + x;
    memcpy((void *)((UINT8*)g_LcdFrameBuffer+data_offset), &Digtal[number][1], 8);

    data_offset = (y/8+1)*(LCD_WIDTH) + x;
    memcpy((void *)((UINT8*)g_LcdFrameBuffer+data_offset), &Digtal[number][9], 8);

    rect.ltX = x;
    rect.ltY = y;
    rect.rbX = x+8;
    rect.rbY = y+16;
    IVTBL(update_mono_lcd_screen)(&rect);
}

static VOID cust_mono_lcd_init(VOID)
{
    T_AMOPENAT_MONO_LCD_PARAM lcdParam;
    lcdParam.height = LCD_HEIGHT;
    lcdParam.width = LCD_WIDTH;
    lcdParam.xoffset = 1;
    lcdParam.yoffset = 0x20;
    lcdParam.frequence = 6000000;//6M
    lcdParam.fameBuffer = g_LcdFrameBuffer;
    lcdParam.csPort = OPENAT_GPIO_UNKNOWN;/*与硬件设计有关*/
    lcdParam.rstPort = OPENAT_GPIO_12;
    lcdParam.pixelBits = 1;
    
    IVTBL(init_mono_lcd)(&lcdParam);
}
#endif

static VOID cust_lcd_init(VOID)
{
#if CUST_LCD_SUPPORT == CUST_MONO_LCD
    cust_mono_lcd_init();
#elif CUST_LCD_SUPPORT == CUST_COLOR_LCD
    cust_color_lcd_init();
#endif
}

static VOID cust_lcd_test(void)
{
#if CUST_LCD_SUPPORT == CUST_MONO_LCD
    cust_lcd_reset();
    cust_lcd_poweron();
#elif CUST_LCD_SUPPORT == CUST_COLOR_LCD
    cust_color_lcd_test();
#endif
}

static VOID cust_audio_test(VOID)
{
    static E_AMOPENAT_DTMF_TYPE dtmf        = OPENAT_AUD_TONE_DTMF_0;
    static E_AMOPENAT_AUDIO_CHANNEL channel = OPENAT_AUD_CHANNEL_EARPIECE;
    static BOOL bMute = FALSE;
    static E_AMOPENAT_SPEAKER_GAIN speakerGain = OPENAT_AUD_SPK_GAIN_0dB;
    static UINT8 testMode = 0;
    
    switch(testMode)
    {
        case 0:
            IVTBL(open_tch)();
            break;
        case 1:
            IVTBL(close_tch)();
            break;

        case 4:
            IVTBL(play_tone)(OPENAT_AUD_TONE_DIAL, 30000, OPENAT_AUD_SPK_GAIN_9dB);
            break;
        case 7:
            IVTBL(stop_tone)();
            break;

        case 3:
            IVTBL(play_dtmf)(dtmf, 30000, OPENAT_AUD_SPK_GAIN_9dB);

            if(++dtmf >= OPENAT_AUD_TONE_DTMF_END)
            {
                dtmf = OPENAT_AUD_TONE_DTMF_0;
            }
            
            break;
        case 6: 
            IVTBL(stop_dtmf)();
            break;

        case 9:
            IVTBL(set_channel)(channel);
            channel = ((channel == OPENAT_AUD_CHANNEL_EARPIECE) ? 
                OPENAT_AUD_CHANNEL_LOUDSPEAKER : OPENAT_AUD_CHANNEL_EARPIECE);
            break;

         case 10: /*star*/
            if(!bMute)
            {
                IVTBL(mute_mic)();
            }
            else
            {
                IVTBL(unmute_mic)();
            }
            bMute = !bMute;
            break;

        case 11:
            IVTBL(set_speaker_gain)(speakerGain);

            if(++speakerGain >= OPENAT_AUD_SPK_GAIN_END)
            {
                speakerGain = OPENAT_AUD_SPK_GAIN_0dB;
            }
            break;
            
        default:
            break;
    }

    testMode++;
    testMode %= 11;
}

void cust_tflash_test(void)
{
/*+\BUG WM-719\maliang\2013.3.21\文件系统接口和播放音频文件接口的文件名改为unicode little ending类型*/
    #define TFALSH_ROOT L"/TFLASH"
    
    AMOPENAT_TFLASH_INIT_PARAM param = 
    {
        .pszMountPointUniLe = TFALSH_ROOT,
    };

    AMOPENAT_FS_FIND_DATA findData;
    INT32 iRet = 0;

    // 初始化T卡,设定T卡挂载路径
    iRet = IVTBL(init_tflash)(&param);

    PUB_TRACE("[cust_tflash_test]:init_tflash return %d", iRet);

    // 可以用文件系统的任何接口访问T卡数据 加上前面挂载的T卡路径
    IVTBL(change_dir)(TFALSH_ROOT);
    iRet = IVTBL(find_first_file)(L"*.*", &findData);
/*-\BUG WM-719\maliang\2013.3.21\文件系统接口和播放音频文件接口的文件名改为unicode little ending类型*/

    PUB_TRACE("[cust_tflash_test]:find_first_file return %d", iRet);

    if(0 == iRet)
    {
        UINT8 i, filename[FS_FILE_NAME_LEN+LEN_FOR_NULL_CHAR];
        UINT16 *unicodeName = (UINT16*)findData.st_name;
        
        for(i = 0; unicodeName[i] != 0 && i < FS_FILE_NAME_LEN; i++)
        {
            filename[i] = unicodeName[i]&0x00ff;
        }

        filename[i] = '\0';

        PUB_TRACE("[cust_tflash_test]:find_first_file name %s", filename);
    }
}

#if PSAM_TEST_SUPPORT==1
static VOID cust_psam_test(VOID)
{
#define BUFFER_LEN 64
    UINT8 psam_rxbuf[BUFFER_LEN] = {0};
    UINT8 psam_txbuf[BUFFER_LEN] = {0};
    UINT16 tx_len = 0;
    UINT16 le;
    E_AMOPENAT_PSAM_OPER_RESULT psam_result;

    /* 1. open psam */
    ASSERT(PSAM_SUCCESS == IVTBL(open_psam)(PSAM_ID_1));
    /* 2. reset psam */
    ASSERT(PSAM_SUCCESS == IVTBL(reset_psam)(psam_rxbuf, BUFFER_LEN, PSAM_VOLT_3V));
    /* 3. read psam card id */
    tx_len = 0;
    le = 0x08;
    psam_txbuf[tx_len++] = 0x80;
    psam_txbuf[tx_len++] = 0xca;
    psam_txbuf[tx_len++] = 0x00;
    psam_txbuf[tx_len++] = 0x01;
    psam_txbuf[tx_len++] = le;
    psam_result = IVTBL(rw_psam)(psam_txbuf, tx_len, psam_rxbuf, le); /* psam card id saved in psam_rxbuf */
    ASSERT(PSAM_SUCCESS == psam_result);
    /* 4. close psam */
    IVTBL(close_psam)();
}
#endif

#if VIDEO_PLAYER_TEST_SUPPORT == 1
static void videoMsgCallback(T_AMOPENAT_VIDEO_MESSAGE *pMsg)
{
    switch(pMsg->evtId)
    {
        case OPENAT_DRV_EVT_VIDEO_PLAY_FINISH_IND:
            PUB_TRACE("[videoMsgCallback]: finish result %d", pMsg->param.playFinishResult);
            break;

        case OPENAT_DRV_EVT_VIDEO_CURRENT_TIME_IND:
            PUB_TRACE("[videoMsgCallback]: current played time %d", pMsg->param.currentTime);
            break;

        default:
            break;
    }
}

static VOID cust_videoplayer_test(VOID)
{
    INT32 testVideoFileFd;
    T_AMOPENAT_VIDEO_PARAM videoParam;
    T_AMOPENAT_VIDEO_INFO videoInfo;

    testVideoFileFd = IVTBL(open_file)("/TFLASH/test_videorecord.avi", FS_O_RDONLY, 0);
    
    videoParam.msgCallback = videoMsgCallback;
    videoParam.videoType = OPENAT_VIDEO_TYPE_MJPG;
    videoParam.iFd = testVideoFileFd;

    ASSERT(TRUE == IVTBL(video_open)(&videoParam));

    ASSERT(TRUE == IVTBL(video_get_info)(&videoInfo));

    PUB_TRACE("[cust_videoplayer_test]: video info width(%d) height(%d) time(%d)", 
                videoInfo.imageWidth, 
                videoInfo.imageHeight, 
                videoInfo.totalTime);

    ASSERT(TRUE == IVTBL(video_play)());

    IVTBL(sleep)(10000 *16384/1000);
    
    ASSERT(TRUE == IVTBL(video_stop)());
    
    ASSERT(TRUE == IVTBL(video_close)());
    
    IVTBL(close_file)(testVideoFileFd);
}
#endif

static VOID cust_poweron_reason_init(VOID)
{
    if(0 == g_PowronInfo.poweronSyncSemaphore)
    {
        g_PowronInfo.poweronSyncSemaphore = IVTBL(create_semaphore)(0);
        ASSERT(0 != g_PowronInfo.poweronSyncSemaphore);
    }
}

static VOID cust_wait_for_poweron_reason(BOOL bDeleteSema)
{
    ASSERT(0 != g_PowronInfo.poweronSyncSemaphore);

    IVTBL(wait_semaphore)(g_PowronInfo.poweronSyncSemaphore, 0);

    if(TRUE == bDeleteSema)
    {
        IVTBL(delete_semaphore)(g_PowronInfo.poweronSyncSemaphore);
        g_PowronInfo.poweronSyncSemaphore = 0;
    }
}
static VOID cust_nv_test(VOID)
{
  
#if NV_SUPPORT == 1
  #define CUST_NV_SIZE (100)
  #define CUST_NV_ID    (1)
  static BOOL init = FALSE;
  UINT8  buf[CUST_NV_SIZE] ={0};
  UINT8  readBuf[CUST_NV_SIZE] = {0};
  UINT32 size;
  INT32  result;
  
  if(!init)
  {
    ASSERT(NV_SUCCESS == IVTBL(nv_init)((UINT32)flashNvAddr1,(UINT32)flashNvAddr2));
    init = TRUE;
  }
  result = IVTBL(nv_add)(CUST_NV_ID,CUST_NV_SIZE);
  if(NV_ERR_NV_ALREADY_EXIST == result)
  {
    IVTBL(nv_read)(CUST_NV_ID,readBuf,CUST_NV_SIZE,&size);
    readBuf[size] = '\0';
    IVTBL(print)("nv read %s",readBuf);    
  }
  else if(NV_SUCCESS == result)
  {
    sprintf(buf,"test nv write hello");
    IVTBL(nv_write)(CUST_NV_ID,buf,strlen(buf),&size);
    IVTBL(nv_read)(CUST_NV_ID,readBuf,CUST_NV_SIZE,&size);
    readBuf[size] = '\0';
    IVTBL(print)("nv read %s",readBuf);        
  }
#endif      
}

/* custom app main */
static VOID cust_task_main(PVOID pParameter)
{
    CUST_MESSAGE *pMessage = NULL;

    /* wait for power on message from pm interface */
    cust_wait_for_poweron_reason(TRUE);

    IVTBL(poweron_system)(OPENAT_PM_STARTUP_MODE_DEFAULT, OPENAT_PM_STARTUP_MODE_DEFAULT);
    
#if SPI_TEST_SUPPORT==1
    uint8  cmd[] = {0xa3,0x0,0x5,0x10};
    IVTBL(write_spi)(OPENAT_SPI_1,cmd,sizeof(cmd));
#endif

    cust_lcd_test();

#if TFLASH_TEST == 1
    cust_tflash_test();    
#endif

#if CAMERA_TEST_SUPPORT == 1
    cust_camera_test();
#endif

#if VIDEO_PLAYER_TEST_SUPPORT == 1
    cust_videoplayer_test();
#endif

    cust_uart_print("Enter message loop");

    cust_nv_test();
    while(1)
    {
        IVTBL(wait_message)(g_CustTaskHandle, (VOID**)&pMessage, 0);
        
        if(NULL != pMessage)
        {
            //dispatch your messge
            switch(pMessage->type)
            {
                case AT_MESSAGE:
                    PUB_TRACE("AT MESSAGE");
                    break;
                
                case KEY_MESSAGE:
                    PUB_TRACE("KEY MESSAGE");
                    cust_audio_test();
                    break;

                case SPI_MESSAGE:
                    PUB_TRACE("SPI data %d ",pMessage->len);
                    //do something
                    break;

            #if TOUCH_SCREEN_SUPORT == 1
                case TOUCHSCREEN_MESSAGE:
                {
                    T_AMOPENAT_TOUCHSCREEN_MESSAGE *pTouchScreenMsg = (T_AMOPENAT_TOUCHSCREEN_MESSAGE *)(pMessage->data);
                    
                    PUB_TRACE("TOUCHSCREEN MESSAGE: %d %d %d", pTouchScreenMsg->penState, pTouchScreenMsg->x, pTouchScreenMsg->y);
                    break;
                }
            #endif
                    
                default:
                    break;
            }
            
            if(NULL != pMessage->data)
            {
                IVTBL(free)(pMessage->data);
            }
            IVTBL(free)(pMessage);
        }
    }
}

static VOID cust_uart_print(CHAR * fmt, ...)
{
#if UART_PRINT_SUPPORT == 0
    return;
#endif
#define UART_USED OPENAT_UART_1
    static BOOL bInit = FALSE;
    
    if(FALSE == bInit)
    {
        T_AMOPENAT_UART_PARAM cfg;
    	cfg.baud = OPENAT_UART_BAUD_115200;
    	cfg.dataBits = 8;
    	cfg.flowControl = OPENAT_UART_FLOWCONTROL_NONE;
    	cfg.parity = OPENAT_UART_NO_PARITY;
    	cfg.stopBits = 2;
      cfg.uartMsgHande = NULL;
    	ASSERT( TRUE == IVTBL(config_uart)(UART_USED, &cfg));
    	bInit = TRUE;
    }
    
    va_list ap;
    char fmtString[128];
    UINT16 len;

    va_start (ap, fmt);
    len = vsnprintf(fmtString, sizeof(fmtString), fmt, ap);
    va_end (ap);
    fmtString[127] = 0;
    
    if(len != 0)
    {
        IVTBL(write_uart)(UART_USED, fmtString, len, FALSE);
    }
}
