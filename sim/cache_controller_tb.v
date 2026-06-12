`timescale 1ns / 1ps
module cache_controller_tb;

    reg        clk;
    reg        rst_b;
    reg        req;
    reg        opcode;
    reg [31:0] data_in;
    reg [31:0] address;

    wire [31:0] data_out;
    wire        hit;
    wire        ready;
    wire [3:0]  fsm_state;

    cache_controller uut (
        .clk      (clk),
        .rst_b    (rst_b),
        .req      (req),
        .opcode   (opcode),
        .data_in  (data_in),
        .address  (address),
        .data_out (data_out),
        .hit      (hit),
        .ready    (ready),
        .fsm_state(fsm_state)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    function [63:0] state_name;
        input [3:0] s;
        begin
            case (s)
                4'd0: state_name = "IDLE    ";
                4'd1: state_name = "RD_HIT  ";
                4'd2: state_name = "RD_MISS ";
                4'd3: state_name = "WR_HIT  ";
                4'd4: state_name = "WR_MISS ";
                4'd5: state_name = "EVICT_RD";
                4'd6: state_name = "EVICT_WR";
                4'd7: state_name = "ALLOC_RD";
                4'd8: state_name = "ALLOC_WR";
                default: state_name = "UNKNOWN ";
            endcase
        end
    endfunction

    integer cycle_count;
    integer hit_count;
    integer miss_count;
    integer op_cycles;

    initial begin
        cycle_count = 0;
        hit_count   = 0;
        miss_count  = 0;
    end

    always @(posedge clk) begin
        if (rst_b) cycle_count = cycle_count + 1;
    end

    task send_op;
        input        rw;
        input [31:0] val;
        input [31:0] addr;
        begin
            @(posedge clk); #1;
            req     = 1;
            opcode  = rw;
            data_in = val;
            address = addr;
            $display("");
            if (rw)
                $display("  Procesor solicita SCRIERE la adresa 0x%08h  (data: 0x%08h, ciclu %0d)",
                         addr, val, cycle_count);
            else
                $display("  Procesor solicita CITIRE  de la adresa 0x%08h  (ciclu %0d)",
                         addr, cycle_count);
        end
    endtask

    task wait_ready;
        begin
            op_cycles = 0;
            @(posedge clk); #1;
            while (!ready) begin
                @(posedge clk); #1;
                op_cycles = op_cycles + 1;
                $display("    Cache-ul proceseaza  -->  stare: %s  |  dirty=%b  |  ciclu intern: %0d",
                         state_name(fsm_state), uut.dirty, op_cycles);
            end
            if (hit) hit_count  = hit_count  + 1;
            else     miss_count = miss_count + 1;
            if (hit)
                $display("  Rezultat: HIT  -- data returnata: 0x%08h  (%0d ciclu(ri))",
                         data_out, op_cycles + 1);
            else
                $display("  Rezultat: MISS -- linie alocata in starea %s  (%0d ciclu(ri))",
                         state_name(fsm_state), op_cycles + 1);
            @(posedge clk); #1;
            req = 0;
        end
    endtask

    task do_op;
        input        rw;
        input [31:0] val;
        input [31:0] addr;
        begin
            send_op(rw, val, addr);
            wait_ready();
        end
    endtask

    initial begin
        $dumpfile("cache_sim.vcd");
        $dumpvars(0, cache_controller_tb);

        rst_b   = 0;
        req     = 0;
        opcode  = 0;
        data_in = 32'h0;
        address = 32'h0;
        repeat(3) @(posedge clk);
        #1; rst_b = 1;
        @(posedge clk); #1;

        $display("TEST 1: Prima citire -- adresa nu e in cache");
        $display("  Asteptat: READ MISS urmat de alocare");
        do_op(0, 32'h00000000, 32'h00000010);

        $display("\nTEST 2: A doua citire la aceeasi adresa");
        $display("  Asteptat: READ HIT -- data vine direct din cache");
        do_op(0, 32'h00000000, 32'h00000010);

        $display("\nTEST 3: Scriere la adresa noua");
        $display("  Asteptat: WRITE MISS cu Write-Allocate");
        $display("  Linia e alocata si marcata dirty (write-back)");
        do_op(1, 32'hDEADBEEF, 32'h00000080);

        $display("\nTEST 4: Scriere la adresa deja alocata");
        $display("  Asteptat: WRITE HIT -- actualizare in cache");
        do_op(1, 32'hCAFEBABE, 32'h00000080);

        $display("\nTEST 5: Citire dupa scriere la aceeasi adresa");
        $display("  Asteptat: READ HIT cu data noua (0xCAFEBABE)");
        do_op(0, 32'h00000000, 32'h00000080);

        $display("\nTEST 6: Citire la adresa cu tag diferit in acelasi set");
        $display("  Asteptat: READ MISS -- tag-ul nu este prezent in cache");
        do_op(0, 32'h00000000, 32'h00002010);

        $display("\nTEST 7: Umplere completa a unui set + EVICT");
        $display("  4 scrieri (WRITE MISS) umplu toate cele 4 ways");
        $display("  Al 5-lea acces forteaza evacuarea LRU dirty");
        $display("  Asteptat: RD_MISS -> EVICT_RD -> ALLOC_RD");
        do_op(1, 32'hAAAA0000, 32'h00000140);
        do_op(1, 32'hAAAA0001, 32'h00002140);
        do_op(1, 32'hAAAA0002, 32'h00004140);
        do_op(1, 32'hAAAA0003, 32'h00006140);
        $display("\n  Toate cele 4 ways sunt pline si dirty.");
        $display("  Urmatoarea citire va declansa evacuarea LRU:");
        do_op(0, 32'h00000000, 32'h00008140);

        $display("\nTEST 8: Acces la word diferit in aceeasi linie");
        $display("  Adresa 0x14 si 0x10 sunt in acelasi bloc (index 0, tag 0)");
        $display("  Asteptat: WRITE HIT apoi READ HIT cu data scrisa");
        do_op(1, 32'h12345678, 32'h00000014);
        do_op(0, 32'h00000000, 32'h00000014);

        #20;
        $display("\nRezultate finale:");
        $display("  Total operatii : %0d", hit_count + miss_count);
        $display("  Hit-uri        : %0d  (acces direct din cache)",  hit_count);
        $display("  Miss-uri       : %0d  (a necesitat alocare)",     miss_count);
        $display("  Rata de hit    : %0.1f%%",
                 100.0 * hit_count / (hit_count + miss_count));
        $display("  Cicluri totale : %0d\n", cycle_count);
        $display("Simulare finalizata cu succes.");
        $finish;
    end

    always @(fsm_state) begin
        if (rst_b)
            $display("    Cache-ul a intrat in starea  %s  la T=%0t ns",
                     state_name(fsm_state), $time);
    end

endmodule
