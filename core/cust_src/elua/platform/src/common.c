/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    common.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/10
 *
 * Description:
 * 
 **************************************************************************/
 
#include "platform.h"
#include "platform_conf.h"
#include "type.h"
#include "genstd.h"
#include "common.h"
#include "buf.h"
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "elua_int.h"
#include "sermux.h"

#if defined( BUILD_LUA_INT_HANDLERS ) || defined( BUILD_C_INT_HANDLERS )
#define BUILD_INT_HANDLERS

#ifndef INT_TMR_MATCH
#define INT_TMR_MATCH         ELUA_INT_INVALID_INTERRUPT
#endif

extern const elua_int_descriptor elua_int_table[ INT_ELUA_LAST ];

#endif // #if defined( BUILD_LUA_INT_HANDLERS ) || defined( BUILD_C_INT_HANDLERS )

static void uart_send( int fd, char c )
{
  fd = fd;
  platform_uart_send( CON_UART_ID, c );
}

static int uart_recv( s32 to )
{
  return platform_uart_recv( CON_UART_ID, CON_TIMER_ID, to );
}

void cmn_platform_init()
{
#ifdef BUILD_INT_HANDLERS
  platform_int_init();
#endif

#if defined( CON_UART_ID ) 
    if(CON_UART_ID < SERMUX_SERVICE_ID_FIRST)
    {
        // Setup console UART
        platform_uart_setup( CON_UART_ID, CON_UART_SPEED, 8, PLATFORM_UART_PARITY_NONE, PLATFORM_UART_STOPBITS_1, 1, 0 );  
        //platform_uart_set_flow_control( CON_UART_ID, CON_FLOW_TYPE );
        //platform_uart_set_buffer( CON_UART_ID, CON_BUF_SIZE );
    }
#endif // #if defined( CON_UART_ID ) && CON_UART_ID < SERMUX_SERVICE_ID_FIRST

  // Set the send/recv functions                          
  std_set_send_func( uart_send );
  std_set_get_func( uart_recv );  
}

// ****************************************************************************
// PIO functions

int platform_pio_has_port( unsigned port )
{
  return port < NUM_PIO;
}

const char* platform_pio_get_prefix( unsigned port )
{
  static char c[ 3 ];
  
  sprintf( c, "P%c", ( char )( port + PIO_PREFIX ) );
  return c;
}

int platform_pio_has_pin( unsigned port, unsigned pin )
{
#if defined( PIO_PINS_PER_PORT )
  return port < NUM_PIO && pin < PIO_PINS_PER_PORT;
#elif defined( PIO_PIN_ARRAY )
  const u8 pio_port_pins[] = PIO_PIN_ARRAY;
  return port < NUM_PIO && pin < pio_port_pins[ port ];
#else
  #error "You must define either PIO_PINS_PER_PORT of PIO_PIN_ARRAY in platform_conf.h"
#endif
}

// ****************************************************************************
// CPU functions

u32 platform_cpu_get_frequency()
{
  return CPU_FREQUENCY;
}


// ****************************************************************************
// Interrupt support
#ifdef BUILD_INT_HANDLERS

int platform_cpu_set_interrupt( elua_int_id id, elua_int_resnum resnum, int status )
{
  elua_int_p_set_status ps;

  if( id < ELUA_INT_FIRST_ID || id > INT_ELUA_LAST )
    return PLATFORM_INT_INVALID;
  if( ( ps = elua_int_table[ id - ELUA_INT_FIRST_ID ].int_set_status ) == NULL )
    return PLATFORM_INT_NOT_HANDLED;
  if( id == INT_TMR_MATCH )
    return cmn_tmr_int_set_status( resnum, status );
  return ps( resnum, status );
}

int platform_cpu_get_interrupt( elua_int_id id, elua_int_resnum resnum )
{
  elua_int_p_get_status pg;

  if( id < ELUA_INT_FIRST_ID || id > INT_ELUA_LAST )
    return PLATFORM_INT_INVALID;
  if( ( pg = elua_int_table[ id - ELUA_INT_FIRST_ID ].int_get_status ) == NULL )
    return PLATFORM_INT_NOT_HANDLED;
  if( id == INT_TMR_MATCH )
    return cmn_tmr_int_get_status( resnum );
  return pg( resnum );
}

int platform_cpu_get_interrupt_flag( elua_int_id id, elua_int_resnum resnum, int clear )
{
  elua_int_p_get_flag pf;

  if( id < ELUA_INT_FIRST_ID || id > INT_ELUA_LAST )
    return PLATFORM_INT_INVALID;
  if( ( pf = elua_int_table[ id - ELUA_INT_FIRST_ID ].int_get_flag ) == NULL )
    return PLATFORM_INT_NOT_HANDLED;
  if( id == INT_TMR_MATCH )
    return cmn_tmr_int_get_flag( resnum, clear );
  return pf( resnum, clear );
}


// Common interrupt handling
void cmn_int_handler( elua_int_id id, elua_int_resnum resnum )
{
  elua_int_add( id, resnum );
#ifdef BUILD_C_INT_HANDLERS
  elua_int_c_handler phnd = elua_int_get_c_handler( id );
  if( phnd )
    phnd( resnum );
#endif
}

#endif // #ifdef BUILD_INT_HANDLERS

// ****************************************************************************
// Misc support

 unsigned int intlog2( unsigned int v )
 {
   unsigned r = 0;
 
   while (v >>= 1)
   {
     r++;
   }
   return r;
 }


