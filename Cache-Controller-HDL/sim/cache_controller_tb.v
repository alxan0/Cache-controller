`timescale 1ns / 1ps

module cache_controller_tb;

    // -----------------------------------------------------------------------
    // DUT interface
    // -----------------------------------------------------------------------
    reg         clk;
    reg         rst_b;
    reg         opcode;
    reg  [31:0] address;
    reg  [31:0] data_in;

    wire [31:0] data_out;
    wire [2:0]  fsm_state;
    wire        hit;
    wire        ready;

    cache_controller dut (
        .clk(clk), .rst_b(rst_b),
        .opcode(opcode),
        .address(address), .data_in(data_in),
        .data_out(data_out), .fsm_state(fsm_state),
        .hit(hit), .ready(ready)
    );

    // -----------------------------------------------------------------------
    // Clock: 10 ns period
    // -----------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Statistics
    // -----------------------------------------------------------------------
    integer total_ops;
    integer total_hits;

    // -----------------------------------------------------------------------
    // State name helper (11 chars wide)
    // -----------------------------------------------------------------------
    function [87:0] state_name;
        input [2:0] s;
        begin
            case (s)
                3'd0: state_name = "IDLE      ";
                3'd1: state_name = "READ_HIT  ";
                3'd2: state_name = "READ_MISS ";
                3'd3: state_name = "WRITE_HIT ";
                3'd4: state_name = "WRITE_MISS";
                3'd5: state_name = "EVICT     ";
                3'd6: state_name = "ALLOCATE  ";
                default: state_name = "UNKNOWN   ";
            endcase
        end
    endfunction

    // -----------------------------------------------------------------------
    // Task: perform one read or write operation.
    // Inputs are applied at negedge so the FSM sees stable signals on the
    // following posedge.  A #1 delay after each @(posedge clk) lets all
    // non-blocking assignments commit before we read registered outputs.
    // -----------------------------------------------------------------------
    task do_op;
        input        rw;
        input [31:0] addr;
        input [31:0] wdata;
        integer timeout;
        begin
            @(negedge clk);         // drive inputs half-cycle before posedge
            opcode  = rw;
            address = addr;
            data_in = wdata;

            @(posedge clk); #1;     // FSM transitions; wait for NBAs to commit

            timeout = 0;
            while (!ready && timeout < 20) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
            end

            total_ops  = total_ops  + 1;
            total_hits = total_hits + hit;
            $display("  [%5d ns]  %-5s  addr=%08h  data=%08h  state=%-10s  %s",
                $time,
                rw ? "WRITE" : "READ",
                addr,
                rw ? wdata : data_out,
                state_name(fsm_state),
                hit ? "HIT " : "MISS");

            @(posedge clk); #1;     // let FSM return to IDLE
        end
    endtask

    // -----------------------------------------------------------------------
    // Address helper: {tag[18:0], index[6:0], 6'b0}
    // -----------------------------------------------------------------------
    function [31:0] make_addr;
        input [18:0] tag;
        input [6:0]  idx;
        begin
            make_addr = {tag, idx, 6'b000000};
        end
    endfunction

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("cache_sim.vcd");
        $dumpvars(0, cache_controller_tb);

        total_ops  = 0;
        total_hits = 0;

        rst_b   = 0;
        opcode  = 0;
        address = 0;
        data_in = 0;
        #22;
        rst_b = 1;
        @(posedge clk); #1;

        $display("=== Cache Controller Simulation ===");
        $display("    4-way set-associative, 128 sets, LRU, write-back/write-allocate");
        $display("");

        // -------------------------------------------------------------------
        // Group 1: Read miss then read hit (same address)
        // FSM path:  IDLE -> READ_MISS -> ALLOCATE -> IDLE
        //            IDLE -> READ_HIT  -> IDLE
        // -------------------------------------------------------------------
        $display("--- Group 1: Read miss / read hit ---");
        do_op(0, make_addr(19'd0, 7'd0), 32'h0);           // MISS
        do_op(0, make_addr(19'd0, 7'd0), 32'h0);           // HIT

        // -------------------------------------------------------------------
        // Group 2: Write hit, then verify the written data reads back
        // FSM path:  IDLE -> WRITE_HIT -> IDLE
        // -------------------------------------------------------------------
        $display("--- Group 2: Write hit + readback ---");
        do_op(1, make_addr(19'd0, 7'd0), 32'hDEAD_BEEF);   // HIT (write)
        do_op(0, make_addr(19'd0, 7'd0), 32'h0);           // HIT (read: should return 0xDEADBEEF)

        // -------------------------------------------------------------------
        // Group 3: Write miss (write-allocate, clean LRU, no eviction)
        // FSM path:  IDLE -> WRITE_MISS -> ALLOCATE -> IDLE
        // -------------------------------------------------------------------
        $display("--- Group 3: Write miss (write-allocate) ---");
        do_op(1, make_addr(19'd1, 7'd5), 32'hCAFE_0001);   // MISS
        do_op(0, make_addr(19'd1, 7'd5), 32'h0);           // HIT (data should be 0xCAFE0001)

        // -------------------------------------------------------------------
        // Group 4: Fill all 4 ways of set 10, then trigger an EVICT
        // After four allocations, the access order A < B < C < D makes A the
        // LRU.  We write to A (dirty), then access a 5th tag in the same set.
        // FSM path for tag4: IDLE -> READ_MISS -> EVICT -> ALLOCATE -> IDLE
        // -------------------------------------------------------------------
        $display("--- Group 4: Fill 4 ways + eviction ---");
        do_op(0, make_addr(19'd0, 7'd10), 32'h0);          // MISS -> fill way A
        do_op(0, make_addr(19'd1, 7'd10), 32'h0);          // MISS -> fill way B
        do_op(0, make_addr(19'd2, 7'd10), 32'h0);          // MISS -> fill way C
        do_op(0, make_addr(19'd3, 7'd10), 32'h0);          // MISS -> fill way D
        // Re-access B, C, D to push A to LRU
        do_op(0, make_addr(19'd1, 7'd10), 32'h0);          // HIT
        do_op(0, make_addr(19'd2, 7'd10), 32'h0);          // HIT
        do_op(0, make_addr(19'd3, 7'd10), 32'h0);          // HIT
        // Write to A -> A becomes dirty (but also MRU after write hit)
        do_op(1, make_addr(19'd0, 7'd10), 32'hAABB_CCDD);  // HIT (write -> dirty)
        // Access the least recently used way (B is now LRU after A was just written)
        do_op(1, make_addr(19'd1, 7'd10), 32'h0);          // HIT
        do_op(1, make_addr(19'd2, 7'd10), 32'h0);          // HIT
        do_op(1, make_addr(19'd3, 7'd10), 32'h0);          // HIT
        // Tag4: new address -> LRU way (A, still dirty from write) -> EVICT then ALLOCATE
        do_op(0, make_addr(19'd4, 7'd10), 32'h0);          // MISS + EVICT
        do_op(0, make_addr(19'd4, 7'd10), 32'h0);          // HIT

        // -------------------------------------------------------------------
        // Group 5: Different set indices are independent
        // -------------------------------------------------------------------
        $display("--- Group 5: Independence of sets ---");
        do_op(0, make_addr(19'd5, 7'd20), 32'h0);          // MISS (set 20)
        do_op(0, make_addr(19'd5, 7'd21), 32'h0);          // MISS (set 21)
        do_op(0, make_addr(19'd5, 7'd20), 32'h0);          // HIT  (set 20)
        do_op(0, make_addr(19'd5, 7'd21), 32'h0);          // HIT  (set 21)

        // -------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------
        $display("");
        $display("=== Simulation complete ===");
        $display("    Total operations : %0d", total_ops);
        $display("    Hits             : %0d", total_hits);
        $display("    Misses           : %0d", total_ops - total_hits);
        if (total_ops > 0)
            $display("    Hit rate         : %0d%%",
                (total_hits * 100) / total_ops);

        $finish;
    end

endmodule
