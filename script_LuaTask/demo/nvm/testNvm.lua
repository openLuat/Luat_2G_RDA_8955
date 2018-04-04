--- 模块功能：参数存储功能测试.
-- @author openLuat
-- @module nvm.testNvm
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"config"
require"nvm"

nvm.init("config.lua")

nvm.set("strPara","str2")
nvm.set("numPara",2)
nvm.set("boolPara",false)
nvm.set("tablePara",{"item2-1","item2-2","item2-3"})

log.info("testNvm.strPara",nvm.get("strPara"))
log.info("testNvm.numPara",nvm.get("numPara"))
log.info("testNvm.boolPara",nvm.get("boolPara"))
local tableValue = nvm.get("tablePara")
log.info("testNvm.tablePara",tableValue[1],tableValue[2],tableValue[3])
