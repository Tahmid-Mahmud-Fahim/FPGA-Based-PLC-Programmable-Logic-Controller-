module tick_gen (
    input  clk,
    input  reset,
    output reg tick_1ms,
    output reg tick_disp
);
    reg [16:0] cnt_1ms;
    reg [15:0] cnt_disp;

    always @(posedge clk) begin
        if (reset) begin
            cnt_1ms   <= 17'd0;
            cnt_disp  <= 16'd0;
            tick_1ms  <= 1'b0;
            tick_disp <= 1'b0;
        end
        else begin
            tick_1ms  <= 1'b0;
            tick_disp <= 1'b0;

            if (cnt_1ms == 17'd99999) begin
                cnt_1ms  <= 17'd0;
                tick_1ms <= 1'b1;
            end
            else begin
                cnt_1ms <= cnt_1ms + 17'd1;
            end

            if (cnt_disp == 16'd4999) begin
                cnt_disp  <= 16'd0;
                tick_disp <= 1'b1;
            end
            else begin
                cnt_disp <= cnt_disp + 16'd1;
            end
        end
    end
endmodule