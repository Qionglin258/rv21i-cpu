/*
 * soc.c - full SoC acceptance demo for Basys 3 (RV32I minimal SoC).
 *
 * Exercises both on-board I/O paths at once in a single endless loop:
 *   - GPIO: SW0..SW7 are inputs (gpio low byte, dir = 0). The popcount of the
 *     switch pattern (how many switches are ON, 0..8) is driven onto gpio high
 *     byte [15:8] and shown in binary on LD0..LD3 (dir = 1).
 *   - UART: after a short "ECHO" banner every byte received from the PC is
 *     echoed back (CR expanded to CR+LF), proving RX and TX.
 *
 * The GPIO update is non-blocking and runs every loop iteration; UART echo is
 * polled through the status register. Neither path stalls the other for longer
 * than one transmitted byte.
 *
 * Register map (simple_bus decode on addr[15:12]):
 *   0x1000 UART DATA  write = send a byte ; read = received byte (clears rx_ready)
 *   0x1004 UART STAT  bit0 = TX idle (safe to send), bit1 = RX byte ready
 *   0x2000 GPIO DIR, 0x2004 GPIO OUT, 0x2008 GPIO IN
 *   0x1FFC result marker (simulation only, dropped by the board bus)
 *
 * No string literals: the link script maps .rodata into instruction space the
 * data port cannot read, so the banner is sent from immediate characters.
 *
 * Build from sw (start.s, link.ld and bin2memh.py are in the same directory):
 *   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
 *     -O2 -nostdlib -ffreestanding -Wall -T link.ld start.s soc.c -o soc.elf
 *   riscv-none-elf-objcopy -O binary soc.elf soc.bin
 *   python bin2memh.py soc.bin imem.hex
 */

#define UART_DATA (*(volatile unsigned int *)0x1000)
#define UART_STAT (*(volatile unsigned int *)0x1004)
#define GPIO_DIR  (*(volatile unsigned int *)0x2000)
#define GPIO_OUT  (*(volatile unsigned int *)0x2004)
#define GPIO_IN   (*(volatile unsigned int *)0x2008)
#define RESULT    (*(volatile unsigned int *)0x1FFC) /* sim marker only: reached main */

static void uart_putc(unsigned c) {
    while ((UART_STAT & 0x1u) == 0u) { /* wait until the transmitter is idle */ }
    UART_DATA = c;
}

static int popcount(unsigned x) {
    int n = 0;
    while (x) {
        n += (int)(x & 1u);
        x >>= 1;
    }
    return n;
}

int main(void) {
    unsigned c;

    RESULT = 1u;                  /* simulation: main is alive (ignored on board) */
    GPIO_DIR = 0x0000FF00u;       /* [15:8] output -> LEDs, [7:0] input <- switches */

    /* power-on banner, sent as immediate characters (no rodata) */
    uart_putc('\r'); uart_putc('\n');
    uart_putc('E'); uart_putc('C'); uart_putc('H'); uart_putc('O');
    uart_putc('\r'); uart_putc('\n');

    for (;;) {
        unsigned sw = GPIO_IN & 0xFFu;
        GPIO_OUT = (unsigned)popcount(sw) << 8;   /* LD0..LD3 = number of ON switches */

        if (UART_STAT & 0x2u) {                   /* rx_ready: a byte arrived */
            c = UART_DATA;                        /* read also clears rx_ready */
            if (c == '\r') {
                uart_putc('\r');                  /* expand Enter into CR+LF */
                uart_putc('\n');
            } else {
                uart_putc(c);                     /* echo the byte back unchanged */
            }
        }
    }
}
