module CU (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input zero,
    input [31:0] alu_result,
    output reg [1:0] pc_sel,
    output reg [3:0] alu_ctrl,
    output reg alu_src,
    output reg [2:0] imm_type,
    output reg reg_we,
    output reg mem_we,
    output reg [1:0]wb_sel
);
always@(*) begin
    // Default values
    pc_sel = 2'b0;
    alu_ctrl = 4'b0000;
    alu_src = 1'b0;
    imm_type = 3'b000;
    reg_we = 1'b0;
    mem_we = 1'b0;
    wb_sel = 2'b0;

    case (opcode)
        7'b0110011: begin // R-type
            reg_we = 1'b1;
            case ({funct7[5], funct3})
                4'b0000: alu_ctrl = 4'b0000; // ADD
                4'b1000: alu_ctrl = 4'b0001; // SUB
                4'b0001: alu_ctrl = 4'b0010; // SLL
                4'b0010: alu_ctrl = 4'b0011; // SLT
                4'b0011: alu_ctrl = 4'b0100; // SLTU
                4'b0100: alu_ctrl = 4'b0101; // XOR
                4'b0101: alu_ctrl = 4'b0110; // SRL
                4'b1101: alu_ctrl = 4'b0111; // SRA
                4'b0110: alu_ctrl = 4'b1000; // OR
                4'b0111: alu_ctrl = 4'b1001; // AND
                default: alu_ctrl = 4'b0000; // Default to ADD
            endcase
        end
        7'b0010011: begin // I-type
            alu_src = 1'b1;
            reg_we = 1'b1;
            imm_type = 3'b001; // Immediate type for I-type
            case (funct3)
                3'b000: alu_ctrl = 4'b0000; // ADDI
                3'b010: alu_ctrl = 4'b0011; // SLTI
                3'b011: alu_ctrl = 4'b0100; // SLTIU
                3'b100: alu_ctrl = 4'b0101; // XORI
                3'b110: alu_ctrl = 4'b1000; // ORI
                3'b111: alu_ctrl = 4'b1001; // ANDI
                3'b001: if(funct7[5] == 1'b0) alu_ctrl = 4'b0010; // SLLI
                3'b101: begin
                    if(funct7[5] == 1'b0) alu_ctrl = 4'b0110; // SRLI
                    else alu_ctrl = 4'b0111; // SRAI
                end
                default: alu_ctrl = 4'b0000; // Default to ADDI
            endcase
        end
        7'b0000011: begin // Iw only
            alu_src = 1'b1;
            reg_we = 1'b1;
            imm_type = 3'b001;
            alu_ctrl = 4'b0000;
            wb_sel = 2'b1;
        end
        7'b0100011: begin // Sw only
            alu_src = 1'b1;
            mem_we = 1'b1;
            imm_type = 3'b010; // Immediate type for S-type
            alu_ctrl = 4'b0000; // ADD for address calculation
        end
        7'b1100011: begin // B-type
            imm_type = 3'b011; // Immediate type for B-type
            alu_ctrl = 4'b0001; // SUB for comparison
            case (funct3)
                3'b000: pc_sel = zero; // BEQ:jump if equal
                3'b001: pc_sel = ~zero; // BNE
                3'b100: begin
                    alu_ctrl = 4'b0011; // SLT for BLT
                    pc_sel = alu_result[0] ? 2'b01 : 2'b00; // Jump if less than
                end
                3'b101: begin
                    alu_ctrl = 4'b0011; // SLT for BGE
                    pc_sel = alu_result[0] ? 2'b00 : 2'b01; // Jump if greater than or equal
                end
                3'b110: begin
                    alu_ctrl = 4'b0100; // SLTU for BLTU
                    pc_sel = alu_result[0] ? 2'b01 : 2'b00; // Jump if less than unsigned
                end
                3'b111: begin
                    alu_ctrl = 4'b0100; // SLTU for BGEU
                    pc_sel = alu_result[0] ? 2'b00 : 2'b01; // Jump if greater than or equal unsigned
                end
                default: pc_sel = 1'b0; // Default to not taken
            endcase
        end
        7'b1101111: begin // JAL
            reg_we = 1'b1;
            pc_sel = 2'b1; // Jump always
            imm_type = 3'b101; // Immediate type for J-type
            alu_ctrl = 4'b0000; // ADD for calculating return address
            wb_sel = 2'b10; // Write PC + 4 to register
        end
        7'b1100111: begin // JALR
            reg_we = 1'b1;
            alu_src = 1'b1; // Use immediate for address calculation
            pc_sel = 2'b10; // Jump always
            imm_type = 3'b001; // Immediate type for I-type
            alu_ctrl = 4'b0000; // ADD for calculating return address
            wb_sel = 2'b10; // Write PC + 4 to register
        end
        default: begin
            // Handle other opcodes as needed
        end
    endcase
end
endmodule