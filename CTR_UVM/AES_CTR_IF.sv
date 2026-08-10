// =============================================================================
// AES_CTR_IF.sv
// Interface for AES-128 CTR DUT with driver/monitor clocking blocks
// Simulator : Questa
// =============================================================================
`ifndef AES_CTR_IF_SV
`define AES_CTR_IF_SV
`timescale 1ns/1ps

interface AES_CTR_IF (input logic clk);

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    logic         rst_n;

    // Key interface
    logic         key_start;
    logic [127:0] master_key;
    logic         keys_ready;

    // IV interface
    logic [127:0] iv_in;
    logic         iv_load;

    // Data interface
    logic         mode;            // 0 = encrypt, 1 = decrypt (don't-care in DUT)
    logic [127:0] data_in;
    logic         valid_in;

    // Recovery
    logic         error_clear;

    // Status outputs
    logic         iv_valid;
    logic         security_error;
    logic [3:0]   error_code;
    logic         require_full_reset;

    // Data outputs
    logic [127:0] data_out;
    logic         valid_out;

    // -------------------------------------------------------------------------
    // Driver Clocking Block (drives inputs, samples status)
    // -------------------------------------------------------------------------
    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        output  key_start, master_key;
        output  iv_in, iv_load;
        output  mode, data_in, valid_in;
        output  error_clear;
        input   keys_ready, iv_valid;
        input   security_error, error_code, require_full_reset;
    endclocking

    // -------------------------------------------------------------------------
    // Monitor Clocking Block (samples EVERYTHING - inputs and outputs)
    // -------------------------------------------------------------------------
    clocking mon_cb @(posedge clk);
        default input #1step;
        input   rst_n;
        input   key_start, master_key, keys_ready;
        input   iv_in, iv_load, iv_valid;
        input   mode, data_in, valid_in;
        input   error_clear;
        input   security_error, error_code, require_full_reset;
        input   data_out, valid_out;
    endclocking

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport DRV (clocking drv_cb, output rst_n);
    modport MON (clocking mon_cb, input rst_n);

    // -------------------------------------------------------------------------
    // Reset task (callable from driver) - async assert, sync deassert
    // -------------------------------------------------------------------------
    task automatic do_reset(input int unsigned cycles = 2);
        rst_n <= 1'b0;
        repeat (cycles) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

endinterface : AES_CTR_IF

`endif // AES_CTR_IF_SV