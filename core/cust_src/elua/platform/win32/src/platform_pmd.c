
#include <stdio.h>

#include "platform.h"
#include "platform_pmd.h"

int platform_pmd_init(PlatformPmdCfg *pmdCfg)
{
#define PRINT_FIELD(fIELD) printf("[platform_pmd_init]: " #fIELD " %d\n", pmdCfg->fIELD)

    PRINT_FIELD(battFullLevel);
    PRINT_FIELD(battRechargeLevel);
    PRINT_FIELD(poweronLevel);
    PRINT_FIELD(poweroffLevel);

    PRINT_FIELD(currentFirst);
    PRINT_FIELD(battlevelFirst);
    PRINT_FIELD(currentSecond);
    PRINT_FIELD(battlevelSecond);
    PRINT_FIELD(currentThird);

    return PLATFORM_OK;
}

int platform_ldo_set(PlatformLdoId id, int level)
{
    //printf("[platform_ldo_set]: %d %d\r\n", id, level);

    return PLATFORM_OK;
}

int platform_pmd_powersave(int sleep_wake)
{
    //printf("[platform_pmd_powersave]: %d\r\n", sleep_wake);

    return PLATFORM_OK;
}

int platform_pmd_get_charger(void)
{
    static int charger = 0;

    charger = !charger;

    return 1;
}

int platform_pmd_get_chg_param(BOOL *battStatus, u16 *battVolt, u8 *battLevel, BOOL *chargerStatus, u8 *chargeState)
{
	*battStatus = TRUE;
	*battVolt = 3800;
	*battLevel = 50;
	*chargerStatus = FALSE;
	*chargeState = 0;
	return PLATFORM_OK;
}