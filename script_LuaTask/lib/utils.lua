--- 模块功能：常用工具类接口
-- @module utils
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.10.19
module(..., package.seeall)

--- 将Lua字符串转成HEX字符串，如"123abc"转为"313233616263"
-- @string str 输入字符串
-- @string[opt=""] separator 输出的16进制字符串分隔符
-- @return hexstring 16进制组成的串
-- @return len 输入的字符串长度
-- @usage
-- string.toHex("\1\2\3") -> "010203" 3
-- string.toHex("123abc") -> "313233616263" 6
-- string.toHex("123abc"," ") -> "31 32 33 61 62 63 " 6
function string.toHex(str,separator)
    return str:gsub('.', function(c)
        return string.format("%02X"..(separator or ""), string.byte(c))
    end)
end
--- 将HEX字符串转成Lua字符串，如"313233616263"转为"123abc", 函数里加入了过滤分隔符，可以过滤掉大部分分隔符（可参见正则表达式中\s和\p的范围）。
-- @string hex,16进制组成的串
-- @return charstring,字符组成的串
-- @return len,输出字符串的长度
-- @usage
-- string.fromHex("010203")       ->  "\1\2\3"
-- string.fromHex("313233616263:) ->  "123abc"
function string.fromHex(hex)
    --滤掉分隔符
    local hex = hex:gsub("[%s%p]", ""):upper()
    return hex:gsub("%x%x", function(c)
        return string.char(tonumber(c, 16))
    end)
end
--- 返回utf8编码字符串的长度
-- @string str,utf8编码的字符串,支持中文
-- @return number,返回字符串长度
-- @usage local cnt = string.utf8Len("中国"),str = 2
function string.utf8Len(str)
    local len = #str
    local left = len
    local cnt = 0
    local arr = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(str, -left)
        local i = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end
-- 将一个字符转为urlEncode编码
local function urlEncodeChar(c)
    return "%" .. string.format("%02X", string.byte(c))
end
--- 返回字符串的urlEncode编码
-- @string str，要转换编码的字符串
-- @return str,urlEncode编码的字符串
-- @usage string.urlEncode("####133")
function string.urlEncode(str)
    return string.gsub(string.gsub(string.gsub(tostring(str), "\n", "\r\n"), "([^%w%.%- ])", urlEncodeChar), " ", "+")
end
--- 返回数字的千位符号格式
-- @number num,数字
-- @return string，千位符号的数字字符串
-- @usage loca s = string.formatNumberThousands(1000) ,s = "1,000"
function string.formatNumberThousands(num)
    local k, formatted
    formatted = tostring(tonumber(num))
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

--- 按照指定分隔符分割字符串
-- @string str 输入字符串
-- @string delimiter 分隔符
-- @return 分割后的字符串列表
-- @usage "123,456,789":split(',') -> {'123','456','789'}
function string.split(str, delimiter)
    local strlist = {}
    for substr in str:gmatch(string.format("([^%s]+)", delimiter)) do
        table.insert(strlist, substr)
    end
    return strlist
end

--- 判断文件是否存在
-- @string path,文件全名例如："/ldata/call.mp3"
-- @return boole,存在为true,不存在为false
-- @usage local ex = io.exists("/ldata/call.mp3")
function io.exists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end
--- 读取文件并返回文件的内容
-- @string path,文件全名例如："/ldata/call.txt"
-- @return string,文件的内容,文件不存在返回nil
-- @usage local c = io.readFile("/ldata/call.txt")
function io.readFile(path)
    local file = io.open(path, "rb")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
end
--- 写入文件指定的内容,默认为覆盖二进制模式
-- @string path,文件全名例如："/ldata/call.txt"
-- @string content,文件内容
-- @string mode,文件写入模式默认"w+b"
-- @return string,文件的内容
-- @usage local c = io.writeFile("/ldata/call.txt","test")
function io.writeFile(path, content, mode)
    local mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end
--- 将文件路径分解为table信息
-- @string path,文件路径全名例如:"/ldata/call.txt"
-- @return table,{dirname="/ldata/",filename="call.txt",basename="call",extname=".txt"}
-- @usage loca p = io.pathInfo("/ldata/call.txt")
function io.pathInfo(path)
    local pos = string.len(path)
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end
    
    local dirname = string.sub(path, 1, pos)
    local filename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local basename = string.sub(filename, 1, extpos - 1)
    local extname = string.sub(filename, extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end
--- 返回文件大小
-- @string path,文件路径全名例如:"/ldata/call.txt","test"
-- @return number ,文件大小
-- @usage locan cnt = io.fileSize("/ldata/call.txt")
function io.fileSize(path)
    local size = 0
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end
