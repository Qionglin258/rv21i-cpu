`timescale 1ns/1ps

module tb_cpu;

    reg         clk;
    reg         arst_n;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    wire [3:0]  mem_byte_en;
    wire [31:0] mem_rdata;
    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] alu_result;
    wire [31:0] reg_wdata;

    cpu u_cpu(
        .clk(clk),
        .arst_n(arst_n),
        .mem_rdata(mem_rdata),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_byte_en(mem_byte_en),
        .pc(pc),
        .instr(instr),
        .alu_result(alu_result),
        .reg_wdata(reg_wdata)
    );

    // dmem wired straight to the CPU core (no simple_bus, no UART/GPIO)
    dmem u_dmem(
        .clk(clk),
        .we(mem_we),
        .addr(mem_addr[11:2]),
        .wdata(mem_wdata),
        .byte_en(mem_byte_en),
        .rdata(mem_rdata)
    );

    // load cpu.c after imem's own time-0 $readmemh, before the first edge at #5
    initial begin
        #1;
        $readmemh("imem_cpu.hex", u_cpu.u_imem.mem);
    end

    always #5 clk = ~clk;

    initial begin
        clk    = 1'b0;
        arst_n = 1'b0;
        #15;
        arst_n = 1'b1;
        #2000;                  // the 19-instruction sequence finishes well before this
        $finish;
    end

endmodule
