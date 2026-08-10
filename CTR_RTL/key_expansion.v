// =============================================================================
// key_expansion.v
// AES-128 Key Expansion - 2 Round Keys per Clock Cycle
// =============================================================================

module key_expansion (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         key_start,
    input  wire [127:0] key_in,

    output reg  [127:0] round_key_a,
    output reg  [127:0] round_key_b,
    output reg  [3:0]   round_num_a,
    output reg  [3:0]   round_num_b,
    output reg          round_key_valid
);

    // -------------------------------------------------------------------------
    // Rcon table
    // -------------------------------------------------------------------------
    function [7:0] rcon;
        input [3:0] round;
        begin
            case (round)
                4'd1:  rcon = 8'h01;
                4'd2:  rcon = 8'h02;
                4'd3:  rcon = 8'h04;
                4'd4:  rcon = 8'h08;
                4'd5:  rcon = 8'h10;
                4'd6:  rcon = 8'h20;
                4'd7:  rcon = 8'h40;
                4'd8:  rcon = 8'h80;
                4'd9:  rcon = 8'h1b;
                4'd10: rcon = 8'h36;
                default: rcon = 8'h00;
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // RotWord
    // -------------------------------------------------------------------------
    function [31:0] rot_word;
        input [31:0] w;
        begin
            rot_word = {w[23:0], w[31:24]};
        end
    endfunction

    // -------------------------------------------------------------------------
    // SubWord instantiation - 8 S-boxes total (4 per path)
    // -------------------------------------------------------------------------
    reg  [31:0] sw_a_in;
    wire [31:0] sw_a_out;
    reg  [31:0] sw_b_in;
    wire [31:0] sw_b_out;

    sbox_lut sb_a0(.in_byte(sw_a_in[31:24]), .lut_out(sw_a_out[31:24]));
    sbox_lut sb_a1(.in_byte(sw_a_in[23:16]), .lut_out(sw_a_out[23:16]));
    sbox_lut sb_a2(.in_byte(sw_a_in[15: 8]), .lut_out(sw_a_out[15: 8]));
    sbox_lut sb_a3(.in_byte(sw_a_in[ 7: 0]), .lut_out(sw_a_out[ 7: 0]));

    sbox_lut sb_b0(.in_byte(sw_b_in[31:24]), .lut_out(sw_b_out[31:24]));
    sbox_lut sb_b1(.in_byte(sw_b_in[23:16]), .lut_out(sw_b_out[23:16]));
    sbox_lut sb_b2(.in_byte(sw_b_in[15: 8]), .lut_out(sw_b_out[15: 8]));
    sbox_lut sb_b3(.in_byte(sw_b_in[ 7: 0]), .lut_out(sw_b_out[ 7: 0]));

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------
    reg [127:0] prev_rk;       // previous round key (feed into next expansion)
    reg [3:0]   stage;         // which pair we are computing (1..5)
    reg         running;       // expansion in progress

    // Combinational wires for key schedule computation
    reg [31:0]  WA0, WA1, WA2, WA3;
    reg [31:0]  WB0, WB1, WB2, WB3;
    reg [3:0]   rnd_a, rnd_b;

    // -------------------------------------------------------------------------
    // Combinational key schedule
    // -------------------------------------------------------------------------
    always @* begin
        // Round numbers for this stage
        rnd_a = (stage << 1) - 4'd1;   // 1,3,5,7,9
        rnd_b = (stage << 1);           // 2,4,6,8,10

        // ---- Round A ----
        // SubWord(RotWord(prev_rk[31:0])) ^ Rcon[rnd_a] ^ prev_rk[127:96]
        sw_a_in = rot_word(prev_rk[31:0]);

        WA0 = prev_rk[127:96] ^ sw_a_out ^ {rcon(rnd_a), 24'h000000};
        WA1 = prev_rk[ 95:64] ^ WA0;
        WA2 = prev_rk[ 63:32] ^ WA1;
        WA3 = prev_rk[ 31: 0] ^ WA2;

        // ---- Round B ----
        // SubWord(RotWord(WA3)) ^ Rcon[rnd_b] ^ WA0
        sw_b_in = rot_word(WA3);

        WB0 = WA0 ^ sw_b_out ^ {rcon(rnd_b), 24'h000000};
        WB1 = WA1 ^ WB0;
        WB2 = WA2 ^ WB1;
        WB3 = WA3 ^ WB2;
    end

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage           <= 4'd0;
            running         <= 1'b0;
            prev_rk         <= 128'd0;
            round_key_a     <= 128'd0;
            round_key_b     <= 128'd0;
            round_num_a     <= 4'd0;
            round_num_b     <= 4'd0;
            round_key_valid <= 1'b0;
        end
        else if (key_start) begin
            // Latch the original key, start at stage 1
            prev_rk         <= key_in;
            stage           <= 4'd1;
            running         <= 1'b1;
            round_key_valid <= 1'b0;
            round_key_a     <= 128'd0;
            round_key_b     <= 128'd0;
            round_num_a     <= 4'd0;
            round_num_b     <= 4'd0;
        end
        else if (running) begin
            // Output the computed pair
            round_key_a     <= {WA0, WA1, WA2, WA3};
            round_key_b     <= {WB0, WB1, WB2, WB3};
            round_num_a     <= rnd_a;
            round_num_b     <= rnd_b;
            round_key_valid <= 1'b1;

            if (stage == 4'd5) begin
                // Last pair (rounds 9 & 10) done
                running <= 1'b0;
                stage   <= 4'd0;
            end else begin
                // Feed round B key into next stage
                prev_rk <= {WB0, WB1, WB2, WB3};
                stage   <= stage + 4'd1;
            end
        end
        else begin
            round_key_valid <= 1'b0;
        end
    end

endmodule