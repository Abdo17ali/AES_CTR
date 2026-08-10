module mix_columns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    mix_column_32bit u_mix_col0 (.col_in(state_in[127:96]), .col_out(state_out[127:96]));
    mix_column_32bit u_mix_col1 (.col_in(state_in[95:64]),  .col_out(state_out[95:64]));
    mix_column_32bit u_mix_col2 (.col_in(state_in[63:32]),  .col_out(state_out[63:32]));
    mix_column_32bit u_mix_col3 (.col_in(state_in[31:0]),   .col_out(state_out[31:0]));
endmodule