--[[
模块名称：网络时间更新
模块功能：只在每次开机或者重启时，连接NTP服务器，更新系统时间
请先自行百度学习NTP协议
然后再阅读本模块
模块最后修改时间：2017.03.22
]]

--定义模块,导入依赖库
local base = _G
local string = require"string"
local os = require"os"
local sys  = require"sys"
local link = require"link"
local misc = require"misc"
local common = require"common"
local pack = require"pack"
module(...)

--加载常用的全局函数至本地
local print = base.print
local send = link.send
local dispatch = sys.dispatch
local sbyte,ssub = string.byte,string.sub


--可用的NTP服务器域名集合，按照顺序去连接服务器同步时间，同步成功后，就退出，不再继续遍历
local tserver =
{	
	"ntp1.aliyun.com",
	"ntp2.aliyun.com",
	"ntp3.aliyun.com",
	"ntp4.aliyun.com",
	"ntp5.aliyun.com",
	"ntp7.aliyun.com",
	"ntp6.aliyun.com",	
	"s2c.time.edu.cn",
	"194.109.22.18",
	"210.72.145.44",
	--[["ntp.sjtu.edu.cn",
	"s1a.time.edu.cn",
	"s1b.time.edu.cn",
	"s1c.time.edu.cn",
	"s1d.time.edu.cn",
	"s2a.time.edu.cn",	
	"s2d.time.edu.cn",
	"s2e.time.edu.cn",
	"s2g.time.edu.cn",
	"s2h.time.edu.cn",
	"s2m.time.edu.cn",]]
}
--当前连接的服务器在tserver中的索引
local tserveridx = 1

--REQUEST命令等待时间
local REQUEST_TIMEOUT = 8000
--每次REQUEST命令重试次数
local REQUEST_RETRY_TIMES = 3
--socket id
local lid
--与当前的NTP服务器时间同步已经重试的次数
local retries = 0


--[[
函数名：retry
功能  ：时间同步过程中的重试动作
参数  ：无
返回值：无
]]
local function retry()
	sys.timer_stop(retry)
	--重试次数加1
	retries = retries + 1
	--未达重试次数,继续发送同步请求
	if retries < REQUEST_RETRY_TIMES then
		request()
	else
		--超过重试次数,与当前服务器同步失败
		upend(false)
	end
end


--[[
函数名：upend
功能  ：与当前的NTP服务器时间同步结果处理
参数  ：
		suc：时间同步结果，true为成功，其余为失败
返回值：无
]]
function upend(suc)
	print("ntp.upend",suc)
	--停止重试定时器
	sys.timer_stop(retry)
	retries = 0
	--断开链接
	link.close(lid)
	--同步时间成功 或者 NTP服务器已经完整遍历
	if suc or tserveridx>=#tserver then
		--产生一个内部消息UPDATE_END_IND，目前与飞行模式配合使用
		dispatch("NTP_END_IND",suc)
	else
		tserveridx = tserveridx+1
		connect()
	end	
end

--[[
函数名：request
功能  ：发送“同步时间”请求数据到服务器
参数  ：无
返回值：无
]]
function request()
	send(lid,common.hexstobins("E30006EC0000000000000000314E31340000000000000000000000000000000000000000000000000000000000000000"))
	sys.timer_start(retry,REQUEST_TIMEOUT)
end

--[[
函数名：nofity
功能  ：socket状态的处理函数
参数  ：
        id：socket id，程序可以忽略不处理
        evt：消息事件类型
		val： 消息事件参数
返回值：无
]]
local function nofity(id,evt,val)
	--连接结果
	if evt == "CONNECT" then
		--产生一个内部消息NTP_BEGIN_IND，目前与飞行模式配合使用
		dispatch("NTP_BEGIN_IND")
		--连接成功
		if val == "CONNECT OK" then
			request()
		--连接失败
		else
			upend(false)
		end
	--连接被动断开
	elseif evt == "STATE" and val == "CLOSED" then		 
		upend(false)
	end
end

--[[
函数名：setclkcb
功能  ：调用misc.setclock接口设置时间后的回调函数
参数  ：
        cmd ：程序可以忽略不处理
        suc：设置成功或者失败，true成功，其他失败
返回值：无
]]
local function setclkcb(cmd,suc)
	upend(suc)
end

--[[
函数名：recv
功能  ：socket接收数据的处理函数
参数  ：
        id ：socket id，程序可以忽略不处理
        data：接收到的数据
返回值：无
]]
local function recv(id,data)
	--停止重试定时器
	sys.timer_stop(retry)
	--数据格式错误
	if string.len(data)~=48 then
		upend(false)
		return
	end
	print("ntp recv:",common.binstohexs(ssub(data,41,44)))
	misc.setclock(os.date("*t",(sbyte(ssub(data,41,41))-0x83)*2^24+(sbyte(ssub(data,42,42))-0xAA)*2^16+(sbyte(ssub(data,43,43))-0x7E)*2^8+(sbyte(ssub(data,44,44))-0x80)+1),setclkcb)
end

--[[
函数名：connect
功能  ：创建socket，并且连接第tserveridx个NTP服务器
参数  ：无
返回值：无
]]
function connect()
	lid = link.open(nofity,recv,"ntp")
	link.connect(lid,"UDP",tserver[tserveridx],123)
end

connect()
