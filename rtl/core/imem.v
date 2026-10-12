module imem (
    input  [11:0] addr,
    output [31:0] rdata,
    input  [11:0] daddr,   // data read-back port (.data initial values)
    output [31:0] drdata
);
reg [7:0] mem [0:4095]; //4096 8-bit locations -- 4096 bytes
assign rdata = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]}; // locate each 4 bytes -- 1 instruction
assign drdata = {mem[daddr+3], mem[daddr+2], mem[daddr+1], mem[daddr]};

initial begin
    $readmemh("imem.hex", mem, 0, 4095); // 1 byte 1 line
end

endmodule