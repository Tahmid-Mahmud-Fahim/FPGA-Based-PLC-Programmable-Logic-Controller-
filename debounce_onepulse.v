module debounce_onepulse #(
    parameter integer COUNT_MAX = 100000
) (
    input  clk,
    input  reset,
    input  din,
    output reg level,
    output reg pulse
);
    reg sync0, sync1;
    reg [31:0] cnt;

    always @(posedge clk) begin
        if (reset) begin
            sync0 <= 1'b0;
            sync1 <= 1'b0;
            cnt   <= 32'd0;
            level <= 1'b0;
            pulse <= 1'b0;
        end
        else begin
            sync0 <= din;
            sync1 <= sync0;
            pulse <= 1'b0;

            if (sync1 == level) begin
                cnt <= 32'd0;
            end
            else begin
                if (cnt == (COUNT_MAX-1)) begin
                    cnt   <= 32'd0;
                    level <= sync1;
                    if (sync1)
                        pulse <= 1'b1;
                end
                else begin
                    cnt <= cnt + 32'd1;
                end
            end
        end
    end
endmodule