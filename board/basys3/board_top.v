// board_top.v - Basys 3 (XC7A35T-CPG236) wrapper around soc_top.
// Stage 1: 8 slide switches in (gpio_in[7:0]), LEDs out (gpio_out[15:8]).
// The 7-segment display is added in stage 2.
//
// GPIO is split into separate input/output vectors (no tri-state inout):
// the switches are a pure input and the LEDs a pure output, so every net
// has exactly one driver. Software sets GPIO_DIR = 0x0000FF00 (high byte).
//
// Clock: the teaching core has asynchronous imem/dmem reads and does not
// close timing at the 100 MHz oscillator (10 ns). A free-running divider
// drives the core through a global clock buffer (BUFG) at 6.25 MHz (160 ns).
// basys3.xdc declares that 6.25 MHz net as a generated clock (/16) so the
// whole SoC is timing-checked.
//
// Reset: a power-on reset (POR) holds the core for ~5.2 ms after config so it
// starts by itself. Slide switch SW15 (rst_sw, UP/ON) also requests reset.
// The two are combined and released synchronously to the divided CPU clock
// (asynchronous assert, synchronous release). The center button is not used:
// N17 reads high when untouched on this board.
//
// LEDs: LD7 is a ~1.5 Hz heartbeat straight from 100 MHz (clock-alive check);
//       LD0..LD3 show the popcount result (gpio_out high byte, low nibble).
//
// This wrapper is board-only; it is NOT compiled into the ModelSim testbench.

module board_top (
    input  wire       clk,     // W5, 100 MHz oscillator
    input  wire [7:0] sw,      // SW0..SW7  -> gpio_in[7:0]
    input  wire       rst_sw,  // SW15 (R2), slide UP/ON = manual reset
    output reg  [7:0] led,     // LD0..LD7
    output wire       uart_tx, // A18 -> FTDI RXD (FPGA transmits to the PC)
    input  wire       uart_rx  // B18 <- FTDI TXD (FPGA receives from the PC)
);

    // ---- free-running divider: 100 MHz -> 6.25 MHz CPU clock (no reset) ----
    reg [3:0] clk_div;
    always @(posedge clk)
        clk_div <= clk_div + 4'd1;

    wire cpu_clk_pre = clk_div[3];   // 100 MHz / 16 = 6.25 MHz
    wire cpu_clk;
    BUFG u_bufg_cpu (.I(cpu_clk_pre), .O(cpu_clk));

    // ---- power-on reset: assert ~5.2 ms after config ----
    reg [19:0] por_cnt = 20'd0;            // FPGA loads this as 0 on config
    wire por_rst_n = por_cnt[19];         // low while counting, high after 2^19
    always @(posedge clk)
        if (!por_rst_n)
            por_cnt <= por_cnt + 20'd1;

    // POR or the slide switch (active high) both request reset
    wire combined_rst_n = por_rst_n & ~rst_sw;

    // asynchronous assert, synchronous release into the CPU clock domain
    reg por_sync1 = 1'b0;
    reg por_sync2 = 1'b0;
    always @(posedge cpu_clk or negedge combined_rst_n) begin
        if (!combined_rst_n) begin
            por_sync1 <= 1'b0;
            por_sync2 <= 1'b0;
        end else begin
            por_sync1 <= 1'b1;
            por_sync2 <= por_sync1;
        end
    end
    wire arst_n = por_sync2;

    // ---- heartbeat on LD7, straight from 100 MHz (independent of CPU) ----
    reg [25:0] hb_cnt;
    always @(posedge clk)
        hb_cnt <= hb_cnt + 26'd1;
    wire heartbeat = hb_cnt[25];          // ~1.5 Hz blink

    // observation ports (unused on the board for now; kept for the 7-seg stage)
    wire [31:0] pc, instr, alu_result, reg_wdata;

    wire [15:0] gpio_in;
    wire [15:0] gpio_out;

    assign gpio_in = {8'd0, sw};          // low byte = switches, high byte unused

    always @(*) begin
        led[7]   = heartbeat;
        led[6:4] = 3'b000;
        led[3:0] = gpio_out[11:8];        // popcount (high byte, low nibble)
    end

    soc_top #(
        .UART_CLK_FREQ(6250000),   // UART runs on the 6.25 MHz CPU clock
        .UART_BAUD    (115200)     // 115200 8N1 to the on-board FTDI USB-UART
    ) u_soc (
        .clk        (cpu_clk),
        .arst_n     (arst_n),
        .pc         (pc),
        .instr      (instr),
        .alu_result (alu_result),
        .reg_wdata  (reg_wdata),
        .uart_tx    (uart_tx),
        .uart_rx    (uart_rx),
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out)
    );

endmodule
