# rv32i_min_cpu

A hand-written 5-stage pipelined RV32I core (IF / ID / EX / MEM / WB) with data RAM,
instruction ROM, a simple bus, a UART and GPIO. C programs are compiled to a hex image
and loaded into instruction memory; example programs report a pass count to a fixed
address.

- ISA: RV32I (`-march=rv32i -mabi=ilp32`), with byte loads/stores (`lb/lbu/sb`) and word `lw/sw`
- Pipeline: load-use stall, branch/jump flush, EX/MEM and MEM/WB forwarding
- Peripherals: UART transmit (polled) and GPIO direction/output/input

## Layout

```
rtl/core    cpu, pc, imem, dmem, regfile, alu, CU, imm_gen
rtl/bus     simple_bus
rtl/periph  uart, gpio
rtl/soc_top soc_top
sim         testbench and simulation workspace (not needed for Vivado)
sw/test     start.s, link.ld, bin2memh.py and example C programs
```

## Memory map (simple_bus decodes mem_addr[15:12])

| Address         | Device | Notes |
|---|---|---|
| `0x0000–0x0FFF` | dmem | 4 KB data RAM with byte strobes. Stack top is `0x1000`, grows down; `.data/.bss` live at the low end |
| `0x1000`        | UART DATA | write = transmit a byte, read = received byte |
| `0x1004`        | UART STAT | bit0 = TX idle (~tx_busy), bit1 = RX ready |
| `0x2000`        | GPIO dir  | bit = 1 makes the pin an output |
| `0x2004`        | GPIO out  | output level |
| `0x2008`        | GPIO in   | synchronized pin input |
| `0x8000–0x8FFF` | imem read-back window | read-only, aliases imem physical `0x000–0xFFF`; used at boot to copy `.data`. Writes are ignored |
| `0x1FFC`        | result port | decodes to an unused UART register, so writes are dropped; used as a software result/observation port |

## Building firmware

```sh
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -msmall-data-limit=0 -mno-relax \
  -O2 -nostdlib -ffreestanding -T link.ld start.s prog.c -o prog.elf
riscv-none-elf-objcopy -O binary prog.elf prog.bin
python bin2memh.py prog.bin imem.hex
```

`imem.hex` is what `imem` loads with `$readmemh`. Useful inspection:

```sh
riscv-none-elf-objdump -d -M numeric,no-aliases prog.elf  # disassembly
riscv-none-elf-objdump -h prog.elf                       # section VMA/LMA/size
```

## C test programs

The programs under `sw/test` are **AI-generated verification tests** (each finishes by
writing its pass count to `0x1FFC`, then loops forever), not hand-written firmware.

If you ask an AI (Copilot, Doubao, ...) to write one, put these constraints in the prompt:

- RV32I, freestanding: `-nostdlib -ffreestanding`, no libc, no `* / %`, no 16-bit types
- always add `-msmall-data-limit=0 -mno-relax` (otherwise small globals are addressed
  through `gp`/x4, which `start.s` never initializes)
- touch peripherals and `0x1FFC` only through `volatile` pointers (addresses in the map above)
- write the answer **once** to `0x1FFC`, then `while (1)`; `main` must never return
- stack top is `0x1000` (grows down); globals start at the bottom of dmem

## How initialized globals (.data) work

- `link.ld` places `.text` at VMA=LMA=0. `.data` has its **run address (VMA)** in dmem but
  its **load address (LMA)** right after `.text` (i.e. burned into imem), and defines
  `_data_load_addr = 0x8000 + (.data offset in imem)`.
- imem has a second read-only port. In the MEM stage the CPU redirects reads in
  `0x8000–0x8FFF` to that port (low 12 bits = imem byte address); all other addresses go
  to the bus.
- At boot `copy_data` reads the `.data` master copy from imem via the window and stores it
  to dmem, `clear_bss` zeroes `.bss`, and only then is `main` called.
- Two read ports are needed because, once the pipeline is full, instruction fetch and a
  `.data` read can happen in the same cycle with different addresses.

## Limitations

1. No half-word (16-bit) instructions: no `sh/lh/lhu`, no `short/uint16_t`.
2. No M extension: no multiply/divide (`* / %`).
3. No libc / no operating system.
4. UART TX is implemented and exercised; the RX path exists but is not end-to-end tested.
