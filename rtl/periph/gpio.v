module gpio (
    input           clk,
    input           arst_n,
    input   [3:0]   addr,
    input   [31:0]  wdata,
    input           we,
    output  reg [31:0] rdata,
    inout   [7:0]   gpio_io
);

reg [7:0] dir_reg;
reg [7:0] out_reg;
reg [7:0] sync1, sync2;

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        sync1 <= 8'd0;
        sync2 <= 8'd0;
    end else begin
        sync1 <= gpio_io;
        sync2 <= sync1;
    end
end

genvar pin;
generate
    for (pin = 0; pin < 8; pin = pin + 1) begin
        assign gpio_io[pin] = dir_reg[pin] ? out_reg[pin] : 1'bz; // only way:& cause 1'b0
    end
endgenerate

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        dir_reg <= 8'd0;
        out_reg <= 8'd0;
    end else if(we) begin
        case(addr)
            4'h0: dir_reg <= wdata[7:0];
            4'h4: out_reg <= wdata[7:0];
            default: ;
        endcase
    end
end

always @(*) begin
    case(addr)
            4'h0: rdata = {24'd0, dir_reg};
            4'h4: rdata = {24'd0, out_reg};
            4'h8: rdata = {24'd0, sync2};
            default: rdata = 32'd0;
    endcase
end

endmodule
