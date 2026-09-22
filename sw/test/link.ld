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
        _data_load_offset = .;  /* data初始值在IMEM里的物理偏移，紧跟代码后 */
    } > IMEM

    /* 数据段：运行地址(VMA)在DMEM，加载地址(LMA)为IMEM物理偏移（烧录位置） */
    .data : AT(_data_load_offset)
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

    /* data初值的“数据总线可读”地址 = IMEM物理偏移 + 回读窗口基址0x8000。
       CPU内部把 0x8000~0x8FFF 旁路到 imem 的只读数据口，start.s 经此窗口拷贝，
       拷贝到DMEM后，程序仍按低地址(DMEM)访问变量。 */
    _data_load_addr = 0x8000 + _data_load_offset;
}
