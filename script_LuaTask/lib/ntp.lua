--- 模块功能：网络授时.
-- 重要提醒！！！！！！
-- 本功能模块采用多个免费公共的NTP服务器来同步时间
-- 并不能保证任何时间任何地点都能百分百同步到正确的时间
-- 所以，如果用户项目中的业务逻辑严格依赖于时间同步功能
-- 则不要使用使用本功能模块，建议使用自己的应用服务器来同步时间
-- 参考 http://ask.openluat.com/article/912 加深对授时功能的理解
-- @module ntp
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.10.21
require "misc"
require "socket"
require "utils"
require "log"
local sbyte, ssub = string.byte, string.sub
module(..., package.seeall)
-- NTP服务器域名集合
local timeServer = {
    "cn.pool.ntp.org",
    "edu.ntp.org.cn",
    "cn.ntp.org.cn",
    "s2c.time.edu.cn",
    "time1.aliyun.com",
    "tw.pool.ntp.org",
    "0.cn.pool.ntp.org",
    "0.tw.pool.ntp.org",
    "1.cn.pool.ntp.org",
    "1.tw.pool.ntp.org",
    "3.cn.pool.ntp.org",
    "3.tw.pool.ntp.org",
}
-- 同步超时等待时间
local NTP_TIMEOUT = 8000
-- 同步是否完成标记
local ntpEnd = false

--- 获取NTP服务器地址列表
-- @return table,服务器地址列表
-- @usage local addtable = ntp.getServers()
function getServers()
    return timeServer
end

--- 设置NTP服务器地址列表
-- @param st,tab类型，服务器地址列表
-- @return 无
-- @usage ntp.getServers({"1edu.ntp.org.cn","cn.ntp.org.cn"})
function setServers(st)
    timeServer = st
end

--- NTP同步标志
-- @return boole,NTP的同步状态true为成功,fasle为失败
-- @usage local sta = ntp.isEnd()
function isEnd()
    return ntpEnd
end

--- 同步时间，每个NTP服务器尝试3次，超时8秒,适用于被任务函数调用
-- @param ts,每隔ts小时同步1次
-- @param fnc,同步成功后回调函数
-- @param fun,同步成功前回调函数
-- @return 无
-- @usage ntp.ntpTime() -- 只同步1次
-- @usage ntp.ntpTime(1) -- 1小时同步1次
-- @usage ntp.ntpTime(nil,fnc) -- 只同步1次，同步成功后执行fnc()
-- @usage ntp.ntpTime(24,fnc) -- 24小时同步1次，同步成功后执行fnc()
function ntpTime(ts, fnc, fun)
    local rc, data, ntim
    ntpEnd = false
    while true do
        local tUnusedSvr = {}
        for i = 1, #timeServer do
            tUnusedSvr[i] = timeServer[i]
        end
        for i = 1, #timeServer do
            while not socket.isReady() do sys.waitUntil('IP_READY_IND') end
            local c = socket.udp()
            local idx = rtos.tick() % #tUnusedSvr + 1
            if c:connect(tUnusedSvr[idx], "123") then
                if c:send(string.fromHex("E30006EC0000000000000000314E31340000000000000000000000000000000000000000000000000000000000000000")) then
                    rc, data = c:recv(NTP_TIMEOUT)
                    if rc and #data == 48 then
                        ntim = os.date("*t", (sbyte(ssub(data, 41, 41)) - 0x83) * 2 ^ 24 + (sbyte(ssub(data, 42, 42)) - 0xAA) * 2 ^ 16 + (sbyte(ssub(data, 43, 43)) - 0x7E) * 2 ^ 8 + (sbyte(ssub(data, 44, 44)) - 0x80) + 1)
                        if type(fun) == "function" then fun() end
                        misc.setClock(ntim, fnc)
                        ntpEnd = true
                        c:close()
                        break
                    end
                end
            end
            
            local cnt, n, m = #tUnusedSvr, 1
            for m = 1, cnt do
                if m ~= idx then
                    tUnusedSvr[n] = tUnusedSvr[m]
                    n = n + 1
                end
            end
            tUnusedSvr[cnt] = nil
            
            c:close()
            sys.wait(1000)
        end
        if ntpEnd then
            sys.publish("NTP_SUCCEED")
            log.info("ntp.timeSync is date:", ntim.year .. "/" .. ntim.month .. "/" .. ntim.day .. "," .. ntim.hour .. ":" .. ntim.min .. ":" .. ntim.sec)
            if ts == nil or type(ts) ~= "number" then break end
            sys.wait(ts * 3600 * 1000)
        else
            log.warn("ntp.timeSync is error!")
            sys.wait(1000)
        end
    end
end
---  自动同步时间任务适合独立执行.
-- 重要提醒！！！！！！
-- 本功能模块采用多个免费公共的NTP服务器来同步时间
-- 并不能保证任何时间任何地点都能百分百同步到正确的时间
-- 所以，如果用户项目中的业务逻辑严格依赖于时间同步功能
-- 则不要使用使用本功能模块，建议使用自己的应用服务器来同步时间
-- @return 无
-- @param ts,每隔ts小时同步1次
-- @param fnc,同步成功后回调函数
-- @param fun,同步成功前回调函数
-- @usage ntp.timeSync() -- 只同步1次
-- @usage ntp.timeSync(1) -- 1小时同步1次
-- @usage ntp.timeSync(nil,fnc) -- 只同步1次，同步成功后执行fnc()
-- @usage ntp.timeSync(24,fnc) -- 24小时同步1次，同步成功后执行fnc()
function timeSync(ts, fnc, fun)
    sys.taskInit(ntpTime, ts, fnc, fun)
end
