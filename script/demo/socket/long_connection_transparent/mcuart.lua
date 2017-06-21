module(...,package.seeall)

require"pm"

--串口ID,1对应uart1
local UART_ID = 1

--SND_UNIT_MAX：每次发送最大的字节数，只要累积收到的数据大于等于这个最大字节数，并且没有正在发送数据到后台，则立即发送前SND_UNIT_MAX字节数据给后台
--SND_DELAY：每次串口收到数据时，重新延迟SND_DELAY毫秒后，没有收到新的数据，并且没有正在发送数据到后台，则立即发送最多前SND_UNIT_MAX字节数据给后台
--这两个变量配合使用，只要任何一个条件满足，都会触发发送动作
--例如：SND_UNIT_MAX,SND_DELAY = 1024,1000，有如下几种情况
--串口收到了500字节数据，接下来的1000毫秒没有收到数据，并且没有正在发送数据到后台，则立即发送这500字节数据给后台
--串口收到了500字节数据，800毫秒后，又收到了524字节数据，此时没有正在发送数据到后台，则立即发送这1024字节数据给后台
local SND_UNIT_MAX,SND_DELAY = 1024,1000

--sndingtosvr：是否正在发送数据到后台
local sndingtosvr

--unsndbuf：还没有发送的数据
--sndingbuf：正在发送的数据
local readbuf--[[,sndingbuf]] = ""--[[,""]]

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上mcuart前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("mcuart",...)
end

--[[
函数名：sndtosvr
功能  ：通知数据发送功能模块，串口数据已准备好，可以发送
参数  ：无
返回值：无
]]
local function sndtosvr()
	--print("sndtosvr",sndingtosvr)
	if not sndingtosvr then
		sys.dispatch("SND_TO_SVR_REQ")
	end
end

--[[
函数名：getsndingbuf
功能  ：获取将要发送的数据
参数  ：无
返回值：string类型，将要发送的数据
]]
local function getsndingbuf()
	print("getsndingbuf",string.len(readbuf),sndingtosvr,sys.timer_is_active(sndtosvr))
	if string.len(readbuf)>0 and not sndingtosvr and (not sys.timer_is_active(sndtosvr) or string.len(readbuf)>=SND_UNIT_MAX) then
		local endidx = string.len(readbuf)>=SND_UNIT_MAX and SND_UNIT_MAX or string.len(readbuf)
		local retstr = string.sub(readbuf,1,endidx)
		readbuf = string.sub(readbuf,endidx+1,-1)
		sndingtosvr = true
		return retstr
	else
		sndingtosvr = false
		return ""
	end	
end

--[[
函数名：resumesndtosvr
功能  ：复位发送中标志，获取将要发送的数据
参数  ：无
返回值：string类型，将要发送的数据
]]
function resumesndtosvr()
	sndingtosvr = false
	return getsndingbuf()
end

--[[
函数名：sndcnf
功能  ：发送结果处理函数
参数  ：
		result：发送结果，true成功，其余值失败
返回值：无
]]
--[[local function sndcnf(result)
	print("sndcnf",result)
	--sndingbuf = ""
	sndingtosvr = false
end]]

--[[
函数名：proc
功能  ：处理串口接收到的数据
参数  ：
		data：当前一次读取到的串口数据
返回值：无
]]
local function proc(data)
	if not data or string.len(data) == 0 then return end
	--追加到未发送数据缓冲区末尾
	readbuf = readbuf..data
	if string.len(readbuf)>=SND_UNIT_MAX then sndtosvr() end
	sys.timer_start(sndtosvr,SND_DELAY)
end


--[[
函数名：snd
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
	local data = ""
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	while true do
		data = uart.read(UART_ID,"*l",0)
		if not data or string.len(data) == 0 then break end
		--print("read",string.len(data)--[[data,common.binstohexs(data)]])
		proc(data)
	end
end

--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
		s：要发送的数据
返回值：无
]]
function write(s)
	print("write",s)
	uart.write(UART_ID,s)	
end

--消息处理函数列表
local procer =
{
	SVR_TRANSPARENT_TO_MCU = write,
	--SND_TO_SVR_CNF = sndcnf,
}

--注册消息处理函数列表
sys.regapp(procer)
--保持系统处于唤醒状态，不会休眠
pm.wake("mcuart")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
sys.reguart(UART_ID,read)
--配置并且打开串口
uart.setup(UART_ID,9600,8,uart.PAR_NONE,uart.STOP_1)


