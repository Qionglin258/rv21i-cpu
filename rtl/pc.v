module pc (
    input clk,
    input arst_n,
    input [31:0] next_pc,
    output reg [31:0] pc
);
always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        pc <= 32'b0; // Reset PC to 0
    end else begin
        pc <= next_pc; // Update PC with next_pc when pc_sel is high
    end
end
endmodule