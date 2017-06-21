::根据注册表信息获取TortoiseSVN的安装目录

::Windows 2000            版本 5.0
::Windows XP              版本 5.1
::Windows Server 2003     版本 5.2
::Windows Server 2003 R2  版本 5.2
::Windows Vista           版本 6.0
::Windows Server 2008     版本 6.0
::Windows Server 2008 R2  版本 6.1
::Windows 7               版本 6.1

ver|find /i "5.1" >nul && goto :WinXP
ver|find /i "5.2" >nul && goto :WinServer2003
::ver|find /i "6.0" >nul && goto :WinVista
ver|find /i "6.1" >nul && goto :Win7
::default
goto :WinXP

::获取Cygwin安装路径
:WinXP
echo Find TortoiseSVN install path @WinXP
for /f "skip=4 tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\TortoiseSVN" /v Directory') do (
  set "TORTOISESVN_HOME=%%b"
)
goto FindTortoiseSVNPathEnd

:Win7
echo Find TortoiseSVN install path @Win7
for /f "skip=2 tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\TortoiseSVN" /v Directory') do (
  set "TORTOISESVN_HOME=%%b"
)
goto FindTortoiseSVNPathEnd

:WinServer2003
echo Find TortoiseSVN install path @WinServer2003
for /f "skip=1 tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\TortoiseSVN" /v Directory') do (
  set "TORTOISESVN_HOME=%%b"
)
goto FindTortoiseSVNPathEnd

:FindTortoiseSVNPathEnd
if "%TORTOISESVN_HOME%"=="" (echo Cannot find TortoisSVN install path! && exit)
set CYGWIN_HOME=%TORTOISESVN_HOME%\bin;%CYGWIN_HOME%