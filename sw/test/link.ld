ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K   /* 指令地址空间 */
    DMEM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K   /* 数据地址空间：0~0xFFF是DMEM */
}

SECTIONS
{
    /* 代码段：放IMEM，指令地址从0开始 */
    .text :
    {
        *(.text)
        *(.text.*)
        *(.rodata)
        . = ALIGN(4);
        _data_load_addr = .;  /* data初始值的加载地址：存在IMEM，紧跟代码后 */
    } > IMEM

    /* 数据段：运行地址在DMEM，初始值存在IMEM */
    .data : AT(_data_load_addr)
    {
        . = ALIGN(4);
        _data_start = .;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        _data_end = .;
    } > DMEM

    /* BSS段：DMEM里，启动时清零 */
    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > DMEM

    /* 栈顶：DMEM最末尾，向下增长 */
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
