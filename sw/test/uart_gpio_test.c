/*
 * uart_gpio_test.c - UART 发送 + GPIO 输出 的外设测试（不改 RTL）
 *
 * 内存映射（simple_bus 按地址高 4 位片选）：
 *   0x1000 UART DATA：写=发送一个字节
 *   0x1004 UART STAT：bit0 = 发送空闲(~tx_busy)，bit1 = 接收就绪
 *   0x2000 GPIO dir  ：1=输出
 *   0x2004 GPIO out  ：输出电平
 *   0x2008 GPIO in   ：引脚同步输入
 *
 * 软件能自验 4 项（写 0x1FFC）；UART 线上到底发出了什么、GPIO 引脚电平，
 * 由 testbench 的 UART 监听器和 gpio_io 采样做端到端校验：
 *   +EXPECTED=4 +CYCLES=8000 +UART_LEN=5 +UART_SUM=419 +GPIO_EXP=5a
 *
 * 发送序列：0xA5、0x5A（翻转位型，充分压物理层），'O','K','\n'
 *   字节和 = 165+90+79+75+10 = 419，共 5 字节。
 */

#define UART_DATA (*(volatile unsigned int *)0x1000)
#define UART_STAT (*(volatile unsigned int *)0x1004)
#define GPIO_DIR  (*(volatile unsigned int *)0x2000)
#define GPIO_OUT  (*(volatile unsigned int *)0x2004)
#define GPIO_IN   (*(volatile unsigned int *)0x2008)

static void uart_putc(unsigned int c) {
    while ((UART_STAT & 0x1u) == 0u) { /* 等发送空闲 */ }
    UART_DATA = c;
}

int main(void) {
    int pass = 0;

    /* 1 上电后发送器应当空闲（STAT bit0 = 1） */
    if ((UART_STAT & 0x1u) == 1u) pass++;

    /* GPIO 全部配为输出 */
    GPIO_DIR = 0xFFu;
    if ((GPIO_DIR & 0xFFu) == 0xFFu) pass++;   /* 2 dir 读回 */

    GPIO_OUT = 0xA5u;
    if ((GPIO_OUT & 0xFFu) == 0xA5u) pass++;   /* 3 out 读回 */

    GPIO_OUT = 0x5Au;
    if ((GPIO_OUT & 0xFFu) == 0x5Au) pass++;   /* 4 最终输出 0x5A */

    /* UART 发送 5 个字节，testbench 在线上解码比对 */
    uart_putc(0xA5);
    uart_putc(0x5A);
    uart_putc('O');
    uart_putc('K');
    uart_putc('\n');

    *(volatile int *)0x1FFC = pass;
    while (1);
}
