`timescale 1ns/1ps
module cache_set #(
    parameter TAG_SIZE  = 19,
    parameter WORD_SIZE = 32
)(
    input  clk,
    input  rst_b,
    input  [TAG_SIZE-1:0]  addr_tag,
    input  [3:0]           word_offset,
    input  [WORD_SIZE-1:0] write_data,
    input  try_read,
    input  try_write,
    input  write_hit_en,
    input  read_alloc_en,
    input  write_alloc_en,
    output [WORD_SIZE-1:0] data_out,
    output [1:0]           hit_way,
    output [1:0]           lru_way,
    output                 hit_miss,
    output                 dirty_out
);
    wire [3:0] hit_vec;
    wire [3:0] dirty_vec;
    wire [WORD_SIZE-1:0] data_vec [3:0];

    wire hit_valid;
    encoder_4to2 hit_enc (.in(hit_vec), .out(hit_way), .valid(hit_valid));
    assign hit_miss = hit_valid;

    wire lru_update = ((try_read | try_write) & hit_valid) | read_alloc_en | write_alloc_en;
    wire [1:0] lru_access = (read_alloc_en | write_alloc_en) ? lru_way : hit_way;

    lru_unit lru (
        .clk(clk), .rst_b(rst_b),
        .access_way(lru_access),
        .update_en(lru_update),
        .lru_way(lru_way)
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : lines
            cache_line #(.TAG_SIZE(TAG_SIZE), .WORD_SIZE(WORD_SIZE)) line_inst (
                .clk(clk), .rst_b(rst_b),
                .addr_tag(addr_tag),
                .word_offset(word_offset),
                .write_data(write_data),
                .write_en      (write_hit_en   & (hit_way == i[1:0]) & hit_valid),
                .read_alloc_en (read_alloc_en  & (lru_way == i[1:0])),
                .write_alloc_en(write_alloc_en & (lru_way == i[1:0])),
                .data_out(data_vec[i]),
                .hit(hit_vec[i]),
                .dirty(dirty_vec[i])
            );
        end
    endgenerate

    assign data_out  = data_vec[hit_way];
    assign dirty_out = dirty_vec[lru_way];

endmodule