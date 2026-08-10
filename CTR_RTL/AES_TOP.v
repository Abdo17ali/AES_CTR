module aes_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         key_start,
    input  wire         Valid_in,
    input  wire [127:0] master_key,
    input  wire [127:0] Data_in,
    output wire         keys_ready,
    output wire         Valid_out,
    output wire [127:0] Data_out
);
    wire         ke_valid;
    wire [127:0] ke_key_a, ke_key_b;
    wire [3:0]   ke_num_a, ke_num_b;
    wire [127:0] K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10;

    key_expansion u_key_expansion (
        .clk(clk), .rst_n(rst_n), .key_start(key_start), .key_in(master_key),
        .round_key_a(ke_key_a), .round_key_b(ke_key_b),
        .round_num_a(ke_num_a), .round_num_b(ke_num_b),
        .round_key_valid(ke_valid)
    );

    key_store u_key_store (
        .clk(clk), .rst_n(rst_n), .master_key(master_key),
        .round_key_valid(ke_valid),
        .round_key_a(ke_key_a), .round_key_b(ke_key_b),
        .round_num_a(ke_num_a), .round_num_b(ke_num_b),
        .keys_ready(keys_ready),
        .K0(K0),.K1(K1),.K2(K2),.K3(K3),.K4(K4),.K5(K5),
        .K6(K6),.K7(K7),.K8(K8),.K9(K9),.K10(K10)
    );

    aes_128_pipelined u_datapath (
        .clk(clk), .rst_n(rst_n), .Valid_in(Valid_in), .Data_in(Data_in),
        .K0(K0),.K1(K1),.K2(K2),.K3(K3),.K4(K4),.K5(K5),
        .K6(K6),.K7(K7),.K8(K8),.K9(K9),.K10(K10),
        .Valid_out(Valid_out), .Data_out(Data_out)
    );
endmodule