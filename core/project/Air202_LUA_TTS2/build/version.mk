# ------------------------------------------------------------------------ #
#                             AirM2M Ltd.                                  # 
#                                                                          #
# Name: version.mk                                                         #
#                                                                          #
# Author: liweiqiang                                                            #
# Verison: V0.1                                                            #
# Date: 2013.3.4                                                         #
#                                                                          #
# File Description:                                                        #
#                                                                          #
#  版本定义文件                                                            #
# ------------------------------------------------------------------------ #

# 版本生成规则 Luat_V$(BUILD_VER)_$(HW_VER)[_$(FUNCTION)]

#BUILD号
BUILD_VER =0001
#硬件版本号
HW_VER = Air202
#可选功能，例如TTS等，表明该版本具有特定功能
OPTION_FUN = TTS2

### 需要设置的内容 ###
# 模块/手机项目号
MODULE_TYPE=A6390

# 客户同一项目不同硬件版本或同一项目不同应用
CUST_HW_TYPE=H


# 软件版本号
ifeq "${BUILD_VER}" ""
${error MUST define BUILD_VER}
else
SW_SN=${BUILD_VER}
endif

# 模块/手机主板号
MODULE_HW_TYPE=13

# 平台软件版本号
PLATFORM_VER=CT8955



# ------------------------------------------------------------------------ #
# 版本号定义
# ------------------------------------------------------------------------ #
# 内部版本号
IN_VER=SW_$(MODULE_TYPE)_$(CUST_HW_TYPE)_V$(SW_SN)_M$(MODULE_HW_TYPE)_$(PLATFORM_VER)_$(HW_VER)

# 外部版本号（默认定义）
ifneq "${OPTION_FUN}"  ""
EX_VER=Luat_V$(SW_SN)_$(HW_VER)_$(OPTION_FUN)
else
EX_VER=Luat_V$(SW_SN)_$(HW_VER)
endif
# ------------------------------------------------------------------------ #
# 版本宏
# ------------------------------------------------------------------------ #
LOCAL_EXPORT_FLAG += \
   IN_VER=\"$(IN_VER)\" \
   EX_VER=\"$(EX_VER)\" \
   
ifeq "${AM_VER_ECHO_SUPPORT}" "TRUE"
ECHO_EX_VER:
	@echo $(EX_VER)
endif
