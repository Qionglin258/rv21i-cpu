`timescale 1ns/1ps

module tb_imem;

reg  [7:0] addr;
wire [31:0] rdata;

imem uut (
    .addr(addr),
    .rdata(rdata)
);

initial begin
    $monitor("addr = 0x%02h, rdata = 0x%08h", addr, rdata);
    addr = 8'h00;
    #10;
    addr = 8'h01;
    #10;
    addr = 8'h02;
    #10;
    addr = 8'h03;
    #10;
    addr = 8'h10;
    #10;
    addr = 8'hFF;
    #10;
    $finish;
end

endmodule
