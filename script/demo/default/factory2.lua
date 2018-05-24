--[[
模块名称：Luat软件提示功能
模块功能：每2秒通过串口输出"This is Luat software, not AT software, please check: wiki.openluat.com for more information!\n"的信息
模块最后修改时间：2018.03.09
]]

module(...,package.seeall)

require"pm"

local UART_ID = 2

--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
	local s
	while true do
		s = uart.read(UART_ID,"*l")
		if not s or string.len(s) == 0 then break end
		print("read bin",s)
		print("read hex",common.binstohexs(s))
	end
end

sys.reguart(UART_ID,read)
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
sys.timer_loop_start(uart.write,1000,UART_ID,"This is Luat software, not AT software, please check: wiki.openluat.com for more information!\n")
pm.wake("factory2")
