// =============================================================================
// aes_ctr_sec_mon.v
// Security monitor for AES-128 CTR mode
//
// IV Reuse Detection: Method B - Monotonic Enforcement
// ─────────────────────────────────────────────────────
// Every new IV must be strictly greater than the last
// loaded IV. This catches:
//   - Back-to-back reuse  (IV=A then IV=A)
//   - Rollback attacks    (IV=100 then IV=099)
//   - Replay attacks      (IV=100 then IV=050)
//
// Known limitation:
//   Protection is within a single power session only.
//   State is lost on reset. Cross-session reuse prevention
//   requires NVM-backed storage which is outside the scope
//   of this implementation.
//
// Standard reference: RFC 3686 counter discipline
// =============================================================================

module aes_ctr_sec_mon (

    input  wire        clk,
    input  wire        rst_n,

    // Control inputs
    input  wire        nonce_load,
    input  wire [95:0] nonce_in,
    input  wire        keys_ready,
    input  wire        valid_in,
    input  wire        ctr_exhausted_warn,
    input  wire        ctr_overflow,
    input  wire        mode,

    
    // Recovery
    input  wire        error_clear,

    // Status outputs
    output reg         nonce_locked,
    output reg         nonce_valid,
    output reg         security_error,
    output reg  [3:0]  error_code,
    output reg         halt_operation,
    output wire        require_full_reset
);

// =============================================================================
// Error Codes
// =============================================================================
localparam ERR_NONE           = 4'b0000;
localparam ERR_NONCE_REUSE    = 4'b0001;
localparam ERR_CTR_OVERFLOW   = 4'b0010;
localparam ERR_RESET_ATTACK   = 4'b0011;
localparam ERR_KEYS_NOT_READY = 4'b0100;
localparam ERR_NO_NONCE       = 4'b0101;
localparam ERR_CTR_EXHAUSTION = 4'b0110;

// =============================================================================
// Internal Registers
// =============================================================================

// ── Method B: Monotonic IV tracking ──────────────────────────────────────────
reg [95:0] last_iv_reg;
reg        last_iv_valid;

// ── Existing state ────────────────────────────────────────────────────────────
reg        reset_detected;
reg        first_reset_done;
reg        nonce_was_loaded;

// =============================================================================
// Method B: Monotonic IV Violation Detection
// =============================================================================
wire iv_monotonic_violation = nonce_load    &&
                              last_iv_valid &&
                              (nonce_in <= last_iv_reg);

// =============================================================================
// Critical Error Classification
// =============================================================================
assign require_full_reset = security_error &&
                            (error_code == ERR_NONCE_REUSE  ||
                             error_code == ERR_CTR_OVERFLOW ||
                             error_code == ERR_RESET_ATTACK ||
                             error_code == ERR_AUTH_FAIL);

// =============================================================================
// Reset Attack Detection
// =============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reset_detected   <= 1'b1;
        first_reset_done <= 1'b0;
    end else begin
        reset_detected   <= 1'b0;
        first_reset_done <= 1'b1;
    end
end

// =============================================================================
// Main Security Monitor
// =============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin

        nonce_locked     <= 1'b0;
        nonce_valid      <= 1'b0;
        security_error   <= 1'b0;
        error_code       <= ERR_NONE;
        halt_operation   <= 1'b0;
        nonce_was_loaded <= 1'b0;

        // Method B reset
        last_iv_reg      <= 96'd0;
        last_iv_valid    <= 1'b0;

    end else begin

        if (security_error) begin

            if (require_full_reset) begin
                halt_operation <= 1'b1;

            end else begin
                if (error_clear) begin
                    security_error <= 1'b0;
                    error_code     <= ERR_NONE;
                    halt_operation <= 1'b0;
                end else begin
                    halt_operation <= 1'b1;
                end
            end

        end else begin

            halt_operation <= 1'b0;

            // Priority 1: Method B monotonic violation
            if (iv_monotonic_violation) begin
                security_error <= 1'b1;
                error_code     <= ERR_NONCE_REUSE;
                halt_operation <= 1'b1;

            end

            // Priority 2: Counter overflow
            else if (ctr_overflow) begin
                security_error <= 1'b1;
                error_code     <= ERR_CTR_OVERFLOW;
                halt_operation <= 1'b1;

            end

          
            end

            // Priority 3: Reset attack
            else if (reset_detected    &&
                     valid_in          &&
                     !nonce_was_loaded &&
                     first_reset_done) begin
                security_error <= 1'b1;
                error_code     <= ERR_RESET_ATTACK;
                halt_operation <= 1'b1;

            end

            // Priority 4: Operation before keys ready
            else if (valid_in && !keys_ready) begin
                security_error <= 1'b1;
                error_code     <= ERR_KEYS_NOT_READY;
                halt_operation <= 1'b1;

            end

            // Priority 5: Operation before nonce loaded
            else if (valid_in && keys_ready && !nonce_locked) begin
                security_error <= 1'b1;
                error_code     <= ERR_NO_NONCE;
                halt_operation <= 1'b1;

            end

            // Priority 6: Counter exhaustion warning
            else if (ctr_exhausted_warn && valid_in) begin
                security_error <= 1'b1;
                error_code     <= ERR_CTR_EXHAUSTION;
                halt_operation <= 1'b1;

            end

            // Normal valid IV load
            else if (nonce_load && !nonce_locked) begin
                nonce_locked     <= 1'b1;
                nonce_valid      <= 1'b1;
                nonce_was_loaded <= 1'b1;

                // Method B: update monotonic reference
                last_iv_reg      <= nonce_in;
                last_iv_valid    <= 1'b1;

            end

        end
    end
end

endmodule