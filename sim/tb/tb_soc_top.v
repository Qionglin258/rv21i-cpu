`timescale 1ns/1ps

module tb_soc_top;

reg        clk;
reg        arst_n;
reg        uart_rx;
wire       uart_tx;
wire [7:0] gpio_io;
reg        gpio_drive_en;
reg [7:0]  gpio_drive_val;

wire [31:0] debug_pc;
wire [31:0] debug_instr;
wire [31:0] debug_alu_result;
wire [31:0] debug_reg_wdata;

integer failures;
integer fetched_instructions;

assign gpio_io = gpio_drive_en ? gpio_drive_val : 8'hzz;

soc_top uut (
    .clk        (clk),
    .arst_n     (arst_n),
    .pc         (debug_pc),
    .instr      (debug_instr),
    .alu_result (debug_alu_result),
    .reg_wdata  (debug_reg_wdata),
    .uart_tx    (uart_tx),
    .uart_rx    (uart_rx),
    .gpio_io    (gpio_io)
);

always #5 clk = ~clk;

task check;
    input condition;
    input [8*80-1:0] message;
    begin
        if (!condition) begin
            $display("FAIL: %s at %0t ns", message, $time);
            failures = failures + 1;
        end
    end
endtask

always @(posedge clk) begin
    if (arst_n && (debug_instr !== 32'bx)) begin
        fetched_instructions = fetched_instructions + 1;
    end
end

initial begin
    clk = 1'b0;
    arst_n = 1'b0;
    uart_rx = 1'b1;
    gpio_drive_en = 1'b0;
    gpio_drive_val = 8'd0;
    failures = 0;
    fetched_instructions = 0;

    #25;
    arst_n = 1'b1;

    // Let the CPU execute the program loaded by imem.hex.
    repeat (40) @(posedge clk);

    check(fetched_instructions >= 10,
          "CPU fetched instructions from imem");
    check(uut.u_gpio.dir_reg == 8'h0F,
          "CPU wrote GPIO direction register");
    check(uut.u_gpio.out_reg == 8'h01,
          "CPU wrote GPIO output register");
    check(gpio_io[3:0] == 4'b0001,
          "GPIO output pins reflect CPU-written value");
    check(gpio_io[7:4] === 4'bzzzz,
          "GPIO input pins remain high impedance");

    if (failures == 0)
        $display("PASS: CPU imem-to-GPIO testbench");
    else
        $display("FAIL: %0d test(s) failed", failures);

    $finish;
end

endmodule
