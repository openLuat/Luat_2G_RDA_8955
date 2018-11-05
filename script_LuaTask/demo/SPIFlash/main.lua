PROJECT = "TEST_SPI_FLASH"
VERSION = "2.0.0"

--加载日志功能模块，并且设置日志输出等级
--如果关闭调用log模块接口输出的日志，等级设置为log.LOG_SILENT即可
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE

require "sys"
require "test_SPIFlashRandomRW"

--启动系统框架
sys.init(0, 0)
sys.run()
