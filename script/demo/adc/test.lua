--[[
模块名称：ADC测试(adc精度为10bit，电压测量范围为0到1.85V，测量精度为20MV)
模块功能：测试ADC功能
模块最后修改时间：2017.07.22
]]

module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end

--adc id
local ADC_ID = 0

local function read()	
	--打开adc
	adc.open(ADC_ID)
	--读取adc
	--adcval为number类型，表示adc的原始值，无效值为0xFFFF
	--voltval为number类型，表示转换后的电压值，单位为毫伏，无效值为0xFFFF；adc.read接口返回的voltval放大了3倍，所以需要除以3还原成原始电压
	local adcval,voltval = adc.read(ADC_ID)
	print("adc.read",adcval,voltval/3,voltval)
	--如果adcval有效
	if adcval and adcval~=0xFFFF then
	end
	--如果voltval有效	
	if voltval and voltval~=0xFFFF then
		--adc.read接口返回的voltval放大了3倍，所以此处除以3
		voltval = voltval/3
	end
end

sys.timer_loop_start(read,1000)

