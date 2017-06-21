module(...,package.seeall)

local i2cid = 1

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
函数名：init
功能  ：打开i2c，写初始化命令给从设备寄存器，并从从设备寄存器读取值
参数  ：无
返回值：无
]]
local function init()
	local i2cslaveaddr = 0x0E
	--注意，此处的i2cslaveaddr是7bit地址
	--底层在读操作时，自动将第一个字节的内容转换为(i2cslaveaddr << 1) | 0x01
	--底层在写操作时，自动将第一个字节的内容转换为(i2cslaveaddr << 1) | 0x00
	if i2c.setup(i2cid,i2c.SLOW,i2cslaveaddr) ~= i2c.SLOW then
		print("init fail")
		return
	end
	local cmd,i = {0x1B,0x00,0x6A,0x01,0x1E,0x20,0x21,0x04,0x1B,0x00,0x1B,0xDA,0x1B,0xDA}
	for i=1,#cmd,2 do
		i2c.write(i2cid,cmd[i],cmd[i+1])
		print("init",string.format("%02X",cmd[i]),string.format("%02X",string.byte(i2c.read(i2cid,cmd[i],1))))
	end
end

init()
--5秒后关闭i2c
sys.timer_start(i2c.close,5000,i2cid)
