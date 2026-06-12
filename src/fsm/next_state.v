`timescale 1ns/1ps
module next_state (
    input  [3:0] current_state,
    input        hit,
    input        dirty,
    input        op_read,
    input        op_write,
    input        req,
    output reg [3:0] nxt
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

    always @(*) begin
        case (current_state)
            IDLE: begin
                if      (req && op_read  &&  hit) nxt = READ_HIT;
                else if (req && op_read  && !hit) nxt = READ_MISS;
                else if (req && op_write &&  hit) nxt = WRITE_HIT;
                else if (req && op_write && !hit) nxt = WRITE_MISS;
                else                              nxt = IDLE;
            end
            // dirty=1 inseamna ca victima LRU trebuie evacuata inainte de alocare
            READ_MISS:  nxt = dirty ? EVICT_RD : ALLOC_RD;
            WRITE_MISS: nxt = dirty ? EVICT_WR : ALLOC_WR;
            EVICT_RD:   nxt = ALLOC_RD;
            EVICT_WR:   nxt = ALLOC_WR;
            // starile terminale revin in IDLE dupa un singur ciclu
            READ_HIT,
            WRITE_HIT,
            ALLOC_RD,
            ALLOC_WR:   nxt = IDLE;
            default:    nxt = IDLE;
        endcase
    end

endmodule
