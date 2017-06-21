--[[
模块名称：gsensor功能
模块功能：目前仅用来检测是否发生了震动
模块最后修改时间：2017.02.16
]]

module(...,package.seeall)

--i2c id
--gsensor锁震动中断的寄存器地址
local i2cid,intregaddr = 1,0x1A

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上gsensor前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("gsensor",...)
end

--[[
函数名：clrint
功能  ：清除gsensor芯片内部的锁震动中断标志，这样gsensor才能开始检测下次震动
参数  ：无
返回值：无
]]
local function clrint() 
	if pins.get(pincfg.GSENSOR) then
		i2c.read(i2cid,intregaddr,1)
	end
end

--[[
函数名：init2
功能  ：gsensor第二步初始化
参数  ：无
返回值：无
]]
local function init2()
	local cmd,i = {0x1B,0x00,0x6A,0x01,0x1E,0x20,0x21,0x04,0x1B,0x00,0x1B,0xDA,0x1B,0xDA}
	for i=1,#cmd,2 do
		i2c.write(i2cid,cmd[i],cmd[i+1])
		print("init2",string.format("%02X",cmd[i]),string.format("%02X",string.byte(i2c.read(i2cid,cmd[i],1))))
	end
	clrint()
end

--[[
函数名：checkready
功能  ：检查“gsensor第一步初始化”是否成功
参数  ：无
返回值：无
]]
local function checkready()
	local s = i2c.read(i2cid,0x1D,1)
	print("checkready",s,(s and s~="") and string.byte(s) or "nil")
	if s and s~="" then
		if bit.band(string.byte(s),0x80)==0 then
			init2()
			return
		end
	end
	sys.timer_start(checkready,1000)
end

--[[
函数名：init
功能  ：gsensor第一步初始化
参数  ：无
返回值：无
]]
local function init()
	--gsensor的i2c地址
	local i2cslaveaddr = 0x0E
	--打开i2c功能
	if i2c.setup(i2cid,i2c.SLOW,i2cslaveaddr) ~= i2c.SLOW then
		print("init fail")
		return
	end
	i2c.write(i2cid,0x1D,0x80)
	sys.timer_start(checkready,1000)
end

--[[
函数名：qryshk
功能  ：查询gsensor是否发生震动
参数  ：无
返回值：无
]]
local function qryshk()
	--发生了震动
	if pins.get(pincfg.GSENSOR) then
		--清除锁震动标志，以便能够检测下次震动
		clrint()
		print("GSENSOR_SHK_IND")
		--产生一个GSENSOR_SHK_IND的内部消息，表示设备发生了震动
		sys.dispatch("GSENSOR_SHK_IND")
	end
end

--启动一个10秒的循环定时器，轮询是否发生震动
--之所以不采取中断方式，是因为频繁震动时，中断太耗电
sys.timer_loop_start(qryshk,10000)
init()

--有时会发生异常，查询出来没有震动，但是gsensor内部的寄存器已经设置了锁震动的标志
--30秒清除一次锁震动标志，用来规避这种异常
sys.timer_loop_start(clrint,30000)
