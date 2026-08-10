// =============================================================================

// aes_ctr_xor.v

// Performs XOR of keystream with data for CTR mode

// =============================================================================

module aes_ctr_xor (
input wire clk,
input wire rst_n,
input wire valid_in,
input wire [127:0] keystream,
input wire [127:0] data_in,
output reg valid_out,
output reg [127:0] data_out
);


always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
valid_out <= 1'b0;
data_out  <= 128'd0;
end else begin
valid_out <= valid_in;

if (valid_in) begin

    data_out <= keystream ^ data_in;

end else begin

    data_out <= 128'd0;

end
end
end
endmodule