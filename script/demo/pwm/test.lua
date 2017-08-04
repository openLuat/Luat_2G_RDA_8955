--[[
模块名称：PWM测试
模块功能：测试PWM功能
模块最后修改时间：2017.07.31
注意：
1、支持2路PWM，仅支持输出功能
2、2路PWM复用的是uart2的tx和rx，如果使用了uart2的串口功能，则不能使用PWM；如果使用了PWM，则不能使用uart2的串口功能；
   串口功能或者PWM功能使用时，必须保证另外一个功能处于关闭状态，如果功能处于开启状态，可通过uart.close或者misc.closepwm接口关闭
]]
require"misc"
module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--[[
函数名：testpwm0
功能  ：PWM通道0输出测试
参数  ：无
返回值：无
]]
local function testpwm0()
	--频率1000Hz，1毫秒一个周期，每个周期内，高脉冲0.5毫秒，低脉冲0.5毫秒
	misc.openpwm(0,1000,50)
	--2分钟后关闭PWM0
	sys.timer_start(misc.closepwm,120000,0)
end

--[[
函数名：testpwm1
功能  ：PWM通道1输出测试
参数  ：无
返回值：无
]]
local function testpwm1()
	--1024毫秒一个周期，每个周期内，高脉冲110毫秒，低脉冲1024-110=914毫秒
	misc.openpwm(1,3,7)
	--2分钟后关闭PWM0
	sys.timer_start(misc.closepwm,120000,1)
end

testpwm0()
testpwm1()
