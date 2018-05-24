--- 模块功能：ADC功能测试.
-- ADC测量精度(10bit，电压测量范围为0到1.85V，分辨率为1850/1024=1.8MV，测量精度误差为20MV)
-- 每隔1s读取一次ADC值
-- @author openLuat
-- @module adc.testAdc
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.14

module(...,package.seeall)

local ADC_ID = 0

--- ADC读取测试
-- @return 无
-- @usage read()
local function read()
	-- 打开adc
	adc.open(ADC_ID)
	-- 读取adc
	-- adcval为number类型，表示adc的原始值，无效值为0xFFFF
	-- voltval为number类型，表示转换后的电压值，单位为毫伏，无效值为0xFFFF；adc.read接口返回的voltval放大了3倍，所以需要除以3还原成原始电压
	local adcval,voltval = adc.read(ADC_ID)
	log.info("testAdc.read",adcval,(voltval-(voltval%3))/3,voltval)
	--如果adcval有效
	if adcval and adcval~=0xFFFF then
	end
	--如果voltval有效	
	if voltval and voltval~=0xFFFF then
		--adc.read接口返回的voltval放大了3倍，所以此处除以3
		voltval = (voltval-(voltval%3))/3
	end
end

sys.timerLoopStart(read,1000)
