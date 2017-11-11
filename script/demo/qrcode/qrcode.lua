--[[
模块名称：二维码生成并显示到屏幕上
模块最后修改时间：2017.11.10
]]

module(...,package.seeall)
require"qrencode"
require"string"
--根据自己的lcd类型以及使用的spi引脚，打开下面的其中一个文件进行测试，
--！！！！！！！！！！！！！！！！！！！！！！！！
--！！！！以下文件从demo/ui 目录中引用！！！！！！
--！！！！！！！！！！！！！！！！！！！！！！！！
--mono表示黑白屏，color表示彩屏
--standard_spi表示使用标准的SPI引脚，lcd_spi表示使用LCD专用的SPI引脚
--require"mono_standard_spi_ssd1306"
--require"mono_standard_spi_st7567"
require"color_standard_spi_st7735"
--require"mono_lcd_spi_ssd1306"
--require"mono_lcd_spi_st7567"
--require"color_lcd_spi_st7735"
--require"color_lcd_spi_gc9106"
--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("QR",...)
end

--[[
函数名：ArrayToBin
功能  ：table数组转string
]]
function ArrayToBin(Array)
    if Len == nil or Len > #Array then
        Len = #Array
    end
	local buf = ""
	local deal_len,dummy_len = 0,0
	while deal_len < Len do
		if (Len - deal_len) > 5120 then
			dummy_len = 5120
		else
			dummy_len = Len - deal_len
		end
		buf = buf .. string.char(unpack(Array, 1 + deal_len, dummy_len + deal_len))
		deal_len = deal_len + dummy_len
	end
	return buf
end

--[[
函数名：create
功能  ：生成用户期望的二维码点阵，以下参数和返回值，没有说明时，均为number型
参数  ：data 需要转换成二维码的数据，string型，如果输入类型错误，直接返回nil nil nil 0
参数  :	wide 用户屏幕宽度
参数  :	high 用户屏幕的高度，bpp,wide,high任意一个参数不正确时，输出原始点阵，不做变换
返回值：buf 二维码点阵 table型 w 宽度 h 高度 isfix 是否经过变换，0为没有
]]
function create(data, wide, high)
	--build方式产生的，是灰度点阵图像

	local isfix = 0
	local newbuf ={0}
	if (type(data) ~= "string") then
		return nil,nil,nil,0
	end
	local w,h,buf = qrencode.build(data)
    --print(wd, ht, #buf,)
	--根据bpp，wide，high将原始图像转换成用户屏幕上显示的图像
	if (type(wide) ~= "number" or type(high) ~= "number") then
		print(type(wide), type(high))
		return buf,w,h,isfix
	end

	if (wide < w or high < h) then
		print(wide,w,high,h)
		return buf,w,h,isfix
	end
	local x,y,d,dx,dy
	x = wide / w
	y = high / h
	d = (x > y) and y or x
	x = w * d
	y = h * d

	for i=1,x do
		for j=1,y do
			newbuf[i + (j - 1) * x] = 0xff
		end
	end
	for i=1,w do
		for j=1,h do
			if (buf[i + (j - 1) * w] ~= 0) then
				for m=i*d-(d-1), i*d do
					for n=j*d-(d-1), j*d do
						newbuf[m + (n - 1) * x] = 0
					end
				end
			end
		end
	end
	return newbuf,x,y,1
end


--[[
函数名：display
功能  ：在LCD上显示二维码
参数  ：data 显示的二维码的数据，由create接口产生，table型
参数  :	wide 二维码宽度
参数  :	high 二维码高度，一般情况下与宽度一致
参数  :	startx 二维码显示的起始X坐标，0开始
参数  :	starty 二维码显示的起始Y坐标，0开始
参数  :	force 二维码剩余空间是否强制刷白，0不是，其它是
返回值：实际显示的数据长度，如果为0，则表示有错误
]]
function display(data,wide,high,startx,starty,force)
	print(data,wide,high,startx,starty)
	return disp.putqrcode(ArrayToBin(data),wide,high,startx,starty,force)
end
