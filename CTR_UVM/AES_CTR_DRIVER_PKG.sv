// =============================================================================
// AES_CTR_DRIVER_PKG.sv
// op_type-aware driver: translates sequence items into pin wiggles
// All driving through drv_cb clocking block (race-free, Questa-safe)
// =============================================================================
`ifndef AES_CTR_DRIVER_PKG_SV
`define AES_CTR_DRIVER_PKG_SV

package AES_CTR_DRIVER_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;
    import AES_CTR_CFG_PKG::*;

    class AES_CTR_DRIVER extends uvm_driver #(AES_CTR_SEQ_ITEM);

        `uvm_component_utils(AES_CTR_DRIVER)

        virtual AES_CTR_IF      vif;
        AES_CTR_AGENT_CONFIG    cfg;

        function new(string name = "AES_CTR_DRIVER", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        // ---------------------------------------------------------------------
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(AES_CTR_AGENT_CONFIG)::get(this, "", "agent_cfg", cfg))
                `uvm_fatal(get_type_name(), "agent_cfg not found in config_db")
            if (cfg.vif == null)
                `uvm_fatal(get_type_name(), "Virtual interface is null in agent_cfg")
            vif = cfg.vif;
        endfunction

        // ---------------------------------------------------------------------
        task run_phase(uvm_phase phase);
            AES_CTR_SEQ_ITEM req;

            init_signals();

            forever begin
                seq_item_port.get_next_item(req);
                `uvm_info(get_type_name(),
                          $sformatf("Driving: %s", req.convert2string()), UVM_HIGH)

                // Optional pre-item gap (used by OP_DATA / OP_IDLE)
                if (req.op_type inside {OP_DATA, OP_IDLE})
                    repeat (req.idle_cycles) @(vif.drv_cb);

                case (req.op_type)
                    OP_RESET       : drive_reset();
                    OP_KEY_LOAD    : drive_key_load(req);
                    OP_IV_LOAD     : drive_iv_load(req);
                    OP_DATA        : drive_data(req);
                    OP_ERROR_CLEAR : drive_error_clear();
                    OP_IDLE        : ;  // gap already consumed above
                    default        : `uvm_error(get_type_name(), "Unknown op_type")
                endcase

                seq_item_port.item_done();
            end
        endtask

        // ---------------------------------------------------------------------
        // Drive all inputs to safe idle values
        // ---------------------------------------------------------------------
        task init_signals();
            vif.rst_n            <= 1'b1;
            vif.drv_cb.key_start <= 1'b0;
            vif.drv_cb.master_key<= '0;
            vif.drv_cb.iv_in     <= '0;
            vif.drv_cb.iv_load   <= 1'b0;
            vif.drv_cb.mode      <= 1'b0;
            vif.drv_cb.data_in   <= '0;
            vif.drv_cb.valid_in  <= 1'b0;
            vif.drv_cb.error_clear <= 1'b0;
          
        endtask

        // ---------------------------------------------------------------------
        // OP_RESET: async assert, sync deassert, then re-idle all inputs
        // ---------------------------------------------------------------------
        task drive_reset();
            init_signals();
            vif.do_reset(cfg.drv_reset_cycles);
            init_signals();
        endtask

        // ---------------------------------------------------------------------
        // OP_KEY_LOAD: 1-cycle key_start pulse, then BLOCK until keys_ready
        // (with timeout protection from agent config)
      
// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
// OP_KEY_LOAD: pulse key_start, then wait for keys_ready using DIRECT signal
// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
// OP_KEY_LOAD: pulse key_start, then wait for keys_ready using DIRECT signal
// ---------------------------------------------------------------------
        // ---------------------------------------------------------------------
        // OP_KEY_LOAD: pulse key_start, then wait for keys_ready 
        // ---------------------------------------------------------------------
               // ---------------------------------------------------------------------
        // OP_KEY_LOAD: pulse key_start, then wait for keys_ready
        // ---------------------------------------------------------------------
        task drive_key_load(AES_CTR_SEQ_ITEM req);
            int unsigned t = 0;

            // Drive key
            vif.drv_cb.master_key <= req.master_key;
            @(vif.drv_cb);

            // Pulse key_start
            vif.drv_cb.key_start <= 1'b1;
            @(vif.drv_cb);
            vif.drv_cb.key_start <= 1'b0;

            // Wait for RTL to acknowledge key_start by dropping keys_ready
            // Escape immediately if security error fires (hardware deadlock prevention)
            while (vif.drv_cb.keys_ready === 1'b1) begin
                if (vif.drv_cb.security_error === 1'b1) begin
                    `uvm_info(get_type_name(),
                        "Security error detected during key drop wait. Aborting key load.",
                        UVM_MEDIUM)
                    return;
                end
                @(vif.drv_cb);
            end

            `uvm_info(get_type_name(), "keys_ready dropped. Waiting for expansion to finish...", UVM_MEDIUM);

            // Now wait for expansion to finish
            while (vif.drv_cb.keys_ready !== 1'b1) begin
                @(vif.drv_cb);
                t++;

                // Escape if security error fires mid-expansion
                if (vif.drv_cb.security_error === 1'b1) begin
                    `uvm_info(get_type_name(),
                        "Security error detected during key expansion. Aborting.",
                        UVM_MEDIUM)
                    return;
                end

                if (t >= cfg.key_ready_timeout) begin
                    `uvm_error(get_type_name(),
                        $sformatf("keys_ready TIMEOUT after %0d cycles", t));
                    return;
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("keys_ready asserted after %0d cycles", t), UVM_MEDIUM);
        endtask
        // ---------------------------------------------------------------------
        // OP_IV_LOAD: 1-cycle iv_load pulse
        // ---------------------------------------------------------------------
        task drive_iv_load(AES_CTR_SEQ_ITEM req);
            vif.drv_cb.iv_in   <= req.iv;
            vif.drv_cb.iv_load <= 1'b1;
            @(vif.drv_cb);  
            vif.drv_cb.iv_load <= 1'b0;
            @(vif.drv_cb);   // allow lock/sec_mon state to settle
        endtask

        // ---------------------------------------------------------------------
        // OP_DATA: 1-cycle valid_in pulse with data + mode
        // Back-to-back achieved by idle_cycles=0 on consecutive items
        // ---------------------------------------------------------------------
        task drive_data(AES_CTR_SEQ_ITEM req);
            vif.drv_cb.data_in  <= req.data;
            vif.drv_cb.mode     <= req.mode;
            vif.drv_cb.valid_in <= 1'b1;
            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b0;
        endtask

        // ---------------------------------------------------------------------
        // OP_ERROR_CLEAR: 1-cycle pulse + settle cycle
        // ---------------------------------------------------------------------
        task drive_error_clear();
            vif.drv_cb.error_clear <= 1'b1;
            @(vif.drv_cb);
            vif.drv_cb.error_clear <= 1'b0;
            @(vif.drv_cb);
        endtask

    endclass : AES_CTR_DRIVER

endpackage : AES_CTR_DRIVER_PKG

`endif // AES_CTR_DRIVER_PKG_SV