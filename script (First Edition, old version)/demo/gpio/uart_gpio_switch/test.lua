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
	print("switchtouart",uartuse)
	if not uartuse then
		--关闭gpio功能
		pio.pin.close(pio.P0_1)
		pio.pin.close(pio.P0_0)
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
	print("switchtogpio",uartuse)
	if uartuse then
		--关闭uart功能
		uartclose()
		--配置gpio方向
		pio.pin.setdir(pio.OUTPUT,pio.P0_1)
		pio.pin.setdir(pio.OUTPUT,pio.P0_0)
		--输出gpio电平
		pio.pin.setval(1,pio.P0_1)
		pio.pin.setval(0,pio.P0_0)
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
sys.timer_loop_start(switch,5000)
