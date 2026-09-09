`timescale 1ns/1ps

module tb_cpu;

reg clk;
reg arst_n;
wire [31:0] pc;
wire [31:0] instr;
wire [31:0] alu_result;
wire [31:0] reg_wdata;
    
cpu u_cpu(
    .clk(clk),
    .arst_n(arst_n),
    .pc(pc),
    .instr(instr),
    .alu_result(alu_result),
    .reg_wdata(reg_wdata)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    arst_n = 1'b0;
    #15;
    arst_n = 1'b1;
    #1000;
    $finish;
end

endmodule
    