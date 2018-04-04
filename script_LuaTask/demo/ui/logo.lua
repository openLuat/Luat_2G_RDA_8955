--- 模块功能：LOGO界面
-- @author openLuat
-- @module ui.logo
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"uiWin"
require"prompt"
require"idle"

--清空LCD显示缓冲区
disp.clear()
if lcd.WIDTH==128 and lcd.HEIGHT==128 then
--显示logo图片
disp.putimage("/ldata/logo_"..(lcd.BPP==1 and "mono.bmp" or "color.png"),lcd.BPP==1 and 41 or 0,lcd.BPP==1 and 18 or 0)
elseif lcd.WIDTH==240 and lcd.HEIGHT==320 then
disp.puttext(common.utf8ToGb2312("欢迎使用Luat"),lcd.getxpos(common.utf8ToGb2312("欢迎使用Luat")),10)
--显示logo图片
disp.putimage("/ldata/logo_color_240X320.png",0,80)
else
--从坐标16,0位置开始显示"欢迎使用Luat"
disp.puttext(common.utf8ToGb2312("欢迎使用Luat"),lcd.getxpos(common.utf8ToGb2312("欢迎使用Luat")),0)
--显示logo图片
disp.putimage("/ldata/logo_"..(lcd.BPP==1 and "mono.bmp" or "color.png"),lcd.BPP==1 and 41 or 1,lcd.BPP==1 and 18 or 33)
end
--刷新LCD显示缓冲区到LCD屏幕上
disp.update()

--5秒后，打开提示框窗口，提示"3秒后进入待机界面"
--提示框窗口关闭后，自动进入待机界面
sys.timerStart(prompt.open,5000,common.utf8ToGb2312("3秒后"),common.utf8ToGb2312("进入待机界面"),nil,idle.open)

