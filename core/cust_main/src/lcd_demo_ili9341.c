/*******************************************************
**
** lcd ili9341参考代码
*******************************************************/
/*******************************************************
* Date        What
* 2013.01.17  创建文件
* 2013.10.12  适配并口彩屏cs,rst管脚配置
********************************************************/

#include "string.h"
#include "stdio.h"

#include "am_openat.h"

#define LCD_WIDTH 320
#define LCD_HEIGHT 240


#define IVTBL(func) (g_s_InterfaceVtbl->func)
#define ASSERT(condition) IVTBL(assert)(condition, (CHAR*)__FUNCTION__, __LINE__)
#define PUB_TRACE(pFormat, ...)  IVTBL(print)(pFormat, ##__VA_ARGS__)

extern T_AMOPENAT_INTERFACE_VTBL * g_s_InterfaceVtbl;

UINT16 g_LcdFrameBuffer[LCD_WIDTH*LCD_HEIGHT];
    
#undef delayms
#define delayms(ms)                         IVTBL(sleep)((ms))

#undef Delayms
#define Delayms                             delayms

#define LCD_ILI9340C_CMD(cmd)               IVTBL(send_color_lcd_command)(cmd)
#define LCD_ILI9340C_Parameter(data)        IVTBL(send_color_lcd_data)(data)    

#undef LCM_WR_CMD
#define LCM_WR_CMD                          LCD_ILI9340C_CMD

#undef LCM_WR_DAT
#define LCM_WR_DAT                          LCD_ILI9340C_Parameter

void ili9341SetWindowAddress(T_AMOPENAT_LCD_RECT_T *rect)
{
    LCM_WR_CMD(0x2a);    //Set Column Address
    LCM_WR_DAT(rect->ltX>>8);
    LCM_WR_DAT(rect->ltX&0x00ff);        
    LCM_WR_DAT(rect->rbX>>8);
    LCM_WR_DAT(rect->rbX&0x00ff);
    
    
    LCM_WR_CMD(0x2b);    //Set Page Address
    LCM_WR_DAT(rect->ltY>>8);
    LCM_WR_DAT(rect->ltY&0x00ff);                
    LCM_WR_DAT(rect->rbY>>8);
    LCM_WR_DAT(rect->rbY&0x00ff);
    
    // Write the display data into GRAM here 
    LCD_ILI9340C_CMD(0x2C); //GRAM start writing 
}

void ili9341LcdTestDisplay(void)
{
    UINT16 i,j;
    T_AMOPENAT_LCD_RECT_T rect;
    
    for ( i=0; i < LCD_HEIGHT; i++) 
        for ( j=0; j < LCD_WIDTH; j++) 
            g_LcdFrameBuffer[i*LCD_WIDTH+j] = 0xf800;       // write display data

    rect.ltX = 0;
    rect.ltY = 0;
    rect.rbX = LCD_WIDTH-1;
    rect.rbY = LCD_HEIGHT-1;

    ili9341SetWindowAddress(&rect);

    IVTBL(update_color_lcd_screen)(&rect, g_LcdFrameBuffer);
}

void ili9341LcdInit(void)
{
    //************* Start Initial Sequence **********// 
    //LCD_ILI9340C_CMD(0xEF);  
    //LCD_ILI9340C_Parameter (0x03); 
    //LCD_ILI9340C_Parameter (0x80); 
    //LCD_ILI9340C_Parameter (0x02); 
     
    LCD_ILI9340C_CMD(0xCF);  
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x81); 
    LCD_ILI9340C_Parameter (0X30); 
     
    LCD_ILI9340C_CMD(0xED);  
    LCD_ILI9340C_Parameter (0x64); 
    LCD_ILI9340C_Parameter (0x03); 
    LCD_ILI9340C_Parameter (0X12); 
    LCD_ILI9340C_Parameter (0X81); 
     
    LCD_ILI9340C_CMD(0xE8);  
    LCD_ILI9340C_Parameter (0x85); 
    LCD_ILI9340C_Parameter (0x11); 
    LCD_ILI9340C_Parameter (0x78); 
    
    
    LCD_ILI9340C_CMD(0xCB);  
    LCD_ILI9340C_Parameter (0x39); 
    LCD_ILI9340C_Parameter (0x2C); 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x34); 
    LCD_ILI9340C_Parameter (0x02); 
     
    LCD_ILI9340C_CMD(0xF7);  
    LCD_ILI9340C_Parameter (0x20); 
     
    LCD_ILI9340C_CMD(0xEA);  
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x00); 
     
    
    LCD_ILI9340C_CMD(0xb6);  
    LCD_ILI9340C_Parameter(0x0a); 
    LCD_ILI9340C_Parameter (0xa2); 
    
    LCD_ILI9340C_CMD(0xC0);       //Power control 
    LCD_ILI9340C_Parameter (0x21);     //VRH[5:0] 
     
    LCD_ILI9340C_CMD(0xC1);       //Power control 
    LCD_ILI9340C_Parameter (0x11);     //SAP[2:0];BT[3:0] 
     
    LCD_ILI9340C_CMD(0xC5);       //VCM control 
    LCD_ILI9340C_Parameter (0x33); 
    LCD_ILI9340C_Parameter (0x3C); 
     
    LCD_ILI9340C_CMD(0xC7);       //VCM control2 
    LCD_ILI9340C_Parameter (0xc0); 
     
    LCD_ILI9340C_CMD(0x36);       // Memory Access Control 
    LCD_ILI9340C_Parameter (0x68); 
    
    LCD_ILI9340C_CMD(0x3A);       
    LCD_ILI9340C_Parameter (0x55); 
    
    LCD_ILI9340C_CMD(0xB1);       //VCM control 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x18); 
    
     
    LCD_ILI9340C_CMD(0xF2);       // 3Gamma Function Disable 
    LCD_ILI9340C_Parameter (0x00); 
     
    LCD_ILI9340C_CMD(0x26);       //Gamma curve selected 
    LCD_ILI9340C_Parameter (0x01); 
     
    LCD_ILI9340C_CMD(0xE0);       //Set Gamma 
    LCD_ILI9340C_Parameter (0x0F); 
    LCD_ILI9340C_Parameter (0x1a); 
    LCD_ILI9340C_Parameter (0x18); 
    LCD_ILI9340C_Parameter (0x0c); 
    LCD_ILI9340C_Parameter (0x10); 
    LCD_ILI9340C_Parameter (0x08); 
    LCD_ILI9340C_Parameter (0x45); 
    LCD_ILI9340C_Parameter (0xba); 
    LCD_ILI9340C_Parameter (0x30); 
    LCD_ILI9340C_Parameter (0x02); 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x00); 
     
    LCD_ILI9340C_CMD(0XE1);       //Set Gamma 
    LCD_ILI9340C_Parameter (0x00); 
    LCD_ILI9340C_Parameter (0x24); 
    LCD_ILI9340C_Parameter (0x27); 
    LCD_ILI9340C_Parameter (0x03); 
    LCD_ILI9340C_Parameter (0x0e); 
    LCD_ILI9340C_Parameter (0x06); 
    LCD_ILI9340C_Parameter (0x3a); 
    LCD_ILI9340C_Parameter (0x45); 
    LCD_ILI9340C_Parameter (0x4f); 
    LCD_ILI9340C_Parameter (0x0d); 
    LCD_ILI9340C_Parameter (0x1f); 
    LCD_ILI9340C_Parameter (0x0f); 
    LCD_ILI9340C_Parameter (0x3f); 
    LCD_ILI9340C_Parameter (0x3f); 
    LCD_ILI9340C_Parameter (0x0F); 
    
    Delayms(50);
    LCD_ILI9340C_CMD(0x11);       //Exit Sleep 
    Delayms(120); 
    LCD_ILI9340C_CMD(0x29);       //Display on 
}

void lcdMsgCallback(T_AMOPENAT_LCD_MESSAGE *pMsg)
{    
    switch(pMsg->evtId)
    {
        case OPENAT_DRV_EVT_LCD_REFRESH_REQ:
            {
                T_AMOPENAT_LCD_REFRESH_REQ *pRefreshReq = &pMsg->param.refreshReq;

                ili9341SetWindowAddress(&pRefreshReq->rect);

                IVTBL(update_color_lcd_screen)(&pRefreshReq->rect, pRefreshReq->pFrameBuffer);
            }
            break;

        default:
            break;
    }
}

VOID cust_color_lcd_init(VOID)
{
    T_AMOPENAT_COLOR_LCD_PARAM param;

    param.width = LCD_WIDTH;
    param.height = LCD_HEIGHT;
    param.msgCallback = lcdMsgCallback;
    param.bus = OPENAT_LCD_PARALLEL_8800; // 设置lcd接口为并口8800
    param.lcdItf.parallel.csPort = OPENAT_GPIO_UNKNOWN; //无自定义cs脚则设为unknown
    param.lcdItf.parallel.rstPort = OPENAT_GPIO_12;
    
    IVTBL(init_color_lcd)(&param);
}

VOID cust_color_lcd_test(VOID)
{
    T_AMOPENAT_GPIO_CFG gpio13Cfg;

    //打开lcd背光 demo项目使用GPIO13作为lcd背光控制管脚
    gpio13Cfg.mode = OPENAT_GPIO_OUTPUT;
    gpio13Cfg.param.defaultState = TRUE;
    IVTBL(config_gpio)(OPENAT_GPIO_13, &gpio13Cfg);

    ili9341LcdInit();
    ili9341LcdTestDisplay();
}

