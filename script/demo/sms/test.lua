--[[
模块名称：短信测试
模块功能：短信发送和接收测试
模块最后修改时间：2017.02.20
]]
require"sms"
module(...,package.seeall)

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上smsapp前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("test",...)
end


-----------------------------------------短信接收功能测试[开始]-----------------------------------------
local function procnewsms(num,data,datetime)
	print("procnewsms",num,data,datetime)
end

sms.regnewsmscb(procnewsms)
-----------------------------------------短信接收功能测试[结束]-----------------------------------------





-----------------------------------------短信发送测试[开始]-----------------------------------------
local function sendtest1(result,num,data)
	print("sendtest1",result,num,data)
end

local function sendtest2(result,num,data)
	print("sendtest2",result,num,data)
end

local function sendtest3(result,num,data)
	print("sendtest3",result,num,data)
end

local function sendtest4(result,num,data)
	print("sendtest4",result,num,data)
end

sms.send("10086","111111",sendtest1)
sms.send("10086","第2条短信",sendtest2)
sms.send("10086","qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432",sendtest3)
sms.send("10086","华康是的撒qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432",sendtest4)
-----------------------------------------短信发送测试[结束]-----------------------------------------
