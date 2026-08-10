// =============================================================================
// shift_rows.v  
// Performs the AES ShiftRows operation.
// This module consumes 0 LUTs and 0 Registers (Pure Routing / Wire Swapping)
// =============================================================================
module shift_rows (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    // We map the 128-bit flat vector to the new shifted positions.
    // state_in byte indices: 
    // [127:120]=b0, [119:112]=b1, ... [7:0]=b15
    
    assign state_out = {
        // --------------------------------------------------------
        // NEW COLUMN 0
        // --------------------------------------------------------
        state_in[127:120],  // Row 0, Col 0 (Unchanged)       -> b0
        state_in[87:80],    // Row 1, Col 1 (Shifted left 1)  -> b5
        state_in[47:40],    // Row 2, Col 2 (Shifted left 2)  -> b10
        state_in[7:0],      // Row 3, Col 3 (Shifted left 3)  -> b15

        // --------------------------------------------------------
        // NEW COLUMN 1
        // --------------------------------------------------------
        state_in[95:88],    // Row 0, Col 1 (Unchanged)       -> b4
        state_in[55:48],    // Row 1, Col 2 (Shifted left 1)  -> b9
        state_in[15:8],     // Row 2, Col 3 (Shifted left 2)  -> b14
        state_in[103:96],   // Row 3, Col 0 (Shifted left 3)  -> b3

        // --------------------------------------------------------
        // NEW COLUMN 2
        // --------------------------------------------------------
        state_in[63:56],    // Row 0, Col 2 (Unchanged)       -> b8
        state_in[23:16],    // Row 1, Col 3 (Shifted left 1)  -> b13
        state_in[111:104],  // Row 2, Col 0 (Shifted left 2)  -> b2
        state_in[71:64],    // Row 3, Col 1 (Shifted left 3)  -> b7

        // --------------------------------------------------------
        // NEW COLUMN 3
        // --------------------------------------------------------
        state_in[31:24],    // Row 0, Col 3 (Unchanged)       -> b12
        state_in[119:112],  // Row 1, Col 0 (Shifted left 1)  -> b1
        state_in[79:72],    // Row 2, Col 1 (Shifted left 2)  -> b6
        state_in[39:32]     // Row 3, Col 2 (Shifted left 3)  -> b11
    };

endmodule