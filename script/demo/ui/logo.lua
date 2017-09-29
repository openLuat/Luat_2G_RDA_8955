--[[
模块名称：logo
模块功能：显示开机欢迎语和logo图片
模块最后修改时间：2017.08.08
]]

module(...,package.seeall)

require"uiwin"
require"prompt"
require"idle"

--清空LCD显示缓冲区
disp.clear()
if lcd.WIDTH==128 and lcd.HEIGHT==128 then
--显示logo图片
disp.putimage("/ldata/logo_"..(lcd.BPP==1 and "mono.bmp" or "color.png"),lcd.BPP==1 and 41 or 0,lcd.BPP==1 and 18 or 0)
else
--从坐标16,0位置开始显示"欢迎使用Luat"
disp.puttext("欢迎使用Luat",16,0)
--显示logo图片
disp.putimage("/ldata/logo_"..(lcd.BPP==1 and "mono.bmp" or "color.png"),lcd.BPP==1 and 41 or 1,lcd.BPP==1 and 18 or 33)
end
--刷新LCD显示缓冲区到LCD屏幕上
disp.update()

--5秒后，打开提示框窗口，提示"3秒后进入待机界面"
--提示框窗口关闭后，自动进入待机界面
sys.timer_start(prompt.open,5000,"3秒后","进入待机界面",nil,idle.open)