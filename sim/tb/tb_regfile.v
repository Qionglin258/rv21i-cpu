module tb_regfile;
    reg clk;
    reg arst_n;
    reg we;
    reg [4:0] waddr;
    reg [31:0] wdata;
    reg [4:0] raddr1;
    wire [31:0] rdata1;
    reg [4:0] raddr2;
    wire [31:0] rdata2;

    // Instantiate the regfile module
    regfile uut (
        .clk(clk),
        .arst_n(arst_n),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr1(raddr1),
        .rdata1(rdata1),
        .raddr2(raddr2),
        .rdata2(rdata2)
    ); //unit under test

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        arst_n = 0;
        we = 0;
        waddr = 5'd0;
        wdata = 32'd0;
        raddr1 = 5'd1;
        raddr2 = 5'd0;

        // Wait for a few clock cycles
        #20;

        // Deassert reset
        arst_n = 1;

        // Write to register 1
        we = 1;
        waddr = 5'd1;
        wdata = 32'd42;
        #10;
        waddr = 5'd0;
        wdata = 32'd100; // This write should be ignored since waddr is 0
        #10 $finish;
    end
endmodule