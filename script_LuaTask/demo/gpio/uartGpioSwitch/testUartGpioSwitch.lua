--- 模块功能：GPIO和UART切换功能测试
-- @author openLuat
-- @module gpio.testUartGpioSwitch
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"pins"

--uartuse：引脚当前是否做为uart功能使用，true表示是，其余的表示不是
local uartid,uartuse = 1,true
--[[
函数名：uartopn
功能  ：打开uart
参数  ：无
返回值：无
]]
local function uartopn()
    uart.setup(uartid,115200,8,uart.PAR_NONE,uart.STOP_1)    
end

--[[
函数名：uartclose
功能  ：关闭uart
参数  ：无
返回值：无
]]
local function uartclose()
    uart.close(uartid)
end

--[[
函数名：switchtouart
功能  ：切换到uart功能使用
参数  ：无
返回值：无
]]
local function switchtouart()
    log.info("switchtouart",uartuse)
    if not uartuse then
        --关闭gpio功能
        pins.close(pio.P0_1)
        pins.close(pio.P0_0)
        --打开uart功能
        uartopn()
        uartuse = true
    end
end

--[[
函数名：switchtogpio
功能  ：切换到gpio功能使用
参数  ：无
返回值：无
]]
local function switchtogpio()
    log.info("switchtogpio",uartuse)
    if uartuse then
        --关闭uart功能
        uartclose()
        pins.setup(pio.P0_1,1)
        pins.setup(pio.P0_0,0)
        uartuse = false
    end    
end

--[[
函数名：switch
功能  ：切换uart和gpio功能
参数  ：无
返回值：无
]]
local function switch()
    if uartuse then
        switchtogpio()
    else
        switchtouart()
    end
end

uartopn()
--循环定时器，5秒切换一次功能
sys.timerLoopStart(switch,5000)
