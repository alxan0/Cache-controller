`timescale 1ns/1ps
// Tabloul de cache: NUM_SETS instante cache_set conectate in paralel.
module cache_array #(
    parameter ADDR_WIDTH  = 32,
    parameter TAG_SIZE    = 19,
    parameter INDEX_SIZE  = 7,
    parameter WORD_SIZE   = 32,
    parameter NUM_SETS    = 128
)(
    input  clk,
    input  rst_b,
    input  [ADDR_WIDTH-1:0] address,
    input  [WORD_SIZE-1:0]  write_data,
    input  try_read,
    input  try_write,
    input  write_hit_en,
    input  read_alloc_en,
    input  write_alloc_en,
    output [WORD_SIZE-1:0] data_out,
    output hit,
    output dirty
);
    // Descompunerea adresei: tag[31:13], index[12:6], word_offset[5:2]
    wire [INDEX_SIZE-1:0] index       = address[12:6];
    wire [3:0]            word_offset = address[5:2];
    wire [TAG_SIZE-1:0]   tag         = address[31:13];

    wire [WORD_SIZE-1:0] set_data   [0:NUM_SETS-1];
    wire                 set_hit    [0:NUM_SETS-1];
    wire                 set_dirty  [0:NUM_SETS-1];

    genvar i;
    generate
        for (i = 0; i < NUM_SETS; i = i + 1) begin : cache_sets
            // active mascheaza semnalele de control: doar setul adresat primeste comenzi
            wire active = (index == i);
            cache_set #(.TAG_SIZE(TAG_SIZE), .WORD_SIZE(WORD_SIZE)) cset (
                .clk(clk), .rst_b(rst_b),
                .addr_tag(tag),
                .word_offset(word_offset),
                .write_data(write_data),
                .try_read      (try_read      & active),
                .try_write     (try_write     & active),
                .write_hit_en  (write_hit_en  & active),
                .read_alloc_en (read_alloc_en & active),
                .write_alloc_en(write_alloc_en & active),
                .data_out (set_data[i]),
                .hit_way (),
                .lru_way (),
                .hit_miss (set_hit[i]),
                .dirty_out(set_dirty[i])
            );
        end
    endgenerate

    assign data_out = set_data[index];
    assign hit      = set_hit[index];
    assign dirty    = set_dirty[index];

endmodule
