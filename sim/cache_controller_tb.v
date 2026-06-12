`timescale 1ns / 1ps

module cache_controller_tb;

    reg clk;
    reg rst_b;
    reg opcode;
    reg [31:0] data_in; 
    reg [31:0] address; 
    
    wire [31:0] data_out;
    wire hit;
    wire ready;
    wire [2:0] fsm_state;

    cache_controller uut (
        .clk(clk),
        .rst_b(rst_b),
        .opcode(opcode),
        .data_in(data_in),
        .address(address),
        .data_out(data_out),
        .hit(hit),
        .ready(ready),
        .fsm_state(fsm_state)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task send_op(input reg rw, input [31:0] val, input [31:0] addr);
        begin
            @(posedge clk);
            opcode  <= rw;
            data_in <= val;
            address <= addr;
            $display("[Cerere CPU] Op = %5s | Addr = 0x%08h | DataIn = 0x%08h @ %0t ns", 
                     rw ? "WRITE" : "READ", addr, val, $time);
            #1; // permiterea propagarii
        end
    endtask

    task wait_ready;
        begin
            while (!ready)
                @(posedge clk);
            #1; // Evaluare stabila post-front
            $display("[Răspuns Cache] Stare FSM = %0d | READY = %b | HIT/MISS = %5s | DataOut = 0x%08h @ %0t ns\n",
                     fsm_state, ready, hit ? "HIT " : "MISS", data_out, $time);
        end
    endtask

    initial begin
        $dumpfile("cache_sim.vcd");
        $dumpvars(0, cache_controller_tb);
        
        rst_b = 0;
        opcode = 0;
        data_in = 0;
        address = 0;

        #12 rst_b = 1;

        $display("--- TEST 1: READ MISS urmat de READ HIT ---");
        send_op(0, 32'h00000000, 32'h00000010); wait_ready(); 
        send_op(0, 32'h00000000, 32'h00000010); wait_ready(); 

        $display("--- TEST 2: WRITE MISS (Write-Allocate induce dirty) ---");
        send_op(1, 32'hDEADBEEF, 32'h00000080); wait_ready(); 
        
        $display("--- TEST 3: WRITE HIT & READ HIT pe date modificate ---");
        send_op(1, 32'hCAFEBABE, 32'h00000080); wait_ready(); 
        send_op(0, 32'h00000000, 32'h00000080); wait_ready(); 

        $display("--- TEST 4: Citiri pe index diferit ---");
        send_op(0, 32'h00000000, 32'h00002010); wait_ready(); 

        #20;
        $display("Simulare terminata cu succes.");
        $finish;
    end

endmodule