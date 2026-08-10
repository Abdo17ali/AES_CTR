module sub_bytes (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_gen
            sbox_lut u_sbox (
                .in_byte (state_in[127 - (i*8) : 120 - (i*8)]),
                .lut_out (state_out[127 - (i*8) : 120 - (i*8)])
            );
        end
    endgenerate
endmodule