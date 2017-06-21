#********************************************************#
# Copyright (C), AirM2M Tech. Co., Ltd.
# Author: lifei
# Description: AMOPENAT 开放平台
# Others:
# History: 
#   Version： Date:       Author:   Modification:
#   V0.1      2012.12.14  lifei     创建文件
#********************************************************#

# Name of the module, with toplevel path, e.g. "phy/tests/dishwasher"
LOCAL_NAME := cust_main

# Space-separated list of modules (libraries) your module depends upon.
# These should include the toplevel name, e.g. "phy/dishes ciitech/hotwater"
LOCAL_DEPEND_LIBS := 

# Add includes from other modules we do not wish to link to
LOCAL_API_DEPENDS := \

LOCAL_ADD_INCLUDE := \
                    platform/std_inc \
                    platform/OpenAT_inc \

# Set this to any non-null string to signal a module which 
# generates a binary (must contain a "main" entry point). 
# If left null, only a library will be generated.
IS_ENTRY_POINT := no

## ------------------------------------ ##
## 	Add your custom flags here          ##
## ------------------------------------ ##
MYCFLAGS += 

## ------------------------------------- ##
##	List all your sources here           ##
## ------------------------------------- ##
C_SRC := ${notdir ${wildcard src/*.c}}

## ------------------------------------- ##
##  Do Not touch below this line         ##
## ------------------------------------- ##
include ${SOFT_WORKDIR}/platform/compilation/cust_rules.mk
