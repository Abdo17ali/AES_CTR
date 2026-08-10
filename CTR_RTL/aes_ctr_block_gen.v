// =============================================================================
// aes_ctr_block_gen.v
// Counter block generator for AES-128 CTR mode
// Format : NIST SP 800-38A
// IV     : Full 128-bit initial counter block
// Counter: Increments last 32 bits of IV
// Block 1: IV (as is)
// Block 2: IV with last 32 bits + 1
// Block N: IV with last 32 bits + (N-1)
// =============================================================================

module aes_ctr_block_gen (
    input  wire         clk,
    input  wire         rst_n,

    // IV interface (full 128-bit)F
    input  wire [127:0] iv_in,
    input  wire         iv_load,

    // Control interface
    input  wire         enable,
    input  wire         block_advance,
    input  wire         iv_locked_in,

    // Outputs
    output reg  [127:0] ctr_block_out,
    output reg          ctr_block_valid,
    output wire [31:0]  ctr_value,
    output wire         ctr_exhausted_warn,
    output wire         ctr_overflow
);

    // Internal registers
    reg [95:0]  iv_upper_reg;    // Upper 96 bits of IV (fixed)
    reg [31:0]  iv_lower_reg;    // Lower 32 bits of IV (initial counter)
    reg [31:0]  counter_reg;     // Running counter
    reg         iv_loaded_reg;

    // Thresholds
    localparam CTR_WARN_THRESHOLD = 32'hFFFFF000;
    localparam CTR_MAX            = 32'hFFFFFFFF;


    // IV loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iv_upper_reg  <= 96'd0;
            iv_lower_reg  <= 32'd0;
            counter_reg   <= 32'd0;
            iv_loaded_reg <= 1'b0;
        end else begin
            if (iv_load && !iv_locked_in && !iv_loaded_reg) begin
                // Store upper 96 bits fixed
                iv_upper_reg  <= iv_in[127:32];
                // Store lower 32 bits as initial counter value
                iv_lower_reg  <= iv_in[31:0];
                // Counter starts at IV lower 32 bits
                counter_reg   <= iv_in[31:0];
                iv_loaded_reg <= 1'b1;
            end
        end
    end

    // Counter block generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctr_block_out   <= 128'd0;
            ctr_block_valid <= 1'b0;
        end else begin
            ctr_block_valid <= 1'b0;

            if (enable && block_advance && iv_loaded_reg) begin
                // Output current counter block
                ctr_block_out   <= {iv_upper_reg, counter_reg};
                ctr_block_valid <= 1'b1;

                // Increment counter if not at max
                if (counter_reg != CTR_MAX) begin
                    counter_reg <= counter_reg+1;
                end
                // At max: counter stays, overflow flag asserted
            end
        end
    end

    // Status outputs
    assign ctr_value          = counter_reg;
    assign ctr_exhausted_warn = (counter_reg >= CTR_WARN_THRESHOLD);
    assign ctr_overflow       = (counter_reg == CTR_MAX &&
                                 block_advance           &&
                                 enable);

endmodule