`timescale 1ns/1ps

// 100 MHz / 115200 -> DIV = 868, one bit = 8680 ns (matches the RTL divisor).
module tb_soc_top;

    localparam integer BIT_NS = 8680;

    reg         clk;
    reg         arst_n;
    reg         uart_rx;
    wire        uart_tx;
    wire [15:0] gpio_out;
    reg  [15:0] gpio_in;

    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire [31:0] debug_alu_result;
    wire [31:0] debug_reg_wdata;

    soc_top uut (
        .clk        (clk),
        .arst_n     (arst_n),
        .pc         (debug_pc),
        .instr      (debug_instr),
        .alu_result (debug_alu_result),
        .reg_wdata  (debug_reg_wdata),
        .uart_tx    (uart_tx),
        .uart_rx    (uart_rx),
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out)
    );

    always #5 clk = ~clk;

    // Drive one 8N1 frame into uart_rx (LSB first) at the DUT's bit time.
    task send_rx_byte;
        input [7:0] b;
        integer k;
        begin
            uart_rx = 1'b0;              // start bit
            #(BIT_NS);
            for (k = 0; k < 8; k = k + 1) begin
                uart_rx = b[k];          // data bits, LSB first
                #(BIT_NS);
            end
            uart_rx = 1'b1;              // stop bit
            #(BIT_NS);
        end
    endtask

    initial begin
        clk     = 1'b0;
        arst_n  = 1'b0;
        uart_rx = 1'b1;                 // idle line
        gpio_in = 16'h0000;

        #25;
        arst_n = 1'b1;

        gpio_in = {8'd0, 8'hFF};        // all switches ON -> popcount 8
        #800000;                        // banner finishes, main loop shows 8

        gpio_in = {8'd0, 8'h5A};        // -> popcount 4
        #300000;

        send_rx_byte(8'h4F); #200000;   // 'O' -> echoed
        send_rx_byte(8'h4B); #200000;   // 'K' -> echoed
        send_rx_byte(8'h0D); #300000;   // Enter -> echoed as CR+LF

        $finish;
    end

endmodule
