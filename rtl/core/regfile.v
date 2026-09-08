module regfile (
    input         clk,
    input         arst_n,    // asynchronous and 'n'
    input         we,
    input  [4:0]  waddr,
    input  [31:0] wdata,
    input  [4:0]  raddr1,
    output [31:0] rdata1,
    input  [4:0]  raddr2,
    output [31:0] rdata2
);
reg [31:0] regs [31:0]; // 32 registers of 32 bits each
integer i; //verilog way.Systemverilog allows 'for(int i...).

// read
assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];
//no need for arst_n, the negedge will do the job.
// write and storage itself
always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] <= 32'd0;
        end
    end else if (we && waddr != 5'd0) begin //attention:&& is logical AND, & is bitwise AND, we should use && here.
        regs[waddr] <= wdata;
    end
end
endmodule
