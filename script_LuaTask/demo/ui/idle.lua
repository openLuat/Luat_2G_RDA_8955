--- 模块功能：待机界面
-- @author openLuat
-- @module ui.idle
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"misc"
require"ntp"
require"common"

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
    disp.puttext(common.utf8ToGb2312("待机界面"),lcd.getxpos(common.utf8ToGb2312("待机界面")),0)
    local tm = misc.getClock()
    local datestr = string.format("%04d",tm.year).."-"..string.format("%02d",tm.month).."-"..string.format("%02d",tm.day)
    local timestr = string.format("%02d",tm.hour)..":"..string.format("%02d",tm.min)
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
    onUpdate = refresh,
}

--[[
函数名：clkind
功能  ：时间更新处理
参数  ：无
返回值：无
]]
local function clkind()
    if uiWin.isActive(appid) then
        refresh()
    end    
end

--[[
函数名：open
功能  ：打开待机界面窗口
参数  ：无
返回值：无
]]
function open()
    appid = uiWin.add(winapp)
end

ntp.timeSync()
sys.timerLoopStart(clkind,60000)
