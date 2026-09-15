module uart(
    input         clk,
    input         arst_n,
    input  [3:0]  addr,
    input  [31:0] wdata, // come from cpu,send right away
    input         we,
    output reg [31:0] rdata, //->soc->bus->cpu->extended to reg_wdata
    output        uart_tx,
    input         uart_rx
);
localparam CLK_FREQ    = 100000000;  // 100 MHz
localparam BAUD_RATE   = 10000000;   // 10 Mbps for simulation
localparam DIVISOR     = CLK_FREQ / BAUD_RATE;
localparam HALF_DIVISOR = (DIVISOR > 1) ? DIVISOR / 2 : 1;

// register map
localparam REG_DATA = 4'h0;    // data register:write:tx, read:rx
localparam REG_STAT = 4'h4;    // status register

//--------------------------
// sending
//--------------------------
reg [15:0] tx_baud_cnt;
reg [3:0]  tx_bit_cnt;
reg [9:0]  tx_shift;
reg        tx_busy;

wire tx_baud_tick = (tx_baud_cnt == DIVISOR - 1);
assign uart_tx = tx_busy ? tx_shift[0] : 1'b1; // send shift[0]

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        tx_baud_cnt <= 16'd0;
        tx_bit_cnt  <= 4'd0;
        tx_shift    <= 10'b1111111111;
        tx_busy     <= 1'b0;
    end
    else begin
        if (we && (addr == REG_DATA) && !tx_busy) begin
            // tx_shift = {1'b1(stop), wdata[7:0], 1'b0(beginning)} LSB first
            tx_shift    <= {1'b1, wdata[7:0], 1'b0};
            tx_busy     <= 1'b1;
            tx_bit_cnt  <= 4'd0;
            tx_baud_cnt <= 16'd0;
        end
        else if (tx_busy && tx_baud_tick) begin
            tx_baud_cnt <= 16'd0;
            tx_shift    <= {1'b1, tx_shift[9:1]};
            tx_bit_cnt  <= tx_bit_cnt + 4'd1;
            if (tx_bit_cnt == 4'd9) begin
                tx_busy <= 1'b0;
            end
        end
        else if (tx_busy) begin
            tx_baud_cnt <= tx_baud_cnt + 16'd1;
        end
    end
end

//--------------------------
// falling edge
//--------------------------
reg rx_sync1, rx_sync2, rx_delay;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        rx_sync1 <= 1'b1;
        rx_sync2 <= 1'b1;
        rx_delay <= 1'b1;
    end
    else begin
        rx_sync1 <= uart_rx;
        rx_sync2 <= rx_sync1;
        rx_delay <= rx_sync2;
    end
end

wire rx_start_flag = rx_delay & ~rx_sync2;

//--------------------------
// receiving
//--------------------------
reg [15:0] rx_baud_cnt;
reg [3:0]  rx_bit_cnt;
reg [7:0]  rx_shift;
reg        rx_busy;
reg [7:0]  rx_data_reg;
reg        rx_ready;

wire rx_baud_tick = (rx_baud_cnt == DIVISOR - 1);

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        rx_baud_cnt <= 16'd0;
        rx_bit_cnt  <= 4'd0;
        rx_shift    <= 8'd0;
        rx_busy     <= 1'b0;
        rx_data_reg <= 8'd0;
        rx_ready    <= 1'b0;
    end
    else begin
        if (!rx_busy && rx_start_flag) begin
            rx_busy     <= 1'b1;
            rx_baud_cnt <= HALF_DIVISOR;
            rx_bit_cnt  <= 4'd0;
        end
        else if (rx_busy && rx_baud_tick) begin
            rx_baud_cnt <= 16'd0;
            
            case (rx_bit_cnt)
                4'd0: begin
                    if (rx_sync2 == 1'b0) begin
                        rx_bit_cnt <= rx_bit_cnt + 4'd1;
                    end
                    else begin
                        rx_busy <= 1'b0; //false start bit, abort
                    end
                end
                
                4'd1, 4'd2, 4'd3, 4'd4,
                4'd5, 4'd6, 4'd7, 4'd8: begin
                    rx_shift <= {rx_sync2, rx_shift[7:1]};
                    rx_bit_cnt <= rx_bit_cnt + 4'd1;
                end
                
                4'd9: begin
                    if (rx_sync2 == 1'b1) begin
                        rx_data_reg <= rx_shift;
                        rx_ready    <= 1'b1;
                    end //else :error
                    rx_busy <= 1'b0;
                end
                
                default: rx_busy <= 1'b0;
            endcase
        end
        else if (rx_busy) begin
            rx_baud_cnt <= rx_baud_cnt + 16'd1;
        end
        
        // anothor if,no else
        if (!we && addr == REG_DATA && rx_ready) begin
            rx_ready <= 1'b0;
        end
    end
end

//--------------------------
// read data
//--------------------------
always @(*) begin
    case (addr)
        REG_DATA: rdata = {24'd0, rx_data_reg}; // read:rx data, write:tx data
        REG_STAT: rdata = {30'd0, rx_ready, ~tx_busy}; // read status register
        default:  rdata = 32'd0;
    endcase
end

endmodule
