--- 模块功能：NTP功能测试.
-- @author openLuat
-- @module ntp.testNtp
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

require"ntp"
require"misc"

local function prinTime()
    local tm = misc.getClock()
    log.info("testNtp.printTime",tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec)
end

sys.timerLoopStart(prinTime,1000)
ntp.timeSync()
