--- 模块功能：Lua补丁
-- @module patch
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.10.21

module(..., package.seeall)

--[[
模块名称：Lua自带接口补丁
模块功能：补丁某些Lua自带的接口，规避调用异常时死机
模块最后修改时间：2017.02.14
]]
--保存Lua自带的os.time接口
local oldostime = os.time

--[[
函数名：safeostime
功能  ：封装自定义的os.time接口
参数  ：
t：日期表，如果没有传入，使用系统当前时间
返回值：t时间距离1970年1月1日0时0分0秒所经过的秒数
]]
function safeostime(t)
    return oldostime(t) or 0
end

--Lua自带的os.time接口指向自定义的safeostime接口
os.time = safeostime

--保存Lua自带的os.date接口
local oldosdate = os.date

--[[
函数名：safeosdate
功能  ：封装自定义的os.date接口
参数  ：
s：输出格式
t：距离1970年1月1日0时0分0秒所经过的秒数
返回值：参考Lua自带的os.date接口说明
]]
function safeosdate(s, t)
    if s == "*t" then
        return oldosdate(s, t) or {year = 2012,
            month = 12,
            day = 11,
            hour = 10,
            min = 9,
            sec = 0}
    else
        return oldosdate(s, t)
    end
end

--Lua自带的os.date接口指向自定义的safeosdate接口
os.date = safeosdate

-- 对coroutine.resume加一个修饰器用于捕获协程错误
local rawcoresume = coroutine.resume
coroutine.resume = function(...)
    function wrapper(co,...)
        if not arg[1] then
            local traceBack = debug.traceback(co)
            traceBack = (traceBack and traceBack~="") and (arg[2].."\r\n"..traceBack) or arg[2]
            if errDump and errDump.appendErr and type(errDump.appendErr)=="function" then
                errDump.appendErr(traceBack)                
            else
                log.error("coroutine.resume",traceBack)
            end
            if _G.COROUTINE_ERROR_RESTART then rtos.restart() end
        end
        return unpack(arg)
    end
    return wrapper(arg[1],rawcoresume(unpack(arg)))
end

os.clockms = function() return rtos.tick()/16 end

--保存Lua自带的json.decode接口
if json and json.decode then oldjsondecode = json.decode end

--- 封装自定义的json.decode接口
-- @string s,json格式的字符串
-- @return table,第一个返回值为解析json字符串后的table
-- @return boole,第二个返回值为解析结果(true表示成功，false失败)
-- @return string,第三个返回值可选（只有第二个返回值为false时，才有意义），表示出错信息
local function safeJsonDecode(s)
    local result, info = pcall(oldjsondecode, s)
    if result then
        return info, true
    else
        return {}, false, info
    end
end

--Lua自带的json.decode接口指向自定义的safeJsonDecode接口
if json and json.decode then json.decode = safeJsonDecode end
