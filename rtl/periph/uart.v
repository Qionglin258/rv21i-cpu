module uart(
    input        clk,
    input        arst_n,
    input  [3:0] addr,
    input  [31:0] wdata, // come from cpu,send right away
    input        we,
    output reg  [31:0] rdata, //->soc->bus->cpu->extended to reg_wdata
    output       uart_tx,
    input        uart_rx
);
localparam CLK_FREQ = 100000000; // 100 MHz
localparam BAUD_RATE = 50000000; // 50 Mbps for simulation
localparam DIVISOR = CLK_FREQ / BAUD_RATE;
reg [15:0] tx_baud_cnt;
reg [3:0]  tx_bit_cnt;
reg [9:0]  tx_shift;
reg        tx_busy;

wire baud_tick = (tx_baud_cnt == DIVISOR - 1);
assign uart_tx = tx_busy ? tx_shift[0] : 1'b1;// send shift[0],so we >>

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        tx_baud_cnt <= 16'd0;
        tx_bit_cnt <= 4'd0;
        tx_shift <= 10'b1111111111; // 1 when idle
        tx_busy <= 1'b0;
    end else begin
        if (we && (addr == 4'h0) && !tx_busy) begin //cpu wants to write&&write data register&&not busy ->send
            tx_shift <= {1'b1, wdata[7:0], 1'b0};
            tx_busy  <= 1'b1;
            tx_bit_cnt  <= 4'd0;
            tx_baud_cnt <= 16'd0;
        end
        else if (tx_busy && baud_tick) begin
            tx_baud_cnt <= 16'd0;
            tx_shift <= {1'b1, tx_shift[9:1]};
            tx_bit_cnt  <= tx_bit_cnt + 4'd1;
            if (tx_bit_cnt == 4'd9) begin
                tx_busy <= 1'b0;
            end
        end
        else if (tx_busy) begin
            tx_baud_cnt <= tx_baud_cnt + 16'd1; //wait for baud tick
        end
    end
end

reg rx_bat1,rx_sync,rx_delay;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        rx_bat1 <= 1'b1;
        rx_sync <= 1'b1; // 1 when idle
        rx_delay <= 1'b1; // to detect falling edge,we're using rx_sync for sure
    end else begin
        rx_bat1 <= uart_rx;
        rx_sync <= rx_bat1;
        rx_delay <= rx_sync;
    end
end

reg [15:0] rx_baud_cnt;
reg [3:0]  rx_bit_cnt;
reg [7:0]  rx_shift;
reg        rx_busy;
reg [7:0]  rx_data_reg;
reg        rx_ready;

always@ (posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        rx_baud_cnt <= 16'd0;
        rx_bit_cnt <= 4'd0;
        rx_shift <= 8'd0;
        rx_busy <= 1'b0;
        rx_ready <= 1'b0;
        rx_data_reg <= 8'd0;
    end else begin
        if (!rx_busy && !rx_sync && rx_delay) begin // falling edge && not busy
            rx_busy <= 1'b1;
            rx_baud_cnt <= DIVISOR / 2; // sampling at 0.5,1.5...tick
            rx_bit_cnt <= 4'd0;
            rx_shift <= 8'd0; // repeat a lot
        end else if (rx_busy && baud_tick) begin
            rx_baud_cnt <= 16'd0;
            if (rx_bit_cnt == 4'd0) begin
                // start bit, check if it's low
                if (!rx_sync) begin
                    rx_bit_cnt <= rx_bit_cnt + 4'd1;
                end else begin
                    rx_busy <= 1'b0; // false start bit, abort
                end
            end // no receiving
            else if (rx_bit_cnt <= 4'd8) begin
                rx_shift <= {rx_sync, rx_shift[7:1]};
                rx_bit_cnt <= rx_bit_cnt + 4'd1;
            end
            else if (rx_bit_cnt == 4'd9) begin
                // stop bit, check if it's high
                if (rx_sync) begin
                    rx_data_reg <= rx_shift;// the rx_shift now is {data[7:0](start_bit,1'b0)}
                    rx_ready <= 1'b1;
                end
                rx_busy <= 1'b0;
                rx_bit_cnt <= 4'd0; // repeat a lot
            end
        end else if (rx_ready && !we && addr == 4'h0) begin // cpu reads data register, clear ready flag
            rx_ready <= 1'b0;
        end else if (rx_busy) begin
            rx_baud_cnt <= rx_baud_cnt + 16'd1; // wait for baud tick
        end
    end
end


always @(*) begin
    case (addr)
        4'h0: rdata = {24'd0, rx_data_reg};  // read data register
        4'h4: rdata = {30'd0, rx_ready, ~tx_busy}; // read status regiter
        default: rdata = 32'd0;
    endcase
end



endmodule
