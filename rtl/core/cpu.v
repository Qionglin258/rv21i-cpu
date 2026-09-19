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

// ===================== 1. Instruction Fetch:pc+imem =====================
wire [31:0] next_pc; // decision is made in EX
wire [31:0] pc_plus4;
wire [31:0] if_pc_plus4;
wire load_bubble;
wire branch_flush;
reg [31:0] mem_wb_alu_result;
reg [31:0] mem_wb_mem_rdata;
reg [4:0]  mem_wb_rd_addr;
reg        mem_wb_reg_we;
reg [1:0]  mem_wb_wb_sel;
reg        mem_wb_load_byte;
reg [31:0] mem_wb_pc_plus4; // have to declare them right now here
assign if_pc_plus4 = pc + 32'd4; // for next_pc

pc u_pc(
    .clk(clk),
    .arst_n(arst_n),
    .next_pc(next_pc), // input
    .pc(pc) // output
);

imem u_imem(
    .addr(pc[11:0]),
    .rdata(instr)
);

// ---------- IF/ID pipeline registers ----------
reg [31:0] if_id_pc;
reg [31:0] if_id_instr;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        if_id_pc <= 32'd0;
        if_id_instr <= 32'd0;
    end else if(branch_flush) begin
        if_id_pc <= 32'd0;
        if_id_instr <= 32'd0;
    end
    else if(!load_bubble) begin
        if_id_pc <= pc;
        if_id_instr <= instr;
    end
end

// ===================== 2. Instruction Decode:regfile+imm_gen+CU =====================
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] imm_out;
wire [2:0] imm_type;
wire alu_src;
wire [3:0] alu_ctrl;
wire [1:0] branch_type;
wire mem_we_id;
wire reg_we_id;
wire [1:0] wb_sel_id;
wire load_byte_id;
wire mem_re_id;

regfile u_regfile(
    .clk(clk),
    .arst_n(arst_n),
    .we(mem_wb_reg_we),       // from WB stage
    .raddr1(if_id_instr[19:15]),
    .raddr2(if_id_instr[24:20]),
    .waddr(mem_wb_rd_addr),   // from WB stage
    .wdata(reg_wdata),        // from WB stage
    .rdata1(rs1_data),
    .rdata2(rs2_data)
);

imm_gen u_imm_gen(
    .instr(if_id_instr),
    .imm_type(imm_type),
    .imm_out(imm_out)
);

CU u_cu(
    .opcode(if_id_instr[6:0]),
    .funct3(if_id_instr[14:12]),
    .funct7(if_id_instr[31:25]),
    .imm_type(imm_type),
    .alu_src(alu_src),
    .alu_ctrl(alu_ctrl),
    .mem_we(mem_we_id),
    .reg_we(reg_we_id),
    .wb_sel(wb_sel_id),
    .load_byte(load_byte_id),
    .mem_re(mem_re_id),
    .branch_type(branch_type)
);

// ---------- ID/EX pipeline registers ----------
reg [31:0] id_ex_pc;
reg [31:0] id_ex_rs1;
reg [31:0] id_ex_rs2;
reg [31:0] id_ex_imm;
reg [4:0]  id_ex_rs1_addr;
reg [4:0]  id_ex_rs2_addr;
reg [4:0]  id_ex_rd_addr;
reg        id_ex_alu_src;
reg [3:0]  id_ex_alu_ctrl;
reg        id_ex_mem_we;
reg        id_ex_reg_we;
reg [1:0]  id_ex_wb_sel;
reg        id_ex_mem_re;
reg        id_ex_load_byte;
reg [1:0]  id_ex_branch_type;
reg [2:0]  id_ex_funct3;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        id_ex_pc <= 32'd0;
        id_ex_rs1 <= 32'd0;
        id_ex_rs2 <= 32'd0;
        id_ex_imm <= 32'd0;
        id_ex_rs1_addr <= 5'd0;
        id_ex_rs2_addr <= 5'd0;
        id_ex_rd_addr <= 5'd0;
        id_ex_alu_src <= 1'b0;
        id_ex_alu_ctrl <= 4'd0;
        id_ex_mem_we <= 1'b0;
        id_ex_reg_we <= 1'b0;
        id_ex_wb_sel <= 2'd0;
        id_ex_load_byte <= 1'b0;
        id_ex_mem_re <= 1'b0;
        id_ex_branch_type <= 2'b00;
        id_ex_funct3 <= 3'b000;
    end else if (branch_flush || load_bubble) begin
        id_ex_branch_type <= 2'b00; // top switch for branch_flush
        id_ex_mem_re <= 1'b0; // top switch for load_bubble

        id_ex_rs1 <= 32'd0;
        id_ex_rs2 <= 32'd0;
        id_ex_imm <= 32'd0;
        id_ex_rs1_addr <= 5'd0;
        id_ex_rs2_addr <= 5'd0;
        id_ex_rd_addr <= 5'd0;
        id_ex_pc <= 32'd0; // data to 0

        id_ex_alu_src <= 1'b0;
        id_ex_alu_ctrl <= 4'd0;
        id_ex_wb_sel <= 2'd0;
        id_ex_load_byte <= 1'b0;
        id_ex_funct3 <= 3'b000;
        id_ex_reg_we <= 1'b0;
        id_ex_mem_we <= 1'b0; // control to 0
    end else begin
        id_ex_pc <= if_id_pc;
        id_ex_rs1 <= rs1_data;
        id_ex_rs2 <= rs2_data;
        id_ex_imm <= imm_out;
        id_ex_rs1_addr <= if_id_instr[19:15];
        id_ex_rs2_addr <= if_id_instr[24:20];
        id_ex_rd_addr <= if_id_instr[11:7];
        id_ex_alu_src <= alu_src;
        id_ex_alu_ctrl <= alu_ctrl;
        id_ex_mem_we <= mem_we_id;
        id_ex_reg_we <= reg_we_id;
        id_ex_wb_sel <= wb_sel_id;
        id_ex_load_byte <= load_byte_id;
        id_ex_mem_re <= mem_re_id;
        id_ex_branch_type <= branch_type;
        id_ex_funct3 <= if_id_instr[14:12];
    end
end

// ===================== 3. Execution (jst kidding) :alu + assign next_pc =====================
wire [31:0] alu_b;
wire ex_zero;
wire [31:0] ex_alu_result;
wire [31:0] ex_pc_plus4;
wire [31:0] pc_relative_target;
wire [31:0] jalr_target;
reg  [1:0] ex_pc_sel;
reg [31:0] ex_mem_alu_result;
reg [31:0] ex_mem_rs2;
reg [4:0]  ex_mem_rd_addr;
reg        ex_mem_mem_we;
reg        ex_mem_reg_we;
reg [1:0]  ex_mem_wb_sel;
reg        ex_mem_load_byte;
reg [31:0] ex_mem_pc_plus4;
reg        ex_mem_mem_re;
wire [31:0] rs1_forwarded;
wire [31:0] rs2_forwarded;

assign ex_pc_plus4 = id_ex_pc + 32'd4;
assign alu_b = id_ex_alu_src ? id_ex_imm : rs2_forwarded;
assign pc_relative_target = id_ex_pc + id_ex_imm;
assign jalr_target = {ex_alu_result[31:1], 1'b0};
assign branch_flush = (ex_pc_sel != 2'b00);

assign rs1_forwarded = 
    (ex_mem_reg_we && ex_mem_rd_addr != 5'd0 && ex_mem_rd_addr == id_ex_rs1_addr) ? ex_mem_alu_result :
    (mem_wb_reg_we && mem_wb_rd_addr != 5'd0 && mem_wb_rd_addr == id_ex_rs1_addr) ? reg_wdata :
    id_ex_rs1;

assign rs2_forwarded = 
    (ex_mem_reg_we && ex_mem_rd_addr != 5'd0 && ex_mem_rd_addr == id_ex_rs2_addr) ? ex_mem_alu_result :
    (mem_wb_reg_we && mem_wb_rd_addr != 5'd0 && mem_wb_rd_addr == id_ex_rs2_addr) ? reg_wdata :
    id_ex_rs2;

alu u_alu(
    .a(rs1_forwarded),
    .b(alu_b),
    .alu_ctrl(id_ex_alu_ctrl),
    .result(ex_alu_result),
    .zero(ex_zero)
);

always@(*) begin
    case(id_ex_branch_type)
        2'b00:ex_pc_sel = 2'b00; // not branch
        2'b01:begin
            case(id_ex_funct3)
                3'b000:ex_pc_sel = ex_zero ? 2'b01 : 2'b00; // BEQ
                3'b001:ex_pc_sel = ex_zero ? 2'b00 : 2'b01; // BNE
                3'b100:ex_pc_sel = ex_alu_result[0] ? 2'b01 : 2'b00; // BLT
                3'b101:ex_pc_sel = ex_alu_result[0] ? 2'b00 : 2'b01; // BGE
                3'b110:ex_pc_sel = ex_alu_result[0] ? 2'b01 : 2'b00; // BLTU
                3'b111:ex_pc_sel = ex_alu_result[0] ? 2'b00 : 2'b01; // BGEU
                default:ex_pc_sel = 2'b00; // not branch
            endcase
        end
        2'b10:ex_pc_sel = 2'b01; // JAL
        2'b11:ex_pc_sel = 2'b10; // JALR
        default:ex_pc_sel = 2'b00; // not branch
    endcase
end
assign next_pc = 
    load_bubble ? pc :
    (ex_pc_sel == 2'b01) ? pc_relative_target :
    (ex_pc_sel == 2'b10) ? jalr_target :
    if_pc_plus4;

// ---------- EX/MEM pipeline registers ----------
always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        ex_mem_alu_result <= 32'd0;
        ex_mem_rs2 <= 32'd0;
        ex_mem_rd_addr <= 5'd0;
        ex_mem_mem_we <= 1'b0;
        ex_mem_mem_re <= 1'b0;
        ex_mem_reg_we <= 1'b0;
        ex_mem_wb_sel <= 2'd0;
        ex_mem_load_byte <= 1'b0;
        ex_mem_pc_plus4 <= 32'd0;
    end else begin
        ex_mem_alu_result <= ex_alu_result;
        ex_mem_rs2 <= rs2_forwarded;
        ex_mem_rd_addr <= id_ex_rd_addr;
        ex_mem_mem_we <= id_ex_mem_we;
        ex_mem_mem_re <= id_ex_mem_re;
        ex_mem_reg_we <= id_ex_reg_we;
        ex_mem_wb_sel <= id_ex_wb_sel;
        ex_mem_load_byte <= id_ex_load_byte;
        ex_mem_pc_plus4 <= ex_pc_plus4;
    end
end

assign load_bubble =
    id_ex_mem_re &&
    (id_ex_rd_addr != 5'd0) &&
    ((id_ex_rd_addr == if_id_instr[19:15]) ||
     (id_ex_rd_addr == if_id_instr[24:20]));

// ===================== 4. memory access : -> bus =====================
assign mem_addr = ex_mem_alu_result;
assign mem_wdata = ex_mem_rs2;
assign mem_we = ex_mem_mem_we;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        mem_wb_alu_result <= 32'd0;
        mem_wb_mem_rdata <= 32'd0;
        mem_wb_rd_addr <= 5'd0;
        mem_wb_reg_we <= 1'b0;
        mem_wb_wb_sel <= 2'd0;
        mem_wb_load_byte <= 1'b0;
        mem_wb_pc_plus4 <= 32'd0;
    end else begin
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_mem_rdata <= mem_rdata;
        mem_wb_rd_addr <= ex_mem_rd_addr;
        mem_wb_reg_we <= ex_mem_reg_we;
        mem_wb_wb_sel <= ex_mem_wb_sel;
        mem_wb_load_byte <= ex_mem_load_byte;
        mem_wb_pc_plus4 <= ex_mem_pc_plus4;
    end
end

// ===================== 5. Write Back :wb_sel + regfile write =====================

always @(*) begin
    case (mem_wb_wb_sel)
        2'b00: reg_wdata = mem_wb_alu_result;
        2'b01: begin
            if (mem_wb_load_byte) begin // read 4 bytes -> read 1 byte
                case (mem_wb_alu_result[1:0])
                    2'b00: reg_wdata = {24'd0, mem_wb_mem_rdata[7:0]};
                    2'b01: reg_wdata = {24'd0, mem_wb_mem_rdata[15:8]};
                    2'b10: reg_wdata = {24'd0, mem_wb_mem_rdata[23:16]};
                    default: reg_wdata = {24'd0, mem_wb_mem_rdata[31:24]};
                endcase
            end else begin
                reg_wdata = mem_wb_mem_rdata;
            end
        end
        2'b10: reg_wdata = mem_wb_pc_plus4;
        default: reg_wdata = 32'd0;
    endcase
end

assign alu_result = ex_alu_result;

endmodule
