`timescale 1ns/1ps
module cache_fsm (
    input  clk,
    input  rst_b,
    input  hit,
    input  dirty,
    input  op_read,
    input  op_write,
    output [2:0] state,
    output try_read,
    output try_write,
    output mem_read,
    output mem_write,
    output write_hit_en,
    output read_alloc_en,
    output write_alloc_en,
    output ready
);
    localparam WRITE_MISS = 3'd4;

    wire [2:0] next;
    reg  [2:0] current_state;
    reg        from_write_miss;

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) current_state <= 3'd0;
        else        current_state <= next;
    end

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b)                           from_write_miss <= 1'b0;
        else if (current_state == WRITE_MISS) from_write_miss <= 1'b1;
        else if (current_state == 3'd0)       from_write_miss <= 1'b0;
    end

    assign state = current_state;

    next_state ns_unit (
        .current_state(current_state),
        .hit(hit), .dirty(dirty),
        .op_read(op_read), .op_write(op_write),
        .nxt(next)
    );

    output_logic out_unit (
        .current_state(current_state),
        .op_read(op_read), .op_write(op_write),
        .from_write_miss(from_write_miss),
        .try_read(try_read), .try_write(try_write),
        .mem_read(mem_read), .mem_write(mem_write),
        .write_hit_en(write_hit_en),
        .read_alloc_en(read_alloc_en),
        .write_alloc_en(write_alloc_en),
        .ready(ready)
    );

endmodule
