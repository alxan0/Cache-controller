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

    reg [TAG_SIZE-1:0]  tag_stored;
    reg [WORD_SIZE-1:0] data_mem [0:15];
    reg                 valid;
    reg                 dirty_r;

    integer k;
    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            tag_stored <= 0;
            valid      <= 1'b0;
            dirty_r    <= 1'b0;
            for (k = 0; k < 16; k = k + 1)
                data_mem[k] <= 0;
        end else begin
            if (alloc_any) begin
                tag_stored <= addr_tag;
                valid      <= 1'b1;
                dirty_r    <= write_alloc_en;
                for (k = 0; k < 16; k = k + 1)
                    data_mem[k] <= write_data;
            end else if (write_en) begin
                data_mem[word_offset] <= write_data;
                dirty_r               <= 1'b1;
            end
        end
    end

    wire tag_match;
    comparator #(.N(TAG_SIZE)) tag_cmp (
        .a(tag_stored),
        .b(addr_tag),
        .eq(tag_match)
    );

    assign data_out = data_mem[word_offset];
    assign hit      = tag_match & valid;
    assign dirty    = dirty_r;

endmodule
