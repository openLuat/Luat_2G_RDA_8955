
#include <STDIO.H>
#include <WINDOWS.H>
#include "platform.h"
#include "platform_lcd.h"

static u16 lcd_width;
static u16 lcd_height;
static u8 pixel_depth;
static COLORREF lcd_hwbkcolor = RGB(255,255,255);
static COLORREF lcd_hwfillcolor = RGB(0,0,0);

extern HDC hConsoleDC;

COLORREF rgb5652rgb888(unsigned char *image) 
{ 
    unsigned char R,G,B; 
    int colorR,colorG,colorB;
    COLORREF color;
    
    B=(*image) & 0x1F;//000BBBBB 
    G=(( *(image+1) << 3 ) & 0x38) + (( *image >> 5 ) & 0x07) ;//得到00GGGGGG00 
    R=( *(image+1) >> 3 ) & 0x1F; //得到000RRRRR 
    colorB=B * 255 / 31; // 把5bits映射到8bits
    colorG=G * 255 / 63; 
    colorR=R * 255 / 31; 
    
    color = RGB(colorR, colorG, colorB);
    
    return color;
}

void platform_lcd_init(const PlatformDispInitParam *pParam)
{
    u8 index;

    lcd_width = pParam->width;
    lcd_height = pParam->height;
    pixel_depth = pParam->bpp;
    
    if (pParam->hwfillcolor == 0xffff)
    {
        lcd_hwbkcolor = RGB(0,0,0);
        lcd_hwfillcolor = RGB(255,255,255);
    }

    for(index = 0; index < pParam->tableSize; index++)
    {
        //printf("[platform_lcd_init].cmd[%d]: 0x%x\r\n", index, pParam->pLcdCmdTable[index]);
    }
    //printf("[platform_lcd_init]: rst pin is port %d pin %d\r\n", PLATFORM_IO_GET_PORT(pParam->pin_rst), PLATFORM_IO_GET_PIN(pParam->pin_rst));
}

/*+\NEW\zhy\2014.9.26\cmd窗口中重复刷新界面*/
PlatformRect RectLast;
u8 *bufferLast = NULL;
#define OFFSET_X 400
#define OFFSET_Y 16//0//16

void lcd_update_function(PlatformRect *pRect, u8 *buffer)
{
    int i,j;
    COLORREF color;
    u8 data;
    int bitIndex,page;
    #if 0
    Rectangle(hConsoleDC,pRect->ltx+OFFSET_X,pRect->lty+OFFSET_Y,pRect->rbx+OFFSET_X,pRect->rby+OFFSET_Y);
    #else
    for(i = pRect->ltx; i <= pRect->rbx; i++)
    {
        for(j = pRect->lty; j <= pRect->rby; j++)
        {
            if(pixel_depth == 1)
            {
                page = j/8;
                bitIndex = j%8;

                data = buffer[page*lcd_width+i];
                
                color = (data&(1<<bitIndex)) ? lcd_hwfillcolor:lcd_hwbkcolor;
            }
            else
            {
                color = rgb5652rgb888(&buffer[(j*lcd_width + i)*pixel_depth/8]);
            }
            SetPixel(hConsoleDC, i+OFFSET_X, j+OFFSET_Y, color);
        }
    }
    #endif
}

void platform_lcd_update(PlatformRect *pRect, u8 *buffer)
{

    memcpy(&RectLast, pRect, sizeof(PlatformRect));
    if(NULL == bufferLast)
    bufferLast = malloc(lcd_width * lcd_height * pixel_depth/8);

    if(bufferLast)
    memcpy(bufferLast,buffer, lcd_width * lcd_height * pixel_depth/8);
    
    lcd_update_function(pRect, buffer);


}
void platform_lcd_update_period(void)
{
    if(bufferLast == NULL)
    return;
    lcd_update_function(&RectLast,bufferLast);

}
/*-\NEW\zhy\2014.9.26\cmd窗口中重复刷新界面*/

void platform_lcd_powersave(int sleep_wake)
{
   return;
}