--必须在这个位置定义PROJECT和VERSION变量
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "USER_SERVER_UPDATE"
VERSION = "1.0.0"
require"sys"
--[[
如果使用UART输出trace，打开这行注释的代码"--sys.opntrace(true,1)"即可，第2个参数1表示UART1输出trace，根据自己的需要修改这个参数
这里是最早可以设置trace口的地方，代码写在这里可以保证UART口尽可能的输出“开机就出现的错误信息”
如果写在后面的其他位置，很有可能无法输出错误信息，从而增加调试难度
]]
--sys.opntrace(true,1)
--[[
使用用户自己的升级服务器时，按照如下步骤操作
1、加载update模块 require"update"
2、设置用户自己的升级服务器地址和端口 update.setup("udp","www.userserver.com",2233)
执行了以上两步后，设备每次开机，网络准备就绪后，就会自动连接升级服务器执行升级功能
3、如果需要定时执行升级功能，打开--update.setperiod(3600)的注释，根据自己的需要，配置定时周期
4、如果需要实时执行升级功能，参考--sys.timer_start(update.request,120000)，根据自己的需要，调用update.request()即可
]]
require"update"
update.setup("udp","www.userserver.com",2233)
--update.setperiod(3600)
--sys.timer_start(update.request,120000)
require"test"

sys.init(0,0)
sys.run()
