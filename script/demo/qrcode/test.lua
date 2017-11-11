module(...,package.seeall)
require"qrcode"
require"string"

WIDTH,HEIGHT,BPP = disp.getlcdinfo()
--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

function test_once()
	local buf,w,h,isfix = qrcode.create("www.baidu.com1234567890",WIDTH,HEIGHT)
	print(buf,#buf, w,h,isfix)
	disp.setbkcolor(0xffff)
	disp.clear()
	qrcode.display(buf,w,h,(WIDTH - w)/2,(HEIGHT - h)/2,0)
	disp.update()
end

sys.timer_start(test_once, 5000)