--- 模块功能：数据链路激活、SOCKET管理(创建、连接、数据收发、状态维护)
-- @module socket
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.9.25
require"link"
require"utils"
module(..., package.seeall)

local req = ril.request

local valid = {"0", "1", "2", "3", "4", "5", "6", "7"}
local validSsl = {"0", "1", "2", "3", "4", "5", "6", "7"}
local sockets = {}
local socketsSsl = {}
-- 单次发送数据最大值
local SENDSIZE = 1460
local SENDSIZE_SSL = 10240
-- 缓冲区最大下标
local INDEX_MAX = 49

--- SOCKET 是否有可用
-- @return 可用true,不可用false
socket.isReady = link.isReady

local function isSocketActive(ssl)
    for _, c in pairs(ssl and socketsSsl or sockets) do
        if c.connected then
            return true
        end
    end
end

local function socketStatusNtfy()
    sys.publish("SOCKET_ACTIVE",isSocketActive() or isSocketActive(true))
end

local function errorInd(error)
    for k,v in pairs({sockets,socketsSsl}) do
        for _, c in pairs(v) do -- IP状态出错时，通知所有已连接的socket
            if c.connected or c.created then
                if error == 'CLOSED' and not c.ssl then c.connected = false socketStatusNtfy() end
                c.error = error
                coroutine.resume(c.co, false)
            end
        end
    end
end

sys.subscribe("IP_ERROR_IND", function() errorInd('IP_ERROR_IND') end)
sys.subscribe('IP_SHUT_IND', function() errorInd('CLOSED') end)

--订阅rsp返回的消息处理函数
local function onSocketURC(data, prefix)
    local tag, id, result = string.match(data, "([SSL]*)[&]*(%d), *([%u :%d]+)")
    tSocket = (tag=="SSL" and socketsSsl or sockets)
    if not id or not tSocket[id] then
        log.error('socket: urc on nil socket', data, id, tSocket[id], socketsSsl[id])
        return
    end
    
    if result == "CONNECT OK" or result:match("CONNECT ERROR") or result:match("CONNECT FAIL") then
        if tSocket[id].wait == "+CIPSTART" or tSocket[id].wait == "+SSLCONNECT" then
            coroutine.resume(tSocket[id].co, result == "CONNECT OK")
        else
            log.error("socket: error urc", tSocket[id].wait)
        end
        return
    end
    
    if tag=="SSL" and string.find(result,"ERROR:")==1 then return end
    
    if string.find(result, "ERROR") or result == "CLOSED" then
        if result == 'CLOSED' and not tSocket[id].ssl then tSocket[id].connected = false socketStatusNtfy() end
        tSocket[id].error = result
        coroutine.resume(tSocket[id].co, false)
    end
end
-- 创建socket函数
local mt = {__index = {}}
local function socket(protocol, cert)
    local ssl = protocol:match("SSL")
    local id = table.remove(ssl and validSsl or valid)
    if not id then
        log.warn("socket.socket: too many sockets")
        return nil
    end
    
    local co = coroutine.running()
    if not co then
        log.warn("socket.socket: socket must be called in coroutine")
        return nil
    end
    -- 实例的属性参数表
    local o = {
        id = id,
        protocol = protocol,
        ssl = ssl,
        cert = cert,
        co = co,
        input = {},
        wait = "",
    }
    
    tSocket = (ssl and socketsSsl or sockets)
    tSocket[id] = o
    
    return setmetatable(o, mt)
end
--- 创建基于TCP的socket对象
-- @bool[opt=nil] ssl，是否为ssl连接，true表示是，其余表示否
-- @table[opt=nil] cert，ssl连接需要的证书配置，只有ssl参数为true时，才参数才有意义，cert格式如下：
-- {
--     caCert = "ca.crt", --CA证书文件(Base64编码 X.509格式)，如果存在此参数，则表示客户端会对服务器的证书进行校验；不存在则不校验
--     clientCert = "client.crt", --客户端证书文件(Base64编码 X.509格式)，服务器对客户端的证书进行校验时会用到此参数
--     clientKey = "client.key", --客户端私钥文件(Base64编码 X.509格式)
--     clientPassword = "123456", --客户端证书文件密码[可选]
-- }
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage 
-- c = socket.tcp()
-- c = socket.tcp(true)
-- c = socket.tcp(true, {caCert="ca.crt"})
-- c = socket.tcp(true, {caCert="ca.crt", clientCert="client.crt", clientKey="client.key"})
-- c = socket.tcp(true, {caCert="ca.crt", clientCert="client.crt", clientKey="client.key", clientPassword="123456"})
function tcp(ssl,cert)
    return socket("TCP"..(ssl==true and "SSL" or ""), (ssl==true) and cert or nil)
end
--- 创建基于UDP的socket对象
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage c = socket.udp()
function udp()
    return socket("UDP")
end

local sslInited
local tSslInputCert,sSslInputCert = {},""

local function sslInit()
    if not sslInited then
        sslInited = true
        req("AT+SSLINIT")        
    end
    
    local i,item
    for i=1,#tSslInputCert do
        item = table.remove(tSslInputCert,1)
        req(item.cmd,item.arg)
    end
    tSslInputCert = {}
end

local function sslTerm()
    if sslInited then
        if not isSocketActive(true) then
            sSslInputCert,sslInited = ""
            req("AT+SSLTERM")
        end
    end
end

local function sslInputCert(t,f)
    if sSslInputCert:match(t..f.."&") then return end
    if not tSslInputCert then tSslInputCert={} end
    local s = io.readFile((f:sub(1,1)=="/") and f or ("/ldata/"..f))
    if not s then log.error("inputcrt err open",path) return end
    table.insert(tSslInputCert,{cmd="AT+SSLCERT=0,\""..t.."\",\""..f.."\",1,"..s:len(), arg=s or ""})
    sSslInputCert = sSslInputCert..t..f.."&"
end

--- 连接服务器
-- @string address 服务器地址，支持ip和域名
-- @param port string或者number类型，服务器端口
-- @return bool result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect();
function mt.__index:connect(address, port)
    assert(self.co == coroutine.running(), "socket:connect: coroutine mismatch")
    
    if not link.isReady() then
        log.info("socket.connect: ip not ready")
        return false
    end
    
    if cc and cc.anyCallExist() then
        log.info("socket:connect: call exist, cannot connect")
        return false
    end
    
    if self.ssl then
        local tConfigCert,i = {}
        if self.cert then
            if self.cert.caCert then
                sslInputCert("cacrt",self.cert.caCert)
                table.insert(tConfigCert,"AT+SSLCERT=1,"..self.id..",\"cacrt\",\""..self.cert.caCert.."\"")
            end
            if self.cert.clientCert then
                sslInputCert("localcrt",self.cert.clientCert)
                table.insert(tConfigCert,"AT+SSLCERT=1,"..self.id..",\"localcrt\",\""..self.cert.clientCert.."\",\""..(self.cert.clientPassword or "").."\"")
            end
            if self.cert.clientKey then
                sslInputCert("localprivatekey",self.cert.clientKey)
                table.insert(tConfigCert,"AT+SSLCERT=1,"..self.id..",\"localprivatekey\",\""..self.cert.clientKey.."\"")
            end
        end
        
        sslInit()
        req(string.format("AT+SSLCREATE=%d,\"%s\",%d", self.id, address..":"..port, (self.cert and self.cert.caCert) and 0 or 1))
        self.created = true
        for i=1,#tConfigCert do
            req(tConfigCert[i])
        end
        req("AT+SSLCONNECT="..self.id)
    else
        req(string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s", self.id, self.protocol, address, port))
    end
    
    ril.regUrc((self.ssl and "SSL&" or "")..self.id, onSocketURC)
    self.wait = self.ssl and "+SSLCONNECT" or "+CIPSTART"
    if coroutine.yield() == false then
        if self.ssl then self:sslDestroy() end
        return false
    end
    self.connected = true
    socketStatusNtfy()
    return true
end
--- 发送数据
-- @string data 数据
-- @return result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect(); c:send("12345678");
function mt.__index:send(data)
    assert(self.co == coroutine.running(), "socket:send: coroutine mismatch")
    if self.error then
        log.warn('socket.client:send', 'error', self.error)
        return false
    end
    if self.id==nil then
        log.warn('socket.client:send', 'closed')
        return false
    end

    for i = 1, string.len(data), (self.ssl and SENDSIZE_SSL or SENDSIZE) do
        -- 按最大MTU单元对data分包
        local stepData = string.sub(data, i, i + SENDSIZE - 1)
        --发送AT命令执行数据发送
        req(string.format("AT+"..(self.ssl and "SSL" or "CIP").."SEND=%d,%d", self.id, string.len(stepData)), stepData)
        self.wait = self.ssl and "+SSLSEND" or "+CIPSEND"
        if not coroutine.yield() then
            if self.ssl then self:sslDestroy() end
            return false
        end
    end
    return true
end
--- 接收数据
-- @number[opt=0] timeout 可选参数，接收超时时间
-- @return result true - 成功，false - 失败
-- @return data 如果成功的话，返回接收到的数据，超时时返回错误为"timeout"
-- @usage  c = socket.tcp(); c:connect(); result, data = c:recv()
function mt.__index:recv(timeout)
    assert(self.co == coroutine.running(), "socket:recv: coroutine mismatch")
    if self.error then
        log.warn('socket.client:recv', 'error', self.error)
        return false
    end

    if #self.input == 0 then
        self.wait = self.ssl and "+SSL RECEIVE" or "+RECEIVE"
        if timeout and timeout~=0 then
            local r, s = sys.wait(timeout)
            if r == nil then
                return false, "timeout"
            else
                if self.ssl and not r then self:sslDestroy() end
                return r, s
            end
        else
            return coroutine.yield()
        end
    end
    
    if self.protocol == "UDP" then
        return true, table.remove(self.input)
    else
        local s = table.concat(self.input)
        self.input = {}
        return true, s
    end
end

function mt.__index:sslDestroy()
    assert(self.co == coroutine.running(), "socket:sslDestroy: coroutine mismatch")
    if self.ssl and (self.connected or self.created) then
        self.connected = false
        self.created = false
        req("AT+SSLDESTROY=" .. self.id)
        self.wait = "+SSLDESTROY"
        coroutine.yield()
        socketStatusNtfy()
    end
end
--- 销毁一个socket
-- @return nil
-- @usage  c = socket.tcp(); c:connect(); c:send("123"); c:close()
function mt.__index:close()
    assert(self.co == coroutine.running(), "socket:close: coroutine mismatch")
    if self.connected or self.created then
        self.connected = false
        self.created = false
        req((self.ssl and "AT+SSLDESTROY=" or "AT+CIPCLOSE=") .. self.id)
        self.wait = self.ssl and "+SSLDESTROY" or "+CIPCLOSE"
        coroutine.yield()
        socketStatusNtfy()
    end
    if self.id~=nil then
        ril.deRegUrc((self.ssl and "SSL&" or "")..self.id, onSocketURC)
        table.insert((self.ssl and validSsl or valid), 1, self.id)
        if self.ssl then
            socketsSsl[self.id] = nil
        else
            sockets[self.id] = nil
        end
        self.id = nil
    end
end
local function onResponse(cmd, success, response, intermediate)
    local prefix = string.match(cmd, "AT(%+%u+)")
    local id = string.match(cmd, "AT%+%u+=(%d)")
    if response == '+PDP: DEACT' then sys.publish('PDP_DEACT_IND') end -- cipsend 如果正好pdp deact会返回+PDP: DEACT作为回应
    local tSocket = prefix:match("SSL") and socketsSsl or sockets
    if not tSocket[id] then
        log.warn('socket: response on nil socket', cmd, response)
        return
    end
    if tSocket[id].wait == prefix then
        if (prefix == "+CIPSTART" or prefix == "+SSLCONNECT") and success then
            -- CIPSTART,SSLCONNECT 返回OK只是表示被接受
            return
        end
        if (prefix == '+CIPSEND' or prefix == "+SSLSEND") and response:match("%d, *([%u%d :]+)") ~= 'SEND OK' then
            success = false
        end
        if not success then tSocket[id].error = response end
        coroutine.resume(tSocket[id].co, success)
    end
end

local function onSocketReceiveUrc(urc)
    local tag, id, len = string.match(urc, "([SSL]*) *RECEIVE,(%d), *(%d+)")
    tSocket = (tag=="SSL" and socketsSsl or sockets)
    len = tonumber(len)
    if len == 0 then return urc end
    local cache = {}
    local function filter(data)
        --剩余未收到的数据长度
        if string.len(data) >= len then -- at通道的内容比剩余未收到的数据多
            -- 截取网络发来的数据
            table.insert(cache, string.sub(data, 1, len))
            -- 剩下的数据仍按at进行后续处理
            data = string.sub(data, len + 1, -1)
            if not tSocket[id] then
                log.warn('socket: receive on nil socket', id)
            else
                local s = table.concat(cache)
                if tSocket[id].wait == "+RECEIVE" or tSocket[id].wait == "+SSL RECEIVE" then
                    coroutine.resume(tSocket[id].co, true, s)
                else -- 数据进缓冲区，缓冲区溢出采用覆盖模式
                    if #tSocket[id].input > INDEX_MAX then tSocket[id].input = {} end
                    table.insert(tSocket[id].input, s)
                end
            end
            return data
        else
            table.insert(cache, data)
            len = len - string.len(data)
            return "", filter
        end
    end
    return filter
end

ril.regRsp("+CIPCLOSE", onResponse)
ril.regRsp("+CIPSEND", onResponse)
ril.regRsp("+CIPSTART", onResponse)
ril.regRsp("+SSLDESTROY", onResponse)
ril.regRsp("+SSLSEND", onResponse)
ril.regRsp("+SSLCONNECT", onResponse)
ril.regUrc("+RECEIVE", onSocketReceiveUrc)
ril.regUrc("+SSL RECEIVE", onSocketReceiveUrc)

function printStatus()
    log.info('socket.printStatus', 'valid id', table.concat(valid), table.concat(validSsl))

    for m,n in pairs({sockets,socketsSsl}) do
        for _, client in pairs(n) do
            for k, v in pairs(client) do
                log.info('socket.printStatus', 'client', client.id, k, v)
            end
        end
    end
end
