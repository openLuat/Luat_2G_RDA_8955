--- 模块功能：NTP功能测试.
-- @author openLuat
-- @module ntp.testNtp
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

-- 重要提醒！！！！！！
-- ntp功能模块采用多个免费公共的NTP服务器来同步时间
-- 并不能保证任何时间任何地点都能百分百同步到正确的时间
-- 所以，如果用户项目中的业务逻辑严格依赖于时间同步功能
-- 则不要使用使用本功能模块，建议使用自己的应用服务器来同步时间
require"ntp"
require"misc"

local function prinTime()
    local tm = misc.getClock()
    log.info("testNtp.printTime", string.format("%04d/%02d/%02d,%02d:%02d:%02d", tm.year, tm.month, tm.day, tm.hour, tm.min, tm.sec))
end

sys.timerLoopStart(prinTime,1000)
ntp.timeSync()
