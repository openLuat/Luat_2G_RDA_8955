/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_pmd.c
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2013/3/28
 *
 * Description:
 *          lua pmd平台接口实现
 **************************************************************************/

#include <stdio.h>

#include "rda_pal.h"

#include "platform.h"
#include "platform_pmd.h"

static const E_AMOPENAT_PM_LDO ldo2OpenatLdo[PLATFORM_LDO_QTY] = {
    OPENAT_LDO_POWER_KEYPDA,
    OPENAT_LDO_POWER_LCD,
/*+\NEW\liweiqiang\2013.5.8\增加KP_LEDR,G,B控制*/
    OPENAT_LDO_POWER_KP_LEDR,
    OPENAT_LDO_POWER_KP_LEDG,
    OPENAT_LDO_POWER_KP_LEDB,
/*-\NEW\liweiqiang\2013.5.8\增加KP_LEDR,G,B控制*/

/*+\NEW\liweiqiang\2013.6.1\增加LDO_VIB控制接口*/
    OPENAT_LDO_POWER_VIB,
/*-\NEW\liweiqiang\2013.6.1\增加LDO_VIB控制接口*/

/*+\NEW\liweiqiang\2013.10.10\增加LDO_VLCD控制POWER_VLCD*/
    OPENAT_LDO_POWER_VLCD,
/*-\NEW\liweiqiang\2013.10.10\增加LDO_VLCD控制POWER_VLCD*/

/*+\NEW\liweiqiang\2013.11.8\增加LDO_VASW,VMMC控制*/
    OPENAT_LDO_POWER_ASW,
    OPENAT_LDO_POWER_MMC,
/*-\NEW\liweiqiang\2013.11.8\增加LDO_VASW,VMMC控制*/

/*+\new\liweiqiang\2014.5.9\增加LDO_VCAM控制 */
    OPENAT_LDO_POWER_CAM,
/*-\new\liweiqiang\2014.5.9\增加LDO_VCAM控制 */

};

/*+\NEW\liweiqiang\2013.9.8\增加pmd.init设置充电电流接口 */
extern BOOL cust_pmd_init(PlatformPmdCfg *cfg);

static E_OPENAT_CHARGE_CURRENT getOpenatCurrent(u16 current)
{
    static const u16 openatCurrentVal[OPENAT_PM_CHARGE_CURRENT_QTY] =
    {
        0,
        50,
        100,
        150,
        200,
        300,
        400,
        500,
        600,
        700,
        800
    };
    uint16 i;

    for(i = 1/*OFF不去判断*/; i < OPENAT_PM_CHARGE_CURRENT_QTY; i++)
    {
        if(openatCurrentVal[i] == current)
        {
/*+\BUG WM-1015\rufei\2013.11.19\ 修改lua充电控制*/
            return i;
/*-\BUG WM-1015\rufei\2013.11.19\ 修改lua充电控制*/
        }
        else if(openatCurrentVal[i] > current)
        {
            break;
        }
    }

    return OPENAT_PM_CHARGE_CURRENT_QTY;
}


int platform_pmd_init(PlatformPmdCfg *pmdCfg)
{
    #define CHECK_FILED(fIELD) do{ \
        if(pmdCfg->fIELD != PMD_CFG_INVALID_VALUE && (pmdCfg->fIELD = getOpenatCurrent(pmdCfg->fIELD)) == OPENAT_PM_CHARGE_CURRENT_QTY) \
        { \
            PUB_TRACE("[platform_pmd_init]: error filed " #fIELD); \
            return PLATFORM_ERR; \
        } \
    }while(0)

    CHECK_FILED(currentFirst);
    CHECK_FILED(currentSecond);
    CHECK_FILED(currentThird);

    return cust_pmd_init(pmdCfg) ? PLATFORM_OK : PLATFORM_ERR;
}
/*-\NEW\liweiqiang\2013.9.8\增加pmd.init设置充电电流接口 */

int platform_ldo_set(PlatformLdoId id, int level)
{
    if(ldo2OpenatLdo[id] >= OPENAT_LDO_POWER_INVALID){
        return PLATFORM_ERR;
    }
    
    IVTBL(poweron_ldo)(ldo2OpenatLdo[id], level);

    return PLATFORM_OK;
}


int platform_pmd_powersave(int sleep_wake)
{
    if(sleep_wake){
/*+\NEW\liweiqiang\2013.10.19\设置工作时主频为208M*/
        IVTBL(sys_request_freq)(OPENAT_SYS_FREQ_32K);
        IVTBL(enter_deepsleep)();
    }
    else{
        IVTBL(exit_deepsleep)();
        IVTBL(sys_request_freq)(OPENAT_SYS_FREQ_208M);
/*-\NEW\liweiqiang\2013.10.19\设置工作时主频为208M*/
    }

    return PLATFORM_OK;
}

/*+\NEW\liweiqiang\2014.2.13\增加pmd.charger查询充电器状态接口 */
int platform_pmd_get_charger(void)
{
    UINT32 chargerStatus;
    
    chargerStatus = IVTBL(get_chargerHwStatus)();
    return chargerStatus == OPENAT_PM_CHR_HW_STATUS_AC_ON ? 1 : 0;
}
/*-\NEW\liweiqiang\2014.2.13\增加pmd.charger查询充电器状态接口 */


/*+NEW\zhuwangbin\2017.2.10\添加充电参数查询接口*/
int platform_pmd_get_chg_param(BOOL *battStatus, u16 *battVolt, u8 *battLevel, BOOL *chargerStatus, u8 *chargeState)
{
	IVTBL(get_chg_param)(battStatus, battVolt, battLevel, chargerStatus, chargeState);

	IVTBL(print)("zwb4 platform_pmd_get_chg_param %d,%d,%d,%d,%d", 
				*battStatus, *battVolt, *battLevel, *chargerStatus, *chargeState);
	return PLATFORM_OK;
}
/*+NEW\zhuwangbin\2017.2.10\添加充电参数查询接口*/