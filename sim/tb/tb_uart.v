`timescale 1ns/1ps

module tb_uart;

reg        clk;
reg        arst_n;
reg [3:0]  addr;
reg [31:0] wdata;
reg        we;
wire [31:0] rdata;
wire       uart_tx;
reg        uart_rx;

localparam integer BIT_TIME = 100;

integer failures;
integer index;
reg [7:0] tx_byte;
reg [9:0] expected_frame;

uart uut (
	.clk     (clk),
	.arst_n  (arst_n),
	.addr    (addr),
	.wdata   (wdata),
	.we      (we),
	.rdata   (rdata),
	.uart_tx (uart_tx),
	.uart_rx (uart_rx)
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

task write_uart;
	input [31:0] value;
	begin
		@(negedge clk);
		addr = 4'h0;
		wdata = value;
		we = 1'b1;
		@(negedge clk);
		we = 1'b0;
	end
endtask

task send_rx_byte;
	input [7:0] value;
	integer bit_index;
	begin
		uart_rx = 1'b0;
		#(BIT_TIME);
		for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
			uart_rx = value[bit_index];
			#(BIT_TIME);
		end
		uart_rx = 1'b1;
		#(BIT_TIME);
	end
endtask

initial begin
	clk = 1'b0;
	arst_n = 1'b0;
	addr = 4'h4;
	wdata = 32'd0;
	we = 1'b0;
	uart_rx = 1'b1;
	failures = 0;

	#25;
	check(rdata == 32'd1, "UART is ready after reset");
	arst_n = 1'b1;

	tx_byte = 8'hA6;
	expected_frame = {1'b1, tx_byte, 1'b0};
	write_uart({24'd0, tx_byte});

	addr = 4'h4;
	#1;
	check(rdata[0] == 1'b0, "TX busy after write");

	for (index = 0; index < 10; index = index + 1) begin
		#(BIT_TIME / 2);
		check(uart_tx == expected_frame[index], "TX frame bit");
		#(BIT_TIME / 2);
	end

	#1;
	check(rdata[0] == 1'b1, "TX ready after frame");

	send_rx_byte(8'h53);
	addr = 4'h4;
	#1;
	check(rdata[1] == 1'b1, "RX ready after received byte");
	addr = 4'h0;
	#1;
	check(rdata[7:0] == 8'h53, "RX data register contains received byte");
	@(negedge clk);
	addr = 4'h4;
	#1;
	check(rdata[1] == 1'b0, "RX ready clears after data read");

	if (failures == 0)
		$display("PASS: UART testbench");
	else
		$display("UART testbench found %0d failure(s)", failures);

	$finish;
end

endmodule
