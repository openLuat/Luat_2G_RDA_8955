# Microsoft Developer Studio Project File - Name="luac" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Console Application" 0x0103

CFG=luac - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "luac.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "luac.mak" CFG="luac - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "luac - Win32 Release" (based on "Win32 (x86) Console Application")
!MESSAGE "luac - Win32 Debug" (based on "Win32 (x86) Console Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "luac - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS" /Yu"stdafx.h" /FD /c
# ADD CPP /nologo /W3 /GX /O2 /I "..\..\..\..\lua\include" /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS" /D "LUA_IO_LIB" /D "LUA_DEBUG_LIB" /D "LUA_FILE_LOAD_SUPPORT" /D "LUA_TTY_SUPPORT" /D "LUA_COMPILER" /D "LUA_USE_COOLSAND_SXR" /FR /FD /c
# ADD BASE RSC /l 0x804 /d "NDEBUG"
# ADD RSC /l 0x804 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /machine:I386 /out:"luac.exe"

!ELSEIF  "$(CFG)" == "luac - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_CONSOLE" /D "_MBCS" /Yu"stdafx.h" /FD /GZ /c
# ADD CPP /nologo /W3 /Gm /GX /ZI /Od /I "..\..\..\..\lua\include" /D "WIN32" /D "_DEBUG" /D "_CONSOLE" /D "_MBCS" /D "LUA_IO_LIB" /D "LUA_DEBUG_LIB" /D "LUA_FILE_LOAD_SUPPORT" /D "LUA_TTY_SUPPORT" /D "LUA_COMPILER" /FD /GZ /c
# ADD BASE RSC /l 0x804 /d "_DEBUG"
# ADD RSC /l 0x804 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 /pdbtype:sept
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 /pdbtype:sept

!ENDIF 

# Begin Target

# Name "luac - Win32 Release"
# Name "luac - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=..\..\..\..\lua\src\lapi.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lauxlib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lbaselib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lcode.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ldblib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ldebug.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ldo.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ldump.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lfunc.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lgc.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\linit.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\liolib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\llex.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lmathlib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lmem.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\loadlib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lobject.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lopcodes.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\loslib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lparser.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lstate.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lstring.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lstrlib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ltable.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ltablib.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ltm.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\luac.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lundump.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lvm.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lzio.c
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\print.c
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=..\..\..\..\lua\src\lapi.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\include\lauxlib.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lcode.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ldebug.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ldo.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lfunc.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lgc.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\llex.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\llimits.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lmem.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lobject.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lopcodes.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lparser.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lrodefs.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lrotable.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lstate.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lstring.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ltable.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\ltm.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\include\lua.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\include\luaconf.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lualib.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lundump.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lvm.h
# End Source File
# Begin Source File

SOURCE=..\..\..\..\lua\src\lzio.h
# End Source File
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
# End Group
# Begin Source File

SOURCE=.\ReadMe.txt
# End Source File
# End Target
# End Project
