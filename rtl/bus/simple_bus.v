module simple_bus(
    input  [31:0] mem_addr, //[15:12] select device, [11:2] select register,[3:0] select register offset
    input  [31:0] mem_wdata,
    input         mem_we,
    output reg  [31:0] mem_rdata,

    output reg  [9:0]  dmem_addr,
    output reg  [31:0] dmem_wdata,
    output reg         dmem_we,
    input  [31:0] dmem_rdata,

    output reg  [3:0]  uart_addr,
    output reg  [31:0] uart_wdata,
    output reg         uart_we,
    input  [31:0] uart_rdata

    output reg [3:0]  gpio_addr,
    output reg [31:0] gpio_wdata,
    output reg        gpio_we,
    input  [31:0] gpio_rdata
);

always @(*) begin
    dmem_addr  = 10'd0;
    dmem_wdata = 32'd0;
    dmem_we    = 1'b0;
    uart_addr  = 4'd0;
    uart_wdata = 32'd0;
    uart_we    = 1'b0;
    gpio_addr  = 4'd0;
    gpio_wdata = 32'd0;
    gpio_we    = 1'b0;
    mem_rdata  = 32'd0;

    case (mem_addr[15:12])
        4'b0000: begin //dmem
            dmem_addr  = mem_addr[11:2]; // memory address
            dmem_wdata = mem_wdata;
            dmem_we    = mem_we;
            mem_rdata  = dmem_rdata;
        end
        4'b0001: begin //uart
            uart_addr  = mem_addr[3:0]; // register offset
            uart_wdata = mem_wdata;
            uart_we    = mem_we;
            mem_rdata  = uart_rdata;
        end
        4'b0010: begin //gpio
            gpio_addr  = mem_addr[3:0]; // register offset
            gpio_wdata = mem_wdata;
            gpio_we    = mem_we;
            mem_rdata  = gpio_rdata;
        end
        default: begin
            mem_rdata = 32'd0;
        end
    endcase
end

endmodule
