/*******************************************************
**
** camera ov7725参考代码
*******************************************************/
/*******************************************************
* Date        What
* 2013.02.03  创建文件
* 2013.02.09  增加视频录制功能测试
* 2013.03.01  增加录像时控制条叠加显示测试
********************************************************/

#include "string.h"
#include "stdio.h"
    
#include "am_openat.h"

#define IVTBL(func) (g_s_InterfaceVtbl->func)
#define ASSERT(condition) IVTBL(assert)(condition, (CHAR*)__FUNCTION__, __LINE__)

extern T_AMOPENAT_INTERFACE_VTBL * g_s_InterfaceVtbl;

static HANDLE cameraPanelRefreshTimer;
extern UINT16 g_LcdFrameBuffer[];
extern void ili9341SetWindowAddress(T_AMOPENAT_LCD_RECT_T *rect);
extern void ili9341LcdTestDisplay(void);

void cameraCallback(T_AMOPENAT_CAMERA_MESSAGE *pMsg)
{    
    switch(pMsg->evtId)
    {
        case OPENAT_DRV_EVT_VIDEORECORD_FINISH_IND:
            IVTBL(print)("[cameraCallback]: videorecord result(%d)", pMsg->param.videorecordFinishResult);
            break;
            
        default:
            break;
    }
}

static const AMOPENAT_CAMERA_REG cameraInitReg[] =
{
    {0x12, 0x80},
    {AMOPENAT_CAMERA_DELAY_CMD, 0x10},
    {0x3d, 0x03},
    {0x17, 0x22},
    {0x18, 0xa4},
    {0x19, 0x07},
    {0x1a, 0xf0},
    {0x32, 0x00},
    {0x29, 0x50},
    {0x2c, 0x78},
    {0x2a, 0x00},
    {0x11, 0x03},
    
    {0x42, 0x7f},
    {0x4d, 0x09},
    {0x63, 0xe0},
    {0x64, 0xff},
    {0x65, 0x2f},
    {0x66, 0x00}, //0x00->0x20 for dsp color bar test
    {0x67, 0x48},
    
    {0x13, 0xf0},
    {0x0d, 0x41},
    {0x0f, 0xc5},
    {0x14, 0x11},
    {0x22, 0x99}, //banding
    {0x23, 0x07},
    {0x24, 0x40},
    {0x25, 0x30},
    {0x26, 0xa1},
    {0x2b, 0x00},
    {0x6b, 0xaa},
    {0x13, 0xff},
    
    {0x90, 0x05},
    {0x91, 0x01},
    {0x92, 0x03},
    {0x93, 0x00},
    {0x94, 0xb0},
    {0x95, 0x9d},
    {0x96, 0x13},
    {0x97, 0x16},
    {0x98, 0x7b},
    {0x99, 0x91},
    {0x9a, 0x1e},
    {0x9b, 0x08},
    {0x9c, 0x20},
    {0x9e, 0x81},
    {0xa6, 0x04},
    
    {0x7e, 0x0c},
    {0x7f, 0x16},
    {0x80, 0x2a},
    {0x81, 0x4e},
    {0x82, 0x61},
    {0x83, 0x6f},
    {0x84, 0x7b},
    {0x85, 0x86},
    {0x86, 0x8e},
    {0x87, 0x97},
    {0x88, 0xa4},
    {0x89, 0xaf},
    {0x8a, 0xc5},
    {0x8b, 0xd7},
    {0x8c, 0xe8},
    {0x8d, 0x20},
    
    {0x11, 0x01},
    {0x0d, 0x41},
    {0x2a, 0x00},
    {0x2b, 0x00},
    {0x33, 0x99},
    {0x34, 0x00},
    {0x2d, 0x00},
    {0x2e, 0x00},
    {0x0e, 0x65},
};

VOID cameraDisplayDemoPanelArea(UINT8 index)
{
    UINT16 i,j;
    T_AMOPENAT_LCD_RECT_T rect;
    UINT16 color;

    switch(index%3)
    {
        case 0:
            color = 0xf800;
            break;

        case 1:
            color = 0x7e00;
            break;

        case 2:
        default:    
            color = 0x001f;
            break;
    }
    
    for ( i=0; i < 240; i++) 
        for ( j=0; j < 320; j++) 
            g_LcdFrameBuffer[i*320+j] = color;       // write display data

    rect.ltX = 0;
    rect.ltY = 200;
    rect.rbX = 319;
    rect.rbY = 239;

    ili9341SetWindowAddress(&rect);
    
    IVTBL(update_color_lcd_screen)(&rect, g_LcdFrameBuffer);
}

VOID cameraPanelRefreshCallback(T_AMOPENAT_TIMER_PARAMETER *pParameter)
{
    static UINT8 index = 0;
    
    IVTBL(start_timer)(cameraPanelRefreshTimer, 1000);
    
    cameraDisplayDemoPanelArea(index++);
}

void cust_camera_test(void)
{
    T_AMOPENAT_CAMERA_PARAM cameraParam;
    T_AMOPENAT_CAM_PREVIEW_PARAM previewParam;
    T_AMOPENAT_CAM_CAPTURE_PARAM captureParam;

    INT32 photoFileFd;

    cameraParam.messageCallback = cameraCallback;

    cameraParam.i2cPort = OPENAT_I2C_2;
    cameraParam.i2cSlaveAddr = 0x21;
    cameraParam.i2cAddrDataBits = AMOPENAT_CAMERA_REG_ADDR_8BITS|AMOPENAT_CAMERA_REG_DATA_8BITS;

    cameraParam.RSTBActiveLow = TRUE;
    cameraParam.PWDNActiveLow = FALSE;
    cameraParam.VSYNCActiveLow = TRUE;

    cameraParam.sensorWidth = 320;
    cameraParam.sensorHeight = 240;
    cameraParam.imageFormat = CAMERA_IMAGE_FORMAT_YUV422;
    cameraParam.initRegTable_p = (PAMOPENAT_CAMERA_REG)cameraInitReg;
    cameraParam.initRegTableCount = sizeof(cameraInitReg)/sizeof(AMOPENAT_CAMERA_REG);

    cameraParam.idReg.addr = 0x0A;
    cameraParam.idReg.value = 0x77;
    
    ASSERT(TRUE == IVTBL(camera_init)(&cameraParam));

    ASSERT(TRUE == IVTBL(camera_poweron)(FALSE));

    IVTBL(sleep)(100 *16384/1000);

    previewParam.startX = 0;
    previewParam.startY = 0;
    previewParam.endX = 319;
    previewParam.endY = 239;

    captureParam.imageWidth = 320;
    captureParam.imageHeight = 240;

    /* 预览拍照功能测试代码--begin */
    ASSERT(TRUE == IVTBL(camera_preview_open)(&previewParam));
    
    IVTBL(sleep)(10000 *16384/1000);

    ASSERT(TRUE == IVTBL(camera_preview_close)());
    
    IVTBL(sleep)(50 *16384/1000);

    ASSERT(TRUE == IVTBL(camera_capture)(&captureParam));

    photoFileFd = IVTBL(open_file)(L"/TFLASH/test_camera_demo.jpg", FS_O_WRONLY|FS_O_CREAT|FS_O_TRUNC, 0);
    
    ASSERT(TRUE == IVTBL(camera_save_photo)(photoFileFd));

    IVTBL(close_file)(photoFileFd);
    /* 预览拍照功能测试代码--end */
    
    /* 间隔1.5s连续抓拍功能测试代码--begin */
    BOOL previewOpened = FALSE;
    UINT8 index = 0;
    CHAR photoFileName[100];

    for(index = 0; index < 20; index++)
    {
        if(!previewOpened)
        {
            ASSERT(TRUE == IVTBL(camera_preview_open)(&previewParam));

            previewOpened = TRUE;
        }
        
        IVTBL(sleep)(1500 *16384/1000);

        ASSERT(TRUE == IVTBL(camera_preview_close)());

        previewOpened = FALSE;
        
        IVTBL(sleep)(50 *16384/1000);

        ASSERT(TRUE == IVTBL(camera_capture)(&captureParam));
        
        ASSERT(TRUE == IVTBL(camera_preview_open)(&previewParam));
    
        previewOpened = TRUE;
 
        sprintf(photoFileName, "/TFLASH/test_camera_%03d.jpg", index);

/*+\BUG WM-719\maliang\2013.3.21\文件系统接口和播放音频文件接口的文件名改为unicode little ending类型*/
        int end,counter;
        for(end=0;;end++)
        {
            if(0 == photoFileName[end])/*找到最后一个*/
            {
                break;
            }
        }
        WCHAR*  photoFileUnicode=(WCHAR*)IVTBL(malloc)((end+1)*sizeof(WCHAR));
        for(counter=0;counter<end;counter++)
        {
            photoFileUnicode[counter]=photoFileName[counter];
        }
        photoFileUnicode[end]=0;
        
        photoFileFd = IVTBL(open_file)(photoFileUnicode, FS_O_WRONLY|FS_O_CREAT|FS_O_TRUNC, 0);
        
        ASSERT(TRUE == IVTBL(camera_save_photo)(photoFileFd));

        IVTBL(close_file)(photoFileFd);

        IVTBL(free)(photoFileUnicode);/*把unicode文件名free掉*/
/*-\BUG WM-719\maliang\2013.3.21\文件系统接口和播放音频文件接口的文件名改为unicode little ending类型*/
    }
    /* 间隔1.5s连续抓拍功能测试代码--end */

    IVTBL(camera_poweroff)();

    // 进行视频录像,不用重新初始化,初始化只需执行一次,但是必须重新打开摄像头
    // 录制视频: 1. poweron 2.preview 3.start record 4. stop 5. poweroff
    // 以视频模式打开摄像头时 退出预览 或者 停止录像后 要重新预览或者录制 必须先poweroff再重新启动
    
    ASSERT(TRUE == IVTBL(camera_poweron)(TRUE));

    cameraPanelRefreshTimer = IVTBL(create_timer)(cameraPanelRefreshCallback, NULL);
    
    IVTBL(start_timer)(cameraPanelRefreshTimer, 1000);

    T_AMOPENAT_CAM_PREVIEW_PARAM videorecPreviewParam;

    videorecPreviewParam.startX = 0;
    videorecPreviewParam.startY = 0;
    videorecPreviewParam.endX = 319;
    videorecPreviewParam.endY = 239;

    videorecPreviewParam.filesizePermit = 5*1024; //5M
    videorecPreviewParam.recordAudio = TRUE;
    videorecPreviewParam.timePermit = 0;
    videorecPreviewParam.encodeQuality = OPENAT_VID_REC_QTY_NORMAL;

    ASSERT(TRUE == IVTBL(camera_preview_open)(&videorecPreviewParam));

    // 测试程序预览5秒后开始 录制 不是必须等5秒
    IVTBL(sleep)(5000 *16384/1000);
    
    INT32 videorecFileFd;

    videorecFileFd = IVTBL(open_file)(L"/TFLASH/test_videorecord.avi", FS_O_WRONLY|FS_O_CREAT|FS_O_TRUNC, 0);
    
    ASSERT(TRUE == IVTBL(camera_videorecord_start)(videorecFileFd));

    IVTBL(sleep)(30000 *16384/1000);

    ASSERT(TRUE == IVTBL(camera_videorecord_stop)());

    IVTBL(close_file)(videorecFileFd);

    IVTBL(delete_timer)(cameraPanelRefreshTimer);

    cameraPanelRefreshTimer = NULL;

    IVTBL(camera_poweroff)();
    
    ili9341LcdTestDisplay();
}

