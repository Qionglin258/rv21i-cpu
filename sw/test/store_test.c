/*
 * store_test.c - RV32I 最小 CPU store 宽度测试（套餐 A：sw / sb）
 * 用内联汇编把 sb / lbu / lw 钉死（指令定向），验证字节写掩码 byte_en：
 *   - 同一字内逐字节 sb，互不覆盖、对齐正确；
 *   - sw 初始化后 sb 只改目标字节，其余 3 字节保持（硬件读-改-写）；
 *   - 高模式字节 0xFF/0x80 落到正确 lane、不污染相邻字节；
 *   - 连续字节循环 sb（变址、跨字）+ lbu 读回；
 *   - sw 整字回归。
 * pass 数写到 0x1FFC。预期 17 项全过 -> result = 17 (0x11)，-O0/-O2 一致。
 *
 * 刻意不使用：sh（半字不支持）、带初值全局变量、外设。
 */

static inline __attribute__((always_inline)) void
write_sb(volatile unsigned char *p, unsigned int v) {
    __asm__ volatile ("sb %1, 0(%0)" :: "r"(p), "r"(v) : "memory");
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
    volatile unsigned int buf[8];
    volatile unsigned char *base = (volatile unsigned char *)buf;
    int k;

    /* ---- T1: 同一字 4 个 lane 逐个 sb，互不覆盖 ---- */
    buf[0] = 0x00000000u;
    write_sb(base + 0, 0xA1);
    write_sb(base + 1, 0xB2);
    write_sb(base + 2, 0xC3);
    write_sb(base + 3, 0xD4);
    if (read_lbu(base + 0) == 0xA1) pass++;  /* 1  lane0 */
    if (read_lbu(base + 1) == 0xB2) pass++;  /* 2  lane1 */
    if (read_lbu(base + 2) == 0xC3) pass++;  /* 3  lane2 */
    if (read_lbu(base + 3) == 0xD4) pass++;  /* 4  lane3 */
    if (read_lw(&buf[0]) == 0xD4C3B2A1u) pass++; /* 5 小端拼字 */

    /* ---- T2: sw 初始化后 sb 改单字节，其余字节保持（读-改-写）---- */
    buf[1] = 0x11223344u;
    write_sb(base + 6, 0xEE);               /* buf[1] 的 lane2 */
    if (read_lbu(base + 4) == 0x44) pass++; /* 6  lane0 保持 */
    if (read_lbu(base + 5) == 0x33) pass++; /* 7  lane1 保持 */
    if (read_lbu(base + 6) == 0xEE) pass++; /* 8  lane2 改写 */
    if (read_lbu(base + 7) == 0x11) pass++; /* 9  lane3 保持 */
    if (read_lw(&buf[1]) == 0x11EE3344u) pass++; /* 10 */

    /* ---- T3: 高模式字节 0xFF/0x80 落对 lane、不污染邻居 ---- */
    buf[2] = 0x00000000u;
    write_sb(base + 8,  0xFF);              /* buf[2] lane0 */
    write_sb(base + 11, 0x80);              /* buf[2] lane3 */
    if (read_lbu(base + 8)  == 0xFF) pass++;/* 11 lane0 = 255 */
    if (read_lbu(base + 9)  == 0x00) pass++;/* 12 lane1 未污染 */
    if (read_lbu(base + 10) == 0x00) pass++;/* 13 lane2 未污染 */
    if (read_lbu(base + 11) == 0x80) pass++;/* 14 lane3 = 128 */
    if (read_lw(&buf[2]) == 0x800000FFu) pass++; /* 15 */

    /* ---- T4: 连续 8 字节循环 sb（变址、跨字），再 lbu 求和 ---- */
    for (k = 0; k < 8; k++) write_sb(base + 12 + k, (unsigned int)(0x20 + k));
    {
        unsigned int sum = 0;
        for (k = 0; k < 8; k++) sum += read_lbu(base + 12 + k);
        if (sum == 284u) pass++;            /* 16 0x20..0x27 之和 */
    }

    /* ---- T5: sw 整字写读回归 ---- */
    buf[5] = 0xDEADBEEFu;
    if (read_lw(&buf[5]) == 0xDEADBEEFu) pass++; /* 17 */

    *(volatile int *)0x1FFC = pass;
    while (1);
}
