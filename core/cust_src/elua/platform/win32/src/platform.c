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

#include <stdio.h>
#include <windows.h>
#include "win_msg.h"
#include <assert.h>

#include "platform.h"
#include "platform_i2c.h"
#include "platform_rtos.h"
#include "platform_conf.h"
#include "common.h"
#include "genstd.h"
#include "devman.h"

#if defined( BUILD_LUA_INT_HANDLERS ) || defined( BUILD_C_INT_HANDLERS )
#define BUILD_INT_HANDLERS

#ifndef INT_TMR_MATCH
#define INT_TMR_MATCH         ELUA_INT_INVALID_INTERRUPT
#endif

extern const elua_int_descriptor elua_int_table[ INT_ELUA_LAST ];

#endif // #if defined( BUILD_LUA_INT_HANDLERS ) || defined( BUILD_C_INT_HANDLERS )

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


int platform_cpu_set_global_interrupts( int status )
{
    return 0;
}

int platform_cpu_get_global_interrupts()
{
    return 0;
}

void platform_sendsound_end(void)
{
    //strcat(atcbuff,"+DTMFDET:69\r\n");
}

/* 兼容旧版本的sleep接口 */
void platform_os_sleep(u32 ms)
{
    Sleep(ms);
}

void platform_assert(const char *func, int line)
{
    #include <ASSERT.H>
    _assert("platform_assert",func,line);
}

void std_set_send_func( p_std_send_char pfunc ){}
void std_set_get_func( p_std_get_char pfunc ){}

int dm_register( const DM_DEVICE *pdev ){return PLATFORM_OK;}

const DM_DEVICE* platform_fs_init(void) {return NULL;}

int dm_init() {return 0;}

//console
static unsigned char luaConsolePort = 0;
void platform_set_console_port( unsigned char id )
{
    luaConsolePort = id;
}

unsigned char platform_get_console_port(void)
{
    return luaConsolePort;
}

int platform_i2c_exists( unsigned id ) 
{
    if(id != 1) 
        return PLATFORM_ERR;

    return PLATFORM_OK;
}

int platform_i2c_setup( unsigned id, PlatformI2CParam *pParam ) 
{
    return pParam->speed;
}

int platform_i2c_close( unsigned id ) 
{
    return PLATFORM_OK;
}

int platform_i2c_send_data( unsigned id, u16 slave_addr, const u8 *pRegAddr, const u8 *buf, u32 len )
{
    return PLATFORM_OK;
}

int platform_i2c_recv_data( unsigned id, u16 slave_addr, const u8 *pRegAddr, u8 *buf, u32 len  )
{
    u32 i;
    for(i = 0; i < len; i++)
    {
        buf[i] = i;
    }

    return len;
}

int platform_adc_exists( unsigned id ) 
{
    return id < NUM_ADC;
}

int platform_adc_open(unsigned id)
{
    return PLATFORM_OK;
}

int platform_adc_read(unsigned id, int *adc, int *volt)
{
    *adc = 523;
    *volt = 3800;
    return PLATFORM_OK;
}

