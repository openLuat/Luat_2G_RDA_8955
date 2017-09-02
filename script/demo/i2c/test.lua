module(...,package.seeall)

local i2cid = 2

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
	--注意：此处的i2cslaveaddr是7bit地址
	--如果i2c外设手册中给的是8bit地址，需要把8bit地址右移1位，赋值给i2cslaveaddr变量
	--如果i2c外设手册中给的是7bit地址，直接把7bit地址赋值给i2cslaveaddr变量即可
	--发起一次读写操作时，启动信号后的第一个字节是命令字节
	--命令字节的bit0表示读写位，0表示写，1表示读
	--命令字节的bit7-bit1,7个bit表示外设地址
	--i2c底层驱动在读操作时，用 (i2cslaveaddr << 1) | 0x01 生成命令字节
	--i2c底层驱动在写操作时，用 (i2cslaveaddr << 1) | 0x00 生成命令字节
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
