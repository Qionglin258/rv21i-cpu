module imem (
    input  [7:0] addr,
    output [31:0] rdata
);
reg [31:0] mem [255:0]; // reg for storage,256 × 32 bits
assign rdata = mem[addr]; // read operation
initial begin
    $readmemh("imem.hex", mem);
end

endmodule