--[[
模块名称：“GPS应用”测试
模块功能：测试gpsapp.lua的接口
模块最后修改时间：2017.02.16
]]
require"gps"
require"agps"
module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上gpsapp前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("testgps",...)
end

local function test1cb(cause)
	--gps.isfix()：是否定位成功
	--gps.getgpslocation()：经纬度信息
	print("test1cb",cause,gps.isfix(),gps.getgpslocation())
end

local function test2cb(cause)
	--gps.isfix()：是否定位成功
	--gps.getgpslocation()：经纬度信息
	print("test2cb",cause,gps.isfix(),gps.getgpslocation())
end

local function test3cb(cause)
	--gps.isfix()：是否定位成功
	--gps.getgpslocation()：经纬度信息
	print("test3cb",cause,gps.isfix(),gps.getgpslocation())
end

--UART2外接UBLOX GPS模块
gps.init(nil,nil,true,1000,2,9600,8,uart.PAR_NONE,uart.STOP_1)

--[[
sys.timer_start(gps.writegpscmd,1000,true,"B56206010600F00000000000FD15",true) --关闭GGA
sys.timer_start(gps.writegpscmd,1000,true,"B56206010600F00100000000FE1A",true) --关闭GLL
sys.timer_start(gps.writegpscmd,1000,true,"B56206010600F00200000000FF1F",true) --关闭GSA
sys.timer_start(gps.writegpscmd,1000,true,"B56206010600F003000000000024",true) --关闭GSV
sys.timer_start(gps.writegpscmd,1000,true,"B56206010600F00500000000022E",true) --关闭VTG
]]
--sys.timer_start(gps.writegpscmd,1000,true,"B562060806006400010001007A12",true) --100ms

--测试代码开关，取值1,2
local testidx = 1

--第1种测试代码
if testidx==1 then
	--执行完下面三行代码后，GPS就会一直开启，永远不会关闭
	--因为gps.open(gps.DEFAULT,{cause="TEST1",cb=test1cb})，这个开启，没有调用gps.close关闭
	gps.open(gps.DEFAULT,{cause="TEST1",cb=test1cb})
	
	--10秒内，如果gps定位成功，会立即调用test2cb，然后自动关闭这个“GPS应用”
	--10秒时间到，没有定位成功，会立即调用test2cb，然后自动关闭这个“GPS应用”
	gps.open(gps.TIMERORSUC,{cause="TEST2",val=10,cb=test2cb})
	
	--300秒时间到，会立即调用test3cb，然后自动关闭这个“GPS应用”
	gps.open(gps.TIMER,{cause="TEST3",val=300,cb=test3cb})
--第2种测试代码
elseif testidx==2 then
	gps.open(gps.DEFAULT,{cause="TEST1",cb=test1cb})
	sys.timer_start(gps.close,30000,gps.DEFAULT,{cause="TEST1"})
	gps.open(gps.TIMERORSUC,{cause="TEST2",val=10,cb=test2cb})
	gps.open(gps.TIMER,{cause="TEST3",val=60,cb=test3cb})	
end
