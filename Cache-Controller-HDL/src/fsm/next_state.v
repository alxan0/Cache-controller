`timescale 1ns/1ps
module next_state (
    input  [2:0] current_state,
    input        hit,
    input        dirty,
    input        op_read,
    input        op_write,
    output reg [2:0] nxt
);
    localparam IDLE       = 3'd0,
               READ_HIT   = 3'd1,
               READ_MISS  = 3'd2,
               WRITE_HIT  = 3'd3,
               WRITE_MISS = 3'd4,
               EVICT      = 3'd5,
               ALLOCATE   = 3'd6;

    always @(*) begin
        case (current_state)
            IDLE: begin
                if      (op_read  &&  hit) nxt = READ_HIT;
                else if (op_read  && !hit) nxt = READ_MISS;
                else if (op_write &&  hit) nxt = WRITE_HIT;
                else if (op_write && !hit) nxt = WRITE_MISS;
                else                       nxt = IDLE;
            end
            READ_MISS,
            WRITE_MISS: nxt = dirty ? EVICT : ALLOCATE;
            EVICT:      nxt = ALLOCATE;
            READ_HIT,
            WRITE_HIT,
            ALLOCATE:   nxt = IDLE;
            default:    nxt = IDLE;
        endcase
    end

endmodule
