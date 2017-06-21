
/* Take into account assert bug in binutils-2.15*/
#if (USE_BINUTILS_2_19 == 1)
#define LD_ASSERT(condition, small, full)   ASSERT(condition, full)
#else
#define LD_ASSERT(condition, small, full)   ASSERT(condition, small)
#endif

/*Mandatory to have the BB side irq handler linked */
ENTRY (cust_main)

SECTIONS
{
    /***************************************
    **               ROM                  **
    ***************************************/
    /* flash start address*/
    . = AM_OPENAT_ROM_BASE;
    
    /* RO */
    .am_openat_custvtbl . : AT (ADDR(.am_openat_custvtbl))
    {
        _am_openat_ro_lma = .;
        _am_openat_ro_vma = .;
        KEEP(*(.am_openat_custvtbl))
        . = ALIGN(0x10);
    }
	_am_openat_ro_lma_end = .;
	_am_openat_ro_lma_size = _am_openat_ro_lma_end - _am_openat_ro_lma;
	
	LD_ASSERT(ABSOLUTE(_am_openat_ro_lma_size) <= ABSOLUTE(0x40),
              "AM OpenAT", "CUST VTBL size bigger than 0x40")
	
	. = AM_OPENAT_ROM_BASE + 0x40;
			  
	.lua_info . : AT (ADDR(.lua_info))
    {
        _lua_info_ro_lma = .;
        _lua_info_ro_vma = .;
        KEEP(*(.lua_info))
        . = ALIGN(0x10);
    }
    
    .cust_rotext . : AT (ADDR(.cust_rotext))
    {
        *(.text)
        *(.text.*)
        *(.stub .gnu.linkonce.t.*)
        . = ALIGN(0x20);
    }
    _am_openat_ro_text_end = .;
    _am_openat_ro_text_size = _am_openat_ro_text_end - _am_openat_ro_lma;

    .cust_rodata . : AT (ADDR(.cust_rodata))
    {
        _am_openat_ro_data_start = .;
        *(.rdata)
        *(.rodata)
        *(.rodata.*)
        *(.rodata.*_png)
        *(.gnu.linkonce.r.*) 
        *(.rodata1)
        *(.roresdata)
        *(.robsdata)
        . = ALIGN(0x20);
    }
    _am_openat_ro_data_end = .;
    _am_openat_ro_data_size = _am_openat_ro_data_end - _am_openat_ro_data_start;
    
    _am_openat_ro_end = .;
    _am_openat_ro_size = _am_openat_ro_end - _am_openat_ro_lma;
    

    _am_openat_rw_lma = .;
	
    /* RAM */
    . = AM_OPENAT_RAM_BASE;
    /* RW */
    .cust_data . : AT ( _am_openat_rw_lma )
    {
        _am_openat_rw_vma = .;
        *(.data)
        *(.data.*)
        *(.gnu.linkonce.d.*)
        *(.sdata .sdata.* .gnu.linkonce.s.*)
        *(.sdata2 .sdata2.* .gnu.linkonce.s2.*)
        . = ALIGN(0x10);
    }
    _am_openat_rw_end = .;
    _am_openat_rw_size = _am_openat_rw_end - _am_openat_rw_vma;
    
    /* ZI */
    _am_openat_zi_base = .;
    .cust_bss . (NOLOAD) : AT (ADDR(.cust_bss))
    {
        *(.sbss .sbss.* .gnu.linkonce.sb.*)
        *(.sbss2 .sbss2.* .gnu.linkonce.sb2.*)
        *(.scommon)
        *(.dynbss)
        *(.bss .bss.* .gnu.linkonce.b.*)
        *(COMMON)
        *(.rambss)
        . = ALIGN(0x10);
    }
    _am_openat_zi_end = .;
    _am_openat_zi_size = _am_openat_zi_end - _am_openat_zi_base;
    
    _am_openat_rom_total_size = _am_openat_ro_size + _am_openat_rw_size;
    LD_ASSERT(ABSOLUTE(_am_openat_ro_size + _am_openat_rw_size) <= ABSOLUTE(AM_OPENAT_ROM_SIZE),
              "AM OpenAT", "CUST ROM size bigger than AM_OPENAT_ROM_SIZE")
    _am_openat_ram_total_size = _am_openat_rw_size + _am_openat_zi_size;
    LD_ASSERT(ABSOLUTE(_am_openat_rw_size + _am_openat_zi_size) <= ABSOLUTE(AM_OPENAT_RAM_SIZE),
              "AM OpenAT", "CUST RAM size bigger than AM_OPENAT_RAM_SIZE")
    
#ifdef AM_CONFIG_SUPPORT
    .am_config AM_CONFIG_BASE : AT (ADDR(.am_config))
    {
    	_am_config_section_start = .;
    	KEEP(*(.am_config))
    	. = ALIGN(0x1000); /* 4K bandery */
    }
    _am_config_section_end = .;
    _am_config_size = _am_config_section_end - _am_config_section_start;
    /*LD_ASSERT(ABSOLUTE(_am_config_section_start) > ABSOLUTE(_rom_flash_start_location),
              "AM CONFIG", "Am config data is overlapped with ram data.")*/
#endif

#ifdef AM_LUA_SUPPORT
    .lua_script_data LUA_SCRIPT_BASE : AT (ADDR(.lua_script_data))
    {
        _lua_script_section_start = .;
        KEEP(*(.lua_script_data))
        . = ALIGN(0x1000); /* 4K bandery */
    }
    _lua_script_section_end = .;
    _lua_script_size = _lua_script_section_end - _lua_script_section_start;
    LD_ASSERT(ABSOLUTE(_lua_script_section_start) > ABSOLUTE(AM_OPENAT_RAM_BASE + _am_openat_rom_total_size),
              "lua script", "lua script data is overlapped with rom data.")
#endif

/*+\BUG\AMOPENAT-75\brezen\2013.9.26\NV接口写入慢的问题*/
    
    . = AM_OPENAT_ROM_BASE + AM_OPENAT_ROM_SIZE - 0x2000;
    .am_openat_nv1 . : AT (ADDR(.am_openat_nv1))
    {
    	am_openat_nv1_start = .;
    	KEEP(*(.am_openat_nv1))
    	. = ALIGN(0x1000); /* 4K bandery */
    }
    am_openat_nv1_end = .;
    am_openat_nv1_size = am_openat_nv1_end - am_openat_nv1_start;	
    .am_openat_nv2 . : AT (ADDR(.am_openat_nv2))
    {
    	am_openat_nv2_start = .;
    	KEEP(*(.am_openat_nv2))
    	. = ALIGN(0x1000); /* 4K bandery */
    }
    am_openat_nv2_end = .;
    am_openat_nv2_size = am_openat_nv2_end - am_openat_nv2_start;
/*-\BUG\AMOPENAT-75\brezen\2013.9.26\NV接口写入慢的问题*/    
    #include "discard.ld"
}
