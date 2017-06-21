require"socket"
module(...,package.seeall)

--[[
功能需求：
1、数据网络准备就绪后，连接后台
2、连接成功后，每隔10秒钟发送一次心跳包"heart data\r\n"到后台；每隔20秒钟发送一次位置包"loc data\r\n"到后台
3、与后台保持长连接，断开后主动再去重连，连接成功仍然按照第2条发送数据
4、收到后台的数据时，在rcv函数中打印出来
测试时请搭建自己的服务器，并且修改下面的PROT，ADDR，PORT，支持域名和IP地址

此例子为长连接，只要是软件上能够检测到的网络异常，可以自动去重新连接
]]

local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len
--测试时请搭建自己的服务器
local SCK_IDX,PROT,ADDR,PORT = 1,"TCP","120.26.196.195",9999
--linksta:与后台的socket连接状态
local linksta
--一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
--如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
--如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20
--reconncnt:当前连接周期内，已经重连的次数
--reconncyclecnt:连续多少个连接周期，都没有连接成功
--一旦连接成功，都会复位这两个标记
--conning:是否在尝试连接
local reconncnt,reconncyclecnt,conning = 0,0

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
函数名：snd
功能  ：调用发送接口发送数据
参数  ：
        data：发送的数据，在发送结果事件处理函数ntfy中，会赋值到item.data中
		para：发送的参数，在发送结果事件处理函数ntfy中，会赋值到item.para中 
返回值：调用发送接口的结果（并不是数据发送是否成功的结果，数据发送是否成功的结果在ntfy中的SEND事件中通知），true为成功，其他为失败
]]
function snd(data,para)
	return socket.send(SCK_IDX,data,para)
end


--[[
函数名：locrpt
功能  ：发送位置包数据到后台
参数  ：无
返回值：无
]]
function locrpt()
	print("locrpt",linksta)
	if linksta then
		snd("loc data\r\n","LOCRPT")		
	end
end


--[[
函数名：locrptcb
功能  ：位置包发送回调，启动定时器，20秒钟后再次发送位置包
参数  ：		
		item：table类型，{data=,para=}，消息回传的参数和数据，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
		result： bool类型，发送结果，true为成功，其他为失败
返回值：无
]]
function locrptcb(item,result)
	print("locrptcb",linksta)
	if linksta then
		sys.timer_start(locrpt,20000)
	end
end


--[[
函数名：heartrpt
功能  ：发送心跳包数据到后台
参数  ：无
返回值：无
]]
function heartrpt()
	print("heartrpt",linksta)
	if linksta then
		snd("heart data\r\n","HEARTRPT")		
	end
end

--[[
函数名：locrptcb
功能  ：心跳包发送回调，启动定时器，10秒钟后再次发送心跳包
参数  ：		
		item：table类型，{data=,para=}，消息回传的参数和数据，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
		result： bool类型，发送结果，true为成功，其他为失败
返回值：无
]]
function heartrptcb(item,result)
	print("heartrptcb",linksta)
	if linksta then
		sys.timer_start(heartrpt,10000)
	end
end


--[[
函数名：sndcb
功能  ：数据发送结果处理
参数  ：          
		item：table类型，{data=,para=}，消息回传的参数和数据，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
		result： bool类型，发送结果，true为成功，其他为失败
返回值：无
]]
local function sndcb(item,result)
	print("sndcb",item.para,result)
	if not item.para then return end
	if item.para=="LOCRPT" then
		locrptcb(item,result)
	elseif item.para=="HEARTRPT" then
		heartrptcb(item,result)
	end
end


--[[
函数名：reconn
功能  ：重连后台处理
        一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
        如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
        如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
参数  ：无
返回值：无
]]
local function reconn()
	print("reconn",reconncnt,conning,reconncyclecnt)
	--conning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致reconncnt增加，实际的重连次数减少
	if conning then return end
	--一个连接周期内的重连
	if reconncnt < RECONN_MAX_CNT then		
		reconncnt = reconncnt+1
		link.shut()
		connect()
	--一个连接周期的重连都失败
	else
		reconncnt,reconncyclecnt = 0,reconncyclecnt+1
		if reconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			sys.restart("connect fail")
		end
		sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000)
	end
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		result： bool类型，消息事件结果，true为成功，其他为失败
		item：table类型，{data=,para=}，消息回传的参数和数据，目前只是在SEND类型的事件中用到了此参数，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
返回值：无
]]
function ntfy(idx,evt,result,item)
	print("ntfy",evt,result,item)
	--连接结果（调用socket.connect后的异步事件）
	if evt == "CONNECT" then
		conning = false
		--连接成功
		if result then
			reconncnt,reconncyclecnt,linksta = 0,0,true
			--停止重连定时器
			sys.timer_stop(reconn)
			--发送心跳包到后台
			heartrpt()
			--发送位置包到后台
			locrpt()
		--连接失败
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000)
		end	
	--数据发送结果（调用socket.send后的异步事件）
	elseif evt == "SEND" then
		if item then
			sndcb(item,result)
		end
		--发送失败，RECONN_PERIOD秒后重连后台，不要调用reconn，此时socket状态仍然是CONNECTED，会导致一直连不上服务器
		--if not result then sys.timer_start(reconn,RECONN_PERIOD*1000) end
		if not result then link.shut() end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		linksta = false
		sys.timer_stop(heartrpt)
		sys.timer_stop(locrpt)
		reconn()
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		linksta = false
		sys.timer_stop(heartrpt)
		sys.timer_stop(locrpt)
		reconn()
	--连接主动断开（调用socket.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		linksta = false
		sys.timer_stop(heartrpt)
		sys.timer_stop(locrpt)
		reconn()		
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((type(result)=="string") and result or "","ERROR") then
		--RECONN_PERIOD秒后重连，不要调用reconn，此时socket状态仍然是CONNECTED，会导致一直连不上服务器
		--sys.timer_start(reconn,RECONN_PERIOD*1000)
		link.shut()
	end
end

--[[
函数名：rcv
功能  ：socket接收数据的处理函数
参数  ：
        idx ：socket.lua中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
function rcv(idx,data)
	print("rcv",data)
end

--[[
函数名：connect
功能  ：创建到后台服务器的连接；
        如果数据网络已经准备好，会理解连接后台；否则，连接请求会被挂起，等数据网络准备就绪后，自动去连接后台
		ntfy：socket状态的处理函数
		rcv：socket接收数据的处理函数
参数  ：无
返回值：无
]]
function connect()
	socket.connect(SCK_IDX,PROT,ADDR,PORT,ntfy,rcv)
	conning = true
end

connect()
