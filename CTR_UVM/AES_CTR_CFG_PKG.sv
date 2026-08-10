// =============================================================================
// AES_CTR_CFG_PKG.sv
// Configuration objects for Agent and Environment
// =============================================================================
`ifndef AES_CTR_CFG_PKG_SV 
`define AES_CTR_CFG_PKG_SV

package AES_CTR_CFG_PKG;

import uvm_pkg::*;
`include "uvm_macros.svh"

// =========================================================================
// AGENT CONFIGURATION
// =========================================================================
class AES_CTR_AGENT_CONFIG extends uvm_object;

    // Virtual interface handle (set from TB top via config_db)
    virtual AES_CTR_IF      vif;

    // Active = drives DUT, Passive = monitor only
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Knobs
    bit                     enable_protocol_checks = 1;  // monitor assertions
    int unsigned            key_ready_timeout      = 100; // cycles to wait
    int unsigned            drv_reset_cycles       = 2;

    `uvm_object_utils_begin(AES_CTR_AGENT_CONFIG)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int (enable_protocol_checks,             UVM_ALL_ON)
        `uvm_field_int (key_ready_timeout,                  UVM_ALL_ON | UVM_DEC)
        `uvm_field_int (drv_reset_cycles,                   UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "AES_CTR_AGENT_CONFIG");
        super.new(name);
    endfunction

endclass : AES_CTR_AGENT_CONFIG

// =========================================================================
// ENVIRONMENT CONFIGURATION
// =========================================================================
class AES_CTR_ENV_CONFIG extends uvm_object;

    // Sub-configuration
    AES_CTR_AGENT_CONFIG    agent_cfg;

    // Component enables
    bit                     has_scoreboard = 1;
    bit                     has_coverage   = 1;

    // DUT timing facts (from RTL analysis)
    int unsigned            pipeline_latency = 8;   // valid_in -> valid_out

    // Security monitor constants (mirrored for scoreboard prediction)
    bit [31:0]              ctr_warn_threshold = 32'hFFFF_F000;
    bit [31:0]              ctr_max            = 32'hFFFF_FFFF;

    // Avalanche test reporting (scoreboard accumulates, reports average)
    bit                     avalanche_mode    = 0;   // enables HD tracking
    real                    avalanche_min_pct = 45.0;
    real                    avalanche_max_pct = 55.0;

    `uvm_object_utils_begin(AES_CTR_ENV_CONFIG)
        `uvm_field_object(agent_cfg,          UVM_ALL_ON)
        `uvm_field_int   (has_scoreboard,     UVM_ALL_ON)
        `uvm_field_int   (has_coverage,       UVM_ALL_ON)
        `uvm_field_int   (pipeline_latency,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int   (avalanche_mode,     UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "AES_CTR_ENV_CONFIG");
        super.new(name);
        agent_cfg = AES_CTR_AGENT_CONFIG::type_id::create("agent_cfg");
    endfunction

endclass : AES_CTR_ENV_CONFIG
endpackage : AES_CTR_CFG_PKG

`endif // AES_CTR_CFG_PKG_SV