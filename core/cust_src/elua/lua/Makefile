#**************************************************************#
# COPY THIS FILE AS "Makefile" IN THE "src" DIR OF YOUR MODULE #
# AND CUSTOMIZE IT TO FIT YOUR NEEDS.                          #
#**************************************************************#


## ----------------------------------------------------------- ##
## Don't touch the next line unless you know what you're doing.##
## ----------------------------------------------------------- ##

## -------------------------------------- ##
## General information about this module. ##
## You must edit these appropriately.     ##
## -------------------------------------- ##

# Name of the module, with toplevel path, e.g. "phy/tests/dishwasher"
LOCAL_NAME := cust_src/elua/lua

# Space-separated list of modules (libraries) your module depends upon.
# These should include the toplevel name, e.g. "phy/dishes ciitech/hotwater"
LOCAL_MODULE_DEPENDS := 

# Add includes from other modules we do not wish to link to
LOCAL_API_DEPENDS := \
                    cust_src/elua/lua \
                    cust_src/elua/newlib/libc \
                    cust_src/elua/modules \
                    cust_src/elua/platform \
                    cust_src/elua/platform/coolsand \

# Set this to a non-null string to signal a toplevel module, like 
# phy but not like phy/kitchensink. This defines the behavior of 
# make deliv
IS_TOP_LEVEL := no

## ------------------------------------ ##
## 	Add your custom flags here          ##
## ------------------------------------ ##
#LOCAL_EXPORT_FLAG += LUA_MATH_LIB
LOCAL_EXPORT_FLAG += LUA_OS_LIB
LOCAL_EXPORT_FLAG += LUA_IO_LIB
LOCAL_EXPORT_FLAG += LUA_DEBUG_LIB
LOCAL_EXPORT_FLAG += LUA_FILE_LOAD_SUPPORT
LOCAL_EXPORT_FLAG += LUA_TTY_SUPPORT

## ------------------------------------- ##
##	List all your sources here           ##
## ------------------------------------- ##
C_SRC := ${notdir ${wildcard src/*.c}}

## ------------------------------------- ##
##  Do Not touch below this line         ##
## ------------------------------------- ##
include ${SOFT_WORKDIR}/platform/compilation/cust_rules.mk

