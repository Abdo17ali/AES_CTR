module aes_128_pipelined (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         Valid_in,
    input  wire [127:0] Data_in,
    input  wire [127:0] K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10,
    output wire         Valid_out,
    output wire [127:0] Data_out
);
    wire [127:0] state_array_reg_out;
    wire [127:0] wire_whitened_data;
    wire [127:0] wire_stage1_to_2, wire_stage2_to_3, wire_stage3_to_4, wire_stage4_to_5;
    wire valid_stage1_to_2, valid_stage2_to_3, valid_stage3_to_4, valid_stage4_to_5;
    reg  valid_in_reg;

    pipeline_reg_128 u_input_reg (
        .clk(clk), .rst_n(rst_n), .en(Valid_in),
        .data_in(Data_in), .data_out(state_array_reg_out)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_in_reg <= 1'b0;
        else        valid_in_reg <= Valid_in;
    end

    add_round_key u_initial_ark (
        .state_in(state_array_reg_out), .round_key(K0), .state_out(wire_whitened_data)
    );

    aes_stage u_stage_1 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in_reg),
        .state_in(wire_whitened_data), .key_a(K1), .key_b(K2),
        .valid_out(valid_stage1_to_2), .state_out(wire_stage1_to_2)
    );
    
    aes_stage u_stage_2 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_stage1_to_2),
        .state_in(wire_stage1_to_2), .key_a(K3), .key_b(K4),
        .valid_out(valid_stage2_to_3), .state_out(wire_stage2_to_3)
    );
    
    aes_stage u_stage_3 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_stage2_to_3),
        .state_in(wire_stage2_to_3), .key_a(K5), .key_b(K6),
        .valid_out(valid_stage3_to_4), .state_out(wire_stage3_to_4)
    );
    
    aes_stage u_stage_4 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_stage3_to_4),
        .state_in(wire_stage3_to_4), .key_a(K7), .key_b(K8),
        .valid_out(valid_stage4_to_5), .state_out(wire_stage4_to_5)
    );
    
    aes_stage_last u_stage_5 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_stage4_to_5),
        .state_in(wire_stage4_to_5), .key_9(K9), .key_10(K10),
        .valid_out(Valid_out), .state_out(Data_out)
    );
endmodule