--- 模块功能：I2C功能测试.
-- @author openLuat
-- @module i2c.testI2c
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

require"utils"

local i2cid = 2

--[[
函数名：init
功能  ：打开i2c，写初始化命令给从设备寄存器，并从从设备寄存器读取值
参数  ：无
返回值：无
说明  : 此函数演示setup、send和recv接口的使用方式
]]
local function init()
    local i2cslaveaddr = 0x0E
    --注意：此处的i2cslaveaddr是7bit地址
    --如果i2c外设手册中给的是8bit地址，需要把8bit地址右移1位，赋值给i2cslaveaddr变量
    --如果i2c外设手册中给的是7bit地址，直接把7bit地址赋值给i2cslaveaddr变量即可
    --发起一次读写操作时，启动信号后的第一个字节是命令字节
    --命令字节的bit0表示读写位，0表示写，1表示读
    --命令字节的bit7-bit1,7个bit表示外设地址
    --i2c底层驱动在读操作时，用 (i2cslaveaddr << 1) | 0x01 生成命令字节
    --i2c底层驱动在写操作时，用 (i2cslaveaddr << 1) | 0x00 生成命令字节
    if i2c.setup(i2cid,i2c.SLOW) ~= i2c.SLOW then
        print("testI2c.init fail")
        return
    end
    local cmd,i = {0x1B,0x00,0x6A,0x01,0x1E,0x20,0x21,0x04,0x1B,0x00,0x1B,0xDA,0x1B,0xDA}
    for i=1,#cmd,2 do
        --向从设备i2cslaveaddr发送寄存器地址cmd[i]
        i2c.send(i2cid,i2cslaveaddr,cmd[i])
        --向从设备i2cslaveaddr发送要写入从设备寄存器内的数据cmd[i+1]
        i2c.send(i2cid,i2cslaveaddr,cmd[i+1])
        
        --向从设备i2cslaveaddr发送寄存器地址cmd[i]
        i2c.send(i2cid,i2cslaveaddr,cmd[i])
        --读取从设备i2cslaveaddr寄存器内的1个字节的数据，并且打印出来
        print("testI2c.init",string.format("%02X",cmd[i]),string.toHex(i2c.recv(i2cid,i2cslaveaddr,1)))
    end
end

--[[
函数名：init1
功能  ：打开i2c，写初始化命令给从设备寄存器，并从从设备寄存器读取值
参数  ：无
返回值：无
说明  : 此函数演示setup、write和read接口的使用方式
]]
local function init1()
    local i2cslaveaddr = 0x0E
    --注意：此处的i2cslaveaddr是7bit地址
    --如果i2c外设手册中给的是8bit地址，需要把8bit地址右移1位，赋值给i2cslaveaddr变量
    --如果i2c外设手册中给的是7bit地址，直接把7bit地址赋值给i2cslaveaddr变量即可
    --发起一次读写操作时，启动信号后的第一个字节是命令字节
    --命令字节的bit0表示读写位，0表示写，1表示读
    --命令字节的bit7-bit1,7个bit表示外设地址
    --i2c底层驱动在读操作时，用 (i2cslaveaddr << 1) | 0x01 生成命令字节
    --i2c底层驱动在写操作时，用 (i2cslaveaddr << 1) | 0x00 生成命令字节
    if i2c.setup(i2cid,i2c.SLOW,i2cslaveaddr) ~= i2c.SLOW then
        print("testI2c.init1 fail")
        return
    end
    local cmd,i = {0x1B,0x00,0x6A,0x01,0x1E,0x20,0x21,0x04,0x1B,0x00,0x1B,0xDA,0x1B,0xDA}
    for i=1,#cmd,2 do
        --向从设备的寄存器地址cmd[i]中写1字节的数据cmd[i+1]
        i2c.write(i2cid,cmd[i],cmd[i+1])
        --从从设备的寄存器地址cmd[i]中读1字节的数据，并且打印出来
        print("testI2c.init1",string.format("%02X",cmd[i]),string.toHex(i2c.read(i2cid,cmd[i],1)))
    end
end

--如下一行代码，表示是否启用i2c id复用功能，0表示不启用，1表示启用，默认启用
--如果启用了i2c id复用功能，i2c id 0和2都表示i2c3
--如果不启用i2c id复用功能，i2c id 0、1、2分别表示i2c1、i2c2、i2c3
--仅0033以及以后的core才支持“此复用功能设置”以及“i2c1和i2c2的功能”
--i2c.set_id_dup(0)
--init和init1接口演示了两套i2c软件接口的使用方式
--init()
init1()
--5秒后关闭i2c
sys.timerStart(i2c.close,5000,i2cid)
