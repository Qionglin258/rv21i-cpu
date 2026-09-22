// board_top.v - Basys 3 (XC7A35T-CPG236) wrapper around soc_top.
// Stage 1: 8 slide switches in (gpio[7:0]), 8 LEDs out (gpio[15:8]).
// The 7-segment display is added in stage 2.
//
// Direction split (set by software: GPIO_DIR = 0x0000FF00):
//   gpio[7:0]  are inputs  -> the core drives them Hi-Z, the switches drive them here.
//   gpio[15:8] are outputs -> driven by the core, routed to the LEDs here.

module board_top (
    input  wire       clk,    // W5, 100 MHz oscillator
    input  wire       btnC,   // center push button = reset (pressed = high)
    input  wire [7:0] sw,     // SW0..SW7  -> gpio[7:0]
    output wire [7:0] led     // LD0..LD7  <- gpio[15:8]
);

    wire        arst_n = ~btnC;   // soc reset is active-low, button is active-high

    // observation ports (unused on the board for now; kept for the 7-seg stage)
    wire [31:0] pc, instr, alu_result, reg_wdata;
    wire        uart_tx;
    wire [15:0] gpio_io;

    // Input byte: driven by the switches. The core keeps these as inputs (Hi-Z),
    // so there is no driver conflict.
    assign gpio_io[7:0]  = sw;
    // Output byte: core-driven, straight to the LEDs.
    assign led           = gpio_io[15:8];

    soc_top u_soc (
        .clk        (clk),
        .arst_n     (arst_n),
        .pc         (pc),
        .instr      (instr),
        .alu_result (alu_result),
        .reg_wdata  (reg_wdata),
        .uart_tx    (uart_tx),
        .uart_rx    (1'b1),        // UART unused: hold RX idle
        .gpio_io    (gpio_io)
    );

endmodule
