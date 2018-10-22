--- 模块功能：二维码显示功能测试.
-- @author openLuat
-- @module qrcode.testQrcode
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(..., package.seeall)

--require"color_std_spi_st7735"
require "mono_std_spi_ssd1306"

-- 定义黑白色值
BLACK, WHITE = 0, 0xffff

--LCD分辨率的宽度和高度(单位是像素)
WIDTH, HEIGHT = disp.getlcdinfo()

-- qrencode.encode(string) 创建二维码信息
-- @param string 二维码字符串
-- @return width 生成的二维码信息宽度
-- @return data 生成的二维码数据
-- @usage local width, data = qrencode.encode("http://www.openluat.com")
local width, data = qrencode.encode('http://www.openluat.com')

-- disp.putqrcode(data, width, display_width, x, y) 显示二维码
-- @param data 从qrencode.encode返回的二维码数据
-- @param width 二维码数据的实际宽度
-- @param display_width 二维码实际显示宽度，实际显示宽度开根号需要是整数
-- @param x 二维码显示起始坐标x
-- @param y 二维码显示起始坐标y

--- 二维码显示函数
local function appQRCode()
    if HEIGHT >= 100 then
        disp.clear()
        disp.drawrect(0, 0, WIDTH - 1, HEIGHT - 1, WHITE)
        local displayWidth = 100
        disp.putqrcode(data, width, displayWidth, (WIDTH - displayWidth) / 2, (HEIGHT - displayWidth) / 2)
    else
        -- 黑白屏演示代码 黑底白色 左边显示hello 右边显示二维码
        disp.setbkcolor(BLACK)
        disp.setcolor(WHITE)
        disp.clear()
        disp.puttext('hello', 0, 0)
        disp.drawrect(64, 0, WIDTH - 1, HEIGHT - 1, WHITE)
        local displayWidth = 50
        disp.putqrcode(data, width, displayWidth, 64 + (64 - displayWidth) / 2, (HEIGHT - displayWidth) / 2)
    end
    disp.update()
end

appQRCode()
