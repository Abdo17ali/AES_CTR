// =============================================================================
// aes_ctr_top_apb.v
// APB3 wrapper for aes_ctr_top
// =============================================================================

module aes_ctr_top_apb #(
    parameter integer APB_ADDR_WIDTH = 8
)(
    input  wire                      PCLK,
    input  wire                      PRESETn,

    input  wire [APB_ADDR_WIDTH-1:0] PADDR,
    input  wire                      PSEL,
    input  wire                      PENABLE,
    input  wire                      PWRITE,
    input  wire [31:0]               PWDATA,

    output reg  [31:0]               PRDATA,
    output wire                      PREADY,
    output reg                       PSLVERR
);

    // =========================================================================
    // APB decode
    // =========================================================================
    wire apb_write = PSEL && PENABLE &&  PWRITE;
    wire apb_read  = PSEL && PENABLE && !PWRITE;

    // Zero wait-state slave
    assign PREADY = 1'b1;

    // =========================================================================
    // Register Map (Byte Addresses)
    // =========================================================================
    localparam ADDR_CTRL  = 8'h00; // RW  [0]=mode
    localparam ADDR_CMD   = 8'h04; // WO  pulse bits
    localparam ADDR_STATUS= 8'h08; // RO  status bits

    localparam ADDR_KEY0  = 8'h0C; // RW  key[31:0]
    localparam ADDR_KEY1  = 8'h10; // RW  key[63:32]
    localparam ADDR_KEY2  = 8'h14; // RW  key[95:64]
    localparam ADDR_KEY3  = 8'h18; // RW  key[127:96]

    localparam ADDR_IV0   = 8'h1C; // RW  iv[31:0]
    localparam ADDR_IV1   = 8'h20; // RW  iv[63:32]
    localparam ADDR_IV2   = 8'h24; // RW  iv[95:64]
    localparam ADDR_IV3   = 8'h28; // RW  iv[127:96]

    localparam ADDR_DIN0  = 8'h2C; // RW  data_in[31:0]
    localparam ADDR_DIN1  = 8'h30; // RW  data_in[63:32]
    localparam ADDR_DIN2  = 8'h34; // RW  data_in[95:64]
    localparam ADDR_DIN3  = 8'h38; // RW  data_in[127:96]

    localparam ADDR_DOUT0 = 8'h3C; // RO  data_out[31:0]
    localparam ADDR_DOUT1 = 8'h40; // RO  data_out[63:32]
    localparam ADDR_DOUT2 = 8'h44; // RO  data_out[95:64]
    localparam ADDR_DOUT3 = 8'h48; // RO  data_out[127:96]

    // =========================================================================
    // Software-visible registers
    // =========================================================================
    reg         mode_reg;
    reg [127:0] master_key_reg;
    reg [127:0] iv_reg;
    reg [127:0] data_in_reg;

    // Output latch
    reg [127:0] data_out_reg;
    reg         data_out_valid_reg;

    // In-flight tracking
    reg         data_inflight_reg;

    // Pulse signals to core
    reg         key_start_pulse;
    reg         iv_load_pulse;
    reg         valid_in_pulse;
    reg         error_clear_pulse;

    // =========================================================================
    // Core status signals
    // =========================================================================
    wire         keys_ready;
    wire         iv_valid;
    wire         security_error;
    wire [3:0]   error_code;
    wire         require_full_reset;
    wire [127:0] data_out;
    wire         valid_out;

    // =========================================================================
    // Gate: only allow new block when conditions fully met
    // =========================================================================
    wire data_can_start = keys_ready        &&
                          iv_valid          &&
                          !security_error   &&
                          !require_full_reset &&
                          !data_inflight_reg  &&
                          !data_out_valid_reg;

    // =========================================================================
    // Core instantiation
    // =========================================================================
    aes_ctr_top u_aes_ctr_top (
        .clk               (PCLK),
        .rst_n             (PRESETn),
        .key_start         (key_start_pulse),
        .master_key        (master_key_reg),
        .keys_ready        (keys_ready),
        .iv_in             (iv_reg),
        .iv_load           (iv_load_pulse),
        .mode              (mode_reg),
        .data_in           (data_in_reg),
        .valid_in          (valid_in_pulse),
        .error_clear       (error_clear_pulse),
        .iv_valid          (iv_valid),
        .security_error    (security_error),
        .error_code        (error_code),
        .require_full_reset(require_full_reset),
        .data_out          (data_out),
        .valid_out         (valid_out)
    );

    // =========================================================================
    // Write path and pulse generation
    // =========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            mode_reg           <= 1'b0;
            master_key_reg     <= 128'd0;
            iv_reg             <= 128'd0;
            data_in_reg        <= 128'd0;
            data_out_reg       <= 128'd0;
            data_out_valid_reg <= 1'b0;
            data_inflight_reg  <= 1'b0;
            key_start_pulse    <= 1'b0;
            iv_load_pulse      <= 1'b0;
            valid_in_pulse     <= 1'b0;
            error_clear_pulse  <= 1'b0;
        end else begin
            // Default: deassert all pulses every cycle
            key_start_pulse   <= 1'b0;
            iv_load_pulse     <= 1'b0;
            valid_in_pulse    <= 1'b0;
            error_clear_pulse <= 1'b0;

            // Latch output when core produces valid data
            if (valid_out) begin
                data_out_reg       <= data_out;
                data_out_valid_reg <= 1'b1;
                data_inflight_reg  <= 1'b0;
            end

            // APB write handling
            if (apb_write) begin
                case (PADDR)
                    ADDR_CTRL: begin
                        mode_reg <= PWDATA[0];
                    end

                    ADDR_CMD: begin
                        // bit[0] = key_start   (Write-1-Pulse)
                        if (PWDATA[0]) key_start_pulse <= 1'b1;

                        // bit[1] = iv_load     (Write-1-Pulse)
                        if (PWDATA[1]) iv_load_pulse <= 1'b1;

                        // bit[2] = data_start  (Write-1-Pulse, gated)
                        if (PWDATA[2] && data_can_start) begin
                            valid_in_pulse    <= 1'b1;
                            data_inflight_reg <= 1'b1;
                        end

                        // bit[3] = error_clear (Write-1-Pulse)
                        if (PWDATA[3]) error_clear_pulse <= 1'b1;

                        // bit[5] = clear output latch
                        if (PWDATA[5]) data_out_valid_reg <= 1'b0;
                    end

                    ADDR_KEY0: master_key_reg[31:0]   <= PWDATA;
                    ADDR_KEY1: master_key_reg[63:32]  <= PWDATA;
                    ADDR_KEY2: master_key_reg[95:64]  <= PWDATA;
                    ADDR_KEY3: master_key_reg[127:96] <= PWDATA;

                    ADDR_IV0:  iv_reg[31:0]           <= PWDATA;
                    ADDR_IV1:  iv_reg[63:32]          <= PWDATA;
                    ADDR_IV2:  iv_reg[95:64]          <= PWDATA;
                    ADDR_IV3:  iv_reg[127:96]         <= PWDATA;

                    ADDR_DIN0: data_in_reg[31:0]      <= PWDATA;
                    ADDR_DIN1: data_in_reg[63:32]     <= PWDATA;
                    ADDR_DIN2: data_in_reg[95:64]     <= PWDATA;
                    ADDR_DIN3: data_in_reg[127:96]    <= PWDATA;

                    default: ; // Ignore unknown addresses
                endcase
            end
        end
    end

    // =========================================================================
    // Read path
    // =========================================================================
    always @(*) begin
        PRDATA = 32'd0;
        case (PADDR)
            ADDR_CTRL: PRDATA[0] = mode_reg;

            ADDR_STATUS: begin
                // bit[0]    = keys_ready
                // bit[1]    = iv_valid
                // bit[2]    = security_error
                // bit[3]    = require_full_reset
                // bit[4]    = data_out_valid (latched)
                // bit[5]    = data_inflight
                // bit[11:8] = error_code
                // bit[12]   = data_can_start
                PRDATA[0]    = keys_ready;
                PRDATA[1]    = iv_valid;
                PRDATA[2]    = security_error;
                PRDATA[3]    = require_full_reset;
                PRDATA[4]    = data_out_valid_reg;
                PRDATA[5]    = data_inflight_reg;
                PRDATA[11:8] = error_code;
                PRDATA[12]   = data_can_start;
            end

            ADDR_KEY0:  PRDATA = master_key_reg[31:0];
            ADDR_KEY1:  PRDATA = master_key_reg[63:32];
            ADDR_KEY2:  PRDATA = master_key_reg[95:64];
            ADDR_KEY3:  PRDATA = master_key_reg[127:96];

            ADDR_IV0:   PRDATA = iv_reg[31:0];
            ADDR_IV1:   PRDATA = iv_reg[63:32];
            ADDR_IV2:   PRDATA = iv_reg[95:64];
            ADDR_IV3:   PRDATA = iv_reg[127:96];

            ADDR_DIN0:  PRDATA = data_in_reg[31:0];
            ADDR_DIN1:  PRDATA = data_in_reg[63:32];
            ADDR_DIN2:  PRDATA = data_in_reg[95:64];
            ADDR_DIN3:  PRDATA = data_in_reg[127:96];

            ADDR_DOUT0: PRDATA = data_out_reg[31:0];
            ADDR_DOUT1: PRDATA = data_out_reg[63:32];
            ADDR_DOUT2: PRDATA = data_out_reg[95:64];
            ADDR_DOUT3: PRDATA = data_out_reg[127:96];

            default:    PRDATA = 32'd0;
        endcase
    end

    // =========================================================================
    // Error response (PSLVERR)
    // =========================================================================
    always @(*) begin
        PSLVERR = 1'b0;
        if (PSEL && PENABLE) begin
            // Invalid address
            case (PADDR)
                ADDR_CTRL,  ADDR_CMD,   ADDR_STATUS,
                ADDR_KEY0,  ADDR_KEY1,  ADDR_KEY2,  ADDR_KEY3,
                ADDR_IV0,   ADDR_IV1,   ADDR_IV2,   ADDR_IV3,
                ADDR_DIN0,  ADDR_DIN1,  ADDR_DIN2,  ADDR_DIN3,
                ADDR_DOUT0, ADDR_DOUT1, ADDR_DOUT2, ADDR_DOUT3:
                    PSLVERR = 1'b0;
                default:
                    PSLVERR = 1'b1;
            endcase

            // Write to read-only registers
            if (PWRITE) begin
                case (PADDR)
                    ADDR_STATUS,
                    ADDR_DOUT0, ADDR_DOUT1, ADDR_DOUT2, ADDR_DOUT3:
                        PSLVERR = 1'b1;
                    ADDR_CMD: begin
                        // Error if SW tries to start when not ready
                        if (PWDATA[2] && !data_can_start)
                            PSLVERR = 1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule