`timescale 1ns/1ps
// Comparator parametrizabil pe N biti, folosit pentru potrivirea tag-ului.
module comparator #(parameter N = 8) (
    input  [N-1:0] a,
    input  [N-1:0] b,
    output         eq
);
    assign eq = (a == b);
endmodule
