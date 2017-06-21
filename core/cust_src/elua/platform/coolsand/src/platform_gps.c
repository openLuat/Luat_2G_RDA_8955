/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_gps.c
 * Author:  zhutianhua
 * Version: V0.1
 * Date:    2014/8/6
 *
 * Description:
 *          lua gpscore平台接口实现
 **************************************************************************/

#include <stdio.h>
#include <string.h>
#include "rda_pal.h"

#include "platform.h"
#include "platform_gps.h"

int platform_gps_open(void){    
    T_AMOPENAT_RDAGPS_PARAM cfg;

    cfg.gps.pinPowerOnPort = OPENAT_GPIO_7;
    cfg.gps.pinResetPort = OPENAT_GPIO_UNKNOWN;
//    cfg.gps.pinBpWakeupGpsPort = OPENAT_GPO_0;
    cfg.gps.pinBpWakeupGpsPolarity = FALSE;
    cfg.gps.pinGpsWakeupBpPort = OPENAT_GPIO_1;
    cfg.gps.pinGpsWakeupBpPolarity = FALSE;

    cfg.i2c.port = OPENAT_I2C_2;
    /*cfg.i2c.cfg.slaveAddr = 0;
    cfg.i2c.cfg.regAddrBytes = 0;
    cfg.i2c.cfg.noAck = FALSE;
    cfg.i2c.cfg.noStop = FALSE;
    cfg.i2c.cfg.i2cMessage = NULL;*/

    PUB_TRACE("[platform_gps_open]");
    IVTBL(poweron_ldo)(OPENAT_LDO_POWER_ASW, 1);
    IVTBL(rdaGps_open)(&cfg);
    return PLATFORM_OK;
}

int platform_gps_close(void){
    T_AMOPENAT_RDAGPS_PARAM cfg;

    cfg.gps.pinPowerOnPort = OPENAT_GPIO_7;
    cfg.gps.pinResetPort = OPENAT_GPIO_UNKNOWN;
//    cfg.gps.pinBpWakeupGpsPort = OPENAT_GPO_0;
    cfg.gps.pinBpWakeupGpsPolarity = FALSE;
    cfg.gps.pinGpsWakeupBpPort = OPENAT_GPIO_1;
    cfg.gps.pinGpsWakeupBpPolarity = FALSE;

    cfg.i2c.port = OPENAT_I2C_2;
    IVTBL(rdaGps_close)(&cfg);
    IVTBL(poweron_ldo)(OPENAT_LDO_POWER_ASW, 0);
    return PLATFORM_OK;
}


