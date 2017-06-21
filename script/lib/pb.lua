local base = _G
local ril = require"ril"
local sys = require"sys"
local string = require"string"

module("pb")

local print,tonumber,req,dispatch = base.print,base.tonumber,ril.request,sys.dispatch
local smatch = string.match
local storagecb,readcb,writecb,deletecb

--[[
函数名：setstorage
功能  ：设置电话本存储区域
参数  ：
		str：string类型，存储区域字符串，仅支持"ME"和"SM"
		cb：设置后的回调函数
返回值：无
]]
function setstorage(str,cb)
	if str=="SM" or str=="ME" then
		storagecb = cb
		req("AT+CPBS=\"" .. str .. "\"" )
	end
end

function find(name)
	if name == "" or name == nil then
		return	false
	end
	req("AT+CPBF=\"" .. name .. "\"" )
	return true
end

--[[
函数名：read
功能  ：读取一条电话本记录
参数  ：
		index：number类型，电话本在存储区的位置
		cb：读取后的回调函数
返回值：无
]]
function read(index,cb)
	if index == "" or index == nil then
		return false
	end
	readcb = cb
	req("AT+CPBR=" .. index)
end

--[[
函数名：writeitem
功能  ：写一条电话本记录
参数  ：
		index：number类型，电话本在存储区的位置
		name：姓名
		num：号码
		cb：写入后的回调函数
返回值：无
]]
function writeitem(index,name,num,cb)
	if num == nil or name == nil or index == nil then
		return false
	end
	writecb = cb
	req("AT+CPBW=" .. index .. ",\"" .. num .. "\"," .. "129" .. ",\"" .. name .. "\"" )
	return true
end

--[[
函数名：deleteitem
功能  ：删除一条电话本记录
参数  ：
		i：number类型，电话本在存储区的位置
		cb：删除后的回调函数
返回值：无
]]
function deleteitem(i,cb)
	if i == "" or i == nil then
		return false
	end
	deletecb = cb
	req("AT+CPBW=" .. i)
	return true
end

local function pbrsp(cmd,success,response,intermediate)
	local prefix = smatch(cmd,"AT(%+%u+%?*)")
	intermediate = intermediate or ""

	if prefix == "+CPBF"  then
		local name = string.match(cmd,"AT%+CPBF%s*=%s*\"(%w*)\"")
		if intermediate == "" then
			dispatch("PB_FIND_CNF",success,"","",name)
		else
			for w in string.gmatch(intermediate, "(.-)\r\n") do
				local index,n = smatch(w,"+CPBF:%s*(%d+),\"([#%*%+%d]*)\",%d+,")
				index = index or ""
				n = n or ""
				dispatch("PB_FIND_CNF",success,index,n,name)
			end
		end
	elseif prefix == "+CPBR" then
		local index = string.match(cmd,"AT%+CPBR%s*=%s*(%d+)")
		local num,name = smatch(intermediate,"+CPBR:%s*%d+,\"([#%*%+%d]*)\",%d+,\"(%w*)\"")
		num,name = num or "",name or ""
		dispatch("PB_READ_CNF",success,index,num,name)
		local cb = readcb
		readcb = nil
		if cb then cb(success,name,num) return end
	elseif prefix == "+CPBW" then
		dispatch("PB_WRITE_CNF",success)
		local cb = writecb
		writecb = nil
		if cb then cb(success) return end
		cb = deletecb
		deletecb = nil
		if cb then cb(success) return end
	elseif prefix == "+CPBS?" then
		local storage,used,total = smatch(intermediate,"+CPBS:%s*\"(%u+)\",(%d+),(%d+)")
		used,total = tonumber(used),tonumber(total)
		dispatch("CPBS_READ_CNF",success,storage,used,total)
	elseif prefix == "+CPBS" then
		local cb = storagecb
		storagecb = nil
		if cb then cb(success) return end
    end
end

ril.regrsp("+CPBF",pbrsp)
ril.regrsp("+CPBR",pbrsp)
ril.regrsp("+CPBW",pbrsp)
ril.regrsp("+CPBS",pbrsp)
ril.regrsp("+CPBS?",pbrsp)
