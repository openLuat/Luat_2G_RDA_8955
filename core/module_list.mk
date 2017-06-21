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
# 该文件用于列出客户需要编译的模块
#
#-----------------------------------
#该模块提供了入口实现模版，一般情况下是需要编译
#LOCAL_MODULE_DEPENDS += cust_main

#加入客户的模块列表
-include ${SOFT_WORKDIR}/cust_src/cust_module_list.mk