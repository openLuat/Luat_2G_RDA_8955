require"pins"
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

TEST1={pin=pio.P0_7,dir=pio.INPUT,}
TEST2={pin=pio.P0_12,dir=pio.INPUT}
TEST3={pin=pio.P0_29,dir=pio.INPUT}
pmd.ldoset(5,pmd.LDO_VMMC)
pins.reg(TEST1,TEST2,TEST3)
local function pinget()
	print(1,pio.pin.getval(TEST1.pin))
	print(2,pio.pin.getval(TEST2.pin))
	print(3,pio.pin.getval(TEST3.pin))
end
--启动1秒的循环定时器，读取3个引脚的输入电平
sys.timer_loop_start(pinget,1000)

--打开下面的代码，GPIO悬空时为高电平

pio.pin.setpull(pio.PULLUP, TEST1.pin)
pio.pin.setpull(pio.PULLUP, TEST2.pin)
pio.pin.setpull(pio.PULLUP, TEST3.pin)

--打开下面的代码，GPIO悬空时为低电平
--[[
pio.pin.setpull(pio.PULLDOWN, TEST1.pin)
pio.pin.setpull(pio.PULLDOWN, TEST2.pin)
pio.pin.setpull(pio.PULLDOWN, TEST3.pin)
]]
--打开下面的代码，GPIO悬空时为不确定电平
--[[
pio.pin.setpull(pio.NOPULL, TEST1.pin)
pio.pin.setpull(pio.NOPULL, TEST2.pin)
pio.pin.setpull(pio.NOPULL, TEST3.pin)
]]