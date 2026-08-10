// =============================================================================
// key_store.v
// AES-128 Round Key Storage
// =============================================================================

module key_store (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         key_start,       // NEW: resets keys_ready on new key
    input  wire [127:0] master_key,
    input  wire         round_key_valid,
    input  wire [127:0] round_key_a,
    input  wire [127:0] round_key_b,
    input  wire [3:0]   round_num_a,
    input  wire [3:0]   round_num_b,
    output reg          keys_ready,
    output reg  [127:0] K0, K1, K2, K3, K4,
                        K5, K6, K7, K8, K9, K10
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            keys_ready <= 1'b0;
            K0  <= 128'd0; K1  <= 128'd0; K2  <= 128'd0;
            K3  <= 128'd0; K4  <= 128'd0; K5  <= 128'd0;
            K6  <= 128'd0; K7  <= 128'd0; K8  <= 128'd0;
            K9  <= 128'd0; K10 <= 128'd0;
        end else begin

            // KEY START FIX:
            // Pull keys_ready LOW the moment key_start is seen.
            // Without this, keys_ready stays HIGH from the previous
            // key expansion, and the UVM driver thinks the new key
            // is ready before expansion even starts.
            if (key_start) begin
                keys_ready <= 1'b0;
            end

            // Always latch K0 from master_key
            K0 <= master_key;

            // Store round keys as they arrive from key expansion
            if (round_key_valid) begin
                case (round_num_a)
                    4'd1: begin K1  <= round_key_a; K2  <= round_key_b; end
                    4'd3: begin K3  <= round_key_a; K4  <= round_key_b; end
                    4'd5: begin K5  <= round_key_a; K6  <= round_key_b; end
                    4'd7: begin K7  <= round_key_a; K8  <= round_key_b; end
                    4'd9: begin
                        K9  <= round_key_a;
                        K10 <= round_key_b;
                        keys_ready <= 1'b1;   // All 11 keys stored
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule