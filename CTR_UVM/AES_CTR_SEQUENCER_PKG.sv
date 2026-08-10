// =============================================================================
// AES_CTR_SEQUENCER_PKG.sv
// UVM Sequencer for AES-CTR sequence items
// Standard UVM sequencer with no special customization
// =============================================================================
`ifndef AES_CTR_SEQUENCER_PKG_SV
`define AES_CTR_SEQUENCER_PKG_SV

package AES_CTR_SEQUENCER_PKG;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import AES_CTR_SEQ_ITEM_PKG::*;

    class AES_CTR_SEQUENCER extends uvm_sequencer #(AES_CTR_SEQ_ITEM);

        `uvm_component_utils(AES_CTR_SEQUENCER)

        function new(string name = "AES_CTR_SEQUENCER",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

    endclass : AES_CTR_SEQUENCER

endpackage : AES_CTR_SEQUENCER_PKG

`endif // AES_CTR_SEQUENCER_PKG_SV