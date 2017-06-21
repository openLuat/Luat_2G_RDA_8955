require"pincfg"
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

-------------------------PIN8测试开始-------------------------
local pin8flg = true
--[[
函数名：pin8set
功能  ：设置PIN8引脚的输出电平，1秒反转一次
参数  ：无
返回值：无
]]
local function pin8set()
	pins.set(pin8flg,pincfg.PIN8)
	pin8flg = not pin8flg
end
--启动1秒的循环定时器，设置PIN8引脚的输出电平
sys.timer_loop_start(pin8set,1000)
-------------------------PIN8测试结束-------------------------


-------------------------PIN9测试开始-------------------------
local pin9flg = true
--[[
函数名：pin9set
功能  ：设置PIN9引脚的输出电平，1秒反转一次
参数  ：无
返回值：无
]]
local function pin9set()
	pins.set(pin9flg,pincfg.PIN9)
	pin9flg = not pin9flg
end
--启动1秒的循环定时器，设置PIN9引脚的输出电平
sys.timer_loop_start(pin9set,1000)
-------------------------PIN9测试结束-------------------------


-------------------------PIN28测试开始-------------------------
--[[
函数名：pin28get
功能  ：读取PIN28引脚的输入电平
参数  ：无
返回值：无
]]
local function pin28get()
	local v = pins.get(pincfg.PIN28)
	print("pin28get",v and "low" or "high")
end
--启动1秒的循环定时器，读取PIN28引脚的输入电平
sys.timer_loop_start(pin28get,1000)
-------------------------PIN28测试结束-------------------------
