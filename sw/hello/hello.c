#define UART_DATA  (*(volatile unsigned int *)0x1000)
#define UART_STAT  (*(volatile unsigned int *)0x1004)

void uart_putc(char c)
{
    while ((UART_STAT & 0x01) == 0);
    UART_DATA = c;
}

void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}

__attribute__((section(".text.main"))) int main(void)
{
    __asm__ volatile ("li sp, 0x0F00");
    uart_puts("Hello RISC-V SoC!\n");
    while (1);
}

