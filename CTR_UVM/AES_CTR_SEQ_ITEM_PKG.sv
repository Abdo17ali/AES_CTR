// =============================================================================
// AES_CTR_SEQ_ITEM_PKG.sv
// Transaction definition for AES-128 CTR verification
// =============================================================================
`ifndef AES_CTR_SEQ_ITEM_PKG_SV
`define AES_CTR_SEQ_ITEM_PKG_SV

package AES_CTR_SEQ_ITEM_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------------------------
    // Operation types the driver understands
    // -------------------------------------------------------------------------
    typedef enum {
        OP_RESET,           // Pulse rst_n (needed between avalanche trials!)
        OP_KEY_LOAD,        // key_start + master_key, wait for keys_ready
        OP_IV_LOAD,         // iv_load + iv_in (one pulse)
        OP_DATA,            // valid_in + data_in (one block)
        OP_ERROR_CLEAR,     // error_clear pulse
        OP_IDLE             // idle_cycles of nothing
    } op_type_e;

    // Data pattern knob for constrained-random + corner generation
    typedef enum {
        PAT_RANDOM,
        PAT_ALL_ZERO,
        PAT_ALL_ONES,
        PAT_WALKING_ONE,
        PAT_NIST            // value supplied directly by sequence (no rand)
    } pattern_e;

    // =========================================================================
    // AES_CTR_SEQ_ITEM
    // =========================================================================
    class AES_CTR_SEQ_ITEM extends uvm_sequence_item;

        // ------------------ Randomized request fields -----------------------
        rand op_type_e       op_type;
         bit [127:0]     master_key;
        rand bit [127:0]     iv;
        rand bit [127:0]     data;
        rand bit             mode;          // kept stable per stream by sequences
        rand int unsigned    idle_cycles;   // gap before driving this item
        rand pattern_e       pattern;

        // ------------------ Response fields (filled by monitor) -------------
        bit [127:0]          data_out;
        bit                  valid_out;
        bit                  keys_ready;
        bit                  iv_valid;
        bit                  security_error;
        bit [3:0]            error_code;
        bit                  require_full_reset;

        // ------------------ Constraints --------------------------------------
        constraint c_idle {
            idle_cycles inside {[0:10]};
            // Weight toward back-to-back (0 gap) - pipeline stress
            idle_cycles dist { 0 := 50, [1:3] := 30, [4:10] := 20 };
        }

        constraint c_pattern_data {
            solve pattern before data;
            (pattern == PAT_ALL_ZERO)  -> data == 128'h0;
            (pattern == PAT_ALL_ONES)  -> data == {128{1'b1}};
            (pattern == PAT_WALKING_ONE) -> $countones(data) == 1;
        }

        constraint c_pattern_dist {
            pattern dist { PAT_RANDOM      := 70,
                           PAT_ALL_ZERO    := 10,
                           PAT_ALL_ONES    := 10,
                           PAT_WALKING_ONE := 10 };
        }

        // ------------------ UVM automation -----------------------------------
        `uvm_object_utils_begin(AES_CTR_SEQ_ITEM)
            `uvm_field_enum(op_type_e, op_type,      UVM_ALL_ON)
            `uvm_field_int (master_key,              UVM_ALL_ON)
            `uvm_field_int (iv,                      UVM_ALL_ON)
            `uvm_field_int (data,                    UVM_ALL_ON)
            `uvm_field_int (mode,                    UVM_ALL_ON)
            `uvm_field_int (idle_cycles,             UVM_ALL_ON | UVM_DEC)
            `uvm_field_enum(pattern_e, pattern,      UVM_ALL_ON)
            `uvm_field_int (data_out,                UVM_ALL_ON)
            `uvm_field_int (valid_out,               UVM_ALL_ON)
            `uvm_field_int (security_error,          UVM_ALL_ON)
            `uvm_field_int (error_code,              UVM_ALL_ON)
            `uvm_field_int (require_full_reset,      UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "AES_CTR_SEQ_ITEM");
            super.new(name);
        endfunction

        // ------------------ Pretty print --------------------------------------
        virtual function string convert2string();
            return $sformatf("op=%s key=%032h iv=%032h data=%032h mode=%0b idle=%0d | out=%032h err=%0b code=%0h",
                              op_type.name(), master_key, iv, data, mode,
                              idle_cycles, data_out, security_error, error_code);
        endfunction

    endclass : AES_CTR_SEQ_ITEM

endpackage : AES_CTR_SEQ_ITEM_PKG

`endif // AES_CTR_SEQ_ITEM_PKG_SV