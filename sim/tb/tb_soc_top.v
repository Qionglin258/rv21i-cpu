`timescale 1ns/1ps

module tb_soc_top;

reg clk;
reg arst_n;
reg uart_rx;
wire [31:0] pc;
wire [31:0] instr;
wire [31:0] alu_result;
wire [31:0] reg_wdata;
wire uart_tx;

soc_top uut (
	.clk(clk),
	.arst_n(arst_n),
	.pc(pc),
	.instr(instr),
	.alu_result(alu_result),
	.reg_wdata(reg_wdata),
	.uart_tx(uart_tx),
	.uart_rx(uart_rx)
);

always #5 clk = ~clk;

initial begin
	clk = 1'b0;
	arst_n = 1'b0;
	uart_rx = 1'b1;

	#20;
	arst_n = 1'b1;
	#1000;

	$finish;
end

endmodule
