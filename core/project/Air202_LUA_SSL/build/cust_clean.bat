::********************************************************#
:: Copyright (C), AirM2M Tech. Co., Ltd.
:: Author: lifei
:: Description: AMOPENAT 开放平台
:: Others:
:: History: 
::   Version： Date:       Author:   Modification:
::   V0.1      2012.12.14  lifei     创建文件
::********************************************************#
@echo off

::将工作目录切换到该bat文件所在的目录
PUSHD %~dp0

::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: 获取相关的路径信息
::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
::获取项目编译目录路径
set PROJ_BUILD_DIR=%cd%

::获取项目路径
cd ..
set PROJ_DIR=%cd%
:: 获取项目名称
for /f %%i in ("%cd%") do set PROJ_NAME=%%~ni
echo PROJ_NAME=%PROJ_NAME%

::获取代码根目录
cd ../..
set ROOT_DIR=%cd%

::回到项目编译目录
cd %PROJ_BUILD_DIR%

::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: 获取Cygwin安装路径
::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if "%CYGWIN_HOME%"=="" (call %ROOT_DIR%/platform/compilation/get_cygwin_install_path.bat)
if "%CYGWIN_HOME%"=="" (goto ErrorNoCygwin)

::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: 设置环境路径
::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:BuildStart
echo Cygwin install path: %CYGWIN_HOME%
::将Cygwin的bin以及cross-compile工具目录加到PATH中
set PATH=%CYGWIN_HOME%\bin;/usr/bin;/crosscompiler/bin;C:\CSDTK\cooltools;

::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: 启动bash开始编译
::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
bash %ROOT_DIR%/cust_build.sh 1 2 clean
echo.
goto End


:ErrorNoCygwin
::echo Can't find Cygwin install path!
goto End

:End

@echo on