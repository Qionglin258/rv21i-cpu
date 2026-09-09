module dmem (
    input         clk,
    input         we,        // write enable
    input  [9:0]  addr,      // address for read/write
    input  [31:0] wdata,     // data to write
    output [31:0] rdata      // data read
);
reg [31:0] mem [0:1023]; // same as []a,the [] before indicates the length while the [] after indicates how many elements there are
assign rdata = mem[addr]; // read operation
always @(posedge clk) begin
    if (we) begin
        mem[addr] <= wdata; // write operation
    end
end
endmodule