module aes_stage (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         valid_in,
    input  wire [127:0] state_in,
    input  wire [127:0] key_a,
    input  wire [127:0] key_b,
    output wire         valid_out,
    output wire [127:0] state_out
);
    wire [127:0] wire_roundA_to_roundB;
    wire [127:0] wire_roundB_to_reg;
    reg          valid_reg;

    aes_round u_round_a (.state_in(state_in),              .round_key(key_a), .state_out(wire_roundA_to_roundB));
    aes_round u_round_b (.state_in(wire_roundA_to_roundB), .round_key(key_b), .state_out(wire_roundB_to_reg));

    pipeline_reg_128 u_stage_reg (
        .clk(clk), .rst_n(rst_n), .en(valid_in),
        .data_in(wire_roundB_to_reg), .data_out(state_out)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_reg <= 1'b0;
        else        valid_reg <= valid_in;
    end
    assign valid_out = valid_reg;
endmodule