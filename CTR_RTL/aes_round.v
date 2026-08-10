module aes_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);
    wire [127:0] state_after_subbytes;
    wire [127:0] state_after_shiftrows;
    wire [127:0] state_after_mixcolumns;

    sub_bytes     u_sub_bytes   (.state_in(state_in),               .state_out(state_after_subbytes));
    shift_rows    u_shift_rows  (.state_in(state_after_subbytes),   .state_out(state_after_shiftrows));
    mix_columns   u_mix_columns (.state_in(state_after_shiftrows),  .state_out(state_after_mixcolumns));
    add_round_key u_add_rk      (.state_in(state_after_mixcolumns), .round_key(round_key), .state_out(state_out));
endmodule