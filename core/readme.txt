Air202和Air800模块的Flash总空间都为4MB
Air202和Air800目前都有5种底层软件：
Luat_VXXXX_Air202.lod、Luat_VXXXX_Air800.lod：不支持SSL、TTS、SPI接口的LCD功能
Luat_VXXXX_Air202_SSL.lod、Luat_VXXXX_Air800_SSL.lod：支持SSL功能
Luat_VXXXX_Air202_TTSX.lod、Luat_VXXXX_Air800_TTSX.lod：支持TTS功能
Luat_VXXXX_Air202_UI.lod、Luat_VXXXX_Air800_UI.lod：支持SPI接口的LCD功能
Luat_VXXXX_Air202_TTS_UI.lod、Luat_VXXXX_Air800_TTS_UI.lod：支持TTS、SPI接口的LCD功能

Luat_VXXX_Air202.lod、Luat_VXXXX_Air800.lod：
Lua脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用512KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用694KB

Luat_VXXX_Air202_SSL.lod、Luat_VXXXX_Air800_SSL.lod：
LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用640KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用591KB

Luat_VXXX_Air202_TTS1.lod、Luat_VXXXX_Air800_TTS1.lod：
LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用216KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用214KB

Luat_VXXX_Air202_UI.lod、Luat_VXXXX_Air800_UI.lod：
LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用512KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用642KB

Luat_VXXXX_Air202_TTS_UI.lod、Luat_VXXXX_Air800_TTS_UI.lod：
LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用216KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用118KB


无论是哪一种底层软件，关于文件系统空间的使用，注意以下几点：
如果用烧写工具烧写脚本和资源时，自动勾选了压缩功能（默认不勾选，只有脚本和资源大小超过Lua脚本和资源可用空间时，才会自动勾选），则开机后，会自动解压缩所有的脚本和资源文件到文件系统中
如果用到远程升级功能，一定要为远程升级文件预留足够用的空间，至少保留升级bin文件大小+“所有脚本和资源的原始大小之和”的文件系统空间



Air202、Air800模块的RAM总空间都为4MB
其中Lua运行内存1024KB，Luat框架引用的一些lua模块需要占用一定的运行内存，可通过sys.lua中的run函数中的代码--print("mem:",base.collectgarbage("count"))实时打印已占用的空间
