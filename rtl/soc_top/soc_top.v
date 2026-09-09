module soc_top(
    input         clk,
    input         arst_n,
    output [31:0] pc,
    output [31:0] instr,
    output [31:0] alu_result,
    output [31:0] reg_wdata,
    output        uart_tx,
    input         uart_rx
);

wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire        mem_we;
wire [31:0] mem_rdata;

wire [9:0]  dmem_addr;
wire [31:0] dmem_wdata;
wire        dmem_we;
wire [31:0] dmem_rdata;

wire [3:0]  uart_addr;
wire [31:0] uart_wdata;
wire        uart_we;
wire [31:0] uart_rdata;

cpu u_cpu(
    .clk(clk),
    .arst_n(arst_n),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_we(mem_we),
    .mem_rdata(mem_rdata),
    .pc(pc),
    .instr(instr),
    .alu_result(alu_result),
    .reg_wdata(reg_wdata)
);

simple_bus u_simple_bus(
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_we(mem_we),
    .mem_rdata(mem_rdata),
    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .dmem_we(dmem_we),
    .dmem_rdata(dmem_rdata),
    .uart_addr(uart_addr),
    .uart_wdata(uart_wdata),
    .uart_we(uart_we),
    .uart_rdata(uart_rdata)
);

dmem u_dmem(
    .clk(clk),
    .we(dmem_we),
    .addr(dmem_addr),
    .wdata(dmem_wdata),
    .rdata(dmem_rdata)
);

uart u_uart(
    .clk(clk),
    .arst_n(arst_n),
    .addr(uart_addr),
    .wdata(uart_wdata),
    .we(uart_we),
    .rdata(uart_rdata),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx)
);

endmodule
