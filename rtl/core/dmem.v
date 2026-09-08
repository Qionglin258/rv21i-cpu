module dmem (
    input         clk,
    input         we,        // write enable
    input  [7:0]  addr,      // address for read/write
    input  [31:0] wdata,     // data to write
    output [31:0] rdata      // data read
);
reg [31:0] mem [255:0]; // 256 times 32 bits memory
assign rdata = mem[addr]; // read operation
always @(posedge clk) begin
    if (we) begin
        mem[addr] <= wdata; // write operation
    end
end
endmodule