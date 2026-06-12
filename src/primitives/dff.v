`timescale 1ns/1ps
module dff (
    input  clk,
    input  rst_b,
    input  en,
    input  d,
    output reg q
);
    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) q <= 1'b0;
        else if (en) q <= d;
    end
endmodule
