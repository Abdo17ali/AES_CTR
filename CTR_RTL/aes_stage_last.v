module aes_stage_last (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         valid_in,
    input  wire [127:0] state_in,
    input  wire [127:0] key_9,
    input  wire [127:0] key_10,
    output wire         valid_out,
    output wire [127:0] state_out
);
    wire [127:0] wire_round9_to_round10;
    wire [127:0] wire_round10_to_reg;
    reg          valid_reg;

    aes_round      u_round_9  (.state_in(state_in),               .round_key(key_9),  .state_out(wire_round9_to_round10));
    aes_round_last u_round_10 (.state_in(wire_round9_to_round10), .round_key(key_10), .state_out(wire_round10_to_reg));

    pipeline_reg_128 u_stage_reg (
        .clk(clk), .rst_n(rst_n), .en(valid_in),
        .data_in(wire_round10_to_reg), .data_out(state_out)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_reg <= 1'b0;
        else        valid_reg <= valid_in;
    end
    assign valid_out = valid_reg;
endmodule