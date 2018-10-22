--- 模块功能：界面显示
-- @module powerKey
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.09.25

require"audio"
module(..., package.seeall)

local winType = "IDLE"

local function display()
    disp.clear()
    
    if winType=="IDLE" then
        disp.puttext(common.utf8ToGb2312("1：键盘测试"),2,0)
        disp.puttext(common.utf8ToGb2312("4：扫码测试"),2,20)
        disp.puttext(common.utf8ToGb2312("7：拍照测试"),2,40)
    elseif winType=="KEY_TEST" then
        disp.puttext(common.utf8ToGb2312("接上喇叭再按键，语音播报听得见，连续5秒不按键， 自动退出此界面"),0,0)
        sys.timerStart(returnIdle,5000)
    elseif winType=="SCAN_TEST" then
        testCamera.scan()
    elseif winType=="PHOTO_TEST" then
        testCamera.takePhoto()
    end
    
    disp.update()
end

function returnIdle()
    winType = "IDLE"
    display()
end

function keyInd(key)
    if winType=="IDLE" then
        if key=="1" then
            winType = "KEY_TEST"
            display()
        elseif key=="4" then
            winType = "SCAN_TEST"
            display()
        elseif key=="7" then
            winType = "PHOTO_TEST"
            display()
        end        
    elseif winType=="KEY_TEST" then
        sys.timerStart(returnIdle,5000)
        audio.play(0,"TTS",key)
    end 
end

sys.subscribe("KEY_PRESSED",keyInd)
display()
