module soc_top #(
    parameter integer UART_CLK_FREQ = 100000000, // 100 MHz for sim
    parameter integer UART_BAUD     = 115200
)(
    input         clk,
    input         arst_n,
    output [31:0] pc,
    output [31:0] instr,
    output [31:0] alu_result,
    output [31:0] reg_wdata,
    output        uart_tx,
    input         uart_rx,
    input  [15:0] gpio_in,
    output [15:0] gpio_out
);

wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire        mem_we;
wire [3:0]  mem_byte_en;
wire [31:0] mem_rdata;

wire [9:0]  dmem_addr;
wire [31:0] dmem_wdata;
wire        dmem_we;
wire [3:0]  dmem_byte_en;
wire [31:0] dmem_rdata;

wire [3:0]  uart_addr;
wire [31:0] uart_wdata;
wire        uart_we;
wire        uart_re;
wire [31:0] uart_rdata;

wire [3:0]  gpio_addr;
wire [31:0] gpio_wdata;
wire        gpio_we;
wire [31:0] gpio_rdata;

cpu u_cpu(
    .clk(clk),
    .arst_n(arst_n),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_we(mem_we),
    .mem_byte_en(mem_byte_en),
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
    .mem_byte_en(mem_byte_en),
    .mem_rdata(mem_rdata),
    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .dmem_we(dmem_we),
    .dmem_byte_en(dmem_byte_en),
    .dmem_rdata(dmem_rdata),
    .uart_addr(uart_addr),
    .uart_wdata(uart_wdata),
    .uart_we(uart_we),
    .uart_re(uart_re),
    .uart_rdata(uart_rdata),
    .gpio_addr(gpio_addr),
    .gpio_wdata(gpio_wdata),
    .gpio_we(gpio_we),
    .gpio_rdata(gpio_rdata)
);

dmem u_dmem(
    .clk(clk),
    .we(dmem_we),
    .byte_en(dmem_byte_en),
    .addr(dmem_addr), //mem_addr[11:2]
    .wdata(dmem_wdata),
    .rdata(dmem_rdata)
);

uart #(
    .CLK_FREQ(UART_CLK_FREQ),
    .BAUD_BAUD(UART_BAUD)
) u_uart(
    .clk(clk),
    .arst_n(arst_n),
    .addr(uart_addr),
    .wdata(uart_wdata),
    .we(uart_we),
    .re(uart_re),
    .rdata(uart_rdata),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx)
);

gpio u_gpio(
    .clk(clk),
    .arst_n(arst_n),
    .addr(gpio_addr),
    .wdata(gpio_wdata),
    .we(gpio_we),
    .rdata(gpio_rdata),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out)
);

endmodule
