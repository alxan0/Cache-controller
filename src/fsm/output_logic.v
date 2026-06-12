`timescale 1ns/1ps
module output_logic (
    input  [3:0] current_state,
    input        op_read,
    input        op_write,
    input        req,
    output try_read,
    output try_write,
    output mem_read,
    output mem_write,
    output write_hit_en,
    output read_alloc_en,
    output write_alloc_en,
    output ready
);
    localparam IDLE       = 4'd0,
               READ_HIT   = 4'd1,
               READ_MISS  = 4'd2,
               WRITE_HIT  = 4'd3,
               WRITE_MISS = 4'd4,
               EVICT_RD   = 4'd5,
               EVICT_WR   = 4'd6,
               ALLOC_RD   = 4'd7,
               ALLOC_WR   = 4'd8;

    assign try_read  = (current_state == IDLE) & op_read  & req;
    assign try_write = (current_state == IDLE) & op_write & req;

    assign mem_write = (current_state == EVICT_RD) | (current_state == EVICT_WR);
    assign mem_read  = (current_state == ALLOC_RD) | (current_state == ALLOC_WR);

    assign write_hit_en   = (current_state == WRITE_HIT);
    assign read_alloc_en  = (current_state == ALLOC_RD);
    assign write_alloc_en = (current_state == ALLOC_WR);

    assign ready = (current_state == READ_HIT)  |
                   (current_state == WRITE_HIT) |
                   (current_state == ALLOC_RD)  |
                   (current_state == ALLOC_WR);

endmodule
