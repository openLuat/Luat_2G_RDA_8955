--[[
模块名称：SPI接口测试
模块功能：通过SPI软件接口，驱动ST 7735驱动芯片的LCD显示,尽在最上面显示两小块红色和绿色图案
模块最后修改时间：2017.09.20
]]

module(...,package.seeall)

--reset，复位引脚
local pinrst = pio.P0_3
--rs，命令/数据选择引脚
local pinrs = pio.P0_12

--ST 7735驱动芯片LCD的初始化命令
local initcmd =
{
	0x11, 
	0x010078,         
	------------------------------------ST7735S Frame Rate-----------------------------------------// 
	0xB1,
	0x030005,
	0x03003C,
	0x03003C,
	0xB2,
	0x030005,
	0x03003C,
	0x03003C,
	0xB3,
	0x030005,
	0x03003C,
	0x03003C,
	0x030005,
	0x03003C,
	0x03003C,
	------------------------------------End ST7735S Frame Rate---------------------------------// 
	0xB4,--Dot inversion 
	0x030000, 
	------------------------------------ST7735S Power Sequence---------------------------------// 
	0xC0,
	0x030028,
	0x030008,
	0x030004,
	0xC1,
	0x0300C0,
	0xC2,
	0x03000D,
	0x030000,
	0xC3,
	0x03008D,
	0x03002A,
	0xC4,
	0x03008D,
	0x0300EE,
	---------------------------------End ST7735S Power Sequence-------------------------------------// 
	0xC5, --VCOM 
	0x03000E,
	0x36,--MX, MY, RGB mode 
	0x0300C0, 
	------------------------------------ST7735S Gamma Sequence---------------------------------// 
	0xE0,
	0x030004,
	0x030022,
	0x030007,
	0x03000A,
	0x03002E,
	0x030030,	
	0x030025,
	0x03002A,
	0x030028,
	0x030026,
	0x03002E,
	0x03003A,
	0x030000,
	0x030001,
	0x030003,
	0x030013,
	0xE1,
	0x030004,
	0x030016,
	0x030006,
	0x03000D,
	0x03002D,
	0x030026,
	0x030023,
	0x030027,
	0x030027,
	0x030025,
	0x03002D,
	0x03003B,
	0x030000,
	0x030001,
	0x030004,
	0x030013,
	--------------------------------------End ST7735S Gamma Sequence-----------------------------// 
	0x3A, --65k mode 
	0x030005, 
	0x29,--Display on 
}

--[[
函数名：writecmd
功能  ：写命令
参数  ：命令
返回值：无
]]			 		
function writecmd(c)
	pio.pin.setval(0,pinrs)
	if type(c)=="number" then c = string.char(c) end
	spi.send(spi.SPI_1, c)
end

--[[
函数名：writedata
功能  ：写数据
参数  ：数据
返回值：无
]]
function writedata(d)
	pio.pin.setval(1,pinrs)
	if type(d)=="number" then d = string.char(d) end
	spi.send(spi.SPI_1, d)
end

--[[
函数名：delay
功能  ：延时毫秒
参数  ：
		t: 延时时间，单位毫秒
返回值：无
]]
function delay(t)
	local i
	for i=1,t*100,1 do
	end
end

--[[
函数名：lcdinit
功能  ：初始化LCD
参数  ：无
返回值：无
]]
local function lcdinit()
	pio.pin.setdir(pio.OUTPUT,pinrst)
	pio.pin.setdir(pio.OUTPUT,pinrs)
	pio.pin.setval(1,pinrst)
	pio.pin.setval(0,pinrst)
	pio.pin.setval(1,pinrst)
	
	for k,v in pairs(initcmd) do
		print("k,v",k,v)
		v1 = bit.rshift(v, 16)
		v2 = bit.band(v,0xffff)
		print("v1",v1)
		if v1 == 0 then
			writecmd(v2)	
		elseif v1 == 1 then
			delay(v2)
		elseif v1 == 3 then
			writedata(v2)
		end
	end
end

--[[
函数名：test
功能  ：测试LCD显示功能
参数  ：无
返回值：无
]]
local function test()
	--配置SPI，SPI1，chpa：0，cpol：1，数据位：8，时钟频率：13M
	spi.setup(spi.SPI_1,0,1,8,13000000)
	
	local s = ""
	for i=1,128*20 do
		s = s..string.char(0xf8)..string.char(0x00)--红色
	end
	for i=1,128*20 do
		s = s..string.char(0x07)..string.char(0xe0)--绿色
	end
	
	print("init")
	
	lcdinit()
	writecmd(0x2A)
	writedata(0)
	writedata(0)
	writedata(0)
	writedata(127)
  
	writecmd(0x2B)
	writedata(0)
	writedata(0)
	writedata(0)
	writedata(39)
  
	writecmd(0x2C)
	pio.pin.setval(1,pinrs)
	spi.send(spi.SPI_1,s)
end

--控制SPI引脚的电压域
pmd.ldoset(6,pmd.LDO_VMMC)
test()
