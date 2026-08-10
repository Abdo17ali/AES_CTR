// =============================================================================
// AES_CTR_SEQUENCE_PKG.sv
// All sequences: NIST SP 800-38A, Control, Security, Avalanche, Stress, Coverage
// =============================================================================
`ifndef AES_CTR_SEQUENCE_PKG_SV
`define AES_CTR_SEQUENCE_PKG_SV

package AES_CTR_SEQUENCE_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;

    // =========================================================================
    // NIST SP 800-38A Appendix F.5 — Official CTR-AES128 Vectors
    // =========================================================================
    localparam bit [127:0] NIST_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    localparam bit [127:0] NIST_IV  = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;

    localparam bit [127:0] NIST_PT [4] = '{
        128'h6bc1bee22e409f96e93d7e117393172a,
        128'hae2d8a571e03ac9c9eb76fac45af8e51,
        128'h30c81c46a35ce411e5fbc1191a0a52ef,
        128'hf69f2445df4f9b17ad2b417be66c3710
    };

    localparam bit [127:0] NIST_CT [4] = '{
        128'h874d6191b620e3261bef6864990db6ce,
        128'h9806f66b7970fdff8617187bb9fffdff,
        128'h5ae4df3edbd5d35e5b4f09020db03eab,
        128'h1e031dda2fbe03d1792170a0f3009cee
    };

    // =========================================================================
    // BASE SEQUENCE 
    // =========================================================================
    class AES_CTR_BASE_SEQ extends uvm_sequence #(AES_CTR_SEQ_ITEM);
        `uvm_object_utils(AES_CTR_BASE_SEQ)
        function new(string name = "AES_CTR_BASE_SEQ"); super.new(name); endfunction

        task do_rst();
            AES_CTR_SEQ_ITEM it = AES_CTR_SEQ_ITEM::type_id::create("rst_it");
            start_item(it); it.op_type = OP_RESET; it.idle_cycles = 0; finish_item(it);
        endtask

        task load_key(bit [127:0] k);
            AES_CTR_SEQ_ITEM it = AES_CTR_SEQ_ITEM::type_id::create("key_it");
            start_item(it); it.op_type = OP_KEY_LOAD; it.master_key = k; it.idle_cycles = 0; finish_item(it);
        endtask

        task load_iv(bit [127:0] v);
            AES_CTR_SEQ_ITEM it = AES_CTR_SEQ_ITEM::type_id::create("iv_it");
            start_item(it); it.op_type = OP_IV_LOAD; it.iv = v; it.idle_cycles = 0; finish_item(it);
        endtask

        task send_block(bit [127:0] d, bit m = 1'b0, int unsigned gap = 0);
            AES_CTR_SEQ_ITEM it = AES_CTR_SEQ_ITEM::type_id::create("data_it");
            start_item(it); it.op_type = OP_DATA; it.data = d; it.mode = m; it.idle_cycles = gap; it.pattern = PAT_NIST; finish_item(it);
        endtask

        task clear_err();
            AES_CTR_SEQ_ITEM it = AES_CTR_SEQ_ITEM::type_id::create("clr_it");
            start_item(it); it.op_type = OP_ERROR_CLEAR; it.idle_cycles = 0; finish_item(it);
        endtask

        task idle(int unsigned n);
            AES_CTR_SEQ_ITEM it = AES_CTR_SEQ_ITEM::type_id::create("idle_it");
            start_item(it); it.op_type = OP_IDLE; it.idle_cycles = n; finish_item(it);
        endtask

        task new_session(bit [127:0] k, bit [127:0] v);
            do_rst(); load_key(k); load_iv(v);
        endtask
    endclass : AES_CTR_BASE_SEQ

    // =========================================================================
    // P0.1 - P0.3 NIST
    // =========================================================================
    class AES_CTR_NIST_F51_ENC_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_NIST_F51_ENC_SEQ)
        function new(string name = "AES_CTR_NIST_F51_ENC_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, NIST_IV);
            foreach (NIST_PT[i]) send_block(NIST_PT[i], 1'b0, 0); 
            idle(20);                                 
        endtask
    endclass

    class AES_CTR_NIST_F52_DEC_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_NIST_F52_DEC_SEQ)
        function new(string name = "AES_CTR_NIST_F52_DEC_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, NIST_IV);
            foreach (NIST_CT[i]) send_block(NIST_CT[i], 1'b1, 0);    
            idle(20);
        endtask
    endclass

    class AES_CTR_NIST_ROUNDTRIP_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_NIST_ROUNDTRIP_SEQ)
        function new(string name = "AES_CTR_NIST_ROUNDTRIP_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, NIST_IV);
            foreach (NIST_PT[i]) send_block(NIST_PT[i], 1'b0, 0);
            idle(20);
            new_session(NIST_KEY, NIST_IV);
            foreach (NIST_CT[i]) send_block(NIST_CT[i], 1'b1, 0);
            idle(20);
        endtask
    endclass

    // =========================================================================
    // P1.1 - P1.3 PROTOCOL CONTROL
    // =========================================================================
           class AES_CTR_KEY_CTRL_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_KEY_CTRL_SEQ)
        function new(string name = "AES_CTR_KEY_CTRL_SEQ");
            super.new(name);
        endfunction
        virtual task body();
            bit [127:0] k1 = 128'hA5A5A5A5_5A5A5A5A_DEADBEEF_01234567;
            bit [127:0] k2 = 128'h00112233_44556677_8899AABB_CCDDEEFF;

            // K1: Normal key load
            new_session(k1, 128'hF0F0F0F0_0F0F0F0F_00000000_00000001);
            send_block(128'hCAFEBABE_CAFEBABE_CAFEBABE_CAFEBABE, 1'b0, 0);
            idle(20);

            // K3: Load a different key (clean session)
            new_session(k2, 128'hF0F0F0F0_0F0F0F0F_00000000_00000001);
            send_block(128'h11111111_22222222_33333333_44444444, 1'b0, 0);
            idle(20);

            // K4: valid_in BEFORE iv -> ERR_NO_NONCE
            do_rst();
            load_key(k1);
            send_block(128'h0, 1'b0, 1);
            idle(5);
            clear_err();

            // K5: valid_in BEFORE key -> ERR_KEYS_NOT_READY
            do_rst();
            send_block(128'h0, 1'b0, 1);
            idle(5);
            clear_err();

            // K6: Clean session after all error tests
            new_session(k1, 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_00000000);
            send_block(128'hDEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD, 1'b0, 0);
            idle(20);
        endtask
    endclass : AES_CTR_KEY_CTRL_SEQ

      class AES_CTR_IV_CTRL_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_IV_CTRL_SEQ)
        function new(string name = "AES_CTR_IV_CTRL_SEQ");
            super.new(name);
        endfunction
        virtual task body();
            bit [127:0] iv_a = 128'h0102030405060708090A0B0C_00000000;

            // V4: valid_in before ANY init -> ERR_KEYS_NOT_READY
            do_rst();
            send_block(128'h0, 1'b0, 1);
            idle(5);
            clear_err();

            // V1: Legal IV load and encryption
            new_session(NIST_KEY, iv_a);
            send_block(128'hDEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD, 1'b0, 0);
            idle(15);

            // V2: SAME IV reload while locked -> silently ignored
            // Must use new_session to keep SB in sync
            new_session(NIST_KEY, iv_a);
            send_block(128'hBEEF_BEEF_BEEF_BEEF_BEEF_BEEF_BEEF_BEEF, 1'b0, 0);
            idle(15);
        endtask
    endclass : AES_CTR_IV_CTRL_SEQ

    class AES_CTR_DATA_PROTOCOL_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_DATA_PROTOCOL_SEQ)
        rand int unsigned num_b2b;
        constraint c_n { num_b2b inside {[8:16]}; }
        function new(string name = "AES_CTR_DATA_PROTOCOL_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_00000000);
            send_block(128'h1, 1'b0, 0); idle(15);
            repeat (num_b2b) send_block({4{$urandom()}}, 1'b0, 0); idle(15);
            repeat (8) send_block({4{$urandom()}}, 1'b0, $urandom_range(1, 5)); idle(20);
        endtask
    endclass

    // =========================================================================
    // P2.1 - P2.5 SECURITY
    // =========================================================================
    class AES_CTR_SEC_NONCE_REUSE_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_SEC_NONCE_REUSE_SEQ)
        function new(string name="AES_CTR_SEC_NONCE_REUSE_SEQ"); super.new(name); endfunction
        virtual task body();
            bit [127:0] iv_a = 128'h11111111_22222222_33333333_00000000;
            bit [127:0] iv_b = 128'h99999999_88888888_77777777_00000000;
            new_session(NIST_KEY, iv_a); load_iv(iv_a);
            send_block(128'h5555_5555_5555_5555_5555_5555_5555_5555, 1'b0, 0); idle(15);
            load_iv(iv_b); idle(5);
            clear_err(); send_block(128'h0, 1'b0, 1); idle(10);
            new_session(NIST_KEY, iv_b);
            send_block(128'hABCD_ABCD_ABCD_ABCD_ABCD_ABCD_ABCD_ABCD, 1'b0, 0); idle(15);
        endtask
    endclass

    class AES_CTR_SEC_CTR_EXHAUST_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_SEC_CTR_EXHAUST_SEQ)
        function new(string name="AES_CTR_SEC_CTR_EXHAUST_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, {96'hAABBCCDD_EEFF0011_22334455, 32'hFFFF_EFFE});
            send_block(128'h1, 1'b0, 0); send_block(128'h2, 1'b0, 0); send_block(128'h3, 1'b0, 0); idle(10);
            clear_err(); send_block(128'h4, 1'b0, 1); idle(10); clear_err();
            new_session(NIST_KEY, {96'h00000000_00000000_00000001, 32'hFFFF_FFFF});
            clear_err(); send_block(128'hAA, 1'b0, 1); idle(10);
            clear_err(); send_block(128'hBB, 1'b0, 1); idle(10);
        endtask
    endclass

    class AES_CTR_SEC_HALT_RECOVERY_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_SEC_HALT_RECOVERY_SEQ)
        function new(string name="AES_CTR_SEC_HALT_RECOVERY_SEQ"); super.new(name); endfunction
        virtual task body();
            do_rst(); send_block(128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, 1'b0, 1); idle(5);
            send_block(128'h0, 1'b0, 1); idle(5);
            clear_err(); load_key(NIST_KEY); send_block(128'h0, 1'b0, 1); idle(5); clear_err();
            load_iv(128'h01234567_89ABCDEF_FEDCBA98_00000000);
            send_block(128'h0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F, 1'b0, 0); idle(15);
        endtask
    endclass

    class AES_CTR_SEC_KEYSTREAM_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_SEC_KEYSTREAM_SEQ)
        rand int unsigned num_blocks; constraint c_n { num_blocks inside {[32:64]}; }
        function new(string name="AES_CTR_SEC_KEYSTREAM_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, 128'hC0DE_C0DE_C0DE_C0DE_C0DE_C0DE_00000000);
            repeat (num_blocks) send_block(128'h0, 1'b0, 0); idle(20);
        endtask
    endclass

    class AES_CTR_SEC_COMBO_STRESS_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_SEC_COMBO_STRESS_SEQ)
        function new(string name="AES_CTR_SEC_COMBO_STRESS_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(NIST_KEY, {96'hAABBCCDD_EEFF0011_22334455, 32'hFFFF_F000});
            send_block(128'h0, 1'b0, 0); idle(5); clear_err();
            load_iv(128'h99999999_88888888_77777777_00000000); 
            clear_err(); send_block(128'h1, 1'b0, 0); idle(10);
        endtask
    endclass

    // =========================================================================
    // COVERAGE CLOSURE: BOUNDARY KEYS & CROSS COVERAGE BOMBARDMENT
    // =========================================================================
    class AES_CTR_KEY_BOUNDARY_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_KEY_BOUNDARY_SEQ)
        function new(string name="AES_CTR_KEY_BOUNDARY_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(128'h0, NIST_IV); send_block(128'h0, 1'b0, 0); idle(10);
            new_session(128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF, NIST_IV); send_block(128'h0, 1'b0, 0); idle(10);
        endtask
    endclass

       class AES_CTR_CROSS_COVERAGE_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_CROSS_COVERAGE_SEQ)
        function new(string name="AES_CTR_CROSS_COVERAGE_SEQ"); super.new(name); endfunction
        
        // Send all 4 data patterns while error is active
        // idle(1) before each block gives Monitor time to sample error flag
        task bombard_patterns();
            send_block(128'h0, 1'b0, 1);
            send_block(128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF, 1'b0, 1);
            send_block(128'h00000000_00000000_00000000_00000001, 1'b0, 1);
            send_block(128'h12345678_9ABCDEF0_11223344_55667788, 1'b0, 1);
            idle(3);
        endtask
        
        virtual task body();
            `uvm_info(get_type_name(), "Running Cross-Coverage Bombardment", UVM_LOW)

            // ── Fault 1: KEYS_NOT_READY (0100) ──
            // After reset, no key loaded, send data
            do_rst();
            // First block triggers the error, remaining blocks sample it
            send_block(128'hAA, 1'b0, 1); // triggers ERR_KEYS_NOT_READY
            idle(2); // let error register
            bombard_patterns();
            clear_err();

            // ── Fault 2: NO_NONCE (0101) ──
            // Key loaded but no IV
            do_rst();
            load_key(NIST_KEY);
            send_block(128'hBB, 1'b0, 1); // triggers ERR_NO_NONCE
            idle(2);
            bombard_patterns();
            clear_err();

            // ── Fault 3: CTR_EXHAUSTION (0110) ──
            // Start counter in warn zone
            new_session(NIST_KEY, {96'hAAAAAAAA_BBBBBBBB_CCCCCCCC, 32'hFFFF_F000});
            send_block(128'hCC, 1'b0, 0); // triggers warn
            idle(2);
            bombard_patterns();
            clear_err();

            // ── Fault 4: CTR_OVERFLOW (0010) ──
            // Start counter at max
            new_session(NIST_KEY, {96'hAAAAAAAA_BBBBBBBB_CCCCCCCC, 32'hFFFF_FFFF});
            clear_err(); // clear the exhaustion warning from loading at max
            send_block(128'hDD, 1'b0, 1); // triggers overflow
            idle(2);
            bombard_patterns();
            // Cannot clear_err (critical), need reset

            // ── Fault 5: NONCE_REUSE (0001) ──
            new_session(NIST_KEY, NIST_IV);
            send_block(128'h0, 1'b0, 0); // one valid block
            idle(10);
            load_iv(128'h99999999_88888888_77777777_00000000); // triggers nonce reuse
            idle(2);
            bombard_patterns();
            // Cannot clear_err (critical), need reset

            idle(10);
        endtask
    endclass : AES_CTR_CROSS_COVERAGE_SEQ

    // =========================================================================
    // AVALANCHE, LINEARITY, RANDOM STRESS
    // =========================================================================
    class AES_CTR_AVALANCHE_KEY_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_AVALANCHE_KEY_SEQ)
        int unsigned num_trials = 128;
        localparam bit [127:0] AV_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        localparam bit [127:0] AV_IV  = 128'hf0f1f2f3f4f5f6f7f8f9fafb_00000000;
        localparam bit [127:0] AV_PT  = 128'h6bc1bee22e409f96e93d7e117393172a;
        function new(string name="AES_CTR_AVALANCHE_KEY_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(AV_KEY, AV_IV); send_block(AV_PT, 1'b0, 0); idle(15);
            for (int unsigned b = 0; b < num_trials; b++) begin
                new_session(AV_KEY ^ (128'h1 << b), AV_IV); send_block(AV_PT, 1'b0, 0); idle(15);
            end
        endtask
    endclass

    class AES_CTR_AVALANCHE_IV_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_AVALANCHE_IV_SEQ)
        int unsigned num_trials = 128;
        localparam bit [127:0] AV_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        localparam bit [127:0] AV_IV  = 128'hf0f1f2f3f4f5f6f7f8f9fafb_00000000;
        localparam bit [127:0] AV_PT  = 128'h6bc1bee22e409f96e93d7e117393172a;
        function new(string name="AES_CTR_AVALANCHE_IV_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(AV_KEY, AV_IV); send_block(AV_PT, 1'b0, 0); idle(15);
            for (int unsigned b = 0; b < num_trials; b++) begin
                new_session(AV_KEY, AV_IV ^ (128'h1 << b)); send_block(AV_PT, 1'b0, 0); idle(15);
            end
        endtask
    endclass

    class AES_CTR_LINEARITY_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_LINEARITY_SEQ)
        int unsigned num_trials = 16;   
        localparam bit [127:0] AV_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        localparam bit [127:0] AV_IV  = 128'hf0f1f2f3f4f5f6f7f8f9fafb_00000000;
        localparam bit [127:0] AV_PT  = 128'h6bc1bee22e409f96e93d7e117393172a;
        function new(string name="AES_CTR_LINEARITY_SEQ"); super.new(name); endfunction
        virtual task body();
            new_session(AV_KEY, AV_IV); send_block(AV_PT, 1'b0, 0); idle(15);
            for (int unsigned t = 0; t < num_trials; t++) begin
                int unsigned b = $urandom_range(0, 127);
                new_session(AV_KEY, AV_IV); send_block(AV_PT ^ (128'h1 << b), 1'b0, 0); idle(15);
            end
        endtask
    endclass

    class AES_CTR_RANDOM_STRESS_SEQ extends AES_CTR_BASE_SEQ;
        `uvm_object_utils(AES_CTR_RANDOM_STRESS_SEQ)
        rand int unsigned num_sessions;
        rand int unsigned blocks_per_session;
        constraint c_s { num_sessions inside {[5:15]}; }
        constraint c_b { blocks_per_session inside {[10:50]}; }
        function new(string name="AES_CTR_RANDOM_STRESS_SEQ"); super.new(name); endfunction
        virtual task body();
            AES_CTR_SEQ_ITEM it;
            for (int unsigned s = 0; s < num_sessions; s++) begin
                bit [127:0] rkey = {4{$urandom()}};
                bit [127:0] riv  = {{3{$urandom()}}, 32'($urandom_range(0, 32'h0000_FFFF))};
                bit         rmode = $urandom_range(0, 1);
                new_session(rkey, riv);
                for (int unsigned blk = 0; blk < blocks_per_session; blk++) begin
                    it = AES_CTR_SEQ_ITEM::type_id::create($sformatf("s%0d_b%0d", s, blk));
                    start_item(it);
                    if (!it.randomize() with { op_type == OP_DATA; mode == rmode; })
                        `uvm_error(get_type_name(), "Randomize failed")
                    finish_item(it);
                end
                idle(20);
            end
        endtask
    endclass

endpackage : AES_CTR_SEQUENCE_PKG

`endif // AES_CTR_SEQUENCE_PKG_SV