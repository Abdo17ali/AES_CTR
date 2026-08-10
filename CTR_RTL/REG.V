module pipeline_reg_128 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire [127:0] data_in,
    output reg  [127:0] data_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 128'd0;
        end else if (en) begin
            data_out <= data_in;
        end
    end
endmodule