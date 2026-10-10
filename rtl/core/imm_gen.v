module imm_gen (
    input  [31:0] instr, // Input instruction
    input [2:0] imm_type,
    output reg [31:0] imm_out   // Output immediate value,actually owns different bits but pad to 32 bits
);
// imm_type selects the immediate ENCODING FORMAT, not the instruction's function.
// One format can serve several functions: I-format is shared by addi (ALU),
// lw/lbu/lb (load) and jalr (jump). Every sign-extended format keeps its sign
// bit at instr[31]. CU decides imm_type from the opcode.
always@(*) begin
    case (imm_type)
        3'b000: imm_out = 32'd0;                                                        // no immediate (R-format, reg-reg ALU)
        3'b001: imm_out = {{20{instr[31]}}, instr[31:20]};                              // I-format: addi, lw/lbu/lb, jalr
        3'b010: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};                 // S-format: sw/sb
        3'b011: imm_out = {{20{instr[31]}}, instr[7],instr[30:25], instr[11:8],1'b0};   // B-format: branches (LSB forced 0)
        3'b100: imm_out = {instr[31:12], 12'd0};                                        // U-format: lui/auipc
        3'b101: imm_out = {{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};  // J-format: jal (LSB forced 0)
        default: imm_out = 32'd0;
    endcase
end
endmodule