module mix_column_32bit (
    input  wire [31:0] col_in,
    output wire [31:0] col_out
);
    wire [7:0] a0 = col_in[31:24];
    wire [7:0] a1 = col_in[23:16];
    wire [7:0] a2 = col_in[15:8];
    wire [7:0] a3 = col_in[7:0];

    wire [7:0] sum = a0 ^ a1 ^ a2 ^ a3;

    function [7:0] xtime;
        input [7:0] x;
        begin
            xtime = (x << 1) ^ (x[7] ? 8'h1B : 8'h00);
        end
    endfunction

    wire [7:0] b0 = a0 ^ sum ^ xtime(a0 ^ a1);
    wire [7:0] b1 = a1 ^ sum ^ xtime(a1 ^ a2);
    wire [7:0] b2 = a2 ^ sum ^ xtime(a2 ^ a3);
    wire [7:0] b3 = a3 ^ sum ^ xtime(a3 ^ a0);

    assign col_out = {b0, b1, b2, b3};
endmodule
