--[[
模块名称：lcd
模块功能：lcd适配接口
模块最后修改时间：2017.08.17
]]

require"lcd_ssd1306"
--require"lcd_st7567"
module(...,package.seeall)

--LCD分辨率的宽度和高度(单位是像素)
WIDTH,HEIGHT = 128,64
--1个ASCII字符宽度为8像素，高度为16像素；汉字宽度和高度都为16像素
CHAR_WIDTH = 8

--[[
函数名：getxpos
功能  ：计算字符串居中显示的X坐标
参数  ：
		str：string类型，要显示的字符串
返回值：X坐标
]]
function getxpos(str)
	return (WIDTH-string.len(str)*CHAR_WIDTH)/2
end
