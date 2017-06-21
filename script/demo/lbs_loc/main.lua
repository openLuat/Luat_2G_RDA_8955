--必须在这个位置定义PROJECT和VERSION变量
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "LBS_LOC"
VERSION = "1.0.0"
--[[
使用基站获取经纬度的功能，必须按照以下步骤操作：
1、打开Luat物联云平台前端页面：https://iot.openluat.com/
2、如果没有用户名，注册用户
3、注册用户之后，如果没有对应的项目，创建一个新项目
4、进入对应的项目，点击左边的项目信息，右边会出现信息内容，找到ProductKey：把ProductKey的内容，赋值给PRODUCT_KEY变量
]]
PRODUCT_KEY = "v32xEAKsGTIEQxtqgwCldp5aPlcnPs3K"
require"sys"
--[[
如果使用UART输出trace，打开这行注释的代码"--sys.opntrace(true,1)"即可，第2个参数1表示UART1输出trace，根据自己的需要修改这个参数
这里是最早可以设置trace口的地方，代码写在这里可以保证UART口尽可能的输出“开机就出现的错误信息”
如果写在后面的其他位置，很有可能无法输出错误信息，从而增加调试难度
]]
--sys.opntrace(true,1)
require"test"

sys.init(0,0)
sys.run()
