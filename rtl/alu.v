module alu (
    input  [31:0] a,      // Operand A
    input  [31:0] b,      // Operand B
    input  [3:0]  alu_ctrl, // ALU operation code
    output reg [31:0] result, // ALU result
    output reg zero         // Zero flag
);
always @(*) begin
    case (alu_ctrl)
        4'b0000: result = a + b;
        4'b0001: result = a - b;
        4'b0010: result = a << b[4:0]; // Shift left logical    
        4'b0011: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // Set less than
        4'b0100: result = (a < b) ? 32'd1 : 32'd0; // Set less than unsigned
        4'b0101: result = a ^ b; // XOR
        4'b0110: result = a >> b[4:0]; // Shift right logical
        4'b0111: result = $signed(a) >>> b[4:0]; // Shift right arithmetic
        4'b1000: result = a | b; // OR
        4'b1001: result = a & b; // AND
        4'b1010: result = b;
        default: result = 32'd0;
    endcase
    zero = (result == 32'd0) ? 1'b1 : 1'b0;
end
endmodule