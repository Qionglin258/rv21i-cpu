// board_top.v - Basys 3 (XC7A35T-CPG236) wrapper around soc_top.
// Stage 1: 8 slide switches in (gpio_in[7:0]), 8 LEDs out (gpio_out[15:8]).
// The 7-segment display is added in stage 2.
//
// GPIO is split into separate input/output vectors (no tri-state inout):
// the switches are a pure input and the LEDs a pure output, so every net
// has exactly one driver. Software sets GPIO_DIR = 0x0000FF00 (high byte).

module board_top (
    input  wire       clk,    // W5, 100 MHz oscillator
    input  wire       btnC,   // center push button = reset (pressed = high)
    input  wire [7:0] sw,     // SW0..SW7  -> gpio_in[7:0]
    output wire [7:0] led     // LD0..LD7  <- gpio_out[15:8]
);

    wire        arst_n = ~btnC;   // soc reset is active-low, button is active-high

    // observation ports (unused on the board for now; kept for the 7-seg stage)
    wire [31:0] pc, instr, alu_result, reg_wdata;
    wire        uart_tx;

    wire [15:0] gpio_in;
    wire [15:0] gpio_out;

    assign gpio_in = {8'd0, sw};      // low byte = switches, high byte unused
    assign led     = gpio_out[15:8];  // high byte = LEDs

    soc_top u_soc (
        .clk        (clk),
        .arst_n     (arst_n),
        .pc         (pc),
        .instr      (instr),
        .alu_result (alu_result),
        .reg_wdata  (reg_wdata),
        .uart_tx    (uart_tx),
        .uart_rx    (1'b1),        // UART unused: hold RX idle
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out)
    );

endmodule
