`timescale 1ns/1ps

module tb_dmem;

reg         clk;
reg         we;
reg  [7:0]  addr;
reg  [31:0] wdata;
wire [31:0] rdata;

dmem uut (
    .clk(clk),
    .we(we),
    .addr(addr),
    .wdata(wdata),
    .rdata(rdata)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    we    = 1'b0;
    addr  = 8'd0;
    wdata = 32'd0;
    #10;

    $display("=== 1. Read initial values before write ===");
    addr = 8'h00;
    #2 $display("addr=0x%02h | rdata=0x%08h", addr, rdata);
    addr = 8'h01;
    #2 $display("addr=0x%02h | rdata=0x%08h", addr, rdata);
    #8;

    $display("\n=== 2. Write data (posedge synchronous) ===");
    we = 1'b1;
    addr  = 8'h00;
    wdata = 32'h12345678;
    #10;
    addr  = 8'h01;
    wdata = 32'hdeadbeef;
    #10;
    addr  = 8'hFF;
    wdata = 32'haabbccdd;
    #10;
    we = 1'b0;
    #10;

    $display("\n=== 3. Read back written data (asynchronous read) ===");
    addr = 8'h00;
    #2 $display("addr=0x%02h | rdata=0x%08h  expected: 12345678", addr, rdata);
    addr = 8'h01;
    #2 $display("addr=0x%02h | rdata=0x%08h  expected: deadbeef", addr, rdata);
    addr = 8'hFF;
    #2 $display("addr=0x%02h | rdata=0x%08h  expected: aabbccdd", addr, rdata);
    #8;

    $display("\n=== 4. Verify write enable mask ===");
    we    = 1'b0;
    addr  = 8'h00;
    wdata = 32'hffffffff;
    #10;
    addr = 8'h00;
    #2 $display("addr=0x%02h | rdata=0x%08h  should remain: 12345678", addr, rdata);
    #8;

    $display("\n=== Test completed ===");
    #20;
    $finish;
end

endmodule
