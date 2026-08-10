// =============================================================================
// AES_CTR_TEST_PKG.sv
// All tests: P0 (NIST SP 800-38A), P1 (Control), P2 (Security),
//            Avalanche (KEY/IV + average report), CTR Linearity, P3 (Stress)
// =============================================================================
`ifndef AES_CTR_TEST_PKG_SV
`define AES_CTR_TEST_PKG_SV

package AES_CTR_TEST_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;
    import AES_CTR_CFG_PKG::*;
    import AES_CTR_SEQUENCE_PKG::*;
    import AES_CTR_ENV_PKG::*;

    // =========================================================================
    // BASE TEST - builds env + configs; derived tests override knobs/sequence
    // =========================================================================
    class AES_CTR_BASE_TEST extends uvm_test;

        `uvm_component_utils(AES_CTR_BASE_TEST)

        AES_CTR_ENV         env;
        AES_CTR_ENV_CONFIG  env_cfg;

        function new(string name = "AES_CTR_BASE_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        // ---------------------------------------------------------------------
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            // Create and populate environment configuration
            env_cfg = AES_CTR_ENV_CONFIG::type_id::create("env_cfg");

            // Virtual interface from TB top
            if (!uvm_config_db#(virtual AES_CTR_IF)::get(this, "", "vif",
                                                         env_cfg.agent_cfg.vif))
                `uvm_fatal(get_type_name(), "vif not found in config_db")

            // Hook for derived tests to modify config BEFORE env build
            configure_test();

            uvm_config_db#(AES_CTR_ENV_CONFIG)::set(this, "env", "env_cfg", env_cfg);

            env = AES_CTR_ENV::type_id::create("env", this);
        endfunction

        // Derived tests override this to set knobs (e.g. avalanche_mode)
        virtual function void configure_test();
        endfunction

        // ---------------------------------------------------------------------
        function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction

        // ---------------------------------------------------------------------
        // Common run: derived tests supply the sequence via get_sequence()
        // ---------------------------------------------------------------------
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return null;   // base test runs nothing
        endfunction

        task run_phase(uvm_phase phase);
            uvm_sequence #(AES_CTR_SEQ_ITEM) seq = get_sequence();

            if (seq == null) begin
                `uvm_info(get_type_name(), "Base test: no sequence to run", UVM_LOW)
                return;
            end

            phase.raise_objection(this, "Test sequence running");
            phase.phase_done.set_drain_time(this, 200ns);   // pipeline drain

            seq.start(env.agent.sequencer);

            phase.drop_objection(this, "Test sequence done");
        endtask

        // ---------------------------------------------------------------------
        function void report_phase(uvm_phase phase);
            uvm_report_server svr = uvm_report_server::get_server();
            if (svr.get_severity_count(UVM_FATAL) +
                svr.get_severity_count(UVM_ERROR) == 0)
                `uvm_info(get_type_name(),
                    $sformatf("\n*** TEST %s : PASSED ***\n", get_type_name()), UVM_LOW)
            else
                `uvm_info(get_type_name(),
                    $sformatf("\n*** TEST %s : FAILED ***\n", get_type_name()), UVM_LOW)
        endfunction

    endclass : AES_CTR_BASE_TEST

    // =========================================================================
    // P0.1 - NIST SP 800-38A F.5.1 Encrypt
    // =========================================================================
    class AES_CTR_NIST_ENC_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_NIST_ENC_TEST)
        function new(string name = "AES_CTR_NIST_ENC_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_NIST_F51_ENC_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P0.2 - NIST SP 800-38A F.5.2 Decrypt
    // =========================================================================
    class AES_CTR_NIST_DEC_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_NIST_DEC_TEST)
        function new(string name = "AES_CTR_NIST_DEC_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_NIST_F52_DEC_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P0.3 - NIST Roundtrip
    // =========================================================================
    class AES_CTR_NIST_ROUNDTRIP_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_NIST_ROUNDTRIP_TEST)
        function new(string name = "AES_CTR_NIST_ROUNDTRIP_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_NIST_ROUNDTRIP_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P1.1 - Key Control
    // =========================================================================
    class AES_CTR_KEY_CTRL_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_KEY_CTRL_TEST)
        function new(string name = "AES_CTR_KEY_CTRL_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_KEY_CTRL_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P1.2 - IV Control
    // =========================================================================
    class AES_CTR_IV_CTRL_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_IV_CTRL_TEST)
        function new(string name = "AES_CTR_IV_CTRL_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_IV_CTRL_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P1.3 - Data Protocol (latency, back-to-back, gapped)
    // =========================================================================
    class AES_CTR_DATA_PROTOCOL_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_DATA_PROTOCOL_TEST)
        function new(string name = "AES_CTR_DATA_PROTOCOL_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            AES_CTR_DATA_PROTOCOL_SEQ seq;
            seq = AES_CTR_DATA_PROTOCOL_SEQ::type_id::create("seq");
            if (!seq.randomize())
                `uvm_error(get_type_name(), "Sequence randomization failed")
            return seq;
        endfunction
    endclass

    // =========================================================================
    // P2.1 - Security: Nonce Reuse (S1a / S1b / S7)
    // =========================================================================
    class AES_CTR_SEC_NONCE_REUSE_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_SEC_NONCE_REUSE_TEST)
        function new(string name = "AES_CTR_SEC_NONCE_REUSE_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_SEC_NONCE_REUSE_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P2.2 - Security: Counter Exhaustion + Overflow (S2 / S3)
    // =========================================================================
    class AES_CTR_SEC_CTR_EXHAUST_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_SEC_CTR_EXHAUST_TEST)
        function new(string name = "AES_CTR_SEC_CTR_EXHAUST_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_SEC_CTR_EXHAUST_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P2.3 - Security: Halt + Recovery (S4 / S5 / S6 / S9)
    // =========================================================================
    class AES_CTR_SEC_HALT_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_SEC_HALT_TEST)
        function new(string name = "AES_CTR_SEC_HALT_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_SEC_HALT_RECOVERY_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P2.4 - Security: Keystream Uniqueness (S8 / S10)
    // =========================================================================
    class AES_CTR_SEC_KEYSTREAM_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_SEC_KEYSTREAM_TEST)
        function new(string name = "AES_CTR_SEC_KEYSTREAM_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            AES_CTR_SEC_KEYSTREAM_SEQ seq;
            seq = AES_CTR_SEC_KEYSTREAM_SEQ::type_id::create("seq");
            if (!seq.randomize())
                `uvm_error(get_type_name(), "Sequence randomization failed")
            return seq;
        endfunction
    endclass

    // =========================================================================
    // AVALANCHE - KEY : flip each key bit, expect average ~50% output flip
    // Scoreboard prints AVERAGE and enforces 45%-55% window
    // =========================================================================
    class AES_CTR_AVALANCHE_KEY_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_AVALANCHE_KEY_TEST)
        function new(string name = "AES_CTR_AVALANCHE_KEY_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void configure_test();
            env_cfg.avalanche_mode    = 1;
            env_cfg.avalanche_min_pct = 45.0;
            env_cfg.avalanche_max_pct = 55.0;
        endfunction

        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_AVALANCHE_KEY_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // AVALANCHE - IV : flip each IV bit, expect average ~50% output flip
    // =========================================================================
    class AES_CTR_AVALANCHE_IV_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_AVALANCHE_IV_TEST)
        function new(string name = "AES_CTR_AVALANCHE_IV_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void configure_test();
            env_cfg.avalanche_mode    = 1;
            env_cfg.avalanche_min_pct = 45.0;
            env_cfg.avalanche_max_pct = 55.0;
        endfunction

        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_AVALANCHE_IV_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // CTR LINEARITY : flip 1 plaintext bit -> EXACTLY 1 output bit flips
    // Same avalanche engine, reconfigured window: avg HD must be exactly
    // 1/128 = 0.78% (tight window 0.5%-1.1% allows no other outcome)
    // =========================================================================
    class AES_CTR_LINEARITY_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_LINEARITY_TEST)
        function new(string name = "AES_CTR_LINEARITY_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void configure_test();
            env_cfg.avalanche_mode    = 1;
            env_cfg.avalanche_min_pct = 0.5;    // 1 bit = 0.78125 %
            env_cfg.avalanche_max_pct = 1.1;
        endfunction

        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            return AES_CTR_LINEARITY_SEQ::type_id::create("seq");
        endfunction
    endclass

    // =========================================================================
    // P3 - Random Stress
    // =========================================================================
    class AES_CTR_RANDOM_STRESS_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_RANDOM_STRESS_TEST)
        function new(string name = "AES_CTR_RANDOM_STRESS_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        virtual function uvm_sequence #(AES_CTR_SEQ_ITEM) get_sequence();
            AES_CTR_RANDOM_STRESS_SEQ seq;
            seq = AES_CTR_RANDOM_STRESS_SEQ::type_id::create("seq");
            if (!seq.randomize())
                `uvm_error(get_type_name(), "Sequence randomization failed")
            return seq;
        endfunction
    endclass

    // =========================================================================
    // FULL REGRESSION TEST - Updated with Coverage Closure Sequences
    // =========================================================================
    class AES_CTR_REGRESSION_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_REGRESSION_TEST)
        function new(string name = "AES_CTR_REGRESSION_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            AES_CTR_NIST_F51_ENC_SEQ      s0;
            AES_CTR_NIST_F52_DEC_SEQ      s1;
            AES_CTR_NIST_ROUNDTRIP_SEQ    s2;
            AES_CTR_KEY_CTRL_SEQ          s3;
            AES_CTR_IV_CTRL_SEQ           s4;
            AES_CTR_DATA_PROTOCOL_SEQ     s5;
            AES_CTR_SEC_NONCE_REUSE_SEQ   s6;
            AES_CTR_SEC_CTR_EXHAUST_SEQ   s7;
            AES_CTR_SEC_HALT_RECOVERY_SEQ s8;
            AES_CTR_SEC_KEYSTREAM_SEQ     s9;
            AES_CTR_SEC_COMBO_STRESS_SEQ  s_combo;
            AES_CTR_KEY_BOUNDARY_SEQ      s_key_bound;
            AES_CTR_CROSS_COVERAGE_SEQ    s_cross;
            AES_CTR_RANDOM_STRESS_SEQ     s10;

            phase.raise_objection(this, "Regression running");
            phase.phase_done.set_drain_time(this, 200ns);

            `uvm_info(get_type_name(), ">>> REGRESSION: P0 NIST", UVM_LOW)
            s0 = AES_CTR_NIST_F51_ENC_SEQ::type_id::create("s0"); s0.start(env.agent.sequencer);
            s1 = AES_CTR_NIST_F52_DEC_SEQ::type_id::create("s1"); s1.start(env.agent.sequencer);
            s2 = AES_CTR_NIST_ROUNDTRIP_SEQ::type_id::create("s2"); s2.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> REGRESSION: P1 Control", UVM_LOW)
            s3 = AES_CTR_KEY_CTRL_SEQ::type_id::create("s3"); s3.start(env.agent.sequencer);
            s4 = AES_CTR_IV_CTRL_SEQ::type_id::create("s4"); s4.start(env.agent.sequencer);
            s5 = AES_CTR_DATA_PROTOCOL_SEQ::type_id::create("s5"); void'(s5.randomize()); s5.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> REGRESSION: P2 Security", UVM_LOW)
            s6 = AES_CTR_SEC_NONCE_REUSE_SEQ::type_id::create("s6"); s6.start(env.agent.sequencer);
            s7 = AES_CTR_SEC_CTR_EXHAUST_SEQ::type_id::create("s7"); s7.start(env.agent.sequencer);
            s8 = AES_CTR_SEC_HALT_RECOVERY_SEQ::type_id::create("s8"); s8.start(env.agent.sequencer);
            s9 = AES_CTR_SEC_KEYSTREAM_SEQ::type_id::create("s9"); void'(s9.randomize()); s9.start(env.agent.sequencer);
            
            `uvm_info(get_type_name(), ">>> REGRESSION: P2.5 Combo Stress", UVM_LOW)
            s_combo = AES_CTR_SEC_COMBO_STRESS_SEQ::type_id::create("s_combo");
            s_combo.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> REGRESSION: Coverage Closure (CG_KEY)", UVM_LOW)
            s_key_bound = AES_CTR_KEY_BOUNDARY_SEQ::type_id::create("s_key_bound");
            s_key_bound.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> REGRESSION: Coverage Closure (CG_SEC_DATA_CROSS)", UVM_LOW)
            s_cross = AES_CTR_CROSS_COVERAGE_SEQ::type_id::create("s_cross");
            s_cross.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> REGRESSION: P3 Stress", UVM_LOW)
            s10 = AES_CTR_RANDOM_STRESS_SEQ::type_id::create("s10"); void'(s10.randomize()); s10.start(env.agent.sequencer);

            phase.drop_objection(this, "Regression done");
        endtask
    endclass : AES_CTR_REGRESSION_TEST


    // =========================================================================
    // ULTIMATE MASTER TEST - Runs EVERY sequence in one simulation
    // Includes Avalanche & Linearity (toggles avalanche_mode dynamically)
    // =========================================================================
    class AES_CTR_MASTER_TEST extends AES_CTR_BASE_TEST;
        `uvm_component_utils(AES_CTR_MASTER_TEST)
        function new(string name = "AES_CTR_MASTER_TEST", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            // ── Standard sequences ──
            AES_CTR_NIST_F51_ENC_SEQ      s0;
            AES_CTR_NIST_F52_DEC_SEQ      s1;
            AES_CTR_NIST_ROUNDTRIP_SEQ    s2;
            AES_CTR_KEY_CTRL_SEQ          s3;
            AES_CTR_IV_CTRL_SEQ           s4;
            AES_CTR_DATA_PROTOCOL_SEQ     s5;
            AES_CTR_SEC_NONCE_REUSE_SEQ   s6;
            AES_CTR_SEC_CTR_EXHAUST_SEQ   s7;
            AES_CTR_SEC_HALT_RECOVERY_SEQ s8;
            AES_CTR_SEC_KEYSTREAM_SEQ     s9;
            AES_CTR_SEC_COMBO_STRESS_SEQ  s_combo;
            AES_CTR_KEY_BOUNDARY_SEQ      s_key_bound;
            AES_CTR_CROSS_COVERAGE_SEQ    s_cross;
            AES_CTR_RANDOM_STRESS_SEQ     s10;

            // ── Avalanche sequences ──
            AES_CTR_AVALANCHE_KEY_SEQ     s_av_key;
            AES_CTR_AVALANCHE_IV_SEQ      s_av_iv;
            AES_CTR_LINEARITY_SEQ         s_lin;

            phase.raise_objection(this, "Master test running");
            phase.phase_done.set_drain_time(this, 500ns);

            // =================================================================
            // PHASE 1: Standard Functional Tests (avalanche_mode = OFF)
            // =================================================================
            `uvm_info(get_type_name(), "========================================", UVM_LOW)
            `uvm_info(get_type_name(), "  PHASE 1: FUNCTIONAL VERIFICATION     ", UVM_LOW)
            `uvm_info(get_type_name(), "========================================", UVM_LOW)

            `uvm_info(get_type_name(), ">>> P0: NIST SP 800-38A Vectors", UVM_LOW)
            s0 = AES_CTR_NIST_F51_ENC_SEQ::type_id::create("s0");
            s0.start(env.agent.sequencer);
            s1 = AES_CTR_NIST_F52_DEC_SEQ::type_id::create("s1");
            s1.start(env.agent.sequencer);
            s2 = AES_CTR_NIST_ROUNDTRIP_SEQ::type_id::create("s2");
            s2.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> P1: Protocol Control", UVM_LOW)
            s3 = AES_CTR_KEY_CTRL_SEQ::type_id::create("s3");
            s3.start(env.agent.sequencer);
            s4 = AES_CTR_IV_CTRL_SEQ::type_id::create("s4");
            s4.start(env.agent.sequencer);
            s5 = AES_CTR_DATA_PROTOCOL_SEQ::type_id::create("s5");
            void'(s5.randomize());
            s5.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> P2: Security Fault Injection", UVM_LOW)
            s6 = AES_CTR_SEC_NONCE_REUSE_SEQ::type_id::create("s6");
            s6.start(env.agent.sequencer);
            s7 = AES_CTR_SEC_CTR_EXHAUST_SEQ::type_id::create("s7");
            s7.start(env.agent.sequencer);
            s8 = AES_CTR_SEC_HALT_RECOVERY_SEQ::type_id::create("s8");
            s8.start(env.agent.sequencer);
            s9 = AES_CTR_SEC_KEYSTREAM_SEQ::type_id::create("s9");
            void'(s9.randomize());
            s9.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> P2.5: Combo Security Stress", UVM_LOW)
            s_combo = AES_CTR_SEC_COMBO_STRESS_SEQ::type_id::create("s_combo");
            s_combo.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> Coverage Closure: Boundary Keys", UVM_LOW)
            s_key_bound = AES_CTR_KEY_BOUNDARY_SEQ::type_id::create("s_key_bound");
            s_key_bound.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> Coverage Closure: Cross Coverage", UVM_LOW)
            s_cross = AES_CTR_CROSS_COVERAGE_SEQ::type_id::create("s_cross");
            s_cross.start(env.agent.sequencer);

            `uvm_info(get_type_name(), ">>> P3: Random Stress", UVM_LOW)
            s10 = AES_CTR_RANDOM_STRESS_SEQ::type_id::create("s10");
            void'(s10.randomize());
            s10.start(env.agent.sequencer);

            // =================================================================
            // PHASE 2: Cryptographic Property Tests (avalanche_mode = ON)
            // =================================================================
            `uvm_info(get_type_name(), "========================================", UVM_LOW)
            `uvm_info(get_type_name(), "  PHASE 2: CRYPTOGRAPHIC PROPERTIES    ", UVM_LOW)
            `uvm_info(get_type_name(), "========================================", UVM_LOW)

            // Enable avalanche mode in scoreboard
            env_cfg.avalanche_mode    = 1;
            env_cfg.avalanche_min_pct = 45.0;
            env_cfg.avalanche_max_pct = 55.0;

            // Reset scoreboard avalanche state for clean measurement
            env.scoreboard.av_have_baseline = 0;
            env.scoreboard.av_hd_q.delete();

            `uvm_info(get_type_name(), ">>> Avalanche: KEY (128 single-bit flips)", UVM_LOW)
            s_av_key = AES_CTR_AVALANCHE_KEY_SEQ::type_id::create("s_av_key");
            s_av_key.start(env.agent.sequencer);

            // Report key avalanche before resetting for IV
            env.scoreboard.report_avalanche();

            // Reset for IV avalanche
            env.scoreboard.av_have_baseline = 0;
            env.scoreboard.av_hd_q.delete();

            `uvm_info(get_type_name(), ">>> Avalanche: IV (128 single-bit flips)", UVM_LOW)
            s_av_iv = AES_CTR_AVALANCHE_IV_SEQ::type_id::create("s_av_iv");
            s_av_iv.start(env.agent.sequencer);

            // Report IV avalanche before resetting for linearity
            env.scoreboard.report_avalanche();

            // Reconfigure for linearity (tight window: 0.5% - 1.1%)
            env_cfg.avalanche_min_pct = 0.5;
            env_cfg.avalanche_max_pct = 1.1;
            env.scoreboard.av_have_baseline = 0;
            env.scoreboard.av_hd_q.delete();

            `uvm_info(get_type_name(), ">>> Linearity: Plaintext bit-flip (16 trials)", UVM_LOW)
            s_lin = AES_CTR_LINEARITY_SEQ::type_id::create("s_lin");
            s_lin.start(env.agent.sequencer);

            // Report linearity
            env.scoreboard.report_avalanche();

            // Turn off avalanche mode so final report_phase doesn't re-report
            env_cfg.avalanche_mode = 0;

            // =================================================================
            // DONE
            // =================================================================
            `uvm_info(get_type_name(), "========================================", UVM_LOW)
            `uvm_info(get_type_name(), "  ALL PHASES COMPLETE                  ", UVM_LOW)
            `uvm_info(get_type_name(), "========================================", UVM_LOW)

            phase.drop_objection(this, "Master test done");
        endtask
    endclass : AES_CTR_MASTER_TEST


endpackage : AES_CTR_TEST_PKG

`endif // AES_CTR_TEST_PKG_SV