module imm_gen (
    input  [31:0] instr, // Input instruction
    input [2:0] imm_type,
    output reg [31:0] imm_out   // Output immediate value,actually owns different bits but pad to 32 bits
);
always@(*) begin
    case (imm_type)
        3'b000: imm_out = 32'd0;
        3'b001: imm_out = {{20{instr[31]}}, instr[31:20]}; // I-type
        3'b010: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
        3'b011: imm_out = {{20{instr[31]}}, instr[7],instr[30:25], instr[11:8],1'b0}; // B-type
        3'b100: imm_out = {instr[31:12], 12'd0}; // U-type
        3'b101: imm_out = {{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0}; // J-type
        default: imm_out = 32'd0;
    endcase
end
endmodule