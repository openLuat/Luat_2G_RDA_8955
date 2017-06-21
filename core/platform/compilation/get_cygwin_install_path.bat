
::+\BUG WM-499\lifei\2012.12.27\OpenAT客户无法获取cygwin安装路径::
::+\BUG WM-491\lifei\2012.12.26\编译时自动获取revision编号::

::根据注册表信息获取cygwin的安装目录

::Windows 2000            版本 5.0
::Windows XP              版本 5.1
::Windows Server 2003     版本 5.2
::Windows Server 2003 R2  版本 5.2
::Windows Vista           版本 6.0
::Windows Server 2008     版本 6.0
::Windows Server 2008 R2  版本 6.1
::Windows 7               版本 6.1

::ver|find /i "5.1" >nul && goto :WinXP
::ver|find /i "5.2" >nul && goto :WinServer2003
::ver|find /i "6.0" >nul && goto :WinVista
::ver|find /i "6.1" >nul && goto :Win7
::default
::goto :WinXP

::获取Cygwin安装路径
echo Find Cygwin install path @WinXP
for /f "skip=4 tokens=1-3" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Cygnus Solutions\Cygwin\mounts v2\/" /v native') do (
  set "CYGWIN_HOME=%%c"
)
if "%CYGWIN_HOME%"=="" (goto Win7) else (goto FindCygwinPathEnd)

:Win7
echo Find Cygwin install path @Win7
for /f "skip=2 tokens=1-3" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Cygnus Solutions\Cygwin\mounts v2\/" /v native') do (
  set "CYGWIN_HOME=%%c"
)
if "%CYGWIN_HOME%"=="" (goto WinServer2003) else (goto FindCygwinPathEnd)

:WinServer2003
echo Find Cygwin install path @WinServer2003
for /f "skip=1 tokens=1-3" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Cygnus Solutions\Cygwin\mounts v2\/" /v native') do (
  set "CYGWIN_HOME=%%c"
)

:FindCygwinPathEnd
if "%CYGWIN_HOME%"=="" (echo Cannot find Cygwin install path! && pause)
if "%TORTOISESVN_HOME%"=="" (
    if exist "%ROOT_DIR%/env/compilation/get_tortoisesvn_install_path.bat" (call %ROOT_DIR%/env/compilation/get_tortoisesvn_install_path.bat)
)

::-\BUG WM-491\lifei\2012.12.26\编译时自动获取revision编号::
::-\BUG WM-499\lifei\2012.12.27\OpenAT客户无法获取cygwin安装路径::
