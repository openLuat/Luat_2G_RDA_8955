一个完整的项目脚本包含2部分：
1、第1部分是lib目录中的“库脚本”（所有项目都应该使用），
2、第2部分就是用户自己编写的“应用脚本”（例如demo目录下的脚本）

使用LuaDB工具烧写软件时，一定要选择这2部分脚本才能保证正常运行！！！


第1部分：
lib：“库脚本”，请注意：这个目录中的脚本是所有应用使用LuaDB工具下载时都需要包含得！！！


第2部分：
demo：以下所有项目的“应用脚本”，xiaoman_gps_tracker下的脚本在小蛮GPS定位器硬件上运行，其余目录下的lua脚本都可以在Air200开发板上运行
定位器中运行。

由于时间有限，部分项目没有仔细测试，运行过程中可能出错，请自行验证，有问题QQ交流，谢谢！

在demo中：
aliyun：MQTT_TCP连接阿里云物联网后台的demo项目（杭州节点）

aliyun_ssl：MQTT_SSL_TCP连接阿里云物联网后台的demo项目（杭州节点）

aliyun_ssl_huadong2：MQTT_SSL_TCP连接阿里云物联网后台的demo项目（华东2节点）

audio：音频播放demo项目

call：语音通话demo项目

default：Air200的默认出厂软件demo项目，可以使用时间线APP查看模块的基站位置

gpio\gpio_single：纯gpio控制demo项目

gpio\i2c_gpio_switch：i2c和gpio功能切换控制demo项目

gpio\uart_gpio_switch：uart和gpio功能切换控制demo项目

i2c：i2c通信demo项目

json：json编解码测试demo项目

lbs_loc：根据多基站获取经纬度的demo项目

luatyun：MQTT_TCP连接Luat云后台的demo项目

luatyun_ssl：MQTT_SSL_TCP连接Luat云后台的demo项目

mqtt：mqtt应用demo项目

mqtt_ssl：MQTT-SSL协议连接后台demo项目

ntp：模块时间自动更新demo项目

nvm：参数存储读写demo项目

pb：电话本读写demo项目

pm：休眠控制demo项目

proto_buffer：google proto buffer编解码测试demo项目

sms：短信demo项目

socket\long_connection：基于TCP的socket长连接通信demo项目（UDP使用方式和TCP完全相同）

socket\long_connection_transparent：基于TCP的socket透传demo项目，uart1透传数据到指定服务器

socket\short_connection：基于TCP的socket短连接通信demo项目（UDP使用方式和TCP完全相同）

socket\short_connection_flymode：基于TCP的socket短连接通信demo项目，会进入飞行模式并且定时退出飞行模式（UDP使用方式和TCP完全相同）

socket_ssl\long_connection：基于SSL-TCP的socket长连接通信demo项目（UDP使用方式和TCP完全相同）

socket_ssl\short_connection：基于SSL-TCP的socket短连接通信demo项目（UDP使用方式和TCP完全相同）

socket_ssl\short_connection_flymode：基于SSL-TCP的socket短连接通信demo项目，会进入飞行模式并且定时退出飞行模式（UDP使用方式和TCP完全相同）

timer：定时器demo项目

uart：串口demo项目

uart_prot1项目：通过uart解析外围设备输入的一种报文（起始标志，长度，指令，数据，校验码，结束标志）

update\Luat_iot_server：使用Luat物联云平台进行固件升级的demo项目

update\Luat_iot_server_daemon：支持Luat物联云平台进行远程升级以及调试信息上报功能

update\user_server：使用用户自己的后台进行固件升级的demo项目

wdt：开启开发板上的硬件看门狗功能项目

write_sn：写SN号到设备的demo项目

