# rv32i_min_cpu

A hand-written 5-stage pipelined RV32I core (IF / ID / EX / MEM / WB) with data RAM,
instruction ROM, a simple peripheral bus, a UART and GPIO. C programs compile to a hex
image that is loaded into instruction memory; the same SoC runs in simulation and on a
Digilent Basys 3 board.

- ISA: RV32I (`-march=rv32i -mabi=ilp32`), word and byte loads/stores (`lw/sw`, `lb/lbu/sb`)
- Pipeline: load-use stall, branch/jump flush, EX/MEM,MEM/WB,and regfile forwarding
- Peripherals: polled UART (TX and RX) and GPIO direction/output/input
- Board: Digilent Basys 3 (Artix-7) — switches in, LEDs out, one USB for JTAG and UART

## Layout

```
rtl/core    cpu, pc, imem, dmem, regfile, alu, CU, imm_gen
rtl/bus     simple_bus
rtl/periph  uart, gpio
rtl/soc_top soc_top
board/basys3 board_top.v, basys3.xdc, imem.hex (Vivado top level)
sw/test     start.s, link.ld, bin2memh.py and verification programs
sw/final    combined final demo (switch popcount LEDs + UART echo)
```

## Memory map

The CPU issues **byte addresses**. `simple_bus` selects a device from the top nibble
`mem_addr[15:12]` (an address that matches no device is dropped, and such reads return 0); a
selected peripheral is handed the register offset `mem_addr[3:0]`.

| Address         | Device | Notes |
|---|---|---|
| `0x0000–0x0FFF` | dmem | 4 KB data RAM, see below |
| `0x1000`        | UART DATA | write = push `wdata[7:0]` into the TX shifter; read = the received byte, and reading clears RX-ready |
| `0x1004`        | UART STAT | bit0 = TX idle (`~tx_busy`), bit1 = a received byte is ready (`rx_ready`) |
| `0x2000`        | GPIO dir  | per-bit direction: 1 = output, 0 = input |
| `0x2004`        | GPIO out  | per-bit output level |
| `0x2008`        | GPIO in   | read-only; board inputs after two synchronizer flip-flops |
| `0x8000–0x8FFF` | imem read-back window | read-only alias of imem bytes `0x000–0xFFF`, see below |
| `0x1FFC`        | result port | decodes to an unused UART offset, so the write is dropped; verification programs use it as an observation address |

**Data RAM.** dmem stores 1024 32-bit words (`reg [31:0] mem[0:1023]`), i.e. 4096 bytes
($2^{12}$ bytes = $2^{15}$ bits). The bus feeds it the word index `mem_addr[11:2]`; the low
two bits `mem_addr[1:0]` select a byte within that word. Reads return the whole word
combinationally, and `lb/lbu` pick the addressed byte and sign/zero-extend it back in the CPU.
Compiled programs use the space from both ends: `.data` then `.bss` (the global/static
variables) are placed from address 0 upward, while the stack starts at `_stack_top = 0x1000`
and grows down. `start.s` loads `sp`  ( stack pointer ) with `0x1000` and every frame decrements it before
storing. Address `0x1000` itself is never accessed.

**GPIO.** The driven value is `gpio_out = dir_reg & out_reg` per bit, so a pin goes high only
when its dir bit is 1 *and* its out bit is 1. The input port is always readable at `0x2008`
regardless of the direction bits; the raw pins pass through two flip-flops first to avoid
metastability. The Basys 3 switch/LED wiring is given in *Board bring-up*.

**imem read-back window.** Besides the instruction-fetch port, imem has a second read-only
data port: reading `0x8000 + n` returns imem byte `n`, and in the MEM stage the CPU muxes this
data in instead of the bus (writes to the window are ignored). It lets the boot code pull the
`.data` initial values out of imem — see *How initialized globals (.data) work*. Two ports are
needed because, once the pipeline is full, an instruction fetch and a `.data` load can read two
different imem addresses in the same cycle.

## Building firmware

```sh
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
  -O2 -nostdlib -ffreestanding -T link.ld start.s prog.c -o prog.elf
riscv-none-elf-objcopy -O binary prog.elf prog.bin
python bin2memh.py prog.bin imem.hex
```

`imem.hex` is what `imem` loads with `$readmemh`. The board program under `sw/final` reuses
`../test/start.s`, `../test/link.ld` and `../test/bin2memh.py`; after
building, copy the generated `imem.hex` over `board/basys3/imem.hex` and rebuild the
bitstream. Useful inspection:

```sh
riscv-none-elf-objdump -d -M numeric,no-aliases prog.elf  # disassembly
riscv-none-elf-objdump -h prog.elf                       # section VMA/LMA/size
```

## On-board programs (Basys 3)

- `sw/final/final_demo.c` — combined acceptance demo running both paths in one loop: the
  popcount of the 8 switches on LD0..LD3, and UART echo of typed characters (RX + TX, Enter
  expanded to CR+LF) after an `ECHO` banner. LD7 is a clock heartbeat independent of the CPU.

## Board bring-up (Basys 3)

- The SoC is clocked at **6.25 MHz**: `board_top` divides the 100 MHz oscillator by 16 and
  feeds it through a `BUFG`. The asynchronous imem/dmem reads do not close timing at 100 MHz;
  the XDC declares the 6.25 MHz net as a generated clock so the whole SoC is timed.
- Reset is slide switch **SW15** (slide UP/ON to hold reset), asserted asynchronously and
  released synchronously to the 6.25 MHz CPU clock. At config the FPGA's GSR already
  initializes every flip-flop; the two reset-sync stages start at 0 and briefly hold the core,
  so no power-on counter is needed. The center pushbutton is not used on this board.
- Pins: SW0..SW7 drive `gpio_in[7:0]`; `gpio_out[11:8]` drives LD0..LD3 (the popcount),
  LD6..LD4 stay off and LD7 is the clock heartbeat. UART is **A18** (FPGA TX) and **B18**
  (FPGA RX), wired on-board to the FTDI USB bridge.
- A **single micro-USB cable** on the JTAG/PROG port both programs the FPGA and exposes the
  UART as a USB serial (COM) port. Open the COM port at **115200, 8 data bits, 1 stop bit,
  no parity, no flow control**.

## C programs

The programs under `sw/test` are AI-generated verification tests (each finishes by writing
its pass count to `0x1FFC`, then loops forever). When asking an AI (Copilot, Doubao, ...) to
write firmware for this core, put these constraints in the prompt:

- RV32I, freestanding: `-nostdlib -ffreestanding`, no libc, no `* / %`, no 16-bit types
- always add `-msmall-data-limit=0 -mno-relax` (otherwise small globals are addressed through
  `gp`/x3, which `start.s` never initializes)
- no string literals or `const` arrays: `.rodata` currently lives in instruction space and is
  not reachable through the data port (low data addresses decode to dmem); build text and hex
  digits from immediate arithmetic instead
- touch peripherals and `0x1FFC` only through `volatile` pointers (addresses in the map above)
- a verification program writes the answer **once** to `0x1FFC`, then `while (1)`; `main` never returns
- stack top is `0x1000` (grows down); globals start at the low end of dmem

## How initialized globals (.data) work

- `link.ld` places `.text` at VMA=LMA=0. `.data` has its **run address (VMA)** in dmem but its
  **load address (LMA)** right after `.text` (i.e. burned into imem), and defines
  `_data_load_addr = 0x8000 + (.data offset in imem)`.
- imem has a second read-only port. In the MEM stage the CPU redirects reads in
  `0x8000–0x8FFF` to that port (low 12 bits = imem byte address); all other addresses go to the bus.
- At boot `copy_data` reads the `.data` master copy from imem via the window and stores it to
  dmem, `clear_bss` zeroes `.bss`, and only then is `main` called.
- Two read ports are needed because, once the pipeline is full, instruction fetch and a
  `.data` read can happen in the same cycle with different addresses.

## Limitations

1. No half-word (16-bit) loads/stores: no `sh/lh/lhu`, no `short`/`uint16_t`.
2. No M extension: no multiply/divide (`* / %`).
3. No libc and no operating system.
4. UART is polled only (no interrupts); 8N1, verified on the board at 115200.
