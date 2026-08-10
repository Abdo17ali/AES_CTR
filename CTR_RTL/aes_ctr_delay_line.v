// =============================================================================
// aes_ctr_delay_line.v
// 7-stage delay line to match AES-CTR pipeline latency (8 cycles total)
// Data delayed 7 cycles to align at XOR input with keystream
// =============================================================================

module aes_ctr_delay_line (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         valid_in,
    input  wire [127:0] data_in,
    output wire         valid_out,
    output wire [127:0] data_out
);

    // 7 stage delay registers
    reg [127:0] data_delay [0:6];
    reg [6:0]   valid_delay;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear all 7 delay stages
            for (i = 0; i < 7; i = i + 1) begin
                data_delay[i] <= 128'd0;
            end
            valid_delay <= 7'b0;
        end else begin
            // Stage 0: capture input
            data_delay[0]  <= data_in;
            valid_delay[0] <= valid_in;

            // Stages 1-6: shift through
            data_delay[1]  <= data_delay[0];
            data_delay[2]  <= data_delay[1];
            data_delay[3]  <= data_delay[2];
            data_delay[4]  <= data_delay[3];
            data_delay[5]  <= data_delay[4];
            data_delay[6]  <= data_delay[5];

            valid_delay[1] <= valid_delay[0];
            valid_delay[2] <= valid_delay[1];
            valid_delay[3] <= valid_delay[2];
            valid_delay[4] <= valid_delay[3];
            valid_delay[5] <= valid_delay[4];
            valid_delay[6] <= valid_delay[5];
        end
    end

    // Output from stage 6 = 7 cycles delay
    assign data_out  = data_delay[6];
    assign valid_out = valid_delay[6];

endmodule