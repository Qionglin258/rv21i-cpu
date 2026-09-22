/*
 * load_test.c - RV32I 最小 CPU load 宽度测试（套餐 A：lw / lbu / lb）
 * 用 sw 整字在栈上布置已知字节模式，再分别以
 *   lbu（零扩展）、lb（符号扩展）、lw（整字）读回比对；
 * pass 数写到 0x1FFC。预期 19 项全过 -> result = 19 (0x13)，-O0 / -O2 一致。
 *
 * 指令定向说明：gcc 15 在 -O0 读 signed char 时习惯发
 *   lbu + slli x,24 + srai x,24（软件符号扩展），并不主动发 lb；
 * 为保证 lb/lbu/lw 三条指令都被确定执行，下面用 always_inline 内联汇编
 * 把“读”指令钉死；地址计算（指针 +k）与结果比较仍交给 C。
 *
 * 刻意不使用：short/uint16_t（半字 lh/lhu 不支持）、sb（字节存储尚未实现）、
 *            带初值全局变量、外设。
 *
 * 字节布局（小端，地址从低到高）：
 *   buf[0] = 0xFF807F11 : lane0=0x11(+17)  lane1=0x7F(+127)
 *                         lane2=0x80(-128/128) lane3=0xFF(-1/255)
 *   buf[1] = 0x00440088 : lane0=0x88(-120/136) lane1=0x00
 *                         lane2=0x44(+68)  lane3=0x00
 */

static inline __attribute__((always_inline)) int
read_lb(const volatile signed char *p) {
    int v;
    __asm__ volatile ("lb %0, 0(%1)" : "=r"(v) : "r"(p));
    return v;
}

static inline __attribute__((always_inline)) unsigned int
read_lbu(const volatile unsigned char *p) {
    unsigned int v;
    __asm__ volatile ("lbu %0, 0(%1)" : "=r"(v) : "r"(p));
    return v;
}

static inline __attribute__((always_inline)) unsigned int
read_lw(const volatile unsigned int *p) {
    unsigned int v;
    __asm__ volatile ("lw %0, 0(%1)" : "=r"(v) : "r"(p));
    return v;
}

int main(void) {
    int pass = 0;
    volatile unsigned int buf[2];
    buf[0] = 0xFF807F11u;
    buf[1] = 0x00440088u;

    const volatile unsigned char *up = (const volatile unsigned char *)buf;
    const volatile signed char   *sp = (const volatile signed char   *)buf;

    /* ---- LBU：零扩展，逐 lane，8 项 ---- */
    if (read_lbu(&up[0]) == 0x11) pass++;   /* 1  word0 lane0            */
    if (read_lbu(&up[1]) == 0x7F) pass++;   /* 2  word0 lane1 = 127      */
    if (read_lbu(&up[2]) == 0x80) pass++;   /* 3  word0 lane2 零扩展=128 */
    if (read_lbu(&up[3]) == 0xFF) pass++;   /* 4  word0 lane3 零扩展=255 */
    if (read_lbu(&up[4]) == 0x88) pass++;   /* 5  word1 lane0 = 136      */
    if (read_lbu(&up[5]) == 0x00) pass++;   /* 6  word1 lane1            */
    if (read_lbu(&up[6]) == 0x44) pass++;   /* 7  word1 lane2 = 68       */
    if (read_lbu(&up[7]) == 0x00) pass++;   /* 8  word1 lane3            */

    /* ---- LB：符号扩展，逐 lane，8 项 ---- */
    if (read_lb(&sp[0]) == 17)   pass++;    /* 9  0x11                   */
    if (read_lb(&sp[1]) == 127)  pass++;    /* 10 0x7F 正数边界          */
    if (read_lb(&sp[2]) == -128) pass++;    /* 11 0x80 负数边界          */
    if (read_lb(&sp[3]) == -1)   pass++;    /* 12 0xFF = -1              */
    if (read_lb(&sp[4]) == -120) pass++;    /* 13 0x88 = -120            */
    if (read_lb(&sp[5]) == 0)    pass++;    /* 14 0x00                   */
    if (read_lb(&sp[6]) == 68)   pass++;    /* 15 0x44                   */
    if (read_lb(&sp[7]) == 0)    pass++;    /* 16 0x00                   */

    /* ---- LW：整字读，小端重组，2 项 ---- */
    if (read_lw(&buf[0]) == 0xFF807F11u) pass++; /* 17 */
    if (read_lw(&buf[1]) == 0x00440088u) pass++; /* 18 */

    /* ---- 交叉验证：同一字节 lbu(128) 与 lb(-128) 之和为 0 ---- */
    if ((int)read_lbu(&up[2]) + read_lb(&sp[2]) == 0) pass++; /* 19 */

    *(volatile int *)0x1FFC = pass;
    while (1);
}
