// =============================================================================
// aes_ctr_top.v
// Top-level wrapper for AES-128 CTR mode
// =============================================================================

module aes_ctr_top (
    input  wire         clk,
    input  wire         rst_n,

    // Key interface
    input  wire         key_start,
    input  wire [127:0] master_key,
    output wire         keys_ready,

    // IV interface (full 128-bit NIST format)
    input  wire [127:0] iv_in,
    input  wire         iv_load,

    // Data interface
    input  wire         mode,
    input  wire [127:0] data_in,
    input  wire         valid_in,

    // Recovery interface
    input  wire         error_clear,

    // Status outputs
    output wire         iv_valid,
    output wire         security_error,
    output wire [3:0]   error_code,
    output wire         require_full_reset,

    // Data outputs
    output wire [127:0] data_out,
    output wire         valid_out
);

    // =========================================================================
    // Internal Wires
    // =========================================================================
    wire [127:0] ctr_block;
    wire         ctr_block_valid;
    wire [31:0]  ctr_value;
    wire         ctr_exhausted_warn;
    wire         ctr_overflow;

    wire [127:0] aes_data_out;
    wire         aes_valid_out;

    wire         delay_valid_out;
    wire [127:0] delay_data_out;

    wire         iv_locked;
    wire         halt_operation;
    wire         block_advance;

    // =========================================================================
    // Control Logic (STRICT GATING FIX)
    // =========================================================================
    
    // Strict combinational check: is it legal to accept data THIS EXACT CYCLE?
    wire data_accept = valid_in      && 
                       keys_ready    && 
                       iv_locked     && 
                       !security_error && 
                       !require_full_reset;

    // Use strict gating for advancing the counter
    assign block_advance = data_accept && !halt_operation;

    // =========================================================================
    // AES-128 Core Instantiation
    // =========================================================================
    aes_top u_aes_top (
        .clk        (clk),
        .rst_n      (rst_n),
        .key_start  (key_start),
        .Valid_in   (ctr_block_valid),
        .master_key (master_key),
        .Data_in    (ctr_block),
        .keys_ready (keys_ready),
        .Valid_out  (aes_valid_out),
        .Data_out   (aes_data_out)
    );

    // =========================================================================
    // Counter Block Generator
    // =========================================================================
    aes_ctr_block_gen u_ctr_block_gen (
        .clk              (clk),
        .rst_n            (rst_n),
        .iv_in            (iv_in),
        .iv_load          (iv_load),
        .enable           (!halt_operation),
        .block_advance    (block_advance),
        .iv_locked_in     (iv_locked),
        .ctr_block_out    (ctr_block),
        .ctr_block_valid  (ctr_block_valid),
        .ctr_value        (ctr_value),
        .ctr_exhausted_warn(ctr_exhausted_warn),
        .ctr_overflow     (ctr_overflow)
    );

    // =========================================================================
    // 8-Stage Delay Line (FIXED: Uses strict data_accept)
    // =========================================================================
    aes_ctr_delay_line u_delay_line (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (data_accept),   // <--- THIS PREVENTS THE GHOST BLOCKS
        .data_in  (data_in),
        .valid_out(delay_valid_out),
        .data_out (delay_data_out)
    );

    // =========================================================================
    // XOR Stage
    // =========================================================================
    aes_ctr_xor u_xor (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (aes_valid_out),
        .keystream(aes_data_out),
        .data_in  (delay_data_out),
        .valid_out(valid_out),
        .data_out (data_out)
    );

    // =========================================================================
    // Security Monitor 
    // =========================================================================
    aes_ctr_sec_mon u_sec_mon (
        .clk              (clk),
        .rst_n            (rst_n),
        .nonce_load       (iv_load),
        .nonce_in         (iv_in[127:32]),
        .keys_ready       (keys_ready),
        .valid_in         (valid_in),
        .ctr_exhausted_warn(ctr_exhausted_warn),
        .ctr_overflow     (ctr_overflow),
        .mode             (mode),
        .error_clear      (error_clear),
        .nonce_locked     (iv_locked),
        .nonce_valid      (iv_valid),
        .security_error   (security_error),
        .error_code       (error_code),
        .halt_operation   (halt_operation),
        .require_full_reset(require_full_reset)
    );

endmodule