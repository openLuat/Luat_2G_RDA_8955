/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/8
 *
 * Description:
 * 
 **************************************************************************/

#include "assert.h"
#include "rda_pal.h"

#include "platform.h"
#include "platform_malloc.h"
#include "platform_conf.h"
#include "common.h"

#if defined( BUILD_LUA_INT_HANDLERS ) || defined( BUILD_C_INT_HANDLERS )
#define BUILD_INT_HANDLERS

#ifndef INT_TMR_MATCH
#define INT_TMR_MATCH         ELUA_INT_INVALID_INTERRUPT
#endif

extern const elua_int_descriptor elua_int_table[ INT_ELUA_LAST ];

#endif // #if defined( BUILD_LUA_INT_HANDLERS ) || defined( BUILD_C_INT_HANDLERS )

static const E_AMOPENAT_GPIO_PORT openatGPIOEx[PIO_PIN_EX] = 
{
    OPENAT_GPIO_32,
    OPENAT_GPIO_33,
    OPENAT_GPIO_34,
    OPENAT_GPIO_35,
    OPENAT_GPIO_36,
};

static unsigned char luaConsolePort = 0;

int platform_init(void)
{
    cmn_platform_init();
    
    return PLATFORM_OK;
}

// ****************************************************************************
// Timer

void platform_s_timer_delay( unsigned id, u32 delay_us )
{
    ASSERT(0);
}
      
u32 platform_s_timer_op( unsigned id, int op, u32 data )
{
  u32 res = 0;
  
  switch( op )
  {
    case PLATFORM_TIMER_OP_START:
    case PLATFORM_TIMER_OP_READ:
    case PLATFORM_TIMER_OP_GET_MAX_DELAY:
    case PLATFORM_TIMER_OP_GET_MIN_DELAY:
    case PLATFORM_TIMER_OP_SET_CLOCK:
    case PLATFORM_TIMER_OP_GET_CLOCK:
      break;
  }
  return res;
}

// ****************************************************************************
// PIO functions
/*+\NEW\liweiqiang\2014.7.21\修正EXIO上报的中断RESNUM错误*/
unsigned int platform_get_pio_pin(E_AMOPENAT_GPIO_PORT openat_gpio)
{
    unsigned int pio_port_pin = PLATFORM_IO_UNKNOWN_PIN;
    
    if(openat_gpio >= OPENAT_GPIO_0 && openat_gpio <= OPENAT_GPIO_31)
    {
        pio_port_pin = PLATFORM_IO_ENCODE(0, openat_gpio - OPENAT_GPIO_0, 0);
    }
    else
    {
        int pin;

        for(pin = 0; pin < PIO_PIN_EX; pin++){
            if(openatGPIOEx[pin] == openat_gpio){
                pio_port_pin = PLATFORM_IO_ENCODE(1, pin, 0);
                break;
            }
        }
    }
    return pio_port_pin;
}
/*-\NEW\liweiqiang\2014.7.21\修正EXIO上报的中断RESNUM错误*/

/*+\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
static void GpioIntCallback(E_OPENAT_DRV_EVT evt, unsigned int gpioNum,unsigned char state)
{
/*+\NEW\liweiqiang\2014.7.21\修正EXIO上报的中断RESNUM错误*/
    unsigned int pio_port_pin = platform_get_pio_pin(gpioNum);

    if(PLATFORM_IO_UNKNOWN_PIN != pio_port_pin)
    {
        PlatformMessage *pMsg = platform_malloc(sizeof(PlatformMessage));
        
        pMsg->id = RTOS_MSG_INT;
        
        if(state)
            pMsg->data.interruptData.id = INT_GPIO_POSEDGE;
        else
            pMsg->data.interruptData.id = INT_GPIO_NEGEDGE;
        
        pMsg->data.interruptData.resnum = pio_port_pin;
        
        platform_rtos_send(pMsg);
    }
/*-\NEW\liweiqiang\2014.7.21\修正EXIO上报的中断RESNUM错误*/
}
/*-\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/

/*+\NEW\liweiqiang\2013.8.16\增加gpio ex控制接口*/
static E_AMOPENAT_GPIO_PORT get_real_gpio(int port, int pin)
{
    E_AMOPENAT_GPIO_PORT realGpio = OPENAT_GPIO_UNKNOWN;

    switch(port)
    {
        case 0:
            realGpio = OPENAT_GPIO_0+pin;
            break;
            
        case 1:
            realGpio = openatGPIOEx[pin];
            break;

        default:
            break;
    }

    return realGpio;
}
/*-\NEW\liweiqiang\2013.8.16\增加gpio ex控制接口*/

pio_type platform_pio_op( unsigned port, pio_type pinmask, int op )
{
    pio_type retval = 1;
    int pin_index;
    int total_pins;
    static const u8 pio_port_pins[] = PIO_PIN_ARRAY;
    T_AMOPENAT_GPIO_CFG cfg;
    E_AMOPENAT_GPIO_PORT realGpio;

/*+\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
    if(op == PLATFORM_IO_PIN_DIR_INT)
    {
        if(port == 1 || (port == 0 && (pinmask&~0xff)))// 仅支持GPIO 0~7设置为中断
        {
            // gpo cannot be set input
            PUB_TRACE("[platform_pio_op]: error!set port.pin %d.0x%x dir input int", port, pinmask);
            return 0;
        }
    }
/*-\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
    
    total_pins = pio_port_pins[port];

    //PUB_TRACE("[platform_pio_op]:  port_pin %d_%d %d", port, pin_index, total_pins);

    for(pin_index = 0; pin_index < total_pins; pin_index++)
    {
        if((pinmask&(1<<pin_index)) != 0)
        {
            if((realGpio = get_real_gpio(port, pin_index)) == OPENAT_GPIO_UNKNOWN)
            {
                PUB_TRACE("[platform_pio_op]: error! port_pin %d_%d not exist!", port, pin_index);
                return 0;
            }
            
            switch( op )
            {
                /*+\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
                case PLATFORM_IO_PIN_DIR_INT:                    
                    cfg.mode = OPENAT_GPIO_INPUT_INT;
                    cfg.param.intCfg.debounce = 20;
                    cfg.param.intCfg.intType = OPENAT_GPIO_INT_BOTH_EDGE;
                    cfg.param.intCfg.intCb = GpioIntCallback;
                    retval = IVTBL(config_gpio)(realGpio, &cfg);
                    break;
                /*-\NEW\liweiqiang\2013.4.5\增加lua gpio 中断配置*/
                    
                case PLATFORM_IO_PIN_DIR_INPUT:
                    cfg.mode = OPENAT_GPIO_INPUT;
                    retval = IVTBL(config_gpio)(realGpio, &cfg);
                    break;
                
                case PLATFORM_IO_PIN_DIR_OUTPUT:
                /*+\NewReq 增加GPIO输出配置1，默认拉高\zhutianhua\2014.10.22\增加GPIO输出配置1，默认拉高*/
                case PLATFORM_IO_PIN_DIR_OUTPUT1:
                /*-\NewReq 增加GPIO输出配置1，默认拉高\zhutianhua\2014.10.22\增加GPIO输出配置1，默认拉高*/
                    cfg.mode = OPENAT_GPIO_OUTPUT;
                    /*+\NewReq 增加GPIO输出配置1，默认拉高\zhutianhua\2014.10.22\增加GPIO输出配置1，默认拉高*/
                    cfg.param.defaultState = op - PLATFORM_IO_PIN_DIR_OUTPUT;
                    /*-\NewReq 增加GPIO输出配置1，默认拉高\zhutianhua\2014.10.22\增加GPIO输出配置1，默认拉高*/
                    retval = IVTBL(config_gpio)(realGpio, &cfg);
                    break;
                    
                case PLATFORM_IO_PIN_SET:
                    retval = IVTBL(set_gpio)(realGpio, 1);
                    break;
                        
                case PLATFORM_IO_PIN_CLEAR:
                    retval = IVTBL(set_gpio)(realGpio, 0);
                    break;
            
                case PLATFORM_IO_PIN_GET:
                {
                    UINT8 gpioValue = 0xff;
                    retval = IVTBL(read_gpio)(realGpio, &gpioValue);
                    // 对于读取操作 一次只能读取一个pin
                    return retval == TRUE ? gpioValue : 0xff;
                    break;
                }

/*+\NEW\liweiqiang\2013.4.11\增加pio.pin.close接口*/
                case PLATFORM_IO_PIN_CLOSE:
                    retval = IVTBL(close_gpio)(realGpio);
                    break;
/*-\NEW\liweiqiang\2013.4.11\增加pio.pin.close接口*/
            
                // not support
                case PLATFORM_IO_PORT_DIR_INPUT:
                case PLATFORM_IO_PORT_DIR_OUTPUT:
                case PLATFORM_IO_PORT_SET_VALUE:
                case PLATFORM_IO_PORT_GET_VALUE:
            
                case PLATFORM_IO_PIN_PULLUP:
                case PLATFORM_IO_PIN_PULLDOWN:
                case PLATFORM_IO_PIN_NOPULL:
                default:
                    retval = 0;
                    break;
            }

        /*+\NEW\liweiqiang\2015.1.9\优化只操作一个IO时的处理*/
            // 只操作一个io可以立即返回
            if ((pinmask&~(1<<pin_index)) == 0){
                break;
            }
        /*-\NEW\liweiqiang\2015.1.9\优化只操作一个IO时的处理*/
        }
    }

    return retval;
}

E_AMOPENAT_GPIO_PORT platform_pio_get_gpio_port(int port_pin)
{
    int port, pin;

/*+\NEW\2013.4.10\增加黑白屏显示支持 */
    if(port_pin == PLATFORM_IO_UNKNOWN_PIN)
        return OPENAT_GPIO_UNKNOWN;
/*-\NEW\2013.4.10\增加黑白屏显示支持 */
    
    port = PLATFORM_IO_GET_PORT(port_pin);
    pin = PLATFORM_IO_GET_PIN(port_pin);

    // 不去判断有效值,总是认为通过lua脚本Px_x转换过来的已经经过有效范围检验

    return get_real_gpio(port, pin);
}

// ****************************************************************************
int platform_cpu_set_global_interrupts( int status )
{
    return 0;
}

int platform_cpu_get_global_interrupts()
{
    return 0;
}

/*+\NEW\liweiqiang\2013.7.1\作长时间运算时自动调节主频加快运算速度*/
void platform_sys_set_max_freq(void)
{
    IVTBL(sys_request_freq)(OPENAT_SYS_FREQ_312M);
}

void platform_sys_set_min_freq(void)
{
    IVTBL(sys_request_freq)(OPENAT_SYS_FREQ_32K);
}
/*-\NEW\liweiqiang\2013.7.1\作长时间运算时自动调节主频加快运算速度*/

//console
void platform_set_console_port( unsigned char id )
{
    luaConsolePort = id;
}

unsigned char platform_get_console_port(void)
{
    return luaConsolePort;
}

/*+\NEW\liweiqiang\2013.6.6\增加adc库*/
// adc
int platform_adc_exists( unsigned id ) 
{
    return id < OPENAT_ADC_QTY;
}

int platform_adc_open(unsigned id)
{
    return IVTBL(init_adc)(id) ? PLATFORM_OK : PLATFORM_ERR;
}

int platform_adc_read(unsigned id, int *adc, int *volt)
{
    u16 adcVal = 0xFFFF;
    u16 voltVal = 0xFFFF;
    BOOL ret;

    ret = IVTBL(read_adc)(id, &adcVal, &voltVal);

    *adc = adcVal;
    *volt = voltVal;
    
    return ret ? PLATFORM_OK : PLATFORM_ERR;
}
/*-\NEW\liweiqiang\2013.6.6\增加adc库*/

