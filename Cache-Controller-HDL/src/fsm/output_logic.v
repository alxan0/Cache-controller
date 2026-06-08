`timescale 1ns/1ps
module output_logic (
    input  [2:0] current_state,
    input        op_read,
    input        op_write,
    input        from_write_miss,
    output try_read,
    output try_write,
    output mem_read,
    output mem_write,
    output write_hit_en,
    output read_alloc_en,
    output write_alloc_en,
    output ready
);
    localparam IDLE       = 3'd0,
               READ_HIT   = 3'd1,
               READ_MISS  = 3'd2,
               WRITE_HIT  = 3'd3,
               WRITE_MISS = 3'd4,
               EVICT      = 3'd5,
               ALLOCATE   = 3'd6;

    assign try_read  = (current_state == IDLE) & op_read;
    assign try_write = (current_state == IDLE) & op_write;

    assign mem_write = (current_state == EVICT);
    assign mem_read  = (current_state == ALLOCATE);

    assign write_hit_en   = (current_state == WRITE_HIT);
    assign read_alloc_en  = (current_state == ALLOCATE) & ~from_write_miss;
    assign write_alloc_en = (current_state == ALLOCATE) &  from_write_miss;

    assign ready = (current_state == READ_HIT)  |
                   (current_state == WRITE_HIT) |
                   (current_state == ALLOCATE);

endmodule
