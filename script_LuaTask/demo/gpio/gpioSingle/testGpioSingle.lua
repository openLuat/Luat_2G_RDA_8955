--- 模块功能：GPIO功能测试.
-- @author openLuat
-- @module gpio.testGpioSingle
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"pins"


--[[
重要提醒!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

使用某些GPIO时，必须在脚本中写代码打开GPIO所属的电压域，配置电压输出输入等级，这些GPIO才能正常工作
必须在GPIO使用前(即调用pins.setup前)调用pmd.ldoset(电压等级,电压域类型)
电压等级与对应的电压如下：
0--关闭
1--1.8V
2--1.9V
3--2.0V
4--2.6V
5--2.8V
6--3.0V
7--3.3V
IO配置为输出时，高电平时的输出电压即为配置的电压等级对应的电压
IO配置为输入或者中断时，外设输入的高电平电压必须与配置的电压等级的电压匹配

电压域与控制的GPIO的对应关系如下：
pmd.LDO_VMMC：GPIO8、GPIO9、GPIO10、GPIO11、GPIO12、GPIO13
pmd.LDO_VLCD：GPIO14、GPIO15、GPIO16、GPIO17、GPIO18
pmd.LDO_VCAM：GPIO19、GPIO20、GPIO21、GPIO22、GPIO23、GPIO24
一旦设置了某一个电压域的电压等级，受该电压域控制的所有GPIO的高电平都与设置的电压等级一致

例如：GPIO8输出电平时，要求输出2.8V，则调用pmd.ldoset(5,pmd.LDO_VMMC)
]]

local level = 0
--GPIO1配置为输出，默认输出低电平，可通过setGpio1Fnc(0或者1)设置输出电平
local setGpio1Fnc = pins.setup(pio.P0_1,0)
sys.timerLoopStart(function()
    level = level==0 and 1 or 0
    setGpio1Fnc(level)
    log.info("testGpioSingle.setGpio1Fnc",level)
end,1000)

--GPIO5配置为输入，可通过getGpio5Fnc()获取输入电平
local getGpio5Fnc = pins.setup(pio.P0_5)
sys.timerLoopStart(function()
    log.info("testGpioSingle.getGpio5Fnc",getGpio5Fnc())
end,1000)
--GPIO上下拉配置(V0021版本后的lod才支持此功能)
if tonumber(string.match(rtos.get_version(),"Luat_V(%d+)_"))>=21 then
    pio.pin.setpull(pio.PULLUP,pio.P0_5)  --配置为上拉
    --pio.pin.setpull(pio.PULLDOWN,pio.P0_5)  --配置为下拉
    --pio.pin.setpull(pio.NOPULL,pio.P0_5)  --不配置上下拉
end


function gpio4IntFnc(msg)
    log.info("testGpioSingle.gpio4IntFnc",msg,getGpio4Fnc())
    --上升沿中断
    if msg==cpu.INT_GPIO_POSEDGE then
    --下降沿中断
    else
    end
end

--GPIO4配置为中断，可通过getGpio4Fnc()获取输入电平，产生中断时，自动执行gpio4IntFnc函数
getGpio4Fnc = pins.setup(pio.P0_4,gpio4IntFnc)
