--- 模块功能：短信功能测试.
-- @author openLuat
-- @module sms.testSms
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"sms"

-----------------------------------------短信接收功能测试[开始]-----------------------------------------
local function procnewsms(num,data,datetime)
	log.info("testSms.procnewsms",num,data,datetime)
end

sms.setNewSmsCb(procnewsms)
-----------------------------------------短信接收功能测试[结束]-----------------------------------------





-----------------------------------------短信发送测试[开始]-----------------------------------------
local function sendtest1(result,num,data)
	log.info("testSms.sendtest1",result,num,data)
end

local function sendtest2(result,num,data)
	log.info("testSms.sendtest2",result,num,data)
end

local function sendtest3(result,num,data)
	log.info("testSms.sendtest3",result,num,data)
end

local function sendtest4(result,num,data)
	log.info("testSms.sendtest4",result,num,data)
end

sms.send("10086","111111",sendtest1)
--sms.send("10086",common.utf8ToGb2312("第2条短信"),sendtest2)
--sms.send("10086","qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432",sendtest3)
--sms.send("10086",common.utf8ToGb2312("华康是的撒qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432qeiuqwdsahdkjahdkjahdkja122136489759725923759823hfdskfdkjnbzndkjhfskjdfkjdshfkjdsfks83478648732432"),sendtest4)
-----------------------------------------短信发送测试[结束]-----------------------------------------
