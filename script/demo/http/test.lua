module(...,package.seeall)
require"misc"
require"http"
require"common"
--[[
功能介绍：http短连接，首先需要提供ADDR和PORT，该数据就是客户端需要连接的客户端
1.需要调用函数，来设置url，添加头部，添加实体，这里注意添加首部Host时，与前面的ADDR和PORT一致,利用的是socket的长连接
2.调用request函数，该函数是发送报文所必需需要调用的
3.rcvcb函数是接收回调函数，会返回结果，状态码，首部（一个表），实体，该函数是自定义函数，客户可以根据自己的需求自己定义
4.接收数据后，如果五秒内没有再处理，会重启，会重新连接
]]
local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len
--测试时请先写出IP地址和端口，后面所写的首部要与这里的host一致，下面的值都是默认的值
local ADDR,PORT ="36.7.87.100",81
--测试POST方法时所用地址
--local ADDR,PORT ="www.luam2m.com",80
local httpclient

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
函数名：rcvcb
功能：接收回调函数，用户自定义对接收参数进行操作
参数：result：0：表示 接收实体长度与实际相同，正确输出 1：表示没有实体	2：表示实体超出实际实体，错误，不输出实体内容	3：接收超时	4:表示服务器进行的是分块传输模式
返回值：
]]
local function rcvcb(result,statuscode,head,body)
	print("resultrcvcb: ",result)  
	print("statuscodercvcb: ",statuscode)
	if	head==nil	then	print("headrcvcb:	nil")
	else
		print("headrcvcb:")
		--遍历打印出所有头部，键为首部名字，键所对应的值为首部的字段值
		for k,v in pairs(head) do		
			print(k..": "..v)
		end
	end
	print("bodyrcvcb:",body)
	httpclient:disconnect(discb)
end


--[[
函数名：connectedcb
功能  ：SOCKET connected 成功回调函数
参数  ：
返回值：
]]
local function connectedcb()
	--GET默认方法
	--设置URL
	httpclient:seturl("/")
	--添加首部，注意Host首部的值与上面的addr，port一致
	httpclient:addhead("Host","36.7.87.100")
	httpclient:addhead("Connection","keep-alive")
	--添加实体内容
	httpclient:setbody("")
	--调用此函数才会发送报文,需要使用POST方式时，将GET改为POST
    httpclient:request("GET",rcvcb)
end 

--[[
函数名：sckerrcb
功能  ：SOCKET失败回调函数
参数  ：
		r：string类型，失败原因值
		CONNECT: socket一直连接失败，不再尝试自动重连
返回值：无
]]
local function sckerrcb(r)
	print("sckerrcb",r)
end
--[[
函数名：connect
功能：连接服务器
参数：
	 connectedcb:连接成功回调函数
	 sckerrcb：http lib中socket一直重连失败时，不会自动重启软件，而是调用sckerrcb函数
返回：
]]
local function connect()
	httpclient:connect(connectedcb,sckerrcb)
end
--[[
函数名：discb
功能  ：HTTP连接断开后的回调
参数  ：无		
返回值：无
]]
function discb()
	print("http discb")
	--20秒后重新建立HTTP连接
	sys.timer_start(connect,20000)
end

--[[
函数名：http_run
功能  ：创建http客户端，并进行连接
参数  ：无		
返回值：无
]]
function http_run()
	--因为http协议必须基于“TCP”协议，所以不必传入PROT参数
	httpclient=http.create(ADDR,PORT)	
	--建立http连接
	connect()	
end


--调用函数运行
http_run()



