// =============================================================================
// AES_CTR_TB_TOP.sv
// Testbench top: clock generation, DUT instance, interface binding, run_test
// Simulator : Questa
// =============================================================================
`ifndef AES_CTR_TB_TOP_SV
`define AES_CTR_TB_TOP_SV

`timescale 1ns/1ps

module AES_CTR_TB_TOP;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_TEST_PKG::*;

    // -------------------------------------------------------------------------
    // Clock generation : 100 MHz (10 ns period)
    // -------------------------------------------------------------------------
    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Interface instance
    // -------------------------------------------------------------------------
    AES_CTR_IF vif (.clk(clk));

    // -------------------------------------------------------------------------
    // DUT instance
    // -------------------------------------------------------------------------
    aes_ctr_top u_dut (
        .clk                (clk),
        .rst_n              (vif.rst_n),

        // Key interface
        .key_start          (vif.key_start),
        .master_key         (vif.master_key),
        .keys_ready         (vif.keys_ready),

        // IV interface
        .iv_in              (vif.iv_in),
        .iv_load            (vif.iv_load),

        // Data interface
        .mode               (vif.mode),
        .data_in            (vif.data_in),
        .valid_in           (vif.valid_in),

        // Recovery
        .error_clear        (vif.error_clear),

        // Status outputs
        .iv_valid           (vif.iv_valid),
        .security_error     (vif.security_error),
        .error_code         (vif.error_code),
        .require_full_reset (vif.require_full_reset),

        // Data outputs
        .data_out           (vif.data_out),
        .valid_out          (vif.valid_out)
    );

    initial begin
        // Create required folders using Questa's $system
        void'($system("cmd /c if not exist logs mkdir logs"));
        void'($system("cmd /c if not exist ucdb mkdir ucdb"));
        void'($system("cmd /c if not exist wlf  mkdir wlf"));
    end

    // -------------------------------------------------------------------------
    // Power-on initialization
    // -------------------------------------------------------------------------
    initial begin
        vif.rst_n       = 1'b0;
        vif.key_start   = 1'b0;
        vif.master_key  = '0;
        vif.iv_in       = '0;
        vif.iv_load     = 1'b0;
        vif.mode        = 1'b0;
        vif.data_in     = '0;
        vif.valid_in    = 1'b0;
        vif.error_clear = 1'b0;
        repeat (3) @(posedge clk);
        vif.rst_n       = 1'b1;
    end

    // -------------------------------------------------------------------------
    // UVM bootstrap
    // -------------------------------------------------------------------------
     initial begin
        uvm_config_db#(virtual AES_CTR_IF)::set(null, "*", "vif", vif);
        $wlfdumpvars(); 
        
        // TELL UVM EXACTLY WHICH TEST TO RUN HERE:
        run_test("AES_CTR_MASTER_TEST");     
    end

    // -------------------------------------------------------------------------
    // Global watchdog
    // -------------------------------------------------------------------------
    initial begin
        #50ms;
        `uvm_fatal("WATCHDOG", "Global simulation timeout - test hung!")
    end

endmodule : AES_CTR_TB_TOP

`endif // AES_CTR_TB_TOP_SV