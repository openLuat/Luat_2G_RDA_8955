module(...,package.seeall)

local schar,slen,sfind,sbyte,ssub = string.char,string.len,string.find,string.byte,string.sub

--[[
功能需求：
uart按照帧结构接收解析外围设备的输入

帧结构如下：
起始标志：1字节，固定为0x01
数据个数：1字节，校验码和数据个数之间的所有数据字节个数
指令：1字节
数据1：1字节
数据2：1字节
数据3：1字节
数据4：1字节
校验码：数据个数到数据4的异或运算
结束标志：1字节，固定为0xFE
]]


--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 1
--起始，结束标志
local FRM_HEAD,FRM_TAIL = 0x01,0xFE
--指令
local CMD_01 = 0x01
--串口读到的数据缓冲区
local rdbuf = ""

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--指令1的数据解析
local function cmd01(s)
	print("cmd01",common.binstohexs(s),slen(s))
	if slen(s)~=4 then return end
	local i,j,databyte
	for i=1,4 do
		databyte = sbyte(s,i)
		for j=0,7 do
			print("cmd01 data"..i.."_bit"..j..": "..(bit.isset(databyte,j) and 1 or 0))
		end
	end
end

--计算字符串s的校验码
local function checksum(s)
	local ret,i = 0
	for i=1,slen(s) do
		ret = bit.bxor(ret,sbyte(s,i))
	end
	return ret
end

--[[
函数名：parse
功能  ：按照帧结构解析处理一条完整的帧数据
参数  ：
		data：所有未处理的数据
返回值：第一个返回值是一条完整帧报文的处理结果，第二个返回值是未处理的数据
]]
local function parse(data)
	if not data then return end
	
	--起始标志
	local headidx = string.find(data,schar(FRM_HEAD))
	if not headidx then print("parse no head error") return true,"" end
	
	--数据个数
	if slen(data)<=headidx then print("parse wait cnt byte") return false,data end
	local cnt = sbyte(data,headidx+1)
	
	if slen(data)<headidx+cnt+3 then print("parse wait complete") return false,data end
	
	--指令
	local cmd = sbyte(data,headidx+2)	
	local procer =
	{
		[CMD_01] = cmd01,
	}
	if not procer[cmd] then print("parse cmd error",cmd) return false,ssub(data,headidx+cnt+4,-1) end
	
	--结束标志
	if sbyte(data,headidx+cnt+3)~=FRM_TAIL then print("parse tail error",sbyte(data,headidx+cnt+3)) return false,ssub(data,headidx+cnt+4,-1) end
	
	--校验码
	local sum1,sum2 = checksum(ssub(data,headidx+1,headidx+1+cnt)),sbyte(data,headidx+cnt+2)
	if sum1~=sum2 then print("parse checksum error",sum1,sum2) return false,ssub(data,headidx+cnt+4,-1) end
	
	procer[cmd](ssub(data,headidx+3,headidx+1+cnt))
	
	return true,ssub(data,headidx+cnt+4,-1)	
end

--[[
函数名：proc
功能  ：处理从串口读到的数据
参数  ：
		data：当前一次从串口读到的数据
返回值：无
]]
local function proc(data)
	if not data or string.len(data) == 0 then return end
	--追加到缓冲区
	rdbuf = rdbuf..data	
	
	local result,unproc
	unproc = rdbuf
	--根据帧结构循环解析未处理过的数据
	while true do
		result,unproc = parse(unproc)
		if not unproc or unproc == "" or not result then
			break
		end
	end

	rdbuf = unproc or ""
end

--[[
函数名：read
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
		data = uart.read(UART_ID,"*l")
		if not data or string.len(data) == 0 then break end
		--打开下面的打印会耗时
		print("read",common.binstohexs(data))
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

--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("test")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("test")后，在不需要串口时调用pm.sleep("test")
pm.wake("test")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
sys.reguart(UART_ID,read)
--配置并且打开串口
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)


