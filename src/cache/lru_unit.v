`timescale 1ns/1ps
module lru_unit (
    input      clk,
    input      rst_b,
    input [1:0] access_way,
    input       update_en,
    output [1:0] lru_way
);
    reg [1:0] age [3:0];

    assign lru_way = (age[0] == 2'd0) ? 2'd0 :
                     (age[1] == 2'd0) ? 2'd1 :
                     (age[2] == 2'd0) ? 2'd2 : 2'd3;

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            age[0] <= 2'd0;
            age[1] <= 2'd1;
            age[2] <= 2'd2;
            age[3] <= 2'd3;
        end else if (update_en) begin
            age[access_way] <= 2'd3;
            if (access_way != 2'd0 && age[0] > age[access_way]) age[0] <= age[0] - 2'd1;
            if (access_way != 2'd1 && age[1] > age[access_way]) age[1] <= age[1] - 2'd1;
            if (access_way != 2'd2 && age[2] > age[access_way]) age[2] <= age[2] - 2'd1;
            if (access_way != 2'd3 && age[3] > age[access_way]) age[3] <= age[3] - 2'd1;
        end
    end

endmodule
