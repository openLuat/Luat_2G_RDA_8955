
LOCAL_MODULE_DEPENDS  += cust_src/elua/lua
LOCAL_MODULE_DEPENDS  += cust_src/elua/newlib
LOCAL_MODULE_DEPENDS  += cust_src/elua/newlib/libc
LOCAL_MODULE_DEPENDS  += cust_src/elua/shell
LOCAL_MODULE_DEPENDS  += cust_src/elua/modules
LOCAL_MODULE_DEPENDS  += cust_src/elua/platform
LOCAL_MODULE_DEPENDS  += cust_src/elua/platform/coolsand

#+\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma
ifeq ($(strip $(AM_LZMA_SUPPORT)), TRUE)
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/lzma
endif
#-\NEW\liweiqiang\2013.5.11\开机自解压luazip目录下文件支持,压缩算法lzma

#+\NEW\liweiqiang\2013.7.16\增加iconv字符编码转换库 
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/iconv
#-\NEW\liweiqiang\2013.7.16\增加iconv字符编码转换库 

#+\NEW\zhutianhua\2014.1.21\添加zlib库
ifeq ($(strip $(AM_ZLIB_SUPPORT)), TRUE)
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/zlib
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/zlib/zlib_pal
endif
#-\NEW\zhutianhua\2014.1.21\添加zlib库

#+\NEW\zhutianhua\2014.1.24\添加libpng库
ifeq ($(strip $(AM_LPNG_SUPPORT)), TRUE)
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/lpng
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/lpng/lpng_pal
endif
#-\NEW\zhutianhua\2014.1.24\添加libpng库

LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/json
#/*begin\NEW\zhutianhua\2017.4.17 15:7\新增crypto算法库*/
LOCAL_MODULE_DEPENDS  += cust_src/elua/lib/crypto
#/*end\NEW\zhutianhua\2017.4.17 15:7\新增crypto算法库*/

