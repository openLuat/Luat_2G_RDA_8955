
#include <string.h>

#include "rda_pal.h"
#include "platform.h"
#include "platform_conf.h"

static const E_AMOPENAT_I2C_PORT i2cIdMap[OPENAT_I2C_QTY] =
{
    OPENAT_I2C_1, //id = 0
    OPENAT_I2C_2, //id = 1
    OPENAT_I2C_3, //id = 2
};

static u16 i2cSlaveAddr[OPENAT_I2C_QTY];

int platform_i2c_exists( unsigned id ) 
{
    if(id != 1) // 仅支持I2C 2
        return PLATFORM_ERR;

    return PLATFORM_OK;
}

int platform_i2c_setup( unsigned id, PlatformI2CParam *pParam ) 
{
    T_AMOPENAT_I2C_PARAM openatI2CParam;
    BOOL ret;

    memset(&openatI2CParam, 0, sizeof(openatI2CParam));

    openatI2CParam.freq = pParam->speed;
    i2cSlaveAddr[id] = pParam->slaveAddr;
    
    ret = IVTBL(open_i2c)(i2cIdMap[id], &openatI2CParam);
    
    return ret ? pParam->speed : 0;
}

int platform_i2c_close( unsigned id) 
{
    return IVTBL(close_i2c)(i2cIdMap[id]);
}

int platform_i2c_send_data( unsigned id, u16 slave_addr, const u8 *pRegAddr, const u8 *buf, u32 len )
{
    // 如果传输的从地址为空 则使用预设的从地址
    if(slave_addr == I2C_NULL_SLAVE_ADDR) {
        slave_addr = i2cSlaveAddr[id];
    }

    // 如果从地址为空,则返回传输失败
    if(slave_addr == I2C_NULL_SLAVE_ADDR){
        return 0;
    }
    
    return IVTBL(write_i2c)(i2cIdMap[id], slave_addr, pRegAddr, buf, len);
}

int platform_i2c_recv_data( unsigned id, u16 slave_addr, const u8 *pRegAddr, u8 *buf, u32 len  )
{
    // 如果传输的从地址为空 则使用预设的从地址
    if(slave_addr == I2C_NULL_SLAVE_ADDR) {
        slave_addr = i2cSlaveAddr[id];
    }

    // 如果从地址为空,则返回传输失败
    if(slave_addr == I2C_NULL_SLAVE_ADDR){
        return 0;
    }
    
    return IVTBL(read_i2c)(i2cIdMap[id], slave_addr, pRegAddr, buf, len);
}

