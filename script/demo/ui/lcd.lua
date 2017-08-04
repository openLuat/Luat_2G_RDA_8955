module(...,package.seeall)
--https://wenku.baidu.com/view/16ad716df8c75fbfc67db231.html
local function init()
	local para =
	{
		width = 128,
		height = 64,
		bpp = 1,
		--xoffset = 32,
		--yoffset = 64,
		bus = disp.BUS_SPI,
		hwfillcolor = 0xFFFF,
		pinrst = pio.P0_2,
		pinrs = pio.P0_12,
		initcmd =
		{
			0xE2, --soft reset
			0xA3, --设置偏压比：  0XA2：BIAS=1/9 (常用) 0XA3：BIAS=1/7 
			0xA0, --显示列地址增减：  0xA0：常规：列地址从左到右， 0xA1：反转：列地址从右到左
			0xC8, --行扫描顺序选择：  0XC0:普通扫描顺序：从上到下 0XC8:反转扫描顺序：从下到上
			0xA6, --显示正显/反显: 0xA6：常规：正显 0xA7：反显 
			0x2F, --选择内部电压供应操作模式 通常是 0x2C,0x2E,0x2F 三条 指令按顺序紧接着写，表示依次打开内部升压、电压调整电路、电压跟随器。也可以单单写0x2F，一次性打开三部分电路
			0x23, --选择内部电阻比例（Rb/Ra）:可以理解为粗调对比度值。可设置范围为：0x20～0x27， 数值越大对比度越浓，越小越淡
			0x81, --设置内部电阻微调，可以理解为微调对比度值，此两个指令需紧接着使用。上面一条指令0x81是不改的，下面一条指令可设置范围为：0x00～0x3F,数值越大对比度越浓，越小越淡
			0x2E,
			0x60, --设置显示存储器的显示初始行,可设置值为0X40~0X7F,分别代表第0～63行，针对该液晶屏一般设置为0x60
			0xAF, --显示开/关: 0XAE:关，0XAF：开
		},
		sleepcmd = {
			0xAE,
		},
		wakecmd = {
			0xAF,
		}
	}
	print("lcd init")
	disp.init(para)
	disp.clear()
	disp.puttext("欢迎使用Luat",16,24)
	disp.update()
end

local function displogo()
	disp.clear()
	disp.putimage("/ldata/logo.bmp",0,0)
	disp.update()
end

pmd.ldoset(6,pmd.LDO_VMMC)
init()
sys.timer_start(displogo,3000)
