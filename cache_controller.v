`timescale 1ns/1ps
// Nivel top-level: leaga FSM-ul de tabloul de cache.
module cache_controller #(
    parameter ADDR_WIDTH = 32,
    parameter TAG_SIZE   = 19,
    parameter INDEX_SIZE = 7,
    parameter WORD_SIZE  = 32,
    parameter NUM_SETS   = 128
)(
    input  clk,
    input  rst_b,
    input  req,
    input  opcode,
    input  [WORD_SIZE-1:0]  data_in,
    input  [ADDR_WIDTH-1:0] address,
    output [WORD_SIZE-1:0]  data_out,
    output [3:0]            fsm_state,
    output                  hit,
    output                  ready
);
    wire dirty;
    // opcode 0 = read, 1 = write
    wire op_read  = ~opcode;
    wire op_write =  opcode;

    wire try_read, try_write;
    wire mem_read, mem_write;
    wire write_hit_en, read_alloc_en, write_alloc_en;

    cache_fsm fsm (
        .clk(clk), .rst_b(rst_b),
        .hit(hit), .dirty(dirty),
        .op_read(op_read), .op_write(op_write),
        .req(req),
        .state(fsm_state),
        .try_read(try_read),   .try_write(try_write),
        .mem_read(mem_read),   .mem_write(mem_write),
        .write_hit_en(write_hit_en),
        .read_alloc_en(read_alloc_en),
        .write_alloc_en(write_alloc_en),
        .ready(ready)
    );

    cache_array # (
        .ADDR_WIDTH(ADDR_WIDTH), .TAG_SIZE(TAG_SIZE),
        .INDEX_SIZE(INDEX_SIZE), .WORD_SIZE(WORD_SIZE),
        .NUM_SETS(NUM_SETS)
    ) cache (
        .clk(clk), .rst_b(rst_b),
        .address(address),
        .write_data(data_in),
        .try_read(try_read),   .try_write(try_write),
        .write_hit_en(write_hit_en),
        .read_alloc_en(read_alloc_en),
        .write_alloc_en(write_alloc_en),
        .data_out(data_out),
        .hit(hit), .dirty(dirty)
    );

endmodule
