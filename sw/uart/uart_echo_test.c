/*
 * uart_echo_test.c - bidirectional USB-UART demo for Basys 3 (PC <-> FPGA).
 *
 * After a short power-on banner it echoes every byte received from the PC
 * straight back. Type in the serial terminal and the FPGA returns the same
 * characters, proving both directions (RX and TX) work. Carriage return is
 * expanded to CR+LF so pressing Enter starts a fresh line.
 *
 * Register map (simple_bus decode on addr[15:12] = 0x1):
 *   0x1000 DATA  write = send a byte ; read = received byte (clears rx_ready)
 *   0x1004 STAT  bit0 = TX idle (safe to send), bit1 = RX byte ready
 *
 * No string literals: the current link script maps .rodata into instruction
 * space that the data port cannot read, so the banner is sent character by
 * character from immediate constants.
 *
 * Build from sw/uart (reuses ../test start.s / link.ld / bin2memh.py):
 *   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
 *     -O2 -nostdlib -ffreestanding -T ../test/link.ld ../test/start.s \
 *     uart_echo_test.c -o t.elf
 *   riscv-none-elf-objcopy -O binary t.elf t.bin
 *   python ../test/bin2memh.py t.bin imem.hex
 * then copy imem.hex to board/basys3 (and sim/hex for the ModelSim echo check).
 */

#define UART_DATA (*(volatile unsigned int *)0x1000)
#define UART_STAT (*(volatile unsigned int *)0x1004)
#define RESULT    (*(volatile unsigned int *)0x1FFC) /* sim marker only: reached main */

static void uart_putc(unsigned c) {
    while ((UART_STAT & 0x1u) == 0u) { /* wait until the transmitter is idle */ }
    UART_DATA = c;
}

int main(void) {
    unsigned c;

    RESULT = 1u; /* simulation: main is alive (ignored by the board bus) */

    /* power-on banner, sent as immediate characters (no rodata) */
    uart_putc('\r'); uart_putc('\n');
    uart_putc('E'); uart_putc('C'); uart_putc('H'); uart_putc('O');
    uart_putc('\r'); uart_putc('\n');

    for (;;) {
        if (UART_STAT & 0x2u) {          /* rx_ready: a byte arrived */
            c = UART_DATA;               /* read also clears rx_ready */
            if (c == '\r') {
                uart_putc('\r');         /* expand Enter into CR+LF */
                uart_putc('\n');
            } else {
                uart_putc(c);            /* echo the byte back unchanged */
            }
        }
    }
}
