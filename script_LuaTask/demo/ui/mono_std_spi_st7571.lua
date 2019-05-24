--- 模块功能：ST 7567驱动芯片LCD命令配置
-- @author openLuat
-- @module ui.mono_std_spi_st7567
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

--[[
注意：disp库目前支持I2C接口和SPI接口的屏，此文件的配置，硬件上使用的是标准的SPI引脚，不是LCD专用的SPI引脚
硬件连线图如下：
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

module(...,package.seeall)

--[[
函数名：init
功能  ：初始化LCD参数
参数  ：无
返回值：无
]]
local function init()
    local para =
    {
        width = 128, --分辨率宽度，128像素；用户根据屏的参数自行修改
        height = 96, --分辨率高度，96像素；用户根据屏的参数自行修改
        bpp = 1, --位深度，1表示单色。单色屏就设置为1，不可修改
        bus = disp.BUS_SPI, --led位标准SPI接口，不可修改
        hwfillcolor = 0xffff, --填充色，黑色
        yoffset = 0,
        pinrst = pio.P0_3, --reset，复位引脚
        pinrs = pio.P0_12, --rs，命令/数据选择引脚
        --初始化命令
		initcmd =
        {
           ----[[
            0xAE,--Display OFF
			0x38,--MODE SET
			0x7c,--频率 70Hz ±20% ,fficiency Level 4
			0x48,--Set Display Duty
			0x60,--
			0xA0,-- ADC select, ADC=1 =>reverse direction
            0xC8,-- SHL select, SHL=1 => reverse direction
			0x44,--Set initial COM0 register
            0x00,--
            0x40,--Set initial display line register
			0x00,--
			0xAB,-- OSC. ON
			0x66,--供电相关
			0x26,--电压之类的
			0x81,-- Set Reference Voltage
			0x32,--EV
			0x55,--Set LCD Bias
			0x93,-- Set FRC and PWM mode (4FRC & 15PWM)
            0x2c,-- Power Control, VC: ON  VR: OFF  VF: OFF
            0x000100c8, --延时200ms
            0x2e,-- Power Control, VC: ON  VR: ON  VF: OFF
            0x000100c8, --延时200ms
            0x2F,-- Power Control, VC: ON   VR: ON  VF: ON
            0x0001000f, --延时10ms
			0xAF,
			--]]

        },
		--]]
        --休眠命令
        sleepcmd = {
            0xAE,
        },
        --唤醒命令
        wakecmd = {
            0xAF,
        }
    }
    disp.init(para)
    disp.clear()
    disp.update()
end

require"pins"
local rs = pins.setup(pio.P0_12,0)
disp.update = function ()
    local pic = disp.getframe()
    rs(0)
    spi.send(spi.SPI_1,string.char(0xb0,0x10))--设置起始页与列
    rs(1)
    for i=1,pic:len() do--发数据
        local data = pic:sub(i,i)
        spi.send(spi.SPI_1,data)
        spi.send(spi.SPI_1,data)
    end
    rs(0)
end

--控制SPI引脚的电压域
pmd.ldoset(6,pmd.LDO_VMMC)
init()
