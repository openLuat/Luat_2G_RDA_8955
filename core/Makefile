#********************************************************#
# Copyright (C), AirM2M Tech. Co., Ltd.
# Author: lifei
# Description: AMOPENAT 开放平台
# Others:
# History: 
#   Version： Date:       Author:   Modification:
#   V0.1      2012.12.14  lifei     创建文件
#********************************************************#

#-----------------------------------
#
# 主入口Makefile
#
#-----------------------------------

#引入需要编译的模块列表
include module_list.mk

# Set this to any non-null string to signal a module which
# generates a binary (must contain a "main" entry point). 
# If left null, only a library will be generated.
IS_ENTRY_POINT := yes

# Assembly / C code
S_SRC := 
C_SRC := 

include ${SOFT_WORKDIR}/platform/compilation/cust_rules.mk
