/*
 * final.c - RV32I 最小 CPU 最终综合验收程序
 * 每个子检查通过则 pass++，最终把 pass 写到 0x1FFC。
 * 预期：26 项全部通过 -> result = 26 (0x1A)，-O0 / -O2 一致。
 *
 * 覆盖（均为当前硬件已实现能力）：
 *   add/addi/sub, sll/slli/srl/sra, and/andi/or/xor,
 *   slt/sltu 与 beq/bne/blt/bge/bltu/bgeu,
 *   jal/jalr(函数调用/返回、多帧), lui,
 *   lw/sw 栈数组、循环、变址寻址、load-use, lbu 字节读。
 * 刻意不使用：sb/sh（字节存储未实现）、带初值全局变量(.data 需 IMEM 数据读)、外设。
 */

__attribute__((noinline))
int double_it(int x) { return x + x; }

__attribute__((noinline))
int compute(int a, int b) { return double_it(a) + double_it(b); }

int main() {
    int pass = 0;

    /* ---- A. 算术 add/addi/sub ---- */
    volatile int a = 30, b = 10;
    volatile int c = 7, d = 8, e = 41;
    if (a - b == 20) pass++;          /* 1  sub                 */
    if (c + d == 15) pass++;          /* 2  add                 */
    if (e + 1 == 42) pass++;          /* 3  addi                */

    /* ---- B. 移位 sll/slli/srl/sra ---- */
    volatile int one = 1, four = 4, three = 3;
    volatile unsigned ua = 0xF0u, ub = 4u;
    volatile int neg = -16;
    if ((one << four) == 16) pass++;  /* 4  sll  (寄存器移位)   */
    if ((three << 1) == 6) pass++;    /* 5  slli (立即数移位)   */
    if ((ua >> ub) == 15) pass++;     /* 6  srl  (逻辑右移)     */
    if ((neg >> one) == -8) pass++;   /* 7  sra  (算术右移)     */

    /* ---- C. 逻辑 and/andi/or/xor ---- */
    volatile int x33 = 0x33, x0f = 0x0f, x30 = 0x30, x05 = 0x05, sv = 7;
    if ((x33 ^ x0f) == 0x3C) pass++;  /* 8  xor = 60            */
    if ((x30 | x05) == 0x35) pass++;  /* 9  or  = 53            */
    if ((x0f & x33) == 3) pass++;     /* 10 and = 3             */
    if ((sv & 15) == 7) pass++;       /* 11 andi                */

    /* ---- D. 比较与分支 slt/sltu/beq/bne/... ---- */
    volatile int five = 5, nine = 9;
    volatile unsigned oneu = 1u, big = 0xFFFFFFFEu;
    if ((five < nine) == 1) pass++;   /* 12 slt  true / blt     */
    if ((nine < five) == 0) pass++;   /* 13 slt  false / bge    */
    if ((oneu < big) == 1) pass++;    /* 14 sltu true / bltu    */
    if ((big < oneu) == 0) pass++;    /* 15 sltu false / bgeu   */
    if (a == a) pass++;               /* 16 beq                 */
    if (a != b) pass++;               /* 17 bne                 */

    /* ---- E. 函数调用 jal / jalr（多帧、参数、返回值）---- */
    if (double_it(21) == 42) pass++;  /* 18 单层 call/ret       */
    if (compute(10, 11) == 42) pass++;/* 19 嵌套 call/ret       */

    /* ---- F. LUI 大立即数 ---- */
    volatile int k = 0x12345000;
    if (k == 0x12345000) pass++;      /* 20 lui                 */

    /* ---- G. 栈数组 lw/sw + 循环 + 变址 + load-use ---- */
    volatile int arr[5];
    int i, sum = 0;
    for (i = 0; i < 5; i++) arr[i] = i + 1;
    for (i = 0; i < 5; i++) sum += arr[i];
    if (sum == 15) pass++;            /* 21 数组求和 1..5 = 15  */
    if (arr[2] == 3) pass++;          /* 22 变址寻址            */

    /* ---- H. LBU 字节读（整字 sw 初始化，小端拆字节）---- */
    volatile unsigned int word = 0x44332211u;
    volatile unsigned char *p = (volatile unsigned char *)&word;
    if (p[0] == 0x11) pass++;         /* 23 lbu 偏移0           */
    if (p[3] == 0x44) pass++;         /* 24 lbu 偏移3           */

    /* ---- I. 综合控制流：奇偶 if/else ±1 ---- */
    int cc = 0;
    for (i = 0; i < 10; i++) {
        if (i % 2 == 0) cc++;
        else cc--;
    }
    if (cc == 0) pass++;              /* 25 测试3 回归 = 0      */

    /* ---- J. 无符号循环 bltu/bgeu ---- */
    volatile unsigned lim = 3u;
    unsigned u;
    int cnt = 0;
    for (u = 0; u < lim; u++) cnt++;
    if (cnt == 3) pass++;             /* 26 无符号回边          */

    *(volatile int *)0x1FFC = pass;
    while (1);
}
