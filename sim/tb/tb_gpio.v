`timescale 1ns/1ps

module tb_gpio;

reg        clk;
reg        arst_n;
reg [3:0]  addr;
reg [31:0] wdata;
reg        we;
wire [31:0] rdata;
wire [7:0] gpio_io;
reg [7:0]  external_gpio;
reg        external_drive;
integer    failures;

assign gpio_io = external_drive ? external_gpio : 8'hzz;

gpio uut (
	.clk     (clk),
	.arst_n  (arst_n),
	.addr    (addr),
	.wdata   (wdata),
	.we      (we),
	.rdata   (rdata),
	.gpio_io (gpio_io)
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

task write_gpio;
	input [3:0] register_addr;
	input [7:0] value;
	begin
		@(negedge clk);
		addr = register_addr;
		wdata = {24'd0, value};
		we = 1'b1;
		@(negedge clk);
		we = 1'b0;
	end
endtask

initial begin
	clk = 1'b0;
	arst_n = 1'b0;
	addr = 4'h0;
	wdata = 32'd0;
	we = 1'b0;
	external_gpio = 8'd0;
	external_drive = 1'b0;
	failures = 0;

	#20;
	check(gpio_io === 8'hzz, "GPIO pins are inputs after reset");
	check(rdata == 32'd0, "direction register resets to zero");
	arst_n = 1'b1;

	write_gpio(4'h4, 8'hA5);
	addr = 4'h4;
	#1;
	check(rdata == 32'h000000A5, "output register can be read");
	check(gpio_io === 8'hzz, "output remains disconnected while direction is zero");

	write_gpio(4'h0, 8'hF3);
	#1;
	check(gpio_io === 8'b1010zz01, "configured output bits drive out_reg");
	addr = 4'h0;
	#1;
	check(rdata == 32'h000000F3, "direction register can be read");

	write_gpio(4'h0, 8'h00);
	external_gpio = 8'h5C;
	external_drive = 1'b1;
	repeat (3) @(posedge clk);
	addr = 4'h8;
	#1;
	check(rdata == 32'h0000005C, "input value is synchronized and readable");

	if (failures == 0)
		$display("PASS: GPIO testbench");
	else
		$display("GPIO testbench found %0d failure(s)", failures);

	$finish;
end

endmodule
