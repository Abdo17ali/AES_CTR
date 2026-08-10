module aes_round_last (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);
    wire [127:0] state_after_subbytes;
    wire [127:0] state_after_shiftrows;

    sub_bytes     u_sub_bytes  (.state_in(state_in),             .state_out(state_after_subbytes));
    shift_rows    u_shift_rows (.state_in(state_after_subbytes), .state_out(state_after_shiftrows));
    add_round_key u_add_rk     (.state_in(state_after_shiftrows),.round_key(round_key), .state_out(state_out));
endmodule