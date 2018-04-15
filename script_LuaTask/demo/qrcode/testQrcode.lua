--- 模块功能：二维码显示功能测试.
-- @author openLuat
-- @module qrcode.testQrcode
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"color_std_spi_st7735"
--require"mono_std_spi_ssd1306"

--LCD分辨率的宽度和高度(单位是像素)
WIDTH,HEIGHT = disp.getlcdinfo()

-- qrencode.encode(string) 创建二维码信息
-- @param string 二维码字符串
-- @return width 生成的二维码信息宽度
-- @return data 生成的二维码数据
-- @usage local width, data = qrencode.encode("http://www.openluat.com")
local width, data = qrencode.encode('http://www.openluat.com')

-- disp.putqrcode(data, width, display_width, x, y) 显示二维码
-- @param data 从qrencode.encode返回的二维码数据
-- @param width 二维码数据的实际宽度
-- @param display_width 二维码实际显示宽度
-- @param x 二维码显示起始坐标x
-- @param y 二维码显示起始坐标y

--- 二维码显示函数
local function appQRCode()
    disp.clear()
    disp.drawrect(0, 0, WIDTH-1, HEIGHT-1, WHITE)
    local displayWidth = (WIDTH>HEIGHT and HEIGHT or WIDTH)-4
    disp.putqrcode(data, width, displayWidth, (WIDTH-displayWidth)/2, (HEIGHT-displayWidth)/2)
    disp.update()
end

appQRCode()
