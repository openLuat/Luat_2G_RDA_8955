--- 模块功能：远程升级功能测试(使用Luat iot平台).
-- 开机后立即执行一次升级功能，仅执行一次，无论下载升级包成功还是失败，都会自动重启；
--
-- 或者超时10分钟还没有返回升级结果，也会自动重启
-- @author openLuat
-- @module update.testUpdate2
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

--[[
使用Luat物联云平台的升级服务器时，按照如下步骤操作
1、在main.lua中定义PRODUCT_KEY变量
2、加载update模块 require"update"
3、调用update.request(cbFnc)即可
]]
require"update"

local function cbFnc(downloadResult)
    sys.restart("testUpdate.downloadResult="..tostring(downloadResult))
end

update.request(cbFnc)
sys.timerStart(sys.restart,600000,"testUpdate timeout")
