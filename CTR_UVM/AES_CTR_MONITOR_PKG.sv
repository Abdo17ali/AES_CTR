// =============================================================================
// AES_CTR_MONITOR_PKG.sv
// =============================================================================
`ifndef AES_CTR_MONITOR_PKG_SV
`define AES_CTR_MONITOR_PKG_SV

package AES_CTR_MONITOR_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;
    import AES_CTR_CFG_PKG::*;

    class AES_CTR_MONITOR extends uvm_monitor;

        `uvm_component_utils(AES_CTR_MONITOR)

        virtual AES_CTR_IF      vif;
        AES_CTR_AGENT_CONFIG    cfg;

        uvm_analysis_port #(AES_CTR_SEQ_ITEM) ap_req;   
        uvm_analysis_port #(AES_CTR_SEQ_ITEM) ap_rsp;   

        longint unsigned cycle_cnt;
        longint unsigned in_stamp_q[$];

        function new(string name = "AES_CTR_MONITOR", uvm_component parent = null);
            super.new(name, parent);
            ap_req = new("ap_req", this);
            ap_rsp = new("ap_rsp", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(AES_CTR_AGENT_CONFIG)::get(this, "", "agent_cfg", cfg))
                `uvm_fatal(get_type_name(), "agent_cfg not found")
            if (cfg.vif == null)
                `uvm_fatal(get_type_name(), "vif is null")
            vif = cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
            cycle_cnt = 0;
            
            // Start the background flush thread
            fork
                monitor_security_flush();
            join_none

            forever begin
                @(vif.mon_cb);
                cycle_cnt++;

                if (vif.mon_cb.rst_n === 1'b0) begin
                    publish_reset();
                    while (vif.mon_cb.rst_n === 1'b0) begin
                        @(vif.mon_cb);
                        cycle_cnt++;
                    end
                    continue;
                end

                if (vif.mon_cb.key_start === 1'b1)   publish_key_load();
                if (vif.mon_cb.iv_load === 1'b1)     publish_iv_load();
                if (vif.mon_cb.valid_in === 1'b1)    publish_data_in();
                if (vif.mon_cb.error_clear === 1'b1) publish_error_clear();
                if (vif.mon_cb.valid_out === 1'b1)   publish_data_out();

                if (cfg.enable_protocol_checks) protocol_checks();
            end
        endtask

               // ---------------------------------------------------------------------
        // FIX: Active Queue Flushing on Security Events
        // ---------------------------------------------------------------------
        virtual task monitor_security_flush();
            forever begin
                // ONLY flush on hard reset! error_clear does not wipe the physical pipeline.
                @(negedge vif.rst_n);
                
                if (in_stamp_q.size() > 0) begin
                    `uvm_info(get_type_name(), "Hard Reset: Flushing Latency Queue to prevent desync", UVM_HIGH)
                    in_stamp_q.delete();
                end
                // @(posedge vif.clk); <-- You can delete this line too
            end
        endtask

        // ---------------- Publishers ----------------
        function void publish_reset();
            AES_CTR_SEQ_ITEM tr = AES_CTR_SEQ_ITEM::type_id::create("mon_rst");
            tr.op_type = OP_RESET;
            in_stamp_q.delete();
            ap_req.write(tr);
        endfunction

        function void publish_key_load();
            AES_CTR_SEQ_ITEM tr = AES_CTR_SEQ_ITEM::type_id::create("mon_key");
            tr.op_type    = OP_KEY_LOAD;
            tr.master_key = vif.mon_cb.master_key;
            ap_req.write(tr);
        endfunction

        function void publish_iv_load();
            AES_CTR_SEQ_ITEM tr = AES_CTR_SEQ_ITEM::type_id::create("mon_iv");
            tr.op_type = OP_IV_LOAD;
            tr.iv      = vif.mon_cb.iv_in;
            ap_req.write(tr);
        endfunction

                function void publish_data_in();
            AES_CTR_SEQ_ITEM tr = AES_CTR_SEQ_ITEM::type_id::create("mon_din");
            tr.op_type            = OP_DATA;
            tr.data               = vif.mon_cb.data_in;
            tr.mode               = vif.mon_cb.mode;
            tr.keys_ready         = vif.mon_cb.keys_ready;
            tr.iv_valid           = vif.mon_cb.iv_valid;
            tr.security_error     = vif.mon_cb.security_error;
            tr.error_code         = vif.mon_cb.error_code;
            tr.require_full_reset = vif.mon_cb.require_full_reset;
            in_stamp_q.push_back(cycle_cnt);
            ap_req.write(tr);
        endfunction

        function void publish_error_clear();
            AES_CTR_SEQ_ITEM tr = AES_CTR_SEQ_ITEM::type_id::create("mon_clr");
            tr.op_type = OP_ERROR_CLEAR;
            ap_req.write(tr);
        endfunction

        function void publish_data_out();
            AES_CTR_SEQ_ITEM tr = AES_CTR_SEQ_ITEM::type_id::create("mon_dout");
            tr.op_type            = OP_DATA;
            tr.valid_out          = 1'b1;
            tr.data_out           = vif.mon_cb.data_out;
            tr.security_error     = vif.mon_cb.security_error;
            tr.error_code         = vif.mon_cb.error_code;
            tr.require_full_reset = vif.mon_cb.require_full_reset;
            tr.keys_ready         = vif.mon_cb.keys_ready;
            tr.iv_valid           = vif.mon_cb.iv_valid;

            if (in_stamp_q.size() > 0)
                tr.idle_cycles = int'(cycle_cnt - in_stamp_q.pop_front());
            else
                tr.idle_cycles = 0; 

            ap_rsp.write(tr);
        endfunction

        function void protocol_checks();
            if ($isunknown(vif.mon_cb.valid_out)) `uvm_error(get_type_name(), "valid_out is X/Z")
            if ($isunknown(vif.mon_cb.keys_ready)) `uvm_error(get_type_name(), "keys_ready is X/Z")
            if (vif.mon_cb.valid_out === 1'b1 && $isunknown(vif.mon_cb.data_out))
                `uvm_error(get_type_name(), "data_out has X/Z while valid_out=1")
        endfunction

    endclass : AES_CTR_MONITOR

endpackage : AES_CTR_MONITOR_PKG

`endif // AES_CTR_MONITOR_PKG_SV