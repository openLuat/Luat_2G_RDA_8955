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
function safeosdate(s,t)
    if s == "*t" then
        return oldosdate(s,t) or {year = 2012,
                month = 12,
                day = 11,
                hour = 10,
                min = 9,
                sec = 0}
    else
        return oldosdate(s,t)
    end
end

--Lua自带的os.date接口指向自定义的safeosdate接口
os.date = safeosdate

