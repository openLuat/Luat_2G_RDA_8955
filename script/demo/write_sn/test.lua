module(...,package.seeall)

require"misc"

--将要写入设备的新SN号
local newsn = "1234567890123456"

--5秒后开始写SN
sys.timer_start(misc.setsn,5000,newsn)
