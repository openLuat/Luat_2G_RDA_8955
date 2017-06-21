// coolsand interrupt support

// Platform-specific headers
#include "rda_pal.h"
#include <stdio.h>

// Generic headers
#include "platform.h"
#include "platform_conf.h"
#include "elua_int.h"
#include "common.h"

#ifndef VTMR_TIMER_ID
#define VTMR_TIMER_ID         ( -1 )
#endif

/*+\NEW\lifei\2012.01.23\解决编译warning*/
#if 0
//支持中断的GPIO id
static const HAL_GPIO_GPO_ID_T validGpioIntId[] = 
{
    HAL_GPIO_NONE, HAL_GPIO_1, HAL_GPIO_2, HAL_GPIO_3, 
    HAL_GPIO_NONE, HAL_GPIO_NONE, HAL_GPIO_NONE, HAL_GPIO_7 
};

static HAL_GPIO_GPO_ID_T resnumToGpioId(elua_int_resnum resnum)
{
    HAL_GPIO_GPO_ID_T gpioId = HAL_GPIO_NONE;

    if(resnum < sizeof(validGpioIntId)/sizeof(validGpioIntId[0]))
    {
        gpioId = validGpioIntId[resnum];
    }

    return gpioId;
}
static elua_int_resnum gpioIdToResnum(HAL_GPIO_GPIO_ID_T gpioId)
{
    u16 port = 0;
    u16 pin;

    for(pin = 0; pin < sizeof(validGpioIntId)/sizeof(validGpioIntId[0]); pin++)
    {
        if(validGpioIntId[pin] == gpioId)
        {
            return PLATFORM_IO_ENCODE(port, pin, 0);
        }
    }

    return PLATFORM_INT_BAD_RESNUM;
}

// ****************************************************************************
// Interrupt handlers
static void dm_GpioIntHandler(HAL_GPIO_GPO_ID_T id)
{
    elua_int_id int_id;
    
    if(hal_GpioGet(id))
    {
        int_id = INT_GPIO_POSEDGE;
    }
    else
    {
        int_id = INT_GPIO_NEGEDGE;
    }
    
    cmn_int_handler( int_id, gpioIdToResnum(id) );
}

static void dm_Gpio1DetectHandler(void)
{
    dm_GpioIntHandler(HAL_GPIO_1);
}

static void dm_Gpio2DetectHandler(void)
{
    dm_GpioIntHandler(HAL_GPIO_2);
}

static void dm_Gpio3DetectHandler(void)
{
    dm_GpioIntHandler(HAL_GPIO_3);
}

static void dm_Gpio7DetectHandler(void)
{
    dm_GpioIntHandler(HAL_GPIO_7);
}
#endif
/*-\NEW\lifei\2012.01.23\解决编译warning*/


// ****************************************************************************
// GPIO helper functions

static int gpioh_get_int_status( elua_int_id id, elua_int_resnum resnum )
{
#if 0    
    int temp;
    u32 mask;
    HAL_GPIO_GPO_ID_T gpioId;

    if((gpioId = resnumToGpioId(resnum)) == HAL_GPIO_NONE)
        return PLATFORM_INT_BAD_RESNUM;

    if(id == INT_GPIO_POSEDGE)
    {
        
    }
    else
    {
        
    }
#endif

    return 0;
}

static int gpioh_set_int_status( elua_int_id id, elua_int_resnum resnum, int status )
{
  return 0;
}

static int gpioh_get_int_flag( elua_int_id id, elua_int_resnum resnum, int clear )
{
  return 0;
}

// ****************************************************************************
// Interrupt: INT_GPIO_POSEDGE

static int int_gpio_posedge_set_status( elua_int_resnum resnum, int status )
{
  return gpioh_set_int_status( INT_GPIO_POSEDGE, resnum, status );
}

static int int_gpio_posedge_get_status( elua_int_resnum resnum )
{
  return gpioh_get_int_status( INT_GPIO_POSEDGE, resnum );
}

static int int_gpio_posedge_get_flag( elua_int_resnum resnum, int clear )
{
  return gpioh_get_int_flag( INT_GPIO_POSEDGE, resnum, clear );
}

// ****************************************************************************
// Interrupt: INT_GPIO_NEGEDGE

static int int_gpio_negedge_set_status( elua_int_resnum resnum, int status )
{
  return gpioh_set_int_status( INT_GPIO_NEGEDGE, resnum, status );
}

static int int_gpio_negedge_get_status( elua_int_resnum resnum )
{
  return gpioh_get_int_status( INT_GPIO_NEGEDGE, resnum );
}

static int int_gpio_negedge_get_flag( elua_int_resnum resnum, int clear )
{
  return gpioh_get_int_flag( INT_GPIO_NEGEDGE, resnum, clear );
}

// ****************************************************************************
// Interrupt initialization

void platform_int_init(void)
{
    /*+\NEW\lifei\2012.01.23\解决编译warning*/
/* 屏蔽固定的IO中断初始化代码,后续修改为根据用户pio setup实际需要再进行初始化 */
#if 0
    HAL_GPIO_CFG_T gpioCfg;

    gpioCfg.direction = HAL_GPIO_DIRECTION_INPUT;
    gpioCfg.irqHandler = dm_Gpio1DetectHandler;
    gpioCfg.irqMask.rising = TRUE;
    gpioCfg.irqMask.falling = TRUE;
    gpioCfg.irqMask.debounce = TRUE;
    gpioCfg.irqMask.level = FALSE;
    hal_GpioOpen(HAL_GPIO_1, &gpioCfg);

    gpioCfg.irqHandler = dm_Gpio2DetectHandler;
    hal_GpioOpen(HAL_GPIO_2, &gpioCfg);

    gpioCfg.irqHandler = dm_Gpio3DetectHandler;
    hal_GpioOpen(HAL_GPIO_3, &gpioCfg);

    gpioCfg.irqHandler = dm_Gpio7DetectHandler;
    hal_GpioOpen(HAL_GPIO_7, &gpioCfg);
#endif   
    /*-\NEW\lifei\2012.01.23\解决编译warning*/ 
}

// ****************************************************************************
// Interrupt table
// Must have a 1-to-1 correspondence with the interrupt enum in platform_conf.h!

const elua_int_descriptor elua_int_table[ INT_ELUA_LAST ] = 
{
  { int_gpio_posedge_set_status, int_gpio_posedge_get_status, int_gpio_posedge_get_flag },
  { int_gpio_negedge_set_status, int_gpio_negedge_get_status, int_gpio_negedge_get_flag },
};

