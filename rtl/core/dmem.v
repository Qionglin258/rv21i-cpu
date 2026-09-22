module dmem (
    input         clk,
    input         we,        // write enable
    input  [9:0]  addr,      // address for read/write
    input  [31:0] wdata,     // data to write
    input  [3:0]  byte_en,   // byte enable for write (strobe:choose to be active)
    output [31:0] rdata      // data read
);
reg [31:0] mem [0:1023]; // same as []a,the [] before indicates the length while the [] after indicates how many elements there are
reg [7:0] init_mem [0:4095];
integer i;
assign rdata = mem[addr]; // read operation

always @(posedge clk) begin
    if (we) begin
        if (byte_en[0]) mem[addr][7:0]   <= wdata[7:0];
        if (byte_en[1]) mem[addr][15:8]  <= wdata[15:8];
        if (byte_en[2]) mem[addr][23:16] <= wdata[23:16];
        if (byte_en[3]) mem[addr][31:24] <= wdata[31:24];
    end
end
endmodule