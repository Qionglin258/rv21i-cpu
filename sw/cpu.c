/*
 * cpu.c - CPU core pipeline demo (rv32i_min_cpu).
 *
 * Runs on the bare core with only dmem attached (no bus, no UART/GPIO), so it
 * never touches a peripheral. It makes the three pipeline hazard mechanisms
 * visible in one short waveform:
 *   - load-use stall (load_bubble): a volatile load consumed on the next op
 *   - forwarding (EX/MEM): the dependent add/xor chain inside the loop
 *   - branch flush (branch_flush): the counted loop and the final spin
 *
 * All results are written to volatile variables: that is what keeps the
 * operations and the loop from being optimized away at -O2, and it supplies
 * runtime values the compiler cannot fold.
 *
 * Build from sw (same start.s, link.ld and bin2memh.py as soc.c):
 *   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
 *     -O2 -nostdlib -ffreestanding -Wall -T link.ld start.s cpu.c -o cpu.elf
 *   riscv-none-elf-objcopy -O binary cpu.elf cpu.bin
 *   python bin2memh.py cpu.bin imem_cpu.hex
 */

static volatile int v;           /* observed scalar (dmem) */
static volatile int loops;       /* volatile loop counter keeps the loop alive */

int main(void) {
    int a, b, c;

    /* basic load/store of a volatile scalar */
    v = 1;
    a = v;               /* load */
    b = a + 1;
    v = b;               /* make the result observable */

    /* the loop body exercises all three: load-use, forwarding and the branch */
    loops = 0;
    while (loops < 5) {
        a = loops;       /* volatile load */
        b = a + 1;       /* consume right after the load -> load-use stall */
        c = b ^ a;       /* depends on b and a -> EX/MEM forwarding */
        a = c + b;       /* depends on c and b -> EX/MEM and MEM/WB forwarding */
        loops = a;       /* volatile store */
    }

    for (;;) {           /* spin: no peripherals on this test */
    }
}
