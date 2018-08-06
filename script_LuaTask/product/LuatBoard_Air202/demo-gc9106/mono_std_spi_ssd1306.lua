--- 模块功能：SSD 1306驱动芯片LCD命令配置
-- @author openLuat
-- @module qrcode.mono_std_spi_ssd1306
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27
--[[
注意：此文件的配置，硬件上使用的是标准的SPI引脚，不是LCD专用的SPI引脚
disp库目前仅支持SPI接口的屏，硬件连线图如下：
Air模块 LCD
GND--地
SPI_CS--片选
SPI_CLK--时钟
SPI_DO--数据
SPI_DI--数据/命令选择
VDDIO--电源
UART1_CTS--复位
注意：Air202早期的开发板，UART1的CTS和RTS的丝印反了
]]
module(..., package.seeall)


--- 初始化LCD参数
-- @param hc,屏幕颜色正显还是反显，可选值0或0xFFFF
-- @return 无
function init(hc)
    if type(hc) ~= "number" then hc = 0x0 end
    --控制SPI引脚的电压域
    pmd.ldoset(6, pmd.LDO_VMMC)
    local para = {
        width = 128, --分辨率宽度，128像素；用户根据屏的参数自行修改
        height = 160, --分辨率高度，64像素；用户根据屏的参数自行修改
        bpp = 16, --位深度，1表示单色。单色屏就设置为1，不可修改
        bus = disp.BUS_SPI, --led位标准SPI接口，不可修改
        xoffset = 0, -- x轴偏移
        yoffset = 32, --Y轴偏移
        freq = 110000,
        -- hwfillcolor = 0xFFFF, --填充色，白色
        hwfillcolor = 0x0, --填充色，黑色
        pinrst = pio.P0_3, --reset，复位引脚
        pinrs = pio.P0_12, --rs，命令/数据选择引脚
        --初始化命令
        initcmd = {
            0xfe,
            0xef,
            0xb3,
            0x0030003,
            0x21,
            0x36,
            0x0030008,
            0x3a,
            0x0030006,
            0xb4,
            0x0030021,
            0xF0,
            0x003002d,
            0x0030054,
            0x0030024,
            0x0030061,
            0x00300ab,
            0x003002e,
            0x003002f,
            0x0030000,
            0x0030020,
            0x0030010,
            0x0030010,
            0x0030017,
            0x0030013,
            0x003000f,
            0xF1,
            0x0030002,
            0x0030022,
            0x0030025,
            0x0030035,
            0x00300a8,
            0x0030008,
            0x0030008,
            0x0030000,
            0x0030000,
            0x0030009,
            0x0030009,
            0x0030017,
            0x0030018,
            0x003000f,
            0xfe,
            0xff,
            0x11,
            0x010078,
            0x29,
        },
        --休眠命令
        sleepcmd = {
            0xfe,
            0xef,
            0x28,
            0x010078,
            0x10,
            0x010096,
        },
        --唤醒命令
        wakecmd = {
            0xfe,
            0xef,
            0x11,
            0x010078,
            0x29,
        }
    }
    para.hwfillcolor = hc or 0x0
    disp.init(para)
    disp.clear()
    disp.update()
end
