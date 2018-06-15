module(...,package.seeall)
require"misc"
require"http"
require"common"

local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len
local ADDR,PORT ="www.lua.org",80
--local ADDR,PORT ="www.linuxhub.org",80
--local ADDR,PORT ="lq946.ngrok.xiaomiqiu.cn",80
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
功能  ：接收回调函数
参数  ：result：数据接收结果(此参数为0时，后面的几个参数才有意义)
				0:成功
				2:表示实体超出实际实体，错误，不输出实体内容
				3:接收超时
		statuscode：http应答的状态码，string类型或者nil
		head：http应答的头部数据，table类型或者nil
		body：http应答的实体数据，string类型或者nil
返回值：无
]]
local function rcvcb(result,statuscode,head,body)
	print("rcvcb",result,statuscode,head,slen(body or ""))
	
	if result==0 then
		if head then
			print("rcvcb head:")
			--遍历打印出所有头部，键为首部名字，键所对应的值为首部的字段值
			for k,v in pairs(head) do		
				print(k..": "..v)
			end
		end
		print("rcvcb body:")
		print(body)
	end
	
	httpclient:disconnect(discb)
end

--[[
函数名：rcvcbfile
功能  ：接收回调函数（下载文件）
参数  ：result：数据接收结果(此参数为0时，后面的几个参数才有意义)
				0:成功
				2:表示实体超出实际实体，错误，不输出实体内容
				3:接收超时
		statuscode：http应答的状态码，string类型或者nil
		head：http应答的头部数据，table类型或者nil
		filename: 下载文件的完整路径名
返回值：无
]]
local function rcvcbfile(result,statuscode,head,filename)
	print("rcvcbfile",result,statuscode,head,filename)	
	
	if result==0 then
		local filehandle = io.open(filename,"rb")
		if not filehandle then print("rcvcbfile open file error") return end
		local current = filehandle:seek()
		local size = filehandle:seek("end")
		filehandle:seek("set", current)
		--输出文件长度
		print("rcvcbfile size",size)
		
		--输出文件内容，如果文件太大，一次性读出文件内容可能会造成内存不足，分次读出可以避免此问题
		print("rcvcbfile content:\r\n")
		if size<=4096 then
			print(filehandle:read("*all"))
		else
			
		end
		
		filehandle:close()
	end
	--文件使用完之后，如果以后不再需求，需要自行删除
	if filename then os.remove(filename) end
	
	httpclient:disconnect(discb)
end

--[[
函数名：connectedcb
功能  ：SOCKET connected 成功回调函数
参数  ：
返回值：
]]
local function connectedcb()
	--[[调用此函数才会发送报文,request(cmdtyp,url,head,body,rcvcb),回调函数rcvcb(result,statuscode,head,body)
		url就是路径，例："/XXX/XXXX"，head为表的形式，例：{"Connection: keep-alive","Content-Type: text/html; charset=utf-8"}，注意:后面
		需加一个空格。body就是需要传的数据，为字符串类型。
	]]
	httpclient:request("GET","/",{},"",rcvcb)
	--httpclient:request("GET","/",{},"",rcvcbfile,"download.bin")
	--httpclient:request("POST","/",{},{[1]="begin\r\n",[2]={file="/lua/test.lua"},[3]="end\r\n"},rcvcb)
	--httpclient:request("POST","/",{},{[1]="begin\r\n",[2]={file_base64="/lua/test.lua"},[3]="end\r\n"},rcvcb)
end 

--[[
函数名：sckerrcb
功能  ：SOCKET失败回调函数
参数  ：
		r：string类型，失败原因值
		CONNECT: socket一直连接失败，不再尝试自动重连
		SEND：socket发送数据失败，不再尝试自动重连
返回值：无
]]
local function sckerrcb(r)
	print("sckerrcb",r)
	if r=="CONNECT" then
		--http.lua中已经断开了连接，根据自己的需求，此处可以直接调用connect()直接重连
	elseif r=="SEND" then
		--http.lua中发送数据失败，但是没有断开连接，此处要自己控制断开连接，然后在discb中做后续的逻辑处理
		httpclient:disconnect(discb)
	end
end
--[[
函数名：connect
功能：连接服务器
参数：
	 connectedcb:连接成功回调函数
	 sckerrcb：http lib中socket一直重连失败或者发送GET、POST请求失败时，不会自动重启软件，而是调用sckerrcb函数
返回：
]]
function connect()
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
	--httpclient:setconnectionmode(true)
	--建立http连接
	connect()	
end


--调用函数运行
http_run()



