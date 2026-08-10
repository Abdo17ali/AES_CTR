
`ifndef AES_CTR_AGENT_PKG_SV

`define AES_CTR_AGENT_PKG_SV


package AES_CTR_AGENT_PKG;

import uvm_pkg::*;
`include "uvm_macros.svh"
import AES_CTR_SEQ_ITEM_PKG::*;
import AES_CTR_CFG_PKG::*;
import AES_CTR_SEQUENCER_PKG::*;
import AES_CTR_DRIVER_PKG::*;
import AES_CTR_MONITOR_PKG::*;

class AES_CTR_AGENT extends uvm_agent;

    `uvm_component_utils(AES_CTR_AGENT)

    // Sub-components
    AES_CTR_SEQUENCER    sequencer;
    AES_CTR_DRIVER       driver;
    AES_CTR_MONITOR      monitor;

    // Configuration
    AES_CTR_AGENT_CONFIG cfg;

    // Pass-through analysis ports (env connects to these, not to monitor
    // internals - standard encapsulation practice)
    uvm_analysis_port #(AES_CTR_SEQ_ITEM) ap_req;
    uvm_analysis_port #(AES_CTR_SEQ_ITEM) ap_rsp;

    function new(string name = "AES_CTR_AGENT", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ---------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get agent configuration
        if (!uvm_config_db#(AES_CTR_AGENT_CONFIG)::get(this, "", "agent_cfg", cfg))
            `uvm_fatal(get_type_name(), "agent_cfg not found in config_db")

        // Make cfg visible to children with one set (hierarchical scope "*")
        uvm_config_db#(AES_CTR_AGENT_CONFIG)::set(this, "*", "agent_cfg", cfg);

        // Monitor: ALWAYS built (active and passive agents both observe)
        monitor = AES_CTR_MONITOR::type_id::create("monitor", this);

        // Driver + Sequencer: ACTIVE only
        if (cfg.is_active == UVM_ACTIVE) begin
            sequencer = AES_CTR_SEQUENCER::type_id::create("sequencer", this);
            driver    = AES_CTR_DRIVER::type_id::create("driver", this);
        end

        ap_req = new("ap_req", this);
        ap_rsp = new("ap_rsp", this);
    endfunction

    // ---------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Export monitor streams through agent boundary
        monitor.ap_req.connect(ap_req);
        monitor.ap_rsp.connect(ap_rsp);

        // Driver <-> Sequencer (active only)
        if (cfg.is_active == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

    // ---------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(),
            $sformatf("Agent mode: %s",
                      (cfg.is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"),
            UVM_LOW)
    endfunction

endclass : AES_CTR_AGENT
endpackage : AES_CTR_AGENT_PKG

`endif // AES_CTR_AGENT_PKG_SV