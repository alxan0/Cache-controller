`timescale 1ns/1ps
// FSM-ul cacheului: registru de stare + logica de tranzitie + logica de iesire.
module cache_fsm (
    input  clk,
    input  rst_b,
    input  hit,
    input  dirty,
    input  op_read,
    input  op_write,
    input  req,
    output [3:0] state,
    output try_read,
    output try_write,
    output mem_read,
    output mem_write,
    output write_hit_en,
    output read_alloc_en,
    output write_alloc_en,
    output ready
);
    wire [3:0] next;
    reg  [3:0] current_state;

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) current_state <= 4'd0;
        else        current_state <= next;
    end

    assign state = current_state;

    next_state ns_unit (
        .current_state(current_state),
        .hit(hit), .dirty(dirty),
        .op_read(op_read), .op_write(op_write),
        .req(req),
        .nxt(next)
    );

    // Iesiri Moore: depind doar de starea curenta
    output_logic out_unit (
        .current_state(current_state),
        .op_read(op_read), .op_write(op_write),
        .req(req),
        .try_read(try_read),   .try_write(try_write),
        .mem_read(mem_read),   .mem_write(mem_write),
        .write_hit_en(write_hit_en),
        .read_alloc_en(read_alloc_en),
        .write_alloc_en(write_alloc_en),
        .ready(ready)
    );

endmodule
