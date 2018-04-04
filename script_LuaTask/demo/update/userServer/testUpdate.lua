--- 模块功能：远程升级功能测试(使用用户自定义平台).
-- 开机后立即执行一次升级功能，仅执行一次，如果升级包下载成功，自动重启
-- @author openLuat
-- @module update.testUpdate3
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

--[[
使用用户自定义平台的升级服务器时，按照如下步骤操作
1、在main.lua中定义PRODUCT_KEY变量
2、加载update模块 require"update"
3、调用update.request(nil,"www.userserver.com/api/site/firmware_upgrade")即可
]]
require"update"

--注意参考update.lua中，对request函数第二个参数的说明
update.request(nil,"www.userserver.com/api/site/firmware_upgrade")
sys.timerLoopStart(log.info,1000,"testUpdate.version",_G.VERSION)
