`timescale 1ns/1ps
module encoder_4to2 (
    input  [3:0] in,
    output [1:0] out,
    output       valid
);
    assign out   = in[0] ? 2'd0 :
                   in[1] ? 2'd1 :
                   in[2] ? 2'd2 : 2'd3;
    assign valid = |in;
endmodule
