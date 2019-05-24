RDA8955芯片的Air模块的Flash总空间都为4MB
目前有11种底层软件：
Luat_VXXXX_8955.lod：不支持SSL、TTS、SPI接口的LCD功能
Luat_VXXXX_8955_SSL.lod：支持SSL功能
Luat_VXXXX_8955_SSL_TTS.lod：支持SSL、TTS功能，不支持MP3、MIDI、录音功能
Luat_VXXXX_8955_SSL_UI.lod：支持SSL、SPI接口的LCD功能
Luat_VXXXX_8955_TTS_UI.lod：支持TTS、SPI接口的LCD功能
Luat_VXXXX_8955_TTS1.lod：支持TTS功能
Luat_VXXXX_8955_TTS2.lod：支持TTS功能、不支持MP3、MIDI、录音、json
Luat_VXXXX_8955_UI.lod：支持SPI接口的LCD功能
Luat_VXXXX_8955_SSL_FLOAT.lod：支持SSL功能、浮点数
Luat_VXXXX_8955_SSL_UI_FLOAT.lod：支持SSL功能、PI接口的LCD功能、浮点数
Luat_VXXXX_8955F.lod：64M flash版本（Air202F），支持SSL、TTS、SPI接口的LCD功能



Luat_VXXXX_8955.lod：
Lua脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用768KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用860KB

Luat_VXXXX_8955_SSL.lod：
LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用768KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用796KB

Luat_VXXXX_8955_SSL_TTS.lod：
LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用324KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用344KB

Luat_VXXXX_8955_SSL_UI.lod：
LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用704KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用540KB

Luat_VXXXX_8955_TTS_UI.lod：
LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用152KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用132KB

Luat_VXXXX_8955_TTS1.lod：
LuaDB脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件）可用216KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用260KB

Luat_VXXXX_8955_UI.lod：
LuaDB 脚本和资源（通过烧写工具烧写的文件，例如lua脚本文件，mp3音频文件，图片文件）可用512KB
文件系统（例如脚本运行过程中创建的参数文件，录音文件，远程升级文件等）可用796KB


文件系统的实际空间可通过rtos.get_fs_free_size()打印

无论是哪一种底层软件，关于文件系统空间的使用，注意以下几点：
如果用烧写工具烧写脚本和资源时，自动勾选了压缩功能（默认不勾选，只有脚本和资源大小超过Lua脚本和资源可用空间时，才会自动勾选），则开机后，会自动解压缩所有的脚本和资源文件到文件系统中
如果用到远程升级功能，一定要为远程升级文件预留足够用的空间，至少保留升级bin文件大小+“所有脚本和资源的原始大小之和”的文件系统空间



8955模块的RAM总空间都为4MB
其中Lua运行内存1024KB，Luat框架引用的一些lua模块需要占用一定的运行内存，可通过sys.lua中的run函数中的代码--print("mem:",base.collectgarbage("count"))实时打印已占用的空间


因flash空间有限:
TTS_UI和TTS2的最后一个版本是0028，以后不再发布新的TTS_UI和TTS2版本；如果同时使用这两项功能，购买Air202F或者Air268F模块，使用Luat_VXXXX_8955F.lod
TTS1的最后一个版本是0033，以后不再发布新的TTS1版本；如果同时使用这两项功能，购买Air202F或者Air268F模块，使用Luat_VXXXX_8955F.lod
