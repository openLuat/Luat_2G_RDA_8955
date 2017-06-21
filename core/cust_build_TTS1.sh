#********************************************************#
# Copyright (C), AirM2M Tech. Co., Ltd.
# Author: lifei
# Description: AMOPENAT 开放平台
# Others:
# History: 
#   Version： Date:       Author:   Modification:
#   V0.1      2012.12.14  lifei     创建文件
#********************************************************#
export ROOT_DIR=`pwd`
export PROJ_NAME=Air202_LUA_TTS1
export PROJ_DIR=$ROOT_DIR/project/$PROJ_NAME
export PROJ_BUILD_DIR=$ROOT_DIR/project/$PROJ_NAME/build
export BUILD_DIR=$ROOT_DIR
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 分析传入的参数
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MAX=$#;
NEED_CLEAN=0
while [  $MAX -gt 0 ]; do  
    PARAMETER=$(echo $1 | tr '[A-Z' '[a-z]')
    if [ "${PARAMETER}" == "clean" ]; then
        NEED_CLEAN=1
        break
    fi
    shift
    MAX=`expr ${MAX} - 1`
done

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 多核CPU编译优化
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MAKE_J_NUMBER=`cat /proc/cpuinfo | grep vendor_id | wc -l`

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# MAKEFILE中使用的路径变量定义
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 工程根目录 ROOT_DIR
if [[ -n "$ROOT_DIR" ]]; then
    export SOFT_WORKDIR=`cygpath $ROOT_DIR`
else
    echo Pls define ROOT_DIR at cust_build.bat && exit
fi
# 客户路径需要的路径或变量的设置
CUST_BUILD_CFG_FILE=$SOFT_WORKDIR/project/$PROJ_NAME/build/cust_cfg.sh
test -f $CUST_BUILD_CFG_FILE && source $CUST_BUILD_CFG_FILE

# 获取SVN最新的revison号作为版本号
SubWCRev.exe ${ROOT_DIR} ${ROOT_DIR}/env/TortoiseSvn/SubWCRev.tpl ${ROOT_DIR}/env/TortoiseSvn/SubWCRev.tpl2 >/dev/null
export SVN_REVISION=`cat ${ROOT_DIR}/env/TortoiseSvn/SubWCRev.tpl2`
rm ${SOFT_WORKDIR}/env/TortoiseSvn/SubWCRev.tpl2

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 编译log文件控制
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 获取编译输出的路径
BUILD_PATH_NAME=`make -s -f ${SOFT_WORKDIR}/project/${PROJ_NAME}/build/version.mk AM_VER_ECHO_SUPPORT=TRUE ECHO_EX_VER`
echo BUILD_PATH_NAME=${BUILD_PATH_NAME}
if [ "${BUILD_PATH_NAME}" == "" ]; then
    echo "[build.sh] Log file put to ???";
    exit
fi
LOG_FILE_PATH=$SOFT_WORKDIR/build
#echo LOG_FILE_PATH=${LOG_FILE_PATH}
if [ "${LOG_FILE_PATH}" == "" ]; then
    echo "[cust_build.sh] Log file put to ???";
    exit
fi

# 根据当前时间，产生不同的文件
#export LOG_FILE=${LOG_FILE_PATH}/build_log_`date "+%Y%m%d%a%H%M"`.log
# OR 每次都使用一个相同的文件
LOG_FILE=${LOG_FILE_PATH}/${BUILD_PATH_NAME}_build.log

# 检查存放log的目录是否建立
if [ ! -d ${LOG_FILE_PATH} ]; then
	mkdir ${LOG_FILE_PATH}
fi

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 开始编译
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Make

start_time=`date +%s`

cd $ROOT_DIR
if [ ${NEED_CLEAN} -eq 1 ]; then
    make clean
fi
#exit
if [ ${MAKE_J_NUMBER} -gt 1 ]; then
    make -j${MAKE_J_NUMBER} 2>&1 | tee ${LOG_FILE}
else
    make 2>&1 | tee ${LOG_FILE}
fi

end_time=`date +%s`

time_distance=`expr ${end_time} - ${start_time}`
hour_distance=`expr ${time_distance} / 3600`
hour_remainder=`expr ${time_distance} % 3600`
min_distance=`expr ${hour_remainder} / 60`
sec_distance=`expr ${hour_remainder} % 60`
echo ++++ Build Time: ${hour_distance}:${min_distance}:${sec_distance} ++++

exit
