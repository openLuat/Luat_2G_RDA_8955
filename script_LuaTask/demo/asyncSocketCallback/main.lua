--必须在这个位置定义PROJECT和VERSION变量
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "Luat_TASK"
VERSION = "2.0.5"
-- 日志级别
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE
require "sys"
require "utils"
require "patch"
require "pins"
-- 加载GSM
require "net"
--8秒后查询第一次csq
net.startQueryAll(8 * 1000, 60 * 1000)
-- 控制台
require "console"
console.setup(1, 115200)
-- 系统工具
require "misc"
require "testSocket"
require "ntp"
ntp.timeSync(1,function()log.info("----------------> AutoTimeSync is Done ! <----------------")end)
-- 启动系统框架
sys.init(0, 0)
sys.run()
