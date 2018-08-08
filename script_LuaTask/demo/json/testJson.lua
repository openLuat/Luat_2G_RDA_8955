--- 模块功能：JSON功能测试.
-- @author openLuat
-- @module json.testJson
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

-----------------------encode测试------------------------
local torigin =
{
    KEY1 = "VALUE1",
    KEY2 = "VALUE2",
    KEY3 = "VALUE3",
    KEY4 = "VALUE4",
    KEY5 = {KEY5_1="VALU5_1",KEY5_2="VALU5_2"},
    KEY6 = {1,2,3},
}

local jsondata = json.encode(torigin)
log.info("testJson.encode",jsondata)
-----------------------encode测试------------------------




-----------------------decode测试------------------------
--{"KEY3":"VALUE3","KEY4":"VALUE4","KEY2":"VALUE2","KEY1":"VALUE1","KEY5":{"KEY5_2":"VALU5_2","KEY5_1":"VALU5_1"}},"KEY6":[1,2,3]}
local origin = "{\"KEY3\":\"VALUE3\",\"KEY4\":\"VALUE4\",\"KEY2\":\"VALUE2\",\"KEY1\":\"VALUE1\",\"KEY5\":{\"KEY5_2\":\"VALU5_2\",\"KEY5_1\":\"VALU5_1\"},\"KEY6\":[1,2,3]}"
local tjsondata,result,errinfo = json.decode(origin)
if result and type(tjsondata)=="table" then
    log.info("testJson.decode KEY1",tjsondata["KEY1"])
    log.info("testJson.decode KEY2",tjsondata["KEY2"])
    log.info("testJson.decode KEY3",tjsondata["KEY3"])
    log.info("testJson.decode KEY4",tjsondata["KEY4"])
    log.info("testJson.decode KEY5",tjsondata["KEY5"]["KEY5_1"],tjsondata["KEY5"]["KEY5_2"])
    log.info("testJson.decode KEY6",tjsondata["KEY6"][1],tjsondata["KEY6"][2],tjsondata["KEY6"][3])
else
    log.info("testJson.decode error",errinfo)
end
-----------------------decode测试------------------------
