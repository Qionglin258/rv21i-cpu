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
integer result_writes;
reg result_write_seen;
reg [31:0] result_value;

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

    if (arst_n && uut.u_cpu.mem_we && (uut.u_cpu.mem_addr == 32'h00001FFC)) begin
        result_writes = result_writes + 1;
        result_write_seen = 1'b1;
        result_value = uut.u_cpu.mem_wdata;
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
    result_writes = 0;
    result_write_seen = 1'b0;
    result_value = 32'd0;

    #25;
    arst_n = 1'b1;

        // Let the CPU execute the test program loaded by imem.hex.
        repeat (3000) @(posedge clk);

    check(fetched_instructions >= 10,
          "CPU fetched instructions from imem");
        check(result_write_seen,
            "CPU wrote the computed result to 0x00001FFC");
        check(result_writes == 1,
            "CPU wrote the result exactly once");
        check(result_value == 32'd0,
            "computed result is zero");

    if (failures == 0)
          $display("PASS: CPU C program testbench, result = %0d", result_value);
    else
        $display("FAIL: %0d test(s) failed", failures);

    $finish;
end

endmodule
