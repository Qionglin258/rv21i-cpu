module board_top (
    input  wire       clk,
    input  wire [7:0] sw,
    input  wire       rst_sw,
    output reg  [7:0] led,
    output wire       uart_tx,
    input  wire       uart_rx
);

    //divider: 100 MHz -> 6.25 MHz
    reg [3:0] clk_div;
    always @(posedge clk)
        clk_div <= clk_div + 4'd1;

    wire cpu_clk_pre = clk_div[3];   // 100 MHz / 16 = 6.25 MHz
    wire cpu_clk;
    BUFG u_bufg_cpu (.I(cpu_clk_pre), .O(cpu_clk)); // global clk buffer,better the quality of the clock
    wire rst_async_n = ~rst_sw;

    // asynchronous assert, synchronous release into the CPU clock domain
    reg rst_sync1 = 1'b0;
    reg rst_sync2 = 1'b0;
    always @(posedge cpu_clk or negedge rst_async_n) begin
        if (!rst_async_n) begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= 1'b0;
        end else begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= rst_sync1;
        end
    end
    wire arst_n = rst_sync2; // reset for 1st 2 beats

    // ---- heartbeat on LD7, straight from 100 MHz (independent of CPU) ----
    reg [25:0] hb_cnt;
    always @(posedge clk)
        hb_cnt <= hb_cnt + 26'd1;
    wire heartbeat = hb_cnt[25];          // ~1.5 Hz blink

    wire [15:0] gpio_in;
    wire [15:0] gpio_out;

    assign gpio_in = {8'd0, sw};          // low byte = switches, high byte unused

    always @(*) begin
        led[7]   = heartbeat;
        led[6:4] = 3'b000;
        led[3:0] = gpio_out[11:8];
    end

    soc_top #(
        .UART_CLK_FREQ(6250000),   // UART runs on the 6.25 MHz CPU clock
        .UART_BAUD    (115200)
    ) u_soc (
        .clk        (cpu_clk),
        .arst_n     (arst_n),
        .uart_tx    (uart_tx),
        .uart_rx    (uart_rx),
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out)
    );

endmodule
