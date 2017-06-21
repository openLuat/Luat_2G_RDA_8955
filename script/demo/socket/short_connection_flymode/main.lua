--必须在这个位置定义PROJECT和VERSION变量
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "SOCKET_SHORT_CONNECTION_FLYMODE"
VERSION = "1.0.0"
require"sys"
--[[
如果使用UART输出trace，打开这行注释的代码"--sys.opntrace(true,1)"即可，第2个参数1表示UART1输出trace，根据自己的需要修改这个参数
这里是最早可以设置trace口的地方，代码写在这里可以保证UART口尽可能的输出“开机就出现的错误信息”
如果写在后面的其他位置，很有可能无法输出错误信息，从而增加调试难度
]]
--sys.opntrace(true,1)
--关闭脚本中的所有trace打印
--sys.opntrace(false)
require"dbg"
dbg.setup("udp","www.test.com",9072)
require"update"
update.setup("udp","www.test.com",2233)
require"test"

net.setled(true)
sys.init(0,0)
--需要抓core中的trace时，打开如下三行
--ril.request("AT*TRACE=\"SXS\",1,0")
--ril.request("AT*TRACE=\"DSS\",1,0")
--ril.request("AT*TRACE=\"RDA\",1,0")
--设置工作模式为简单模式
sys.setworkmode(sys.SIMPLE_MODE)
sys.run()
