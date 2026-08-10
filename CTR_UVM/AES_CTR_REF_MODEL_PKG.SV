`ifndef AES_CTR_REF_MODEL_PKG_SV 
`define AES_CTR_REF_MODEL_PKG_SV

package AES_CTR_REF_MODEL_PKG;


typedef bit [127:0] block_t;

// -------------------------------------------------------------------------
// FIPS-197 S-box
// -------------------------------------------------------------------------
localparam byte unsigned SBOX [0:255] = '{
    8'h63,8'h7c,8'h77,8'h7b,8'hf2,8'h6b,8'h6f,8'hc5,8'h30,8'h01,8'h67,8'h2b,8'hfe,8'hd7,8'hab,8'h76,
    8'hca,8'h82,8'hc9,8'h7d,8'hfa,8'h59,8'h47,8'hf0,8'had,8'hd4,8'ha2,8'haf,8'h9c,8'ha4,8'h72,8'hc0,
    8'hb7,8'hfd,8'h93,8'h26,8'h36,8'h3f,8'hf7,8'hcc,8'h34,8'ha5,8'he5,8'hf1,8'h71,8'hd8,8'h31,8'h15,
    8'h04,8'hc7,8'h23,8'hc3,8'h18,8'h96,8'h05,8'h9a,8'h07,8'h12,8'h80,8'he2,8'heb,8'h27,8'hb2,8'h75,
    8'h09,8'h83,8'h2c,8'h1a,8'h1b,8'h6e,8'h5a,8'ha0,8'h52,8'h3b,8'hd6,8'hb3,8'h29,8'he3,8'h2f,8'h84,
    8'h53,8'hd1,8'h00,8'hed,8'h20,8'hfc,8'hb1,8'h5b,8'h6a,8'hcb,8'hbe,8'h39,8'h4a,8'h4c,8'h58,8'hcf,
    8'hd0,8'hef,8'haa,8'hfb,8'h43,8'h4d,8'h33,8'h85,8'h45,8'hf9,8'h02,8'h7f,8'h50,8'h3c,8'h9f,8'ha8,
    8'h51,8'ha3,8'h40,8'h8f,8'h92,8'h9d,8'h38,8'hf5,8'hbc,8'hb6,8'hda,8'h21,8'h10,8'hff,8'hf3,8'hd2,
    8'hcd,8'h0c,8'h13,8'hec,8'h5f,8'h97,8'h44,8'h17,8'hc4,8'ha7,8'h7e,8'h3d,8'h64,8'h5d,8'h19,8'h73,
    8'h60,8'h81,8'h4f,8'hdc,8'h22,8'h2a,8'h90,8'h88,8'h46,8'hee,8'hb8,8'h14,8'hde,8'h5e,8'h0b,8'hdb,
    8'he0,8'h32,8'h3a,8'h0a,8'h49,8'h06,8'h24,8'h5c,8'hc2,8'hd3,8'hac,8'h62,8'h91,8'h95,8'he4,8'h79,
    8'he7,8'hc8,8'h37,8'h6d,8'h8d,8'hd5,8'h4e,8'ha9,8'h6c,8'h56,8'hf4,8'hea,8'h65,8'h7a,8'hae,8'h08,
    8'hba,8'h78,8'h25,8'h2e,8'h1c,8'ha6,8'hb4,8'hc6,8'he8,8'hdd,8'h74,8'h1f,8'h4b,8'hbd,8'h8b,8'h8a,
    8'h70,8'h3e,8'hb5,8'h66,8'h48,8'h03,8'hf6,8'h0e,8'h61,8'h35,8'h57,8'hb9,8'h86,8'hc1,8'h1d,8'h9e,
    8'he1,8'hf8,8'h98,8'h11,8'h69,8'hd9,8'h8e,8'h94,8'h9b,8'h1e,8'h87,8'he9,8'hce,8'h55,8'h28,8'hdf,
    8'h8c,8'ha1,8'h89,8'h0d,8'hbf,8'he6,8'h42,8'h68,8'h41,8'h99,8'h2d,8'h0f,8'hb0,8'h54,8'hbb,8'h16
};

// -------------------------------------------------------------------------
// GF(2^8) helpers
// -------------------------------------------------------------------------
function automatic byte unsigned xtime(byte unsigned b);
    return byte'((b << 1) ^ (b[7] ? 8'h1b : 8'h00));
endfunction

function automatic byte unsigned gmul3(byte unsigned b);
    return byte'(xtime(b) ^ b);
endfunction

// -------------------------------------------------------------------------
// Byte access: byte 0 = state[127:120] (matches RTL/NIST ordering)
// -------------------------------------------------------------------------
function automatic byte unsigned get_byte(block_t s, int unsigned i);
    return byte'(s >> (8 * (15 - i)));
endfunction

function automatic block_t set_byte(block_t s, int unsigned i, byte unsigned v);
    block_t mask = 128'hFF << (8 * (15 - i));
    return (s & ~mask) | (block_t'(v) << (8 * (15 - i)));
endfunction

// -------------------------------------------------------------------------
// AES round transformations
// -------------------------------------------------------------------------
function automatic block_t sub_bytes(block_t s);
    block_t r = '0;
    for (int i = 0; i < 16; i++)
        r = set_byte(r, i, SBOX[get_byte(s, i)]);
    return r;
endfunction

function automatic block_t shift_rows(block_t s);
    block_t r = '0;
    // b[4c+row] <= b[4*((c+row) mod 4) + row]
    for (int c = 0; c < 4; c++)
        for (int row = 0; row < 4; row++)
            r = set_byte(r, 4*c + row, get_byte(s, 4*((c + row) % 4) + row));
    return r;
endfunction

function automatic block_t mix_columns(block_t s);
    block_t r = '0;
    for (int c = 0; c < 4; c++) begin
        byte unsigned a0 = get_byte(s, 4*c+0);
        byte unsigned a1 = get_byte(s, 4*c+1);
        byte unsigned a2 = get_byte(s, 4*c+2);
        byte unsigned a3 = get_byte(s, 4*c+3);
        r = set_byte(r, 4*c+0, xtime(a0) ^ gmul3(a1) ^ a2        ^ a3);
        r = set_byte(r, 4*c+1, a0        ^ xtime(a1) ^ gmul3(a2) ^ a3);
        r = set_byte(r, 4*c+2, a0        ^ a1        ^ xtime(a2) ^ gmul3(a3));
        r = set_byte(r, 4*c+3, gmul3(a0) ^ a1        ^ a2        ^ xtime(a3));
    end
    return r;
endfunction

// -------------------------------------------------------------------------
// Key expansion: 11 round keys
// -------------------------------------------------------------------------
function automatic void key_expand(input block_t key, output block_t rk [0:10]);
    bit [31:0] w [0:43];
    byte unsigned rc [1:10] = '{8'h01,8'h02,8'h04,8'h08,8'h10,
                                8'h20,8'h40,8'h80,8'h1b,8'h36};
    {w[0], w[1], w[2], w[3]} = key;

    for (int i = 4; i < 44; i++) begin
        bit [31:0] t = w[i-1];
        if (i % 4 == 0) begin
            t = {t[23:0], t[31:24]};                       // RotWord
            t = {SBOX[t[31:24]], SBOX[t[23:16]],            // SubWord
                 SBOX[t[15:8]],  SBOX[t[7:0]]};
            t = t ^ {rc[i/4], 24'h0};                       // Rcon
        end
        w[i] = w[i-4] ^ t;
    end
    for (int r = 0; r <= 10; r++)
        rk[r] = {w[4*r], w[4*r+1], w[4*r+2], w[4*r+3]};
endfunction

// -------------------------------------------------------------------------
// AES-128 single-block encryption (FIPS-197)
// -------------------------------------------------------------------------
function automatic block_t aes128_encrypt(block_t key, block_t pt);
    block_t rk [0:10];
    block_t st;
    key_expand(key, rk);
    st = pt ^ rk[0];
    for (int r = 1; r <= 9; r++)
        st = mix_columns(shift_rows(sub_bytes(st))) ^ rk[r];
    st = shift_rows(sub_bytes(st)) ^ rk[10];
    return st;
endfunction

// -------------------------------------------------------------------------
// CTR helpers (SP 800-38A, DUT increments lower 32 bits)
// -------------------------------------------------------------------------
function automatic block_t ctr_keystream(block_t key,
                                         bit [95:0] iv_upper,
                                         bit [31:0] ctr);
    return aes128_encrypt(key, {iv_upper, ctr});
endfunction

function automatic block_t ctr_process(block_t key,
                                       bit [95:0] iv_upper,
                                       bit [31:0] ctr,
                                       block_t data);
    return ctr_keystream(key, iv_upper, ctr) ^ data;
endfunction
endpackage : AES_CTR_REF_MODEL_PKG

`endif // AES_CTR_REF_MODEL_PKG_SV