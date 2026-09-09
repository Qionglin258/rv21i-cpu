module imem (
    input  [9:0] addr,
    output [31:0] rdata
);
reg [31:0] mem [0:1023]; // 1024 x 32-bit instruction words,it doesn't matter whether 0-1023 or 1023-0,but be consistent with readmemh
assign rdata = mem[addr]; // read operation
initial begin
    $readmemh("imem.hex", mem, 0, 1023);
end

endmodule