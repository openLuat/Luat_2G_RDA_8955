--- 模块功能：GPIO和I2C切换功能测试
-- @author openLuat
-- @module gpio.testI2cGpioSwitch
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"pins"


--i2cuse：引脚当前是否做为i2c功能使用，true表示是，其余的表示不是
local i2cid,i2cuse = 0,true
--[[
函数名：i2copn
功能  ：打开i2c
参数  ：无
返回值：无
]]
local function i2copn()
    --第三个地址参数0x15只是一个例子，实际使用时由外围设备决定
    if i2c.setup(i2cid,i2c.SLOW,0x15) ~= i2c.SLOW then
        log.info("i2copn fail")
    end
end

--[[
函数名：i2close
功能  ：关闭i2c
参数  ：无
返回值：无
]]
local function i2close()
    i2c.close(i2cid)
end

--[[
函数名：switchtoi2c
功能  ：切换到i2c功能使用
参数  ：无
返回值：无
]]
local function switchtoi2c()
    log.info("switchtoi2c",i2cuse)
    if not i2cuse then
        --关闭gpio功能
        pins.close(pio.P0_6)
        pins.close(pio.P0_7)
        --打开i2c功能
        i2copn()
        i2cuse = true
    end
end

--[[
函数名：switchtogpio
功能  ：切换到gpio功能使用
参数  ：无
返回值：无
]]
local function switchtogpio()
    log.info("switchtogpio",i2cuse)
    if i2cuse then
        --关闭i2c功能
        i2close()
        pins.setup(pio.P0_6,1)
        pins.setup(pio.P0_7,0)
        i2cuse = false
    end    
end

--[[
函数名：switch
功能  ：切换i2c和gpio功能
参数  ：无
返回值：无
]]
local function switch()
    if i2cuse then
        switchtogpio()
    else
        switchtoi2c()
    end
end

i2copn()
--循环定时器，5秒切换一次功能
sys.timerLoopStart(switch,5000)
