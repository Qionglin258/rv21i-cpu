/*
 * uart_tx_test.c - board bring-up for the on-board USB-UART (FPGA -> PC).
 *
 * After power-on reset it prints an incrementing 32-bit counter in hex, so a
 * PC serial terminal shows a scrolling 00000000, 00000001, ... at 115200 8N1.
 * TX only (nothing is received), GPIO untouched.
 *
 * Only UART registers and immediate constants are used on purpose: the current
 * link script maps .rodata into instruction space that the data port cannot
 * read (low data addresses decode to DMEM), so there are no string literals and
 * no constant table here -- hex digits are built by arithmetic.
 *
 * Registers (simple_bus decode on addr[15:12] = 0x1):
 *   0x1000 DATA  write = send one byte
 *   0x1004 STAT  bit0 = TX idle (safe to send the next byte)
 *
 * Build from sw/uart (reuses ../test start.s / link.ld / bin2memh.py):
 *   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
 *     -O2 -nostdlib -ffreestanding -T ../test/link.ld ../test/start.s \
 *     uart_tx_test.c -o t.elf
 *   riscv-none-elf-objcopy -O binary t.elf t.bin
 *   python ../test/bin2memh.py t.bin imem.hex
 * then copy imem.hex to board/basys3 (and sim/hex for the ModelSim UART check).
 */

#define UART_DATA (*(volatile unsigned int *)0x1000)
#define UART_STAT (*(volatile unsigned int *)0x1004)

static void uart_putc(unsigned c) {
    while ((UART_STAT & 0x1u) == 0u) { /* wait until the transmitter is idle */ }
    UART_DATA = c;
}

static void uart_hex8(unsigned x) {
    int i;
    for (i = 7; i >= 0; --i) {
        unsigned n = (x >> (4 * i)) & 0xFu;
        uart_putc(n < 10u ? ('0' + n) : ('A' + (n - 10u)));
    }
}

static void delay(void) {
    volatile unsigned i;
    for (i = 0; i < 300000u; ++i) { }
}

int main(void) {
    unsigned cnt = 0;

    uart_putc('\r'); uart_putc('\n');
    uart_putc('R'); uart_putc('V'); uart_putc('3'); uart_putc('2');
    uart_putc('I'); uart_putc('\r'); uart_putc('\n');

    for (;;) {
        uart_hex8(cnt);
        uart_putc('\r');
        uart_putc('\n');
        ++cnt;
        delay();
    }
}
