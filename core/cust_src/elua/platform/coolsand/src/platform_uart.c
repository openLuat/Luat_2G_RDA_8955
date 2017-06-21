/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_uart.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/15
 *
 * Description:
 *  2013.08.07 liweiqiang       增加uart1支持
 **************************************************************************/

#include "string.h"
#include "malloc.h"

#include "rda_pal.h"
#include "cycle_queue.h"
#include "assert.h"

#include "platform.h"
#include "platform_conf.h"
#include "platform_rtos.h"

#define COS_WAIT_FOREVER            0

//vat recv queue
/*+\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */
#define VATC_RX_BUF_SIZE            8192
#define VATC_READ_BUF_SIZE          512
/*-\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */

#define UART_RX_BUF_SIZE            1460

// 临时缓冲区
#define RX_BUFFER_SIZE          256
/*+\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */
#define READ_BUFFER_SIZE        126
/*-\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */

#define PHY_PORT(ID)            (uartmap[ID].port)

typedef struct UartPhyContextTag
{
    CycleQueue  rxqueue;
    uint8       temprxbuff[RX_BUFFER_SIZE];
/*+\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */
    uint8       readbuf[READ_BUFFER_SIZE];
    uint8       readindex;
    uint8       readsize;
/*-\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */
}UartPhyContext;

typedef struct UartMapTag
{
    const E_AMOPENAT_UART_PORT port;
    const PUART_MESSAGE        msg;
}UartMap;

typedef struct UartContextTag
{
    uint8 opened;
    uint8 workmode; //uart数据提示方式:1:用户轮询 其他:消息提示 2: host uart ID A2数据透传
}UartContext;

/*+\NEW\liweiqiang\2014.7.21\修正AM002_LUA项目RAM不够编译不过的问题*/
#if defined(LOW_MEMORY_SUPPORT)
static UartPhyContext uartPhyContext[3]/*openat uart 1 & 2 & host uart*/;
#else
static uint8 uart1RxBuff[UART_RX_BUF_SIZE];
static uint8 uart2RxBuff[UART_RX_BUF_SIZE];
/*+\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
static uint8 uart3RxBuff[UART_RX_BUF_SIZE];
/*-\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/

static UartPhyContext uartPhyContext[3]/*openat uart 1 & 2 & host uart*/ =
{
    // OPENAT_UART_1,
    {
        {
            uart1RxBuff,
            UART_RX_BUF_SIZE,
            0,
            0,
            1,
            0,
            0,
        },
    },
    // OPENAT_UART_2,
    {
        {
            uart2RxBuff,
            UART_RX_BUF_SIZE,
            0,
            0,
            1,
            0,
            0,
        },
    },
/*+\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
    // OPENAT_UART_3,
    {
        {
            uart3RxBuff,
            UART_RX_BUF_SIZE,
            0,
            0,
            1,
            0,
            0,
        },
    },
/*-\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
};
#endif
/*-\NEW\liweiqiang\2014.7.21\修正AM002_LUA项目RAM不够编译不过的问题*/

static void uart0_message_handle(T_AMOPENAT_UART_MESSAGE* evt);
static void uart1_message_handle(T_AMOPENAT_UART_MESSAGE* evt);
static void uart2_message_handle(T_AMOPENAT_UART_MESSAGE* evt);
/*+\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
static void uart3_message_handle(T_AMOPENAT_UART_MESSAGE* evt);
/*-\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/

static const UartMap uartmap[NUM_UART] = 
{
    {OPENAT_UART_2,uart0_message_handle},
    {OPENAT_UART_1,uart1_message_handle},
    {OPENAT_UART_2,uart2_message_handle},
/*+\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
    {OPENAT_UART_3,uart3_message_handle},
/*-\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
};

static UartContext uartContext[NUM_UART];

static HANDLE hAtcReadSem = 0;
static uint8 vatcRxBuff[VATC_RX_BUF_SIZE];
CycleQueue vatcRx_Q = {
    vatcRxBuff,
    VATC_RX_BUF_SIZE,
    0,
    0,
    1,
    0,
    0,
};
/*+\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */
static uint8 vatc_read_buffer[VATC_READ_BUF_SIZE];
static uint16 vatc_read_buf_size;
static uint16 vatc_read_buf_index;
/*-\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */

/*+\NEW\liweiqiang\2013.4.7\优化debug口输出*/
static char debugStdoutBuffer[128];//openat接口的print接口buff最大为127字节与其同步
/*-\NEW\liweiqiang\2013.4.7\优化debug口输出*/
static UINT16 debugStdoutCachedCount = 0;

static void sendUartMessage(int uart_id, E_OPENAT_DRV_EVT event_id)
{
    PlatformMessage *pMsg = IVTBL(malloc)(sizeof(PlatformMessage));

    if(event_id == OPENAT_DRV_EVT_UART_RX_DATA_IND)
    {
        pMsg->id = RTOS_MSG_UART_RX_DATA;
    }
    else if(event_id == OPENAT_DRV_EVT_UART_TX_DONE_IND)
    {
        pMsg->id = RTOS_MSG_UART_TX_DONE;
    }
    
    pMsg->data.uart_id = uart_id;

    platform_rtos_send(pMsg);
}

static E_AMOPENAT_UART_BAUD findOpenatUartBaud(u32 baud)
{
    u8 index;
    E_AMOPENAT_UART_BAUD openat_uart_baud = OPENAT_UART_NUM_OF_BAUD_RATES;
    
    #define BAUD_2_UART_BAUD(baud) {baud, OPENAT_UART_BAUD_##baud}
    
    static const u32 baud2OpenatUartBaud[OPENAT_UART_NUM_OF_BAUD_RATES][2] =
    {
        BAUD_2_UART_BAUD(1200),
        BAUD_2_UART_BAUD(2400),
        BAUD_2_UART_BAUD(4800),
        BAUD_2_UART_BAUD(9600),
        BAUD_2_UART_BAUD(14400),
        BAUD_2_UART_BAUD(19200),
        BAUD_2_UART_BAUD(28800),
        BAUD_2_UART_BAUD(38400),
        BAUD_2_UART_BAUD(57600),
        BAUD_2_UART_BAUD(76800),
        BAUD_2_UART_BAUD(115200),
        BAUD_2_UART_BAUD(230400),
        BAUD_2_UART_BAUD(460800),
        BAUD_2_UART_BAUD(576000),
        BAUD_2_UART_BAUD(921600),
        BAUD_2_UART_BAUD(1152000),
        BAUD_2_UART_BAUD(4000000),
    };

    for(index = 0; index < OPENAT_UART_NUM_OF_BAUD_RATES; index++)
    {
        if(baud == baud2OpenatUartBaud[index][0])
        {
            openat_uart_baud = baud2OpenatUartBaud[index][1];
        }
        else if(baud < baud2OpenatUartBaud[index][0])
        {
            break;
        }
    }

    return openat_uart_baud;
}

static void uart_message_handle(uint8 id, T_AMOPENAT_UART_MESSAGE* evt)
{
    uint8 length;
    uint8 phyid = uartmap[id].port;
/*+\NEW\liweiqiang\2013.4.7\优化uart/atc数据接收消息提示,避免发消息过于频繁导致系统无法响应 */
    BOOL needMsg = FALSE; // buffer是空的时候,放入数据才需要作提示

    if(evt->evtId == OPENAT_DRV_EVT_UART_RX_DATA_IND)
    {
        length = IVTBL(read_uart)(phyid, uartPhyContext[phyid].temprxbuff, evt->param.dataLen, 0);

        if(length != 0)
        {
            needMsg = uartPhyContext[phyid].rxqueue.empty ? TRUE : FALSE;
            
            // 此处后续最好加上保护,写入缓冲在uart中断,读取数据在lua shell线程
            QueueInsert(&uartPhyContext[phyid].rxqueue, uartPhyContext[phyid].temprxbuff, length);
        }

        if(needMsg)
        {
            sendUartMessage(id, evt->evtId);
        }
    }
    else if(evt->evtId == OPENAT_DRV_EVT_UART_TX_DONE_IND)
    {
        sendUartMessage(id, evt->evtId);
    }
/*-\NEW\liweiqiang\2013.4.7\优化uart/atc数据接收消息提示,避免发消息过于频繁导致系统无法响应 */
}

static void uart0_message_handle(T_AMOPENAT_UART_MESSAGE* evt)
{
    uart_message_handle(0, evt);
}

static void uart1_message_handle(T_AMOPENAT_UART_MESSAGE* evt)
{
    uart_message_handle(1, evt);
}

static void uart2_message_handle(T_AMOPENAT_UART_MESSAGE* evt)
{
    uart_message_handle(2, evt);
}

/*+\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
static void uart3_message_handle(T_AMOPENAT_UART_MESSAGE* evt)
{
    uart_message_handle(3, evt);
}
/*-\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/

/*+\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
static void host_uart_recv(UINT8 *data, UINT32 length)
{
    uint8 phyid = OPENAT_UART_3;
    BOOL needMsg = FALSE; // buffer是空的时候,放入数据才需要作提示

    if(length != 0)
    {
        needMsg = uartPhyContext[phyid].rxqueue.empty ? TRUE : FALSE;
        
        QueueInsert(&uartPhyContext[phyid].rxqueue, data, length);
    }

    if(needMsg)
    {
        sendUartMessage(3, OPENAT_DRV_EVT_UART_RX_DATA_IND);
    }
}
/*-\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */

/****************************************************************************
 *
 * Function: PlatformUartOpen
 *
 * Parameters: 
 *         void
 *
 * Returns: void 
 *
 * Description: 打开串口
 *
 ****************************************************************************/
static u32 uart_phy_open( unsigned id, u32 baud, int databits, int parity, int stopbits, u32 mode, u32 txDoneReport)
{
    T_AMOPENAT_UART_PARAM uartParam;
    
    if(uartContext[id].opened)
        return baud;

/*+\NEW\liweiqiang\2014.7.21\修正AM002_LUA项目RAM不够编译不过的问题*/
    if(!uartPhyContext[PHY_PORT(id)].rxqueue.buf)
    {
        uartPhyContext[PHY_PORT(id)].rxqueue.buf = calloc(1, UART_RX_BUF_SIZE);
        uartPhyContext[PHY_PORT(id)].rxqueue.size = UART_RX_BUF_SIZE;
        QueueClean(&uartPhyContext[PHY_PORT(id)].rxqueue);
    }
/*-\NEW\liweiqiang\2014.7.21\修正AM002_LUA项目RAM不够编译不过的问题*/

/*+\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    if(PHY_PORT(id) == OPENAT_UART_3 && mode == 2)
    {
        if(IVTBL(host_init)(host_uart_recv))
        {
            uartContext[id].opened = 1;
            uartContext[id].workmode = mode;
            return baud;
        }
        else
        {
            return 0;
        }
    }
/*-\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    
    uartParam.baud = findOpenatUartBaud(baud);

    if(uartParam.baud == OPENAT_UART_NUM_OF_BAUD_RATES)
    {
        goto uart_open_error;
    }
    
    uartParam.dataBits = databits;

    switch(stopbits)
    {
        case PLATFORM_UART_STOPBITS_1:
            uartParam.stopBits = 1;
            break;
            
        case PLATFORM_UART_STOPBITS_2:
            uartParam.stopBits = 2;
            break;

        case PLATFORM_UART_STOPBITS_1_5:
        default:
            goto uart_open_error;
            break;
    }

    switch(parity)
    {
        case PLATFORM_UART_PARITY_EVEN:
            uartParam.parity = OPENAT_UART_EVEN_PARITY;
            break;

        case PLATFORM_UART_PARITY_ODD:
            uartParam.parity = OPENAT_UART_ODD_PARITY;
            break;

        case PLATFORM_UART_PARITY_NONE:
            uartParam.parity = OPENAT_UART_NO_PARITY;
            break;

        default:
            goto uart_open_error;
            break;
    }

/*+\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/
    if(PHY_PORT(id) == OPENAT_UART_3)
    {
        uartParam.flowControl = OPENAT_UART_FLOWCONTROL_HW;
    }
    else
    {
        uartParam.flowControl = OPENAT_UART_FLOWCONTROL_NONE;
    }
/*-\NEW\liweiqiang\2013.8.31\增加host uart通讯支持*/

    if(platform_get_console_port() == id)
    {
        uartParam.uartMsgHande = NULL;
    }
    else
    {
        if(mode == 1)
        {
            uartParam.uartMsgHande = NULL;
        }
        else
        {
            uartParam.uartMsgHande = uartmap[id].msg;
        }
    }

    uartParam.txDoneReport = txDoneReport;
    
    if(TRUE == IVTBL(config_uart)(PHY_PORT(id), &uartParam))
    {
        uartContext[id].opened = 1;
        uartContext[id].workmode = mode;
        return baud;
    }

uart_open_error:
    return 0;
}

/*+\NEW\liweiqiang\2013.4.20\增加uart.close接口 */
static u32 uart_phy_close(unsigned id)
{
    u32 ret;

    if(!uartContext[id].opened)
        return PLATFORM_OK;

/*+\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    if(PHY_PORT(id) == OPENAT_UART_3 && uartContext[id].workmode == 2)
    {
        // host uart此种模式不需要关闭
        return PLATFORM_OK;
    }
/*-\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
        
    ret = IVTBL(close_uart)(PHY_PORT(id)) ? PLATFORM_OK : PLATFORM_ERR;

    uartContext[id].opened = FALSE;

    QueueClean(&uartPhyContext[PHY_PORT(id)].rxqueue);
/*+\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */
    uartPhyContext[PHY_PORT(id)].readindex = uartPhyContext[PHY_PORT(id)].readsize = 0;
/*-\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */

    return ret;
}
/*-\NEW\liweiqiang\2013.4.20\增加uart.close接口 */

static u32 uart_phy_write(u8 id, uint8 *data_p, uint16 length)
{
    /*begin\NEW\zhutianhua\2017.2.28 13:53\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
    if (id>=NUM_UART)
    {
        return 0;
    }
    /*end\NEW\zhutianhua\2017.2.28 13:53\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
    if(!uartContext[id].opened)
        return 0;

/*+\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    if(PHY_PORT(id) == OPENAT_UART_3 && uartContext[id].workmode == 2)
    {
        IVTBL(host_send_data)(data_p, length);
        return length;
    }
/*-\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    
    return IVTBL(write_uart)(PHY_PORT(id), data_p, length, FALSE);
}

static u32 uart_phy_sync_write(u8 id, uint8 *data_p, uint16 length)
{
    /*begin\NEW\zhutianhua\2017.2.28 13:53\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
    if (id>=NUM_UART)
    {
        return 0;
    }
    /*end\NEW\zhutianhua\2017.2.28 13:53\新增rtos.set_trace接口，可控制是否输出Lua的trace*/
    if(!uartContext[id].opened)
        return 0;

/*+\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    if(PHY_PORT(id) == OPENAT_UART_3 && uartContext[id].workmode == 2)
    {
        IVTBL(host_send_data)(data_p, length);
        return length;
    }
/*-\NEW\liweiqiang\2014.1.2\host uart ID 0xA2数据透传支持 */
    
    return IVTBL(write_uart)(PHY_PORT(id), data_p, length,TRUE);
}

static u32 uart_phy_read(u8 id, uint8 *data_p, uint16 length, u32 timeout)
{    
    if(!uartContext[id].opened)
        return 0;

    if(uartContext[id].workmode == 1)
    {
        // 用户轮询方式直接从uart接口读取
        return IVTBL(read_uart)(PHY_PORT(id), data_p, length, timeout);
    }
    else
    {
        // 消息提示方式:从环形缓冲区读取
/*+\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */
        u32 rcvdlen = 0;
        UartPhyContext *context = &uartPhyContext[PHY_PORT(id)];

        while(rcvdlen < length)
        {
            if(context->readindex >= context->readsize)
            {
            /*+\NEW\liweiqiang\2014.4.12\增加串口缓冲区数据保护 */
                IVTBL(uart_enable_rx_int)(PHY_PORT(id), FALSE);
                context->readsize = QueueDelete(&context->rxqueue, context->readbuf, READ_BUFFER_SIZE);
                IVTBL(uart_enable_rx_int)(PHY_PORT(id), TRUE);
            /*-\NEW\liweiqiang\2014.4.12\增加串口缓冲区数据保护 */

                context->readindex = 0;

                if(context->readsize == 0) break;
            }

            data_p[rcvdlen++] = context->readbuf[context->readindex++];
        }
        
        return rcvdlen;
/*-\NEW\liweiqiang\2014.4.12\优化对串口uart库每次只读取一个字节的处理 */
    }
}

/*+\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */
static u32 vatc_read(uint8 *data_p, uint16 length, u32 timeout)
{
    u32 rcvdlen = 0;

    while(rcvdlen < length)
    {
        if(vatc_read_buf_index >= vatc_read_buf_size)
        {
            IVTBL(wait_semaphore)(hAtcReadSem, COS_WAIT_FOREVER);
            vatc_read_buf_size = QueueDelete(&vatcRx_Q, vatc_read_buffer, VATC_READ_BUF_SIZE);
            IVTBL(release_semaphore)(hAtcReadSem);
            vatc_read_buf_index = 0;

            if(vatc_read_buf_size == 0) break;
        }

        data_p[rcvdlen++] = vatc_read_buffer[vatc_read_buf_index++];
    }
    
    return rcvdlen;
}
/*-\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */

/*+\NEW\liweiqiang\2013.4.7\优化debug口输出*/
static void debugPortFlush(void)
{
    if(debugStdoutCachedCount != 0)
    {
        debugStdoutBuffer[debugStdoutCachedCount] = '\0';
        IVTBL(print)(debugStdoutBuffer);
        
        memset(debugStdoutBuffer, 0, sizeof(debugStdoutBuffer));
        debugStdoutCachedCount = 0;
    }
}

static void debugPortWrite(const u8 *buff, u16 len)
{
    u16 i;
    u8 data;

    for(i = 0; i < len; i++)
    {
        data = buff[i];
        
        if(data == '\r' || data == '\n')
        {
            debugPortFlush();
        }
        else
        {
            if(debugStdoutCachedCount < sizeof(debugStdoutBuffer) - 1)
                debugStdoutBuffer[debugStdoutCachedCount++] = data;
            else
            {
                debugPortFlush();
                debugStdoutBuffer[debugStdoutCachedCount++] = data;
            }
        }
    }
}
/*-\NEW\liweiqiang\2013.4.7\优化debug口输出*/

void RILAPI_ReceiveData(void *data, int len)
{
/*+\NEW\liweiqiang\2013.4.7\优化uart/atc数据接收消息提示,避免发消息过于频繁导致系统无法响应 */
    BOOL needMsg = FALSE; // buffer是空的时候,放入数据才需要作提示
    
    IVTBL(wait_semaphore)(hAtcReadSem, COS_WAIT_FOREVER);
    needMsg = vatcRx_Q.empty ? TRUE : FALSE;
    QueueInsert(&vatcRx_Q, data, len);
    IVTBL(release_semaphore)(hAtcReadSem);

    if(needMsg)
    {
        sendUartMessage(PLATFORM_UART_ID_ATC, OPENAT_DRV_EVT_UART_RX_DATA_IND);
    }
/*-\NEW\liweiqiang\2013.4.7\优化uart/atc数据接收消息提示,避免发消息过于频繁导致系统无法响应 */
}

void platform_setup_vat_queue(void)
{
    QueueClean(&vatcRx_Q);
    hAtcReadSem = IVTBL(create_semaphore)(1);
}

u32 platform_uart_setup( unsigned id, u32 baud, int databits, int parity, int stopbits, u32 mode, u32 txDoneReport)
{      
    u32 ret = baud;

    if(PLATFORM_UART_ID_ATC == id)
    {
        /* 在初始化vat之前就初始化缓冲区,不由lua控制初始化,避免漏掉vat的数据 */
    }
    else if(PLATFORM_PORT_ID_DEBUG == id)
    {   
        memset(debugStdoutBuffer, 0, sizeof(debugStdoutBuffer));
        debugStdoutCachedCount = 0;
    }    
    else
    {
        ret = uart_phy_open(id, baud, databits, parity, stopbits, mode, txDoneReport);
    }

    return ret;
}

/*+\NEW\liweiqiang\2013.4.20\增加uart.close接口 */
u32 platform_uart_close( unsigned id )
{
    u32 ret = PLATFORM_ERR;
    
    if(id < NUM_UART) //非特殊端口才可以关闭
    {
        return uart_phy_close(id);
    }

    return ret;
}
/*-\NEW\liweiqiang\2013.4.20\增加uart.close接口 */

u32 platform_s_uart_send( unsigned id, u8 data )
{
    u32 ret = 1;
    
    if(PLATFORM_UART_ID_ATC == id)
    {
        IVTBL(send_at_command)(&data, 1);
    }
    else if(PLATFORM_PORT_ID_DEBUG == id)
    {
/*+\NEW\liweiqiang\2013.4.7\优化debug口输出*/
        debugPortWrite(&data, 1);
/*-\NEW\liweiqiang\2013.4.7\优化debug口输出*/
    }
    else
    {
        return uart_phy_write(id, &data, 1);
    }

    return ret;
}

u32 platform_s_uart_sync_send( unsigned id, u8 data )
{
    u32 ret = 1;
    
    if(PLATFORM_UART_ID_ATC == id)
    {
        IVTBL(send_at_command)(&data, 1);
    }
    else if(PLATFORM_PORT_ID_DEBUG == id)
    {
/*+\NEW\liweiqiang\2013.4.7\优化debug口输出*/
        debugPortWrite(&data, 1);
/*-\NEW\liweiqiang\2013.4.7\优化debug口输出*/
    }
    else
    {
        return uart_phy_sync_write(id, &data, 1);
    }

    return ret;
}

/*+\NEW\liweiqiang\2013.4.7\修改uart数据发送为buffer方式 */
u32 platform_s_uart_send_buff( unsigned id, const u8 *buff, u16 len )
{
    u32 ret = len;
    
    if(PLATFORM_UART_ID_ATC == id)
    {
        IVTBL(send_at_command)((UINT8*)buff, len);
    }
    else if(PLATFORM_PORT_ID_DEBUG == id)
    {
        debugPortWrite(buff, len);
    }
    else
    {
        return uart_phy_write(id, (uint8 *)buff, len);
    }

    return ret;
}
/*-\NEW\liweiqiang\2013.4.7\修改uart数据发送为buffer方式 */

u32 platform_s_uart_sync_send_buff( unsigned id, const u8 *buff, u16 len )
{
    u32 ret = len;
    
    if(PLATFORM_UART_ID_ATC == id)
    {
        IVTBL(send_at_command)((UINT8*)buff, len);
    }
    else if(PLATFORM_PORT_ID_DEBUG == id)
    {
        debugPortWrite(buff, len);
    }
    else
    {
        return uart_phy_sync_write(id, (uint8 *)buff, len);
    }

    return ret;
}

/* 兼容旧版本的sleep接口 */
void platform_os_sleep(u32 ms)
{
    IVTBL(sleep)(ms *16384/1000);
}

int platform_s_uart_recv( unsigned id, s32 timeout )
{
    uint8 rcvdBuf[1];
    int rcvdLength = 0;
    
    if(PLATFORM_UART_ID_ATC == id)
    {
/*+\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */
        rcvdLength = vatc_read(rcvdBuf, 1, timeout);
/*-\NEW\liweiqiang\2014.4.12\优化对虚拟AT每次只读取一个字节的处理 */
    }
    else if(PLATFORM_PORT_ID_DEBUG == id)
    {
        // debug口读取直接堵塞挂起
        HANDLE hDebugPortReadSem = IVTBL(create_semaphore)(0);
        PUB_TRACE("[platform_s_uart_recv]: read from debug port, stop!");
        IVTBL(wait_semaphore)(hDebugPortReadSem, COS_WAIT_FOREVER);
        return -1;
    }
    else
    {
        rcvdLength = uart_phy_read(id, rcvdBuf, 1, timeout);
    }
    
    return rcvdLength ? rcvdBuf[0] : -1;
}

int platform_s_uart_set_flow_control( unsigned id, int type )
{
  return PLATFORM_ERR;
}

