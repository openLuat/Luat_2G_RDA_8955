# Luat

![LUAT LOGO](http://www.openluat.com/img/favicon.png "LUAT LOGO")

## 概述

Luat 是合宙（AirM2M）推出的物联网开源架构，依托于通信模块做简易快捷的开发.

Luat = Lua + AT, Luat推出的物联网开源架构，依托于通信模块做简易快捷的开发，将传统的AT命令用Lua语言封装成API，并提供各种功能应用的demo，大大减少用户的开发成本。

开发者可以通过调用API轻松，便捷的实现TTS、GPS、SOCKET、MQTT、OTA等功能。例如下面通过几条代码既可以实现GPS，MQTT功能。

GPS

```lua
--引用gps.lua、sys.lua
require"gps"
require"sys"

--定义函数prtgps，在trace中输出gps定位信息
--是否3D定位，经纬度，速度，方向角，海拔
local function prtgps()
    print("gps", gps.is3dfix(), gps.getgpslocation(), gps.getgpsspd(), gps.getgpscog(), gps.getaltitude())
end

--设置定时器，每10秒调用一次prtgps函数
sys.timer_loop_start(prtgps, 10000)
--开机后，初始化gps；gps授时同步时钟
gps.init()
gps.settimezone(gps.GPS_BEIJING_TIME)
```

mqtt

```lua
--引用mqtt.lua
require"mqtt"

--mqtt connect成功的回调函数
local function connectedcb()
    --订阅主题
    mqttclient:subscribe({topic="/event0",qos=1})
    --发布消息
    mqttclient:publish("/event0", "qos1data", 1)
end

--创建mqtt client
mqttclient = mqtt.create("TCP", "lbsmqtt.airm2m.com", 8083)
--连接到 mqtt 服务器
mqttclient:connect("clientID", 240, "username", "password", connectedcb)
```

## Luat介绍

Lua脚本是内嵌在模块基础软件core中运行的（core编译生成的文件是.lod文件），Lod中有支持Lua运行的环境，Lua脚本就在这个环境中运行。脚本实现功能是通过API（对AT命令进行了封装）实现的。

在模块内部，Lua发出AT命令，并通过虚拟的uart.ATC 口和Lod之间进行AT命令的交互。即Lua发出AT命令，Lod接收后进行解析并返回AT命令运行结果，不需要上位机（一般是单片机）通过物理串口给模块发AT命令，这样就节省了单片机的花费。

![infomation](http://wiki.openluat.com/img/coreLua.jpg)

## script和script_LuaTask

script和script_LuaTask是两版上层脚本开发架构：

- 1、script是第一版，整个应用开发仅支持单线程

- 2、script_LuaTask是第二版，基于Lua的协程实现了多线程的支持，相比于第一版script来说，用户编程变得简洁，在此郑重感谢Luat开源技术支持群（QQ群号：201848376）里的“稀饭放姜”大神对此版本架构提出的建议以及对此版本开发做出的贡献，同时感谢LuaTask群（QQ群号：670342655）里面的所有成员对此版本的辛勤付出。

> 建议新项目使用script_LuaTask版本开发。

各个接口说明可在[http://wiki.openluat.com/doc/luatApi/](http://wiki.openluat.com/doc/luatApi/)查看

---

# 项目结构

```
├── core

    └──Luat_VXXXX_8955.lod：不支持SSL、TTS、SPI接口的LCD功能
    Lua脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用768KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用860KB

    └──Luat_VXXXX_8955_SSL.lod：支持SSL功能
    LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用768KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用796KB

    └──Luat_VXXXX_8955_SSL_TTS.lod：支持SSL、TTS功能，不支持MP3、MIDI、录音功能
    LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用324KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用344KB

    └──Luat_VXXXX_8955_SSL_UI.lod：支持SSL、SPI接口的LCD功能
    LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用704KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用540KB

    └──Luat_VXXXX_8955_TTS_UI.lod：支持TTS、SPI接口的LCD功能
    LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用152KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用132KB

    └──Luat_VXXXX_8955_TTS1.lod：支持TTS功能
    LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用216KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用260KB

    └──Luat_VXXXX_8955_UI.lod：支持SPI接口的LCD功能
    LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用512KB
    文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用796KB

    └──Luat_VXXXX_8955_SSL_FLOAT.lod：支持SSL功能、浮点数

    └──Luat_VXXXX_8955_SSL_UI_FLOAT.lod：支持SSL功能、PI接口的LCD功能、浮点数

    └──Luat_VXXXX_8955F.lod：64M flash版本（Air202F），支持SSL、TTS、SPI接口的LCD功能


├── script_LuaTask 基于Lua的协程实现了多线程的支持

    └── demo 例程
    └── lib 库文件
    └── product/LuatBoard_Air202  LuatBoard开发板
```

底层软件（也叫基础软件，位于/core）用C语言开发完成，支撑Lua的运行。

lib目录中的“库脚本”（所有项目都应该使用），

用户自己编写的“应用脚本”（例如demo目录下的脚本）

# LuaTools

使用Luat调试开发工具对模块进行lod和script的下载。该工具功能如下：

- 加密lod功能；

- 下载官方lod底层；

- 下载Lua脚本进行二次开发；

- 用App验证开发板是否为良品；

- 对模块打印trace进行输出分析；

- 生成量产文件进行远程升级/批量生产。

> 工具并不支持代码编辑功能，如果要编辑代码，则需下载其他编辑器，比如sublime text 3，vscode，notepad++等。

你可以[点击此处](http://wiki.openluat.com/doc/tools/)查看使用教程
