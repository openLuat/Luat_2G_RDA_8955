--- 模块功能：HTTP客户端
-- @module httpv2
-- @author 稀饭放姜
-- @license MIT
-- @copyright OpenLuat.com
-- @release 2017.10.23
require 'socket'
require 'utils'
module(..., package.seeall)

local Content_type = {'application/x-www-form-urlencoded', 'application/json', 'application/octet-stream'}

-- 处理表的url编码
function urlencodeTab(params)
    local msg = {}
    for k, v in pairs(params) do
        table.insert(msg, string.urlencode(k) .. '=' .. string.urlencode(v))
        table.insert(msg, '&')
    end
    table.remove(msg)
    return table.concat(msg)
end
--- HTTP客户端
-- @string method,提交方式"GET" or "POST"
-- @string url,HTTP请求超链接
-- @number timeout,超时时间
-- @param params,table类型，请求发送的查询字符串，通常为键值对表
-- @param data,table类型，正文提交的body,通常为键值对、json或文件对象类似的表
-- @number ctype,Content-Type的类型(可选1,2,3),默认1:"urlencode",2:"json",3:"octet-stream"
-- @string basic,HTTP客户端的authorization basic验证的"username:password"
-- @param headers,table类型,HTTP headers部分
-- @return string,table,string,正常返回response_code, response_header, response_body
-- @return string,string,错误返回 response_code, error_message
-- @usage local c, h, b = httpv2.request(url, method, headers, body)
-- @usage local r, e  = httpv2.request("http://wrong.url/ ")
function request(method, url, timeout, params, data, ctype, basic, headers)
    local response_header, response_code, response_message, response_body, host, port, path, str, sub, len = {}
    local headers =
        headers or
        {
            ['User-Agent'] = 'Mozilla/4.0',
            ['Accept'] = '*/*',
            ['Accept-Language'] = 'zh-CN,zh,cn',
            ['Content-Type'] = 'application/x-www-form-urlencoded',
            ['Content-Length'] = '0',
            ['Connection'] = 'close'
        }
    -- 判断SSL支持是否满足
    local ssl, https = string.find(rtos.get_version(), 'SSL'), url:find('https://')
    if ssl == nil and https then
        return '401', 'SOCKET_SSL_ERROR'
    end
    -- 对host:port整形
    if url:find('://') then
        url = url:sub(8)
    end
    sub = url:find('/')
    if not sub then
        url = url .. '/'
        sub = -1
    end
    str = url:match('([%w%.%-%:]+)/')
    port = str:match(':(%d+)') or 80
    host = str:match('[%w%.%-]+')
    path = url:sub(sub)
    sub = ''
    -- 处理查询字符串
    if params ~= nil and type(params) == 'table' then
        path = path .. '?' .. urlencodeTab(params)
    end
    -- 处理HTTP协议body部分的数据
    ctype = ctype or 2
    headers['Content-Type'] = Content_type[ctype]
    if ctype == 1 and data ~= nil then
        if type(data) == 'table' then
            data = table.concat(data)
        end
        sub = urlencodeTab(data)
        len = string.len(sub)
        headers['Content-Length'] = len or 0
    elseif ctype == 2 and data ~= nil then
        if type(data) == 'table' then
            sub = json.encode(data)
        elseif type(data) == 'string' then
            sub = data
        end
        len = string.len(sub)
        headers['Content-Length'] = len or 0
    elseif ctype == 3 and type(data) == 'string' then
        len = io.filesize(data)
        headers['Content-Length'] = len or 0
    end
    -- 处理HTTP Basic Authorization 验证
    if basic ~= nil and type(basic) == 'string' then
        headers['Authorization'] = 'Basic ' .. crypto.base64_encode(basic, #basic)
    end
    -- 处理headers部分
    local msg = {}
    for k, v in pairs(headers) do
        table.insert(msg, k .. ': ' .. v)
    end
    -- 合并request报文
    str = str .. '\r\n' .. table.concat(msg, '\r\n') .. '\r\n\r\n'
    -- log.info("httpv2.request send:", str:tohex())
    -- 发送请求报文
    if not sys.waitUntil("IP_READY_IND", timeout) then return '502', 'SOCKET_TIMOUT_ERROR' end
    local c = socket.tcp()
    if not c:connect(host, port) then
        c:close()
        return '502', 'SOCKET_CONN_ERROR'
    end
    if ctype ~= 3 then
        str = method .. ' ' .. path .. ' HTTP/1.0\r\nHost: ' .. str .. sub .. '\r\n'
        if not c:send(str) then
            c:close()
            return '426', 'SOCKET_SEND_ERROR'
        end
    else
        str = method .. ' ' .. path .. ' HTTP/1.0\r\nHost: ' .. str
        if not c:send(str) then
            c:close()
            return '426', 'SOCKET_SEND_ERROR'
        end
        local file = io.open(data, 'r')
        if file then
            while true do
                local dat = file:read(1024)
                if dat == nil then
                    io.close(file)
                    break
                end
                log.info('httpv2.request dat:', dat:tohex())
                if not c:send(dat) then
                    io.close(file)
                    c:close()
                    return '426', 'SOCKET_SEND_ERROR'
                end
            end
        end
        if not c:send('\r\n') then
            c:close()
            return '426', 'SOCKET_SEND_ERROR'
        end
    end
    
    msg = {}
    local r, s = c:recv(timeout)
    if not r then
        return '503', 'SOCKET_RECV_TIMOUT'
    end
    response_code = s:match(' (%d+) ')
    response_message = s:match(' (%a+)')
    log.info('httpv2.response code and message:\t', response_code, response_message)
    for k, v in s:gmatch('([%a%-]+): (%C+)') do
        response_header[k] = v
    end
    local gzip = s:match('%aontent%-%ancoding: (%a+)')
    while true do
        table.insert(msg, s)
        r, s = c:recv(timeout)
        if not r then
            break
        end
    end
    c:close()
    str = table.concat(msg)
    sub, len = str:find('\r?\n\r?\n')
    if gzip then
        return response_code, response_header, ((zlib.inflate(table.concat(msg))):read())
    end
    return response_code, response_header, str:sub(len + 1, -1)
end
