--- 常用工具类接口
-- @module utils
-- @author 小强,稀饭放姜
-- @license MIT
-- @copyright openLuat.com
-- @release 2017.10.19
module(..., package.seeall)

--- 返回文件大小
-- @string path,文件路径全名例如:"/ldata/call.txt","test"
-- @return number ,文件大小
-- @usage locan cnt = io.filesize("/ldata/call.txt")
function io.filesize(path)
    local size = 0
    local file = io.open(path or "", "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end

--[[
函数名：filedata
功能  ：获取文件指定位置起的指定长度数据
参数  ：
		path：string类型，文件路径全名，例如:"/ldata/call.txt"
		offset：number类型，指定位置，取值范围是“0 到 文件长度-1”
        len：number类型，指定长度，如果设置的长度大于文件剩余的长度，则只能读取剩余的长度内容
返回值：指定长度的数据，如果读取失败，返回空字符串""
]]
function io.filedata(path,offset,len)
	local f,rt = io.open(path,"rb")
    --如果打开文件失败，返回内容为空“”
	if not f then print("filedata err：open") return "" end
	if not f:seek("set",offset) then f:close() print("filedata err：seek") return "" end
    --读取指定长度的数据
	rt = f:read(len)
	f:close()
	return rt or ""
end

function min(a,b)
	return (a>b and a or b)
end
