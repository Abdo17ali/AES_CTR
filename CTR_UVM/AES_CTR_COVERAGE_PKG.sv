// =============================================================================
// AES_CTR_COVERAGE_PKG.sv
// Functional coverage collector
// Includes Advanced Cross-Coverage (Security Faults x Data Payloads)
// =============================================================================
`ifndef AES_CTR_COVERAGE_PKG_SV
`define AES_CTR_COVERAGE_PKG_SV

package AES_CTR_COVERAGE_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;

    `uvm_analysis_imp_decl(_cov_req)
    `uvm_analysis_imp_decl(_cov_rsp)

    class AES_CTR_COVERAGE extends uvm_component;

        `uvm_component_utils(AES_CTR_COVERAGE)

        uvm_analysis_imp_cov_req #(AES_CTR_SEQ_ITEM, AES_CTR_COVERAGE) imp_req;
        uvm_analysis_imp_cov_rsp #(AES_CTR_SEQ_ITEM, AES_CTR_COVERAGE) imp_rsp;

        // Sampled classification variables
        typedef enum bit [1:0] {V_ZERO, V_ONES, V_WALK1, V_RAND} val_class_e;

        val_class_e  key_cls,  iv_cls,  data_cls;
        bit [31:0]   ctr_start;
        bit          mode_s;
        bit          sec_err_s;
        bit [3:0]    err_code_s;
        bit          crit_s;
        op_type_e    op_s;

        // ----------------- Base Covergroups ----------------------------------
        covergroup CG_KEY;
            option.per_instance = 1;
            CP_KEY: coverpoint key_cls {
                bins all_zero  = {V_ZERO};
                bins all_ones  = {V_ONES};
                bins random_k  = {V_RAND, V_WALK1};
            }
        endgroup

        covergroup CG_IV;
            option.per_instance = 1;
            CP_CTR_START: coverpoint ctr_start {
                bins low        = {[32'h0000_0000 : 32'h0000_FFFF]};
                bins mid        = {[32'h0001_0000 : 32'hFFFE_FFFF]};
                bins near_warn  = {[32'hFFFF_0000 : 32'hFFFF_EFFF]};
                bins warn_zone  = {[32'hFFFF_F000 : 32'hFFFF_FFFE]};
                bins at_max     = {32'hFFFF_FFFF};
            }
        endgroup

        covergroup CG_DATA;
            option.per_instance = 1;
            CP_DATA: coverpoint data_cls {
                bins all_zero    = {V_ZERO};   
                bins all_ones    = {V_ONES};
                bins walking_one = {V_WALK1};
                bins random_d    = {V_RAND};
            }
            CP_MODE: coverpoint mode_s {
                bins encrypt = {0};
                bins decrypt = {1};
            }
            X_DATA_MODE: cross CP_DATA, CP_MODE;
        endgroup
        covergroup CG_SECURITY;
            option.per_instance = 1;
            CP_ERR: coverpoint err_code_s iff (sec_err_s) {
                bins nonce_reuse    = {4'b0001};
                bins ctr_overflow   = {4'b0010};
                bins keys_not_ready = {4'b0100};
                bins no_nonce       = {4'b0101};
                bins ctr_exhaustion = {4'b0110};
                ignore_bins unreachable = {4'b0011, 4'b0111};
            }
            CP_CRIT: coverpoint crit_s iff (sec_err_s) {
                bins warning_only = {0};
                bins critical     = {1};
            }
            // Cross: Every error code seen as both warning and critical category
            X_ERR_CRIT: cross CP_ERR, CP_CRIT {
                // Only valid combinations
                ignore_bins invalid_warning_nonce  = binsof(CP_ERR.nonce_reuse)    && binsof(CP_CRIT.warning_only);
                ignore_bins invalid_warning_ovfl   = binsof(CP_ERR.ctr_overflow)   && binsof(CP_CRIT.warning_only);
                ignore_bins invalid_critical_keys  = binsof(CP_ERR.keys_not_ready) && binsof(CP_CRIT.critical);
                ignore_bins invalid_critical_nonce = binsof(CP_ERR.no_nonce)       && binsof(CP_CRIT.critical);
                ignore_bins invalid_critical_exh   = binsof(CP_ERR.ctr_exhaustion) && binsof(CP_CRIT.critical);
            }
        endgroup
        
        // ----------------- ADVANCED CROSS-COVERAGE ---------------------------
        covergroup CG_SEC_DATA_CROSS;
            option.per_instance = 1;
            
            CP_DATA_PAYLOAD: coverpoint data_cls {
                bins all_zero    = {V_ZERO};
                bins all_ones    = {V_ONES};
                bins walking_one = {V_WALK1};
                bins random_d    = {V_RAND};
            }
            
            CP_FAULT_TYPE: coverpoint err_code_s {
                bins nonce_reuse    = {4'b0001};
                bins ctr_overflow   = {4'b0010};
                bins keys_not_ready = {4'b0100};
                bins no_nonce       = {4'b0101};
                bins ctr_exhaustion = {4'b0110};
            }
            
            X_SEC_DATA: cross CP_DATA_PAYLOAD, CP_FAULT_TYPE;
        endgroup

        covergroup CG_OPS;
            option.per_instance = 1;
            CP_OP: coverpoint op_s {
                bins rst   = {OP_RESET};
                bins key   = {OP_KEY_LOAD};
                bins iv    = {OP_IV_LOAD};
                bins data  = {OP_DATA};
                bins clr   = {OP_ERROR_CLEAR};
            }
            X_FLOW: cross CP_OP, CP_OP;
            option.cross_num_print_missing = 0;
        endgroup

        // ---------------------------------------------------------------------
        function new(string name = "AES_CTR_COVERAGE", uvm_component parent = null);
            super.new(name, parent);
            imp_req           = new("imp_req", this);
            imp_rsp           = new("imp_rsp", this);
            CG_KEY            = new();
            CG_IV             = new();
            CG_DATA           = new();
            CG_SECURITY       = new();
            CG_OPS            = new();
            CG_SEC_DATA_CROSS = new();
        endfunction

        function val_class_e classify(bit [127:0] v);
            if (v == '0)                 return V_ZERO;
            if (v == '1)                 return V_ONES;
            if ($countones(v) == 1)      return V_WALK1;
            return V_RAND;
        endfunction

        // ---------------------------------------------------------------------
               function void write_cov_req(AES_CTR_SEQ_ITEM tr);
            op_s = tr.op_type;
            CG_OPS.sample();

            // Sample security state
            sec_err_s  = tr.security_error;
            err_code_s = tr.error_code;
            crit_s     = tr.require_full_reset;
            
            // Only sample CG_SECURITY when an error is actually active
            if (tr.security_error) begin
                CG_SECURITY.sample();
            end

            case (tr.op_type)
                OP_KEY_LOAD: begin
                    key_cls = classify(tr.master_key);
                    CG_KEY.sample();
                end
                OP_IV_LOAD: begin
                    iv_cls    = classify(tr.iv);
                    ctr_start = tr.iv[31:0];
                    CG_IV.sample();
                end
                OP_DATA: begin
                    data_cls = classify(tr.data);
                    mode_s   = tr.mode;
                    CG_DATA.sample();
                    
                    // Sample cross when error is active AND data is being sent
                    if (sec_err_s) begin
                        CG_SEC_DATA_CROSS.sample();
                    end
                end
                default: ;
            endcase
        endfunction

        function void write_cov_rsp(AES_CTR_SEQ_ITEM tr);
            // Intentional: Blocked outputs don't arrive here, 
            // so we sample everything in write_cov_req instead.
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info(get_type_name(), $sformatf({"\n",
                "==================== COVERAGE SUMMARY ======================\n",
                "  CG_KEY            : %0.2f %%\n",
                "  CG_IV             : %0.2f %%\n",
                "  CG_DATA           : %0.2f %%\n",
                "  CG_SECURITY       : %0.2f %%\n",
                "  CG_SEC_DATA_CROSS : %0.2f %%  <-- Advanced Metric\n",
                "  CG_OPS            : %0.2f %%\n",
                "============================================================"},
                CG_KEY.get_inst_coverage(),  CG_IV.get_inst_coverage(),
                CG_DATA.get_inst_coverage(), CG_SECURITY.get_inst_coverage(),
                CG_SEC_DATA_CROSS.get_inst_coverage(), CG_OPS.get_inst_coverage()), UVM_LOW)
        endfunction

    endclass : AES_CTR_COVERAGE

endpackage : AES_CTR_COVERAGE_PKG

`endif // AES_CTR_COVERAGE_PKG_SV