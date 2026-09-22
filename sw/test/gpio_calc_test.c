/*
 * gpio_calc_test.c - on-board demo for Basys 3 (no UART needed).
 *
 * GPIO is widened to 16 bits for the board:
 *   gpio[7:0]   = inputs  from the 8 slide switches SW0..SW7 (dir = 0)
 *   gpio[15:8]  = outputs to the 8 LEDs LD0..LD7            (dir = 1)
 *
 * The LEDs show popcount(switches): the number of switches that are ON,
 * in binary (0..8). Any switch pattern gives the correct computed answer,
 * which is what a fixed blink state machine cannot do.
 *
 * Build (note the two mandatory flags):
 *   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
 *     -O2 -nostdlib -ffreestanding -T link.ld start.s gpio_calc_test.c -o t.elf
 *   riscv-none-elf-objcopy -O binary t.elf t.bin
 *   python bin2memh.py t.bin imem.hex
 */

#define GPIO_DIR (*(volatile unsigned int *)0x2000)
#define GPIO_OUT (*(volatile unsigned int *)0x2004)
#define GPIO_IN  (*(volatile unsigned int *)0x2008)

static int popcount(unsigned int x) {
    int n = 0;
    while (x) {
        n += (int)(x & 1u);
        x >>= 1;
    }
    return n;
}

int main(void) {
    GPIO_DIR = 0x0000FF00u;  /* [15:8] output -> LEDs, [7:0] input <- switches */

    for (;;) {
        unsigned int sw = GPIO_IN & 0xFFu;
        GPIO_OUT = (popcount(sw) & 0xFFu) << 8;
    }
}
