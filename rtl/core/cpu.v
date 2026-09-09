module cpu(
    input clk,
    input arst_n,
    input [31:0] mem_rdata,
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output mem_we,
    output [31:0] pc,
    output [31:0] instr,
    output [31:0] alu_result,
    output reg [31:0] reg_wdata
);

reg [31:0] next_pc;
wire [31:0] pc_plus4;
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] imm_out;
wire [31:0] alu_b;
wire zero;
wire [31:0] dmem_rdata;
wire [2:0] imm_type;
wire alu_src;
wire [3:0] alu_ctrl;
wire reg_we;
wire [1:0] wb_sel;
wire [1:0] pc_sel;
wire [31:0] pc_relative_target;
wire [31:0] jalr_target;

assign pc_plus4 = pc + 32'd4;
assign pc_relative_target = pc + imm_out;
assign jalr_target = alu_result; // rs1 + immediate
assign alu_b = alu_src ? imm_out : rs2_data;

always@(*) begin
    case(pc_sel)
        2'b00: next_pc = pc_plus4; // PC + 4
        2'b01: next_pc = pc_relative_target; // JAL / B target
        2'b10: next_pc = jalr_target; // JALR target
        default: next_pc = pc_plus4; // Default to PC + 4
    endcase
    case (wb_sel)
        2'b00: reg_wdata = alu_result; // ALU result
        2'b01: reg_wdata = dmem_rdata; // Data memory read data
        2'b10: reg_wdata = pc_plus4; // PC + 4
        default: reg_wdata = 32'd0; // Default to zero
    endcase
end

pc u_pc(
    .clk(clk),
    .arst_n(arst_n),
    .next_pc(next_pc),
    .pc(pc)
);

imem u_imem(
    .addr(pc[11:2]),
    .rdata(instr)
);

regfile u_regfile(
    .clk(clk),
    .arst_n(arst_n),
    .we(reg_we),
    .raddr1(instr[19:15]),
    .raddr2(instr[24:20]),
    .waddr(instr[11:7]),
    .wdata(reg_wdata),
    .rdata1(rs1_data),
    .rdata2(rs2_data)
);

imm_gen u_imm_gen(
    .instr(instr),
    .imm_type(imm_type),
    .imm_out(imm_out)
);

CU u_cu(
    .opcode(instr[6:0]),
    .funct3(instr[14:12]),
    .funct7(instr[31:25]),
    .zero(zero),
    .alu_result(alu_result),
    .imm_type(imm_type),
    .alu_src(alu_src),
    .alu_ctrl(alu_ctrl),
    .mem_we(mem_we),
    .reg_we(reg_we),
    .wb_sel(wb_sel),
    .pc_sel(pc_sel)
);

alu u_alu(
    .a(rs1_data),
    .b(alu_b),
    .alu_ctrl(alu_ctrl),
    .result(alu_result),
    .zero(zero)
);

endmodule
