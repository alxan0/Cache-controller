`timescale 1ns/1ps
module cache_line #(
    parameter TAG_SIZE  = 19,
    parameter WORD_SIZE = 32
)(
    input  clk,
    input  rst_b,
    input  [TAG_SIZE-1:0]  addr_tag,
    input  [3:0]           word_offset,
    input  [WORD_SIZE-1:0] write_data,
    input  write_en,
    input  read_alloc_en,
    input  write_alloc_en,
    output [WORD_SIZE-1:0] data_out,
    output hit,
    output dirty
);
    wire alloc_any = read_alloc_en | write_alloc_en;
    wire [TAG_SIZE-1:0] tag_stored;

    genvar i;
    generate
        for (i = 0; i < TAG_SIZE; i = i + 1) begin : tag_regs
            dff tag_dff (
                .clk(clk), .rst_b(rst_b),
                .en(alloc_any),
                .d(addr_tag[i]),
                .q(tag_stored[i])
            );
        end
    endgenerate

    wire [WORD_SIZE-1:0] cache_word_out [0:15];
    generate
        for (i = 0; i < 16; i = i + 1) begin : words_regs
            wire data_en = (write_en && (word_offset == i)) | alloc_any;
            genvar j;
            for (j = 0; j < WORD_SIZE; j = j + 1) begin : data_bits
                dff data_dff (
                    .clk(clk), .rst_b(rst_b),
                    .en(data_en),
                    .d(write_data[j]),
                    .q(cache_word_out[i][j])
                );
            end
        end
    endgenerate

    assign data_out = cache_word_out[word_offset];

    wire valid;
    dff valid_dff (
        .clk(clk), .rst_b(rst_b),
        .en(alloc_any),
        .d(1'b1),
        .q(valid)
    );

    wire dirty_next = write_en | write_alloc_en;
    dff dirty_dff (
        .clk(clk), .rst_b(rst_b),
        .en(write_en | alloc_any),
        .d(dirty_next),
        .q(dirty)
    );

    wire tag_match;
    comparator #(.N(TAG_SIZE)) tag_cmp (
        .a(tag_stored),
        .b(addr_tag),
        .eq(tag_match)
    );

    assign hit = tag_match & valid;

endmodule