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
--从坐标16,0位置开始显示"欢迎使用Luat"
disp.puttext("欢迎使用Luat",16,0)
--从坐标41,18位置开始显示图片logo.bmp
disp.putimage("/ldata/logo.bmp",41,18)
--刷新LCD显示缓冲区到LCD屏幕上
disp.update()

--5秒后，打开提示框窗口，提示"3秒后进入待机界面"
--提示框窗口关闭后，自动进入待机界面
sys.timer_start(prompt.open,5000,"3秒后","进入待机界面",nil,idle.open)