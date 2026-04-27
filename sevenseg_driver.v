module sevenseg_driver (
    input         clk,
    input         reset,
    input         tick,
    input  [31:0] hex_data,
    input  [7:0]  dp_mask,
    output reg [6:0] seg,
    output reg    dp,
    output reg [7:0] an
);
    reg [2:0] scan_sel;
    reg [3:0] digit;
    reg       dp_on;


    always @(posedge clk) begin
        if (reset)
            scan_sel <= 3'd0;
        else if (tick)
            scan_sel <= scan_sel + 3'd1;
    end

    always @(*) begin
        case (scan_sel)
            3'd0: begin digit = hex_data[3:0];    dp_on = dp_mask[0]; an = 8'b1111_1110; end
            3'd1: begin digit = hex_data[7:4];    dp_on = dp_mask[1]; an = 8'b1111_1101; end
            3'd2: begin digit = hex_data[11:8];   dp_on = dp_mask[2]; an = 8'b1111_1011; end
            3'd3: begin digit = hex_data[15:12];  dp_on = dp_mask[3]; an = 8'b1111_0111; end
            3'd4: begin digit = hex_data[19:16];  dp_on = dp_mask[4]; an = 8'b1110_1111; end
            3'd5: begin digit = hex_data[23:20];  dp_on = dp_mask[5]; an = 8'b1101_1111; end
            3'd6: begin digit = hex_data[27:24];  dp_on = dp_mask[6]; an = 8'b1011_1111; end
            default: begin digit = hex_data[31:28]; dp_on = dp_mask[7]; an = 8'b0111_1111; end
        endcase
    end

    always @(*) begin
        case (digit)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            default: seg = 7'b0001110;
        endcase
        dp = dp_on;
    end
endmodule