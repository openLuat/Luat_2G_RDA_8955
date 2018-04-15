--- 模块功能：提示框窗口
-- @author openLuat
-- @module ui.prompt
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

--appid：窗口id
--str1,str2,str3：最多显示的3行字符串
--callback,callbackpara：提示框窗口关闭后的回调函数以及回调函数的参数
local appid,str1,str2,str3,callback,callbackpara

local pos = 
{
    {24},--显示1行字符串时的Y坐标
    {10,37},--显示2行字符串时，每行字符串对应的Y坐标
    {4,24,44},--显示3行字符串时，每行字符串对应的Y坐标
}

--[[
函数名：refresh
功能  ：窗口刷新处理
参数  ：无
返回值：无
]]
local function refresh()
    disp.clear()
    if str3 then
        disp.puttext(str3,lcd.getxpos(str3),pos[3][3])
    end
    if str2 then
        disp.puttext(str2,lcd.getxpos(str2),pos[str3 and 3 or 2][2])
    end
    if str1 then
        disp.puttext(str1,lcd.getxpos(str1),pos[str3 and 3 or (str2 and 2 or 1)][1])
    end
    disp.update()
end

--[[
函数名：close
功能  ：关闭提示框窗口
参数  ：无
返回值：无
]]
local function close()
    if not appid then return end
    sys.timerStop(close)
    if callback then callback(callbackpara) end
    uiWin.remove(appid)
    appid = nil
end

--窗口的消息处理函数表
local app = {
    onUpdate = refresh,
}

--[[
函数名：open
功能  ：打开提示框窗口
参数  ：
        s1：string类型，显示的第1行字符串
        s2：string类型，显示的第2行字符串，可以为空或者nil
        s3：string类型，显示的第3行字符串，可以为空或者nil
        cb：function类型，提示框关闭时的回调函数，可以为nil
        cbpara：提示框关闭时回调函数的参数，可以为nil
        prd：number类型，提示框自动关闭的超时时间，单位毫秒，默认3000毫秒
返回值：无
]]
function open(s1,s2,s3,cb,cbpara,prd)
    str1,str2,str3,callback,callbackpara = s1,s2,s3,cb,cbpara
    appid = uiWin.add(app)
    sys.timerStart(close,prd or 3000)
end
