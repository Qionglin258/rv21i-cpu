module uart(
    input        clk,
    input        arst_n,
    input  [3:0] addr,
    input  [31:0] wdata, // come from cpu,send right away
    input        we,
    output reg  [31:0] rdata,
    output       uart_tx,
    input        uart_rx
);
// send only
localparam CLK_FREQ = 100000000; // 100 MHz
localparam BAUD_RATE = 50000000; // 50 Mbps for simulation
localparam DIVISOR = CLK_FREQ / BAUD_RATE;
reg [15:0] baud_cnt;
reg [3:0]  bit_cnt;
reg [9:0]  tx_shift;
reg        tx_busy;

wire baud_tick = (baud_cnt == DIVISOR - 1);
assign uart_tx = tx_busy ? tx_shift[0] : 1'b1;// send shift[0],so we >>

always @(*) begin
    case (addr)
        4'h0: rdata = 32'd0;
        4'h4: rdata = {31'd0, ~tx_busy};
        default: rdata = 32'd0;
    endcase
end

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        baud_cnt <= 16'd0;
        bit_cnt <= 4'd0;
        tx_shift <= 10'b1111111111;
        tx_busy <= 1'b0;
    end else begin
        if (we && (addr == 4'h0) && !tx_busy) begin
            tx_shift <= {1'b1, wdata[7:0], 1'b0};
            tx_busy  <= 1'b1;
            bit_cnt  <= 4'd0;
            baud_cnt <= 16'd0;
        end
        else if (tx_busy && baud_tick) begin
            baud_cnt <= 16'd0;
            tx_shift <= {1'b1, tx_shift[9:1]};
            bit_cnt  <= bit_cnt + 4'd1;
            if (bit_cnt == 4'd9) begin
                tx_busy <= 1'b0;
            end
        end
        else if (tx_busy) begin
            baud_cnt <= baud_cnt + 16'd1;
        end
    end
end


endmodule
