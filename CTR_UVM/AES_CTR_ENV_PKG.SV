//=============================================================================
// AES_CTR_ENV_PKG.sv
// Environment: agent + scoreboard + coverage, all config-driven
// =============================================================================
`ifndef AES_CTR_ENV_PKG_SV
`define AES_CTR_ENV_PKG_SV

package AES_CTR_ENV_PKG;


import uvm_pkg::*;
`include "uvm_macros.svh"
import AES_CTR_SEQ_ITEM_PKG::*;
import AES_CTR_CFG_PKG::*;
import AES_CTR_AGENT_PKG::*;
import AES_CTR_SCOREBOARD_PKG::*;
import AES_CTR_COVERAGE_PKG::*;

class AES_CTR_ENV extends uvm_env;

    `uvm_component_utils(AES_CTR_ENV)

    // Sub-components
    AES_CTR_AGENT       agent;
    AES_CTR_SCOREBOARD  scoreboard;
    AES_CTR_COVERAGE    coverage;

    // Configuration
    AES_CTR_ENV_CONFIG  cfg;

    function new(string name = "AES_CTR_ENV", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ---------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get environment configuration
        if (!uvm_config_db#(AES_CTR_ENV_CONFIG)::get(this, "", "env_cfg", cfg))
            `uvm_fatal(get_type_name(), "env_cfg not found in config_db")

        // Distribute configs downward
        uvm_config_db#(AES_CTR_ENV_CONFIG)::set(this, "*", "env_cfg", cfg);
        uvm_config_db#(AES_CTR_AGENT_CONFIG)::set(this, "agent",
                                                  "agent_cfg", cfg.agent_cfg);

        // Build sub-components per config knobs
        agent = AES_CTR_AGENT::type_id::create("agent", this);

        if (cfg.has_scoreboard)
            scoreboard = AES_CTR_SCOREBOARD::type_id::create("scoreboard", this);

        if (cfg.has_coverage)
            coverage = AES_CTR_COVERAGE::type_id::create("coverage", this);
    endfunction

    // ---------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Agent -> Scoreboard
        if (cfg.has_scoreboard) begin
            agent.ap_req.connect(scoreboard.imp_req);
            agent.ap_rsp.connect(scoreboard.imp_rsp);
        end

        // Agent -> Coverage
        if (cfg.has_coverage) begin
            agent.ap_req.connect(coverage.imp_req);
            agent.ap_rsp.connect(coverage.imp_rsp);
        end
    endfunction

    // ---------------------------------------------------------------------
    function void end_of_elaboration_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf({"\n",
            "================ ENVIRONMENT CONFIGURATION =================\n",
            "  Agent mode         : %s\n",
            "  Scoreboard         : %s\n",
            "  Coverage           : %s\n",
            "  Pipeline latency   : %0d cycles\n",
            "  Avalanche mode     : %s\n",
            "============================================================"},
            (cfg.agent_cfg.is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE",
            cfg.has_scoreboard ? "ENABLED" : "DISABLED",
            cfg.has_coverage   ? "ENABLED" : "DISABLED",
            cfg.pipeline_latency,
            cfg.avalanche_mode ? "ON" : "OFF"), UVM_LOW)
    endfunction

endclass : AES_CTR_ENV
endpackage : AES_CTR_ENV_PKG

`endif // AES_CTR_ENV_PKG_SV