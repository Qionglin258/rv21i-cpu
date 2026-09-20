ENTRY(main)
SECTIONS
{
    . = 0x00000000;
    .text : {
        *(.text.main)
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
    }
    .data : { *(.data) }
    .bss  : { *(.bss)  }
}
