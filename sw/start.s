.global _start
.section .text

_start:
    /* 1. 设置栈指针 */
    la      sp, _stack_top

    /* 2. 拷贝.data段：从IMEM拷贝到DMEM */
    la      a0, _data_load_addr   /* 源地址：IMEM里的初始值 */
    la      a1, _data_start       /* 目的地址：DMEM里的运行地址 */
    la      a2, _data_end         /* 结束地址 */
copy_data:
    bge     a1, a2, copy_done     /* 拷完则跳出 */
    lw      t0, 0(a0)             /* 从IMEM读4字节 */
    sw      t0, 0(a1)             /* 写到DMEM */
    addi    a0, a0, 4
    addi    a1, a1, 4
    j       copy_data
copy_done:

    /* 3. 清零.bss段 */
    la      a0, _bss_start
    la      a1, _bss_end
clear_bss:
    bge     a0, a1, clear_done
    sw      zero, 0(a0)
    addi    a0, a0, 4
    j       clear_bss
clear_done:

    /* 4. 跳转到C语言main函数 */
    call    main

    /* main返回则死循环 */
end_loop:
    j       end_loop
