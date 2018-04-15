--[[
模块名称：idle
模块功能：待机界面
模块最后修改时间：2017.08.14
]]

module(...,package.seeall)

require"misc"

local ssub = string.sub

--appid：窗口id
local appid

--[[
函数名：refresh
功能  ：窗口刷新处理
参数  ：无
返回值：无
]]
local function refresh()
	--清空LCD显示缓冲区
	disp.clear()
	disp.puttext("待机界面",lcd.getxpos("待机界面"),0)
	local clkstr = "20"..misc.getclockstr()
	local datestr = ssub(clkstr,1,4).."-"..ssub(clkstr,5,6).."-"..ssub(clkstr,7,8)
	local timestr = ssub(clkstr,9,10)..":"..ssub(clkstr,11,12)
	--显示日期
	disp.puttext(datestr,lcd.getxpos(datestr),24)
	--显示时间
	disp.puttext(timestr,lcd.getxpos(timestr),44)
	--刷新LCD显示缓冲区到LCD屏幕上
	disp.update()
end

--窗口类型的消息处理函数表
local winapp =
{
	onupdate = refresh,
}

--[[
函数名：clkind
功能  ：时间更新处理
参数  ：无
返回值：无
]]
local function clkind()
	if uiwin.isactive(appid) then
		refresh()
	end
end

--非窗口类型的消息处理函数表
local msgapp =
{
	CLOCK_IND = clkind,
}

--[[
函数名：open
功能  ：打开待机界面窗口
参数  ：无
返回值：无
]]
function open()
	appid = uiwin.add(winapp)
	sys.regapp(msgapp)
end
