# Luat

Luat = Lua +  AT  

Luat 是合宙（AirM2M）推出的物联网开源架构，依托于通信模块做简易快捷的开发.

其中， Air202是一款GPRS模块。

开源社区：bbs.openluat.com

GitHub：https://github.com/airm2m-open/Luat_Air202

开发套件：https://luat.taobao.com 或 https://openluat.taobao.com



## 合宙开源平台Luat架构简介


底层软件（也叫基础软件，位于/Luat_Air202/core）用C语言开发完成，支撑Lua的运行。

上层软件用Lua脚本语言来开发实现，位于/Luat_Air202/script。 


## 开源用户须知

Luat开源/script代码中，/demo里是各个功能的示例程序。/lib下是demo以及所有用户代码都需要调用的库文件。

一般用户只需修改上层lua脚本，即可快速完成二次开发，而不用修改core基础软件。这部分用户，请参考：合宙开源项目lua开发须知

注意：还有一部分用户，只需要MCU通过物理串口发送AT命令控制模块，对这部分用户，请购买我司Air202T模块或开发板。
