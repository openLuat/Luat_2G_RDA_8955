--重要提醒：必须在这个位置定义MODULE_TYPE、PROJECT和VERSION变量
--MODULE_TYPE：模块型号，目前仅支持Air201、Air202、Air800
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
MODULE_TYPE = "Air202"
PROJECT = "USER_SERVER_UPDATE"
VERSION = "1.0.0"
require"sys"
--[[
如果使用UART输出trace，打开这行注释的代码"--sys.opntrace(true,1)"即可，第2个参数1表示UART1输出trace，根据自己的需要修改这个参数
这里是最早可以设置trace口的地方，代码写在这里可以保证UART口尽可能的输出“开机就出现的错误信息”
如果写在后面的其他位置，很有可能无法输出错误信息，从而增加调试难度
]]
--sys.opntrace(true,1)
--用户使用自己搭建的http服务器来存在升级包时，也要定义PRODUCT_KEY变量，变量的值根据自己的项目需求自行定义
PRODUCT_KEY = "HJdJ7BGeQ3aUjMUetdYrUUuSMEDoAAZI"
--[[
使用用户自己的升级服务器时，按照如下步骤操作
1、加载updatehttp模块 require"updatehttp"
2、设置用户自己的升级服务器地址、端口和GET命令的URL，例如 updatehttp.setup("TCP","www.userserver.com",80,"/api/site/firmware_upgrade")
执行了以上两步后，设备每次开机，网络准备就绪后，就会自动连接升级服务器执行升级功能
3、如果需要定时执行升级功能，打开--updatehttp.setperiod(3600)的注释，根据自己的需要，配置定时周期
4、如果需要实时执行升级功能，参考--sys.timer_start(updatehttp.request,120000)，根据自己的需要，调用updatehttp.request()即可
]]
require"updatehttp"
--[[
--重要提醒：
--updatehttp.setup接口传入的url只是GET命令的URL的前半部分，updatehttp.lua中会在后面加上如下信息
"?project_key="..base.PRODUCT_KEY
"&imei="..misc.getimei()
"&device_key="..misc.getsn()
"&firmware_name="..base.PROJECT.."_"..rtos.get_version()
"&version="..base.VERSION
]]
updatehttp.setup("tcp","www.userserver.com",80,"/api/site/firmware_upgrade")
--updatehttp.setperiod(3600)
--sys.timer_start(updatehttp.request,120000)

--[[
重要提醒：
一旦使用了远程升级功能，强烈建议使用dbg功能，参考下面两行代码
因为通过远程升级新版本的脚本后，如果新版本的脚本运行时有语法错误，则会重启自动回退到最后一次本地烧写的版本
回退后，一旦连接上升级服务器，还会继续远程升级。就陷入了一个“远程升级新版本->新版本运行出错，重启->自动回退到旧版本”的死循环，导致功能异常和浪费数据流量
例如本地烧写的版本是1.0.0，服务器上配置了1.0.1版本，但是1.0.1版本运行时有语法错误，则设备会循环“远程升级到1.0.1->1.0.1运行出错，重启->自动回退到1.0.0”
一旦加上dbg功能后，发生语法错误重启后，会将语法错误上报到dbg服务器。开发人员查看语法错误日志，可以及时修正语法错误，持续迭代版本
dbg服务器支持TCP和UDP协议，收到任何上报，都要回复大写的OK
如果不方便自己搭建dbg服务器，可以使用合宙提供的"UDP","ota.airm2m.com",9072服务器
在iot.openluat.com中登录，进入一个产品，在左侧的"查询debug"中可以查询设备上报的错误信息
]]
require"dbg"
sys.timer_start(dbg.setup,12000,"UDP","ota.airm2m.com",9072)

require"test"

--加载硬件看门狗功能模块
--根据自己的硬件配置决定：1、是否加载此功能模块；2、配置Luat模块复位单片机引脚和互相喂狗引脚
--合宙官方出售的Air201开发板上有硬件看门狗，所以使用官方Air201开发板时，必须加载此功能模块
--[[
require "wdt"
wdt.setup(pio.P0_30, pio.P0_31)
]]


sys.init(0,0)
sys.run()
