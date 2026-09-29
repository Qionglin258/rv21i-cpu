`timescale 1ns/1ps
//============================================================================
// tb_soc_top.v - RV32I 最小 SoC 通用测试台
//
// 结果约定：固件把“通过项数”恰好写一次到 0x1FFC，测试台嗅探该写。
//
// 运行参数（vsim 命令行 plusarg，全部可省略，省略取默认值）：
//   +CYCLES=<n>     仿真运行的时钟周期数，默认 3000
//   +EXPECTED=<dec> 期望的 result 值（即固件里通过项数），默认 0
//   +UART_LEN=<n>   期望 UART 收到的字节数；>0 时启用 UART 校验，默认 0
//   +UART_SUM=<dec> 期望收到全部字节的算术和（配合 +UART_LEN 锁定内容）
//   +GPIO_CHECK=1   给出该参数则在结束时校验 GPIO 输出
//   +GPIO_EXP=<hex> 期望的 8 位 GPIO 输出（十六进制），如 +GPIO_EXP=5a
//   +RX_TEST=1      向 DUT 的 uart_rx 注入 A5 5A 'O' 'K'，验证 echo 固件原样回发
//
// 例：
//   vsim -c tb_soc_top -g/... +EXPECTED=17 +CYCLES=3000 -do "run -all; quit -f"
//   vsim -c tb_soc_top +EXPECTED=4 +CYCLES=8000 \
//        +UART_LEN=5 +UART_SUM=419 +GPIO_CHECK=1 +GPIO_EXP=5a -do "run -all; quit -f"
//============================================================================
module tb_soc_top;

    // UART: 100MHz / 115200 -> DIV = 868, 1 bit = 868 clk = 8680 ns, 8N1, LSB first.
    // BIT_NS matches the RTL's integer divisor exactly so the monitor samples
    // the same (slightly off-nominal) baud rate the DUT produces.
    localparam integer BIT_NS   = 8680;
    localparam integer BIT_HALF = BIT_NS / 2;

    reg        clk;
    reg        arst_n;
    reg        uart_rx;
    wire       uart_tx;
    wire [15:0] gpio_out;  // DUT -> LEDs
    reg  [15:0] gpio_in;   // testbench -> DUT (models the switches)

    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire [31:0] debug_alu_result;
    wire [31:0] debug_reg_wdata;

    integer failures;
    integer fetched_instructions;
    integer result_writes;
    reg        result_write_seen;
    reg [31:0] result_value;

    // ---- plusarg configuration ----
    integer      cycles;
    integer      expected;
    integer      uart_len_exp;
    integer      uart_sum_exp;
    reg          gpio_check_en;
    reg [7:0]    gpio_exp;
    reg [7:0]    sw_in;      // +SW=<hex>: drive gpio_in low byte like the board switches
    integer      rx_test_en; // +RX_TEST=1: inject an RX frame sequence to test echo

    // ---- UART monitor storage ----
    integer      ui;
    integer      ub;
    reg [7:0]    ubyte;
    reg [7:0]    uart_mem [0:255];
    integer      uart_n;
    integer      uart_sum;

    // gpio_in is driven directly by the testbench (like board switches); defaults to 0.

    soc_top uut (
        .clk        (clk),
        .arst_n     (arst_n),
        .pc         (debug_pc),
        .instr      (debug_instr),
        .alu_result (debug_alu_result),
        .reg_wdata  (debug_reg_wdata),
        .uart_tx    (uart_tx),
        .uart_rx    (uart_rx),
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out)
    );

    always #5 clk = ~clk;

    task check;
        input condition;
        input [8*96-1:0] message;
        begin
            if (!condition) begin
                $display("  [FAIL] %0s at %0t ns", message, $time);
                failures = failures + 1;
            end
        end
    endtask

    // Drive one 8N1 frame into the DUT's uart_rx (LSB first), at the same
    // BIT_NS the DUT uses, so its half-bit aligned receiver samples correctly.
    task send_rx_byte;
        input [7:0] b;
        integer k;
        begin
            uart_rx = 1'b0;              // start bit
            #(BIT_NS);
            for (k = 0; k < 8; k = k + 1) begin
                uart_rx = b[k];          // data bits, LSB first
                #(BIT_NS);
            end
            uart_rx = 1'b1;              // stop bit
            #(BIT_NS);
        end
    endtask

    // Count fetched instructions and the single result write to 0x1FFC.
    always @(posedge clk) begin
        if (arst_n && (debug_instr !== 32'bx)) begin
            fetched_instructions = fetched_instructions + 1;
        end

        if (arst_n && uut.u_cpu.mem_we && (uut.u_cpu.mem_addr == 32'h00001FFC)) begin
            result_writes    = result_writes + 1;
            result_write_seen = 1'b1;
            result_value     = uut.u_cpu.mem_wdata;
        end
    end

    // ---------------- UART transmit monitor (sample the DUT's uart_tx) ----
    initial begin
        uart_n   = 0;
        uart_sum = 0;
        forever begin
            @(negedge uart_tx);          // start bit falling edge
            #(BIT_HALF);                 // center of start bit
            #(BIT_NS);                   // center of data bit 0
            ubyte = 8'd0;
            for (ub = 0; ub < 8; ub = ub + 1) begin
                ubyte[ub] = uart_tx;     // LSB first
                #(BIT_NS);
            end
            // now at center of stop bit; latch the byte
            uart_mem[uart_n] = ubyte;
            uart_sum        = uart_sum + ubyte;
            uart_n          = uart_n + 1;
            #(BIT_HALF);                 // realign to frame boundary
        end
    end

    // ---------------- optional RX stimulus (echo self-test) ----------------
    // This is the only process that drives uart_rx, so the line idles high
    // when the test is off. With +RX_TEST=1 it waits for reset release and the
    // 8-byte banner, then sends A5 5A 'O' 'K' with a gap wider than one TX
    // frame (the UART has a single-byte RX buffer). The echo firmware returns
    // each byte, so the TX monitor captures banner(8) + echo(4) = 12 bytes.
    initial begin
        uart_rx = 1'b1;                 // idle line
        rx_test_en = 0;
        if ($value$plusargs("RX_TEST=%d", rx_test_en)) ;
        if (rx_test_en) begin
            #1000000;
            send_rx_byte(8'hA5); #(100000);
            send_rx_byte(8'h5A); #(100000);
            send_rx_byte(8'h4F); #(100000); // 'O'
            send_rx_byte(8'h4B); #(100000); // 'K'
        end
    end

    initial begin
        // ---- defaults, then override from plusargs ----
        cycles        = 3000;
        expected      = 0;
        uart_len_exp  = 0;
        uart_sum_exp  = 0;
        gpio_check_en = 1'b0;
        gpio_exp      = 8'h00;
        sw_in         = 8'h00;

        if ($value$plusargs("CYCLES=%d",   cycles))       ;
        if ($value$plusargs("EXPECTED=%d", expected))     ;
        if ($value$plusargs("UART_LEN=%d", uart_len_exp)) ;
        if ($value$plusargs("UART_SUM=%d", uart_sum_exp)) ;
        if ($value$plusargs("GPIO_EXP=%h",  gpio_exp))    gpio_check_en = 1'b1;
        if ($value$plusargs("GPIO_CHECK=%d", ui))         gpio_check_en = ui[0];
        if ($value$plusargs("SW=%h",        sw_in))       ;

        // ---- DUT init ----
        clk            = 1'b0;
        arst_n         = 1'b0;
        gpio_in        = {8'd0, sw_in};

        failures             = 0;
        fetched_instructions = 0;
        result_writes        = 0;
        result_write_seen    = 1'b0;
        result_value         = 32'd0;

        #25;
        arst_n = 1'b1;

        repeat (cycles) @(posedge clk);

        // ---------------- report ----------------
        $display("==================================================");
        $display(" RESULT  value=%0d  writes=%0d  fetched=%0d  (expected %0d)",
                 result_value, result_writes, fetched_instructions, expected);

        $display(" UART    received %0d byte(s), checksum=%0d (expect len %0d sum %0d)",
                 uart_n, uart_sum, uart_len_exp, uart_sum_exp);
        for (ui = 0; ui < uart_n; ui = ui + 1) begin
            if (uart_mem[ui] >= 32 && uart_mem[ui] < 127)
                $display("         [%0d] 0x%02h  '%c'", ui, uart_mem[ui], uart_mem[ui]);
            else
                $display("         [%0d] 0x%02h", ui, uart_mem[ui]);
        end

        $display(" GPIO    in=0x%02h  out_hi=0x%02h (%0d)  out_lo=0x%02h", gpio_in[7:0], gpio_out[15:8], gpio_out[15:8], gpio_out[7:0]);
        $display("==================================================");

        // ---------------- checks ----------------
        check(fetched_instructions >= 10, "CPU fetched instructions from imem");
        check(result_write_seen,            "CPU wrote the result to 0x1FFC");
        check(result_writes === 1,          "CPU wrote the result exactly once");
        check(result_value === expected,    "result value matches EXPECTED");

        if (uart_len_exp > 0) begin
            check(uart_n   == uart_len_exp, "UART received byte count matches");
            check(uart_sum == uart_sum_exp, "UART received byte checksum matches");
        end

        if (gpio_check_en) begin
            check(gpio_out[7:0] === gpio_exp, "GPIO output matches GPIO_EXP (low byte)");
        end

        if (failures == 0)
            $display("PASS: all checks ok, result = %0d", result_value);
        else
            $display("FAIL: %0d check(s) failed", failures);

        $finish;
    end

endmodule
