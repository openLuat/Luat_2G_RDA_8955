#include <stdio.h>
#include <windows.h>
#include "win_msg.h"
#include "platform_conf.h"
#include "platform.h"
#include "platform_rtos.h"
#include "cycle_queue.h"

#define COM_RX_BUF_SIZE (1460)
#define COM_TX_BUF_SIZE (1460)
#define COM_NAME_SIZE   (30)

typedef struct ComDevTag
{
    int id;
    char name[COM_NAME_SIZE+1];
    HANDLE hCom;
    HANDLE dwThreadId;
    HANDLE dwWriteThreadId;
    HANDLE semWrite;
    CycleQueue txq;
    CycleQueue rxq;
}ComDev;

static ComDev comDev[] = 
{
    {0, "", INVALID_HANDLE_VALUE},
    {1, "", INVALID_HANDLE_VALUE},  
    {2, "", INVALID_HANDLE_VALUE},
    {3, "", INVALID_HANDLE_VALUE},
    //{0xff, "COM5", INVALID_HANDLE_VALUE},
    {PLATFORM_UART_ID_ATC, "", INVALID_HANDLE_VALUE},
};

static ComDev *_find_com_dev(int id)
{
    int i;

    for(i = 0; i < sizeof(comDev)/sizeof(comDev[0]); i++)
    {
        if(id == comDev[i].id)
        {
            return &comDev[i];
        }
    }

    return NULL;
}

void send_uart_message(int uart_id)
{
    MSG msg;
    
    PlatformMessage *pMsg = malloc(sizeof(PlatformMessage));
    
    pMsg->id = RTOS_MSG_UART_RX_DATA;
    pMsg->data.uart_id = uart_id;
    
    msg.message = SIMU_RTOS_MSG_ID;
    msg.wParam = (WPARAM)pMsg;
    SendToLuaShellMessage(&msg);
}

void simulate_uart_thread(LPVOID lparam)
{
    ComDev *dev = (ComDev *)lparam;
    DWORD dwCommEvent;
    uint8 tempbuf[1460];
    int readsize = 0;
    uint8 *buffer = NULL;
    DWORD dwCount;
    BOOL rx_indicate = FALSE;
    DWORD dwErrorFlags;
    COMSTAT ComStat;
    OVERLAPPED overlappedRead;
    FILE *flog;

    if(dev->id == PLATFORM_UART_ID_ATC)
    {
        remove("atc.log");
    }

    memset(&overlappedRead, 0, sizeof(overlappedRead));
    overlappedRead.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);

    SetCommMask(dev->hCom, EV_RXCHAR);

    while(1)
    {
        WaitCommEvent(dev->hCom, &dwCommEvent, NULL);
    
        ClearCommError(dev->hCom, &dwErrorFlags, &ComStat);
        
        if(ComStat.cbInQue > sizeof(tempbuf))
        {
            buffer = malloc(ComStat.cbInQue);
            readsize = ComStat.cbInQue;    
        }
        else
        {
            buffer = tempbuf;
            readsize = sizeof(tempbuf);
        }
        
        if(dev->id == PLATFORM_UART_ID_ATC)
        {
            //flog = fopen("atc.log","a+");
            //fprintf(flog,"cbinqueue: %d!\n", ComStat.cbInQue);
            //fclose(flog);
        }

        ReadFile(dev->hCom, buffer, readsize, &dwCount, &overlappedRead);

        if(GetOverlappedResult(dev->hCom, &overlappedRead, &dwCount, TRUE))
        {
            if(dwCount)
            {
                if(dev->rxq.empty)
                {
#if 0 
                    if(comDev->id == PLATFORM_UART_ID_ATC && strstr(buffer, "\n") == NULL)
                    {
                        rx_indicate = FALSE;
                    }
                    else
                    {
                        rx_indicate = TRUE;
                    }
#else
                    rx_indicate = TRUE;    
#endif
                }
                else
                    rx_indicate = FALSE;

                if(dev->id == PLATFORM_UART_ID_ATC)
                {
                    flog = fopen("atc.log","ab+");
                    //fprintf(flog,"dwCount: %d!\n", dwCount);
                    fprintf(flog,"\r\nrecv:");
                    fwrite(buffer, dwCount, 1, flog);
                    fclose(flog);
                }

                QueueInsert(&dev->rxq, buffer, dwCount);
            }        
        }
        
        if(rx_indicate)
            send_uart_message(dev->id);

        if(buffer != tempbuf && buffer)
        {
            free(buffer);
            buffer = NULL;
        }
    }
}

void simulate_uart_write_thread(LPVOID lparam)
{
    ComDev *dev = (ComDev *)lparam;
    uint8 tempbuf[1000];
    int len;
    DWORD dwWritten = 0;
    OVERLAPPED overlappedWrite;

    memset(&overlappedWrite, 0, sizeof(overlappedWrite));
    overlappedWrite.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);

    while(1)
    {
        WaitForSingleObject(dev->semWrite, INFINITE);

        memset(tempbuf, 0, sizeof(tempbuf));
        len = QueueDelete(&dev->txq, tempbuf, sizeof(tempbuf));
        
        WriteFile(dev->hCom, tempbuf, len, &dwWritten, &overlappedWrite);

        if(dev->id == PLATFORM_UART_ID_ATC)
        {
            FILE *flog = fopen("atc.log","ab+");
            //fprintf(flog,"dwCount: %d!\n", dwCount);
            if(flog){
                fprintf(flog,"\r\nsend:");
                fwrite(tempbuf, len, 1, flog);
                fclose(flog);
            }
        }
        
        if(GetOverlappedResult(dev->hCom, &overlappedWrite, &dwWritten, TRUE))
        {

        }
    }
}

u32 platform_uart_setup( unsigned id, u32 baud, int databits, int parity, int stopbits, u32 mode, u32 txDoneReport)
{      
    ComDev *dev = _find_com_dev(id);
    DCB dcb;
    DWORD dwThread;

    if(id == platform_get_console_port())
    {
        return baud;
    }

    if(dev == NULL || dev->name == NULL)
    {
        printf("unknwon uart id %d\n", id);
        goto setup_failed;
    }

    if(dev->name[0] == '\0' || strcmp(dev->name, "NONE") == 0){
        printf("uart %d not set com port!\n", id);
        return baud;
    }

    dev->hCom = CreateFile(dev->name,//"COMx"
        GENERIC_READ|GENERIC_WRITE, //允许读和写
        0, //独占方式
        NULL,
        OPEN_EXISTING, //打开而不是创建
        FILE_ATTRIBUTE_NORMAL|FILE_FLAG_OVERLAPPED,
		NULL);

    if(dev->hCom == INVALID_HANDLE_VALUE)
    {
        printf("open uart %d failed %s\n", id, strerror(GetLastError()));
        goto setup_failed;
    }

    memset(&dev->rxq, 0, sizeof(dev->rxq));
    dev->rxq.buf = malloc(COM_RX_BUF_SIZE);
    dev->rxq.size = COM_RX_BUF_SIZE;
    QueueClean(&dev->rxq);

    memset(&dev->txq, 0, sizeof(dev->txq));
    dev->txq.buf = malloc(COM_TX_BUF_SIZE);
    dev->txq.size = COM_TX_BUF_SIZE;
    QueueClean(&dev->txq);

    GetCommState(dev->hCom, &dcb);
    if(baud == 0)
    {
        dcb.BaudRate = 115200; //波特率 
        dcb.ByteSize = 8; //数据位
        dcb.Parity = NOPARITY; //奇偶校验位
        dcb.StopBits = ONESTOPBIT; //停止位
        dcb.fDtrControl = DTR_CONTROL_ENABLE;
        dcb.fRtsControl = RTS_CONTROL_ENABLE;
    }
    else
    {
        dcb.BaudRate = baud; //波特率
        dcb.ByteSize = databits; //数据位
        dcb.Parity = NOPARITY; //奇偶校验位
        dcb.StopBits = ONESTOPBIT; //停止位
    }

    dcb.fInX = FALSE;
    dcb.fOutX = FALSE;

    if(id == PLATFORM_UART_ID_ATC)
    {
        dcb.fDtrControl = DTR_CONTROL_ENABLE;
        dcb.fRtsControl = RTS_CONTROL_ENABLE;
    }
   
    SetCommState(dev->hCom, &dcb);

#if 1
    {
        COMMTIMEOUTS to;
        GetCommTimeouts(dev->hCom, &to);
        //memset(&to, 0, sizeof(to));
        //设定读超时
        to.ReadIntervalTimeout = 50;
        to.ReadTotalTimeoutMultiplier = 1;
        to.ReadTotalTimeoutConstant = 10;
        //设定写超时
        //to.WriteTotalTimeoutMultiplier = 500;
        //to.WriteTotalTimeoutConstant = 2000;
        SetCommTimeouts(dev->hCom, &to);
    }
#else
    {
        COMMTIMEOUTS to;
        memset(&to, 0, sizeof(to));
        SetCommTimeouts(dev->hCom, &to);
    }
#endif // 0

    SetupComm(dev->hCom, 1460, 1460); //输入缓冲区和输出缓冲区的大小都是1024

    PurgeComm(dev->hCom, PURGE_TXABORT|PURGE_TXCLEAR|PURGE_RXABORT|PURGE_RXCLEAR);
    
    dev->semWrite = CreateSemaphore(NULL, 1, 10, NULL);

    dev->dwThreadId = CreateThread(NULL , 
        1*1024, 
        (LPTHREAD_START_ROUTINE)simulate_uart_thread,
        (LPVOID)dev,
        0,
        &dwThread);

    dev->dwWriteThreadId = CreateThread(NULL , 
        1*1024, 
        (LPTHREAD_START_ROUTINE)simulate_uart_write_thread,
        (LPVOID)dev,
        0,
        &dwThread);

    return baud;
    
setup_failed:
    return 0;
}

u32 platform_uart_close( unsigned id )
{
    ComDev *dev = _find_com_dev(id);

    if(!dev->hCom || dev->hCom == INVALID_HANDLE_VALUE){
        return PLATFORM_OK;
    }

    TerminateThread(dev->dwThreadId, 0);
    TerminateThread(dev->dwWriteThreadId, 0);
    CloseHandle(dev->semWrite);
    CloseHandle(dev->hCom);
    
    dev->hCom = INVALID_HANDLE_VALUE;
    dev->semWrite = INVALID_HANDLE_VALUE;
    dev->dwWriteThreadId = INVALID_HANDLE_VALUE;
    dev->dwThreadId = INVALID_HANDLE_VALUE;

    return PLATFORM_OK;
}

u32 platform_s_uart_send( unsigned id, u8 data )
{
    ComDev *dev = _find_com_dev(id);
    DWORD dwWritten = 0;
    OVERLAPPED overlappedWrite;
    memset(&overlappedWrite, 0, sizeof(overlappedWrite));

    if(id == platform_get_console_port())
    {
        printf("%c", data);
        return 1;
    }

    if(dev->hCom == INVALID_HANDLE_VALUE)
    {
        return 0;
    }

    WriteFile(dev->hCom, &data, 1, &dwWritten, &overlappedWrite);
    return dwWritten;
}

u32 platform_s_uart_sync_send( unsigned id, u8 data )
{
    ComDev *dev = _find_com_dev(id);
    DWORD dwWritten = 0;
    OVERLAPPED overlappedWrite;
    memset(&overlappedWrite, 0, sizeof(overlappedWrite));

    if(id == platform_get_console_port())
    {
        printf("%c", data);
        return 1;
    }

    if(dev->hCom == INVALID_HANDLE_VALUE)
    {
        return 0;
    }

    WriteFile(dev->hCom, &data, 1, &dwWritten, &overlappedWrite);
    return dwWritten;
}

u32 platform_s_uart_send_buff( unsigned id, const u8 *buff, u16 len )
{
    ComDev *dev = _find_com_dev(id);

    if(id == platform_get_console_port())
    {
        printf("%s", buff);
        return len;
    }

    if(dev->hCom == INVALID_HANDLE_VALUE)
    {
        return 0;
    }
    
    QueueInsert(&dev->txq, buff, len);

    ReleaseSemaphore(dev->semWrite, 1, NULL);

    return len;
}

u32 platform_s_uart_sync_send_buff( unsigned id, const u8 *buff, u16 len )
{
    ComDev *dev = _find_com_dev(id);

    if(id == platform_get_console_port())
    {
        printf("%s", buff);
        return len;
    }

    if(dev->hCom == INVALID_HANDLE_VALUE)
    {
        return 0;
    }
    
    QueueInsert(&dev->txq, buff, len);

    ReleaseSemaphore(dev->semWrite, 1, NULL);

    return len;
}

int platform_s_uart_recv( unsigned id, s32 timeout )
{
    ComDev *dev = _find_com_dev(id);
    uint8 chRead;

    if(dev->hCom == INVALID_HANDLE_VALUE)
    {
        return -1;
    }

    if(1 == QueueDelete(&dev->rxq, &chRead, 1))
    {
        return chRead;
    }
    else
    {
        return -1;
    }
}

int platform_s_uart_set_flow_control( unsigned id, int type )
{
    return PLATFORM_ERR;
}

int platform_uart_init(void){
    FILE *fset = fopen("set.ini","rb");
    char buf[1460];
    static const int id_to_index[] = {
        2,
        1,
        2,
        3,
    };
    char coms[4][COM_NAME_SIZE+1] = {0};
    int i, setindex;

    if(fset){
        while(fgets(buf, sizeof(buf), fset)){
            if(strncmp(buf, "uart=", 5) == 0){
                int pos, pstart = 5, index = 0;

                for(pos = 5; pos < strlen(buf); pos++){
                    if(buf[pos] == ',' || buf[pos] == '\n'){
                        if(pos-pstart > COM_NAME_SIZE){
                            printf("error: too long com name %s!\n", &buf[pstart]);
                            continue;
                        }
                        strcpy(coms[index], "\\\\.\\");
                        memcpy(&coms[index][4], &buf[pstart], pos-pstart);
                        coms[index][pos-pstart+4] = '\0';
                        index++;
                        pstart = pos+1; /*skip ',' */
                        if(index >= sizeof(coms)/sizeof(coms[0])){
                            break;
                        }
                    }
                }
                break;
            }
        }
        fclose(fset);
    }

    for(i = 0; i < sizeof(comDev)/sizeof(comDev[0]); i++){
        if(comDev[i].id == PLATFORM_UART_ID_ATC){
            setindex = 0;
        } else {
            setindex = id_to_index[comDev[i].id];
        }
        
        strcpy(comDev[i].name, coms[setindex]);
    }
}