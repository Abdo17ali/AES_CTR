// =============================================================================
// AES_CTR_SCOREBOARD_PKG.sv
// =============================================================================
`ifndef AES_CTR_SCOREBOARD_PKG_SV
`define AES_CTR_SCOREBOARD_PKG_SV

package AES_CTR_SCOREBOARD_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;
    import AES_CTR_CFG_PKG::*;
    import AES_CTR_REF_MODEL_PKG::*;

    `uvm_analysis_imp_decl(_req)
    `uvm_analysis_imp_decl(_rsp)

    class AES_CTR_SCOREBOARD extends uvm_scoreboard;

        `uvm_component_utils(AES_CTR_SCOREBOARD)

        uvm_analysis_imp_req #(AES_CTR_SEQ_ITEM, AES_CTR_SCOREBOARD) imp_req;
        uvm_analysis_imp_rsp #(AES_CTR_SEQ_ITEM, AES_CTR_SCOREBOARD) imp_rsp;

        AES_CTR_ENV_CONFIG cfg;

        // Mirrored DUT state
        bit [127:0]  key_m;
        bit          iv_locked_m;
        bit [95:0]   iv_upper_m;
        bit [31:0]   ctr_m;
        bit          sec_err_m;
        bit [3:0]    err_code_m;
        bit          crit_m;

        // Expected output queue
        bit [127:0]  exp_q [$];
        bit          lat_polluted;

        // Detail tracking
        bit [127:0]  last_data_in;
        bit [127:0]  last_keystream;
        bit [31:0]   last_ctr_used;
        bit          ks_seen [bit [127:0]];

        // Statistics
        int unsigned n_pass, n_fail, n_blocked, n_outputs, n_lat_checked, n_err_code_pass, n_err_code_fail;

        // Avalanche engine
        bit [127:0]  av_baseline;
        bit          av_have_baseline;
        int unsigned av_hd_q [$];

        function new(string name = "AES_CTR_SCOREBOARD", uvm_component parent = null);
            super.new(name, parent);
            imp_req = new("imp_req", this);
            imp_rsp = new("imp_rsp", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(AES_CTR_ENV_CONFIG)::get(this, "", "env_cfg", cfg))
                `uvm_fatal(get_type_name(), "env_cfg not found")
            reset_mirror();
        endfunction

        // ---------------------------------------------------------------------
        // FIX: Start background thread
        // ---------------------------------------------------------------------
        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            fork
                scoreboard_security_flush();
            join_none
        endtask

              // ---------------------------------------------------------------------
        // FIX: Scoreboard Queue Flush
        // ---------------------------------------------------------------------
        virtual task scoreboard_security_flush();
            virtual AES_CTR_IF vif;
            if (!uvm_config_db#(virtual AES_CTR_IF)::get(this, "", "vif", vif))
                `uvm_fatal(get_type_name(), "vif not found for scoreboard flush")

            forever begin
                // ONLY flush on hard reset!
                @(negedge vif.rst_n);
                
                if (exp_q.size() > 0) begin
                    `uvm_info(get_type_name(), "Hard Reset: Flushing Expected Queue", UVM_HIGH)
                    exp_q.delete();
                    lat_polluted = 0; 
                end
            end
        endtask

        function void reset_mirror();
            iv_locked_m      = 0;
            iv_upper_m       = '0;
            ctr_m            = '0;
            sec_err_m        = 0;
            err_code_m       = 4'b0000;
            crit_m           = 0;
            lat_polluted     = 0;
            last_data_in     = '0;
            last_keystream   = '0;
            last_ctr_used    = '0;
            if (exp_q.size() > 0)
                `uvm_warning(get_type_name(), $sformatf("Reset with %0d in-flight blocks (flushed)", exp_q.size()))
            exp_q.delete();
            ks_seen.delete();
        endfunction

        function void write_req(AES_CTR_SEQ_ITEM tr);
            case (tr.op_type)
                OP_RESET: reset_mirror();
                OP_KEY_LOAD: key_m = tr.master_key;
                OP_IV_LOAD: begin
                    if (!iv_locked_m && !sec_err_m) begin
                        iv_locked_m = 1;
                        iv_upper_m  = tr.iv[127:32];
                        ctr_m       = tr.iv[31:0];
                    end else if (iv_locked_m && !sec_err_m && tr.iv[127:32] != iv_upper_m) begin
                        sec_err_m  = 1;
                        err_code_m = 4'b0001;
                        crit_m     = 1;
                    end
                end
                OP_ERROR_CLEAR: begin
                    if (sec_err_m && !crit_m) begin
                        sec_err_m  = 0;
                        err_code_m = 4'b0000;
                    end
                end
                OP_DATA: process_data_in(tr);
                default: ;
            endcase
        endfunction

        function void process_data_in(AES_CTR_SEQ_ITEM tr);
            bit accept = tr.keys_ready && iv_locked_m && !tr.security_error;

            if (accept) begin
                bit [127:0] ks = ctr_keystream(key_m, iv_upper_m, ctr_m);
                bit [127:0] exp = ks ^ tr.data;

                last_data_in   = tr.data;
                last_keystream = ks;
                last_ctr_used  = ctr_m;

                exp_q.push_back(exp);

                if (ks_seen.exists(ks))
                    `uvm_error(get_type_name(), $sformatf("SECURITY S10: duplicate keystream! ctr=%08h", ctr_m))
                else
                    ks_seen[ks] = 1;

                if (ctr_m == cfg.ctr_max) begin
                    sec_err_m  = 1;
                    err_code_m = 4'b0010;
                    crit_m     = 1;       
                end else begin
                    if (ctr_m >= cfg.ctr_warn_threshold && !sec_err_m) begin
                        sec_err_m  = 1;
                        err_code_m = 4'b0110; 
                    end
                    ctr_m = ctr_m + 32'd1;
                end
            end else begin
                n_blocked++;
                lat_polluted = 1;

                if (!sec_err_m) begin
                    if (!tr.keys_ready) begin
                        sec_err_m  = 1;
                        err_code_m = 4'b0100;
                    end else if (!iv_locked_m) begin
                        sec_err_m  = 1;
                        err_code_m = 4'b0101;
                    end
                end
            end
        endfunction

        function void write_rsp(AES_CTR_SEQ_ITEM tr);
            bit [127:0] exp;
            n_outputs++;

            if (exp_q.size() == 0) begin
                `uvm_error(get_type_name(), $sformatf("UNEXPECTED data_out=%032h", tr.data_out))
                n_fail++;
                return;
            end

            exp = exp_q.pop_front();

            if (tr.data_out === exp) begin
                n_pass++;
                print_match(tr, exp);
            end else begin
                n_fail++;
                print_mismatch(tr, exp);
            end

            if (!lat_polluted) begin
                n_lat_checked++;
                if (tr.idle_cycles != cfg.pipeline_latency)
                    `uvm_error(get_type_name(), $sformatf("LATENCY violation: measured=%0d expected=%0d", tr.idle_cycles, cfg.pipeline_latency))
            end

            if (tr.security_error) begin
                if (tr.error_code === err_code_m) n_err_code_pass++;
                else begin
                    n_err_code_fail++;
                    `uvm_error(get_type_name(), $sformatf("ERROR_CODE mismatch: DUT=%04b predicted=%04b", tr.error_code, err_code_m))
                end
            end

            if (cfg.avalanche_mode) begin
                if (!av_have_baseline) begin
                    av_baseline      = tr.data_out;
                    av_have_baseline = 1;
                end else
                    av_hd_q.push_back($countones(tr.data_out ^ av_baseline));
            end
        endfunction

        // ---------------------------------------------------------------------
        // PRINTING & LOGGING
        // ---------------------------------------------------------------------
        function void print_match(AES_CTR_SEQ_ITEM tr, bit [127:0] exp);
            string mode_str = tr.mode ? "DECRYPT" : "ENCRYPT";
            string latency_str = !lat_polluted ? $sformatf("%0d cycles", tr.idle_cycles) : "N/A (blocked txn in flight)";
            string msg = "\n";
            msg = {msg, "+----------------------------------------------------------+\n"};
            msg = {msg, $sformatf("| TRANSACTION  %-10s  #%-5d  @%-15t|\n", mode_str, n_outputs, $time)};
            msg = {msg, "+----------------------------------------------------------+\n"};
            msg = {msg, "  Result   : *** PASS ***                                \n"};
            msg = {msg, "+----------------------------------------------------------+"};
            `uvm_info(get_type_name(), msg, UVM_HIGH)
            write_txn_file(n_outputs, mode_str, exp, tr.data_out, latency_str, 0);
        endfunction

        function void print_mismatch(AES_CTR_SEQ_ITEM tr, bit [127:0] exp);
            string mode_str = tr.mode ? "DECRYPT" : "ENCRYPT";
            string msg = "\n";
            msg = {msg, "+----------------------------------------------------------+\n"};
            msg = {msg, $sformatf("| *** MISMATCH ***  %-10s  #%-5d  @%-12t|\n", mode_str, n_outputs, $time)};
            msg = {msg, "+----------------------------------------------------------+\n"};
            msg = {msg, $sformatf("|   EXPECTED : %032h  |\n", exp)};
            msg = {msg, $sformatf("|   DUT OUT  : %032h  |\n", tr.data_out)};
            msg = {msg, "+----------------------------------------------------------+"};
            `uvm_error(get_type_name(), msg)
            write_txn_file(n_outputs, mode_str, exp, tr.data_out, "MISMATCH", 1);
        endfunction

        function void write_txn_file(int unsigned txn_num, string mode_str, bit [127:0] exp, bit [127:0] dut_out, string latency_str, bit is_fail);
            int unsigned fd = $fopen("logs/transaction_log.txt", "a");
            if (fd) begin
                $fdisplay(fd, "TRANSACTION #%0d  MODE=%s  TIME=%0t", txn_num, mode_str, $time);
                $fdisplay(fd, "EXPECTED   : %032h", exp);
                $fdisplay(fd, "DUT_OUTPUT : %032h", dut_out);
                if (is_fail) $fdisplay(fd, "XOR_DIFF   : %032h", exp ^ dut_out);
                $fdisplay(fd, "RESULT     : %s", is_fail ? "FAIL" : "PASS");
                $fclose(fd);
            end
        endfunction

        function void write_csv(string line);
            int unsigned fd = $fopen("logs/regression_data.csv", "a");
            if (fd) begin
                $fdisplay(fd, "%s", line);
                $fclose(fd);
            end
        endfunction

        function void report_phase(uvm_phase phase);
            string result_str = (n_fail == 0) ? "PASS" : "FAIL";
            string test_name  = uvm_top.get_child("uvm_test_top").get_type_name();
            string msg = "\n";
            
            msg = {msg, "+------------------------------------------------------+\n"};
            msg = {msg, $sformatf("| SCOREBOARD SUMMARY : %-31s|\n", test_name)};
            msg = {msg, "+------------------------------------------------------+\n"};
            msg = {msg, $sformatf("| Result            : %-32s|\n", result_str)};
            msg = {msg, $sformatf("| Outputs observed  : %-32d|\n", n_outputs)};
            msg = {msg, $sformatf("| Data MATCHES      : %-32d|\n", n_pass)};
            msg = {msg, $sformatf("| Data MISMATCHES   : %-32d|\n", n_fail)};
            msg = {msg, "+------------------------------------------------------+"};
            `uvm_info(get_type_name(), msg, UVM_LOW)

            if (cfg.avalanche_mode) report_avalanche();

            write_csv($sformatf("%s|%s|%0d|%0d|%0d|%0d|%0d", test_name, result_str, n_pass, n_outputs, n_fail, n_blocked, cfg.pipeline_latency));

            if (exp_q.size() > 0)
                `uvm_error(get_type_name(), $sformatf("%0d expected outputs never appeared!", exp_q.size()))
        endfunction

        function void report_avalanche();
            real sum = 0.0, avg, pct;
            int unsigned mn = 128, mx = 0;
            string result_str, test_name, msg;

            if (av_hd_q.size() == 0) return;
            foreach (av_hd_q[i]) begin
                sum += av_hd_q[i];
                if (av_hd_q[i] < mn) mn = av_hd_q[i];
                if (av_hd_q[i] > mx) mx = av_hd_q[i];
            end
            avg  = sum / av_hd_q.size();
            pct  = (avg / 128.0) * 100.0;

            result_str = (pct >= cfg.avalanche_min_pct && pct <= cfg.avalanche_max_pct) ? "PASS" : "FAIL";
            test_name  = uvm_top.get_child("uvm_test_top").get_type_name();
            
            msg = "\n";
            msg = {msg, "+------------------------------------------------------+\n"};
            msg = {msg, "|           AVALANCHE EFFECT REPORT                    |\n"};
            msg = {msg, "+------------------------------------------------------+\n"};
            msg = {msg, $sformatf("| AVERAGE AVALANCHE : %-27.2f %%  |\n", pct)};
            msg = {msg, $sformatf("| RESULT            : %-32s|\n", result_str)};
            msg = {msg, "+------------------------------------------------------+"};
            `uvm_info(get_type_name(), msg, UVM_LOW)

            if (pct < cfg.avalanche_min_pct || pct > cfg.avalanche_max_pct)
                `uvm_error(get_type_name(), "AVALANCHE FAIL")
        endfunction

    endclass : AES_CTR_SCOREBOARD

endpackage : AES_CTR_SCOREBOARD_PKG

`endif // AES_CTR_SCOREBOARD_PKG_SV