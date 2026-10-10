/*
 * data_init_test.c - 验证带非零初值的全局变量(.data)能正确初始化
 *
 * 原理：.data 初值烧在 IMEM（紧跟 .text），start.s 的 copy_data 经数据回读
 *       窗口 0x8000+ 把初值读到、再写到 DMEM 的运行地址；.bss 应被清零。
 *       全部加 volatile，强制从内存 load，防止 -O2 常量传播把初值变成立即数
 *       而“假绿”。
 *
 * 预期 12 项全过 -> result = 12 (0x0C)，-O0/-O2 一致。
 */

volatile unsigned int  g_word        = 0x12345678u;   /* .data 单字       */
volatile unsigned int  g_table[4]    = {11u, 22u, 33u, 44u}; /* .data 数组 */
volatile signed int    g_neg         = -7;            /* .data 负数       */
volatile unsigned char g_bytes[4]    = {0xA5, 0x5A, 0x00, 0xFF}; /* .data 字节 */
volatile unsigned int  g_zero;                        /* 未初始化，进入.bss，应清零     */

int main(void) {
    int pass = 0;

    if (g_word == 0x12345678u) pass++;        /* 1  .data 单字初值      */
    if (g_table[0] == 11u) pass++;            /* 2  .data 数组          */
    if (g_table[1] == 22u) pass++;            /* 3                      */
    if (g_table[2] == 33u) pass++;            /* 4                      */
    if (g_table[3] == 44u) pass++;            /* 5                      */
    if (g_neg == -7) pass++;                  /* 6  .data 负数          */
    if (g_bytes[0] == 0xA5) pass++;           /* 7  .data 字节(小端)    */
    if (g_bytes[1] == 0x5A) pass++;           /* 8                      */
    if (g_bytes[2] == 0x00) pass++;           /* 9  含 0x00 初值        */
    if (g_bytes[3] == 0xFF) pass++;           /* 10 高模式字节          */
    if (g_zero == 0u) pass++;                 /* 11 .bss 清零           */

    /* 12 变量必须在“可写”的 DMEM，而不是只读的 IMEM 窗口 */
    g_word = 0xCAFEBABEu;
    if (g_word == 0xCAFEBABEu) pass++;        /* 12 写回                */

    *(volatile int *)0x1FFC = pass;
    while (1);
}
