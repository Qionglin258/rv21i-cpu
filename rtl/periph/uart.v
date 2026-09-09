module uart(
    input        clk,
    input        arst_n,
    input  [3:0] addr,
    input  [31:0] wdata,
    input        we,
    output reg  [31:0] rdata,
    output       uart_tx,
    input        uart_rx
);

assign uart_tx = 1'b1;

always @(*) begin
    case (addr)
        4'h0: rdata = 32'd0;
        4'h4: rdata = 32'h1;
        default: rdata = 32'd0;
    endcase
end

endmodule
