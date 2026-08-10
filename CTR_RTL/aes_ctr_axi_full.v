// =============================================================================
// aes_ctr_axi_full.v
// AXI4-Lite + AXI4-Stream wrapper for AES-128 CTR core
// FINAL VERSION fixes:
//   1. Mid-operation register gating (prevents IV/Key change mid-stream)
//   2. Deadlock-free backpressure (drains AXI-Stream on security error)
//   3. Parameterized pipeline latency (matches delay line depth)
//   4. GCM ports removed from core instantiation
// =============================================================================

module aes_ctr_axi_full #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 5,
    parameter C_AXIS_DATA_WIDTH  = 128,
    parameter PIPELINE_LATENCY   = 8    // Must match aes_ctr_delay_line depth
)(
    // Clock and Reset
    input  wire                               aclk,
    input  wire                               aresetn,

    // AXI4-Lite Slave (Control/Status)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  wire [2:0]                         s_axi_awprot,
    input  wire                               s_axi_awvalid,
    output wire                               s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]      s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]  s_axi_wstrb,
    input  wire                               s_axi_wvalid,
    output wire                               s_axi_wready,
    output wire [1:0]                         s_axi_bresp,
    output wire                               s_axi_bvalid,
    input  wire                               s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]      s_axi_araddr,
    input  wire [2:0]                         s_axi_arprot,
    input  wire                               s_axi_arvalid,
    output wire                               s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1:0]      s_axi_rdata,
    output wire [1:0]                         s_axi_rresp,
    output wire                               s_axi_rvalid,
    input  wire                               s_axi_rready,

    // AXI4-Stream KEY Input
    input  wire [C_AXIS_DATA_WIDTH-1:0]       s_axis_key_tdata,
    input  wire                               s_axis_key_tvalid,
    output wire                               s_axis_key_tready,

    // AXI4-Stream IV Input
    input  wire [C_AXIS_DATA_WIDTH-1:0]       s_axis_iv_tdata,
    input  wire                               s_axis_iv_tvalid,
    output wire                               s_axis_iv_tready,

    // AXI4-Stream DATA Input
    input  wire [C_AXIS_DATA_WIDTH-1:0]       s_axis_data_tdata,
    input  wire                               s_axis_data_tvalid,
    input  wire                               s_axis_data_tlast,
    output wire                               s_axis_data_tready,

    // AXI4-Stream DATA Output
    output wire [C_AXIS_DATA_WIDTH-1:0]       m_axis_data_tdata,
    output wire                               m_axis_data_tvalid,
    output wire                               m_axis_data_tlast,
    input  wire                               m_axis_data_tready,

    // Interrupt
    output wire                               irq
);

    // =========================================================================
    // Byte Swap Function (AXI-Stream = LSB first, AES core = MSB first)
    // =========================================================================
    function [127:0] swap_endian;
        input [127:0] data_in;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                swap_endian[(15-i)*8 +: 8] = data_in[i*8 +: 8];
        end
    endfunction

    // =========================================================================
    // Control and Status Wires
    // =========================================================================
    wire ctrl_key_start;
    wire ctrl_iv_load;
    wire ctrl_mode;
    wire ctrl_error_clear;
    wire ctrl_soft_reset;

    wire stat_keys_ready;
    wire stat_iv_valid;
    wire stat_security_error;
    wire stat_require_reset;
    wire [3:0] stat_error_code;
    wire stat_key_loaded;
    wire stat_iv_loaded;
    wire stat_busy;

    // =========================================================================
    // Soft Reset Generator (32-cycle pulse on soft reset command)
    // =========================================================================
    reg [4:0] soft_rst_count;
    wire      aes_core_rstn;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            soft_rst_count <= 5'd0;
        else if (ctrl_soft_reset)
            soft_rst_count <= 5'd31;
        else if (soft_rst_count > 0)
            soft_rst_count <= soft_rst_count - 1;
    end

    assign aes_core_rstn = aresetn & (soft_rst_count == 0);

    // =========================================================================
    // AXI-Lite Register File
    // =========================================================================
    aes_ctr_axi_lite_regs #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_regs (
        .s_axi_aclk         (aclk),
        .s_axi_aresetn      (aresetn),
        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awprot       (s_axi_awprot),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),
        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),
        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bready       (s_axi_bready),
        .s_axi_araddr       (s_axi_araddr),
        .s_axi_arprot       (s_axi_arprot),
        .s_axi_arvalid      (s_axi_arvalid),
        .s_axi_arready      (s_axi_arready),
        .s_axi_rdata        (s_axi_rdata),
        .s_axi_rresp        (s_axi_rresp),
        .s_axi_rvalid       (s_axi_rvalid),
        .s_axi_rready       (s_axi_rready),
        .ctrl_key_start     (ctrl_key_start),
        .ctrl_iv_load       (ctrl_iv_load),
        .ctrl_mode          (ctrl_mode),
        .ctrl_error_clear   (ctrl_error_clear),
        .ctrl_soft_reset    (ctrl_soft_reset),
        .stat_keys_ready    (stat_keys_ready),
        .stat_iv_valid      (stat_iv_valid),
        .stat_security_error(stat_security_error),
        .stat_require_reset (stat_require_reset),
        .stat_error_code    (stat_error_code),
        .stat_key_loaded    (stat_key_loaded),
        .stat_iv_loaded     (stat_iv_loaded),
        .stat_busy          (stat_busy)
    );

    // =========================================================================
    // Pipeline Active Tracking (FIX 1: Register Gating)
    // Prevents key/IV changes while data is in the pipeline
    // =========================================================================
    reg [15:0] valid_shift;
    wire       fifo_empty;
    wire       pipeline_active = (valid_shift != 16'd0);
    wire       core_is_busy    = pipeline_active || !fifo_empty;

    assign stat_busy = core_is_busy;

    // =========================================================================
    // KEY Capture from AXI-Stream
    // Only accept new key when NOT busy processing data
    // =========================================================================
    reg  [127:0] key_reg;
    reg          key_loaded_reg;

    assign s_axis_key_tready = !key_loaded_reg && !core_is_busy;
    assign stat_key_loaded   = key_loaded_reg;

    wire key_xfer = s_axis_key_tvalid && s_axis_key_tready;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            key_reg        <= 128'd0;
            key_loaded_reg <= 1'b0;
        end else begin
            if (ctrl_soft_reset)
                key_loaded_reg <= 1'b0;
            else if (key_xfer) begin
                key_reg        <= swap_endian(s_axis_key_tdata);
                key_loaded_reg <= 1'b1;
            end
        end
    end

    // =========================================================================
    // IV Capture from AXI-Stream
    // Only accept new IV when NOT busy processing data
    // =========================================================================
    reg  [127:0] iv_reg;
    reg          iv_loaded_reg;
    reg          iv_load_pulse;

    assign s_axis_iv_tready = stat_keys_ready && !core_is_busy;
    assign stat_iv_loaded   = iv_loaded_reg;

    wire iv_xfer = s_axis_iv_tvalid && s_axis_iv_tready;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            iv_reg        <= 128'd0;
            iv_loaded_reg <= 1'b0;
            iv_load_pulse <= 1'b0;
        end else begin
            iv_load_pulse <= 1'b0;
            if (ctrl_soft_reset)
                iv_loaded_reg <= 1'b0;
            else if (iv_xfer) begin
                iv_reg        <= swap_endian(s_axis_iv_tdata);
                iv_loaded_reg <= 1'b1;
                iv_load_pulse <= 1'b1;
            end
        end
    end

    wire iv_load_to_core = iv_load_pulse || ctrl_iv_load;

    // =========================================================================
    // DATA Stream Input
    // FIX 2: Deadlock-Free Backpressure
    // On security error: keep tready HIGH to drain/sink incoming data
    // so the AXI DMA and Linux OS do not hang forever
    // =========================================================================
    wire fifo_full;

    wire normal_accept = stat_iv_valid      &&
                         !stat_security_error &&
                         !stat_require_reset  &&
                         !fifo_full;

    // Error drain: sink data harmlessly so upstream DMA does not deadlock
    wire error_drain = stat_security_error || stat_require_reset;

    assign s_axis_data_tready = normal_accept || error_drain;

    // Only pass valid data to AES core during normal_accept
    wire data_xfer = s_axis_data_tvalid && normal_accept;

    wire [127:0] data_in_swapped = swap_endian(s_axis_data_tdata);

    // =========================================================================
    // TLAST Pipeline Tracking
    // =========================================================================
    reg [15:0] tlast_shift;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            tlast_shift <= 16'd0;
            valid_shift <= 16'd0;
        end else begin
            tlast_shift <= {tlast_shift[14:0],
                            (data_xfer ? s_axis_data_tlast : 1'b0)};
            valid_shift <= {valid_shift[14:0], data_xfer};
        end
    end

    // =========================================================================
    // AES-CTR Core Instantiation
    // Uses aes_core_rstn so soft_reset physically resets the pipeline
    // =========================================================================
    wire [127:0] core_data_out;
    wire         core_valid_out;

    aes_ctr_top u_aes_core (
        .clk               (aclk),
        .rst_n             (aes_core_rstn),
        .key_start         (ctrl_key_start),
        .master_key        (key_reg),
        .keys_ready        (stat_keys_ready),
        .iv_in             (iv_reg),
        .iv_load           (iv_load_to_core),
        .mode              (ctrl_mode),
        .data_in           (data_in_swapped),
        .valid_in          (data_xfer),
        .error_clear       (ctrl_error_clear),
        .iv_valid          (stat_iv_valid),
        .security_error    (stat_security_error),
        .error_code        (stat_error_code),
        .require_full_reset(stat_require_reset),
        .data_out          (core_data_out),
        .valid_out         (core_valid_out)
    );

    wire [127:0] core_data_out_swapped = swap_endian(core_data_out);

    // FIX 3: Dynamic TLAST tap based on PIPELINE_LATENCY parameter
    wire core_tlast_out = tlast_shift[PIPELINE_LATENCY-1];

    // =========================================================================
    // Output FIFO (Decouples core from downstream backpressure)
    // =========================================================================
    wire [4:0]   fifo_count;
    wire [128:0] fifo_data_out;

    wire fifo_wr = core_valid_out;
    wire fifo_rd = m_axis_data_tvalid && m_axis_data_tready;

    output_fifo_129x16 u_out_fifo (
        .clk     (aclk),
        .rst_n   (aes_core_rstn),
        .wr_en   (fifo_wr),
        .data_in ({core_tlast_out, core_data_out_swapped}),
        .rd_en   (fifo_rd),
        .data_out(fifo_data_out),
        .full    (fifo_full),
        .empty   (fifo_empty),
        .count   (fifo_count)
    );

    assign m_axis_data_tdata  = fifo_data_out[127:0];
    assign m_axis_data_tlast  = fifo_data_out[128];
    assign m_axis_data_tvalid = !fifo_empty;

    // =========================================================================
    // Interrupt (assert on critical security errors)
    // =========================================================================
    assign irq = stat_security_error || stat_require_reset;

endmodule