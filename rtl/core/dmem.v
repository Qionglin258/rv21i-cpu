module dmem (
    input         clk,
    input         we,        // write enable
    input  [9:0]  addr,      // address for read/write
    input  [31:0] wdata,     // data to write
    output [31:0] rdata      // data read
);
reg [31:0] mem [0:1023]; // same as []a,the [] before indicates the length while the [] after indicates how many elements there are
reg [7:0] init_mem [0:4095];
integer i;
assign rdata = mem[addr]; // read operation

initial begin
    $readmemh("imem.hex", init_mem, 0, 4095);
    for (i = 0; i < 1024; i = i + 1) begin
        mem[i] = {init_mem[i * 4 + 3], init_mem[i * 4 + 2], init_mem[i * 4 + 1], init_mem[i * 4]};
    end
end

always @(posedge clk) begin
    if (we) begin
        mem[addr] <= wdata; // write operation
    end
end
endmodule