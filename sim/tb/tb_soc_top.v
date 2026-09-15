`timescale 1ns/1ps

module tb_soc_top;

// 时钟复位
reg         clk;
reg         arst_n;

// UART 引脚
wire        uart_tx;
reg         uart_rx;

// GPIO 双向引脚处理
wire [7:0]  gpio_io;
reg         gpio_drive_en;  // TB 侧驱动使能：1=驱动输入，0=高阻（测输出）
reg [7:0]   gpio_drive_val; // TB 侧输出的电平
assign gpio_io = gpio_drive_en ? gpio_drive_val : 8'hzz;

wire [31:0] debug_pc;
wire [31:0] debug_instr;
wire [31:0] debug_alu_result;
wire [31:0] debug_reg_wdata;

// 测试统计
integer     failures;
reg [31:0]  rd0, rd1;
reg [31:0]  stat, data;
reg [31:0]  dir_rd, out_rd, in_rd;

// 波特率参数：和 UART 内部 DIVISOR 对应
// 100MHz 时钟，DIVISOR=10 → 10Mbps → 每位 100ns
localparam BIT_TIME = 100;

// 地址映射表
localparam DMEM_BASE  = 32'h00000000;
localparam UART_BASE  = 32'h00001000;
localparam GPIO_BASE  = 32'h00002000;

// 寄存器偏移
localparam UART_DATA  = 4'h0;
localparam UART_STAT  = 4'h4;
localparam GPIO_DIR   = 4'h0;
localparam GPIO_OUT   = 4'h4;
localparam GPIO_IN    = 4'h8;

// 例化 SoC 顶层
soc_top uut (
    .clk     (clk),
    .arst_n  (arst_n),
    .pc      (debug_pc),
    .instr   (debug_instr),
    .alu_result (debug_alu_result),
    .reg_wdata  (debug_reg_wdata),
    .uart_tx (uart_tx),
    .uart_rx (uart_rx),
    .gpio_io (gpio_io)
);

// 100MHz 系统时钟
always #5 clk = ~clk;

// 通用断言检查
task check;
    input condition;
    input [8*80-1:0] message;
    begin
        if (!condition) begin
            $display("FAIL: %s at %0t ns", message, $time);
            failures = failures + 1;
        end
    end
endtask

// 总线写任务：模拟 CPU 写一个 32 位寄存器
task bus_write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(negedge clk);
        // 直接驱动 CPU 侧总线信号；若你的 CPU 是封装好的，可改为通过 CPU 接口写入
        // 此处对应总线的 mem_addr/mem_wdata/mem_we
        force uut.mem_addr = addr;
        force uut.mem_wdata = data;
        force uut.mem_we = 1'b1;
        @(negedge clk);
        release uut.mem_addr;
        release uut.mem_wdata;
        release uut.mem_we;
    end
endtask

// 总线读任务：模拟 CPU 读一个 32 位寄存器
task bus_read;
    input [31:0] addr;
    output [31:0] data;
    begin
        @(negedge clk);
        force uut.mem_addr = addr;
        force uut.mem_we = 1'b0;
        @(posedge clk);
        #1;
        data = uut.mem_rdata;
        release uut.mem_addr;
        release uut.mem_we;
    end
endtask

// 发送串口字节：模拟外部设备给 UART 发数据
task send_uart_byte;
    input [7:0] byte_val;
    integer i;
    begin
        force uut.mem_addr = UART_BASE + UART_STAT;
        force uut.mem_we = 1'b0;
        uart_rx = 1'b0; // 起始位
        #(BIT_TIME);
        for (i=0; i<8; i=i+1) begin
            uart_rx = byte_val[i];
            #(BIT_TIME);
        end
        uart_rx = 1'b1; // 停止位
        #(BIT_TIME);
        release uut.mem_addr;
        release uut.mem_we;
    end
endtask

initial begin
    // 初始化
    clk = 0;
    arst_n = 0;
    uart_rx = 1'b1;
    gpio_drive_en = 0;
    gpio_drive_val = 0;
    failures = 0;

    // 复位释放
    #20;
    arst_n = 1;
    #10;

    $display("=== Start SoC Integration Test ===");

    // ========== 测试1：数据内存读写 ==========
    $display("[Test 1] Data Memory R/W");
    bus_write(DMEM_BASE + 32'h00, 32'h12345678);
    bus_write(DMEM_BASE + 32'h04, 32'hABCDEF01);
    
    begin
        bus_read(DMEM_BASE + 32'h00, rd0);
        bus_read(DMEM_BASE + 32'h04, rd1);
        check(rd0 == 32'h12345678, "DMEM word 0 write/read mismatch");
        check(rd1 == 32'hABCDEF01, "DMEM word 1 write/read mismatch");
    end

    // ========== 测试2：UART 寄存器读写与收发 ==========
    $display("[Test 2] UART Register & Transceiver");
    
    // 检查复位后状态：发送空闲、接收无数据
    begin
        bus_read(UART_BASE + UART_STAT, stat);
        check(stat[0] == 1'b1, "UART TX idle after reset");
        check(stat[1] == 1'b0, "UART RX empty after reset");
    end

    // 测试发送：写数据寄存器，检查忙标志
    bus_write(UART_BASE + UART_DATA, 32'hA5);
    #1;
    begin
        bus_read(UART_BASE + UART_STAT, stat);
        check(stat[0] == 1'b0, "UART TX busy after write");
    end

    // 等待发送完成，检查回到空闲
    #(BIT_TIME * 10);
    begin
        bus_read(UART_BASE + UART_STAT, stat);
        check(stat[0] == 1'b1, "UART TX idle after frame done");
    end

    // 测试接收：发一个字节，检查就绪标志和数据
    send_uart_byte(8'h3C);
    begin
        bus_read(UART_BASE + UART_STAT, stat);
        check(stat[1] == 1'b1, "UART RX ready after receive");
        bus_read(UART_BASE + UART_DATA, data);
        check(data[7:0] == 8'h3C, "UART RX data mismatch");
        // 读数据后检查标志清零
        bus_read(UART_BASE + UART_STAT, stat);
        check(stat[1] == 1'b0, "UART RX ready clear after read");
    end

    // ========== 测试3：GPIO 寄存器与输入输出 ==========
    $display("[Test 3] GPIO Register & I/O");
    
    // 测试写方向、输出寄存器，读回验证
    bus_write(GPIO_BASE + GPIO_DIR, 32'h0F); // 低4位输出，高4位输入
    bus_write(GPIO_BASE + GPIO_OUT, 32'h0A); // 输出 00001010
    
    begin
        bus_read(GPIO_BASE + GPIO_DIR, dir_rd);
        bus_read(GPIO_BASE + GPIO_OUT, out_rd);
        check(dir_rd[7:0] == 8'h0F, "GPIO direction register write/read mismatch");
        check(out_rd[7:0] == 8'h0A, "GPIO output register write/read mismatch");
    end

    // 测试输出电平：检查引脚电平是否和输出寄存器一致
    #1;
    check(gpio_io[3:0] == 4'b1010, "GPIO output pin level mismatch");

    // 测试输入功能：TB 驱动高4位引脚，读输入寄存器
    gpio_drive_en = 1;
    gpio_drive_val = 8'hB0; // 高4位 1011
    #10;
    begin
        bus_read(GPIO_BASE + GPIO_IN, in_rd);
        check(in_rd[7:4] == 4'b1011, "GPIO input register read mismatch");
    end
    gpio_drive_en = 0;

    // ========== 最终结果 ==========
    #100;
    if (failures == 0)
        $display("=== PASS: All SoC tests passed ===");
    else
        $display("=== FAIL: %0d test(s) failed ===", failures);
    
    $finish;
end

endmodule
