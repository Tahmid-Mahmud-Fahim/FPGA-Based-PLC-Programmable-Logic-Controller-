module plc_multi_rung_top (
    input         CLK100MHZ,
    input         CPU_RESETN,
    input  [15:0] sw,
    input         BTNC,
    input         BTNU,
    input         BTND,
    input         BTNL,
    input         BTNR,
    output reg [15:0] LED,
    output [6:0]  seg,
    output        dp,
    output [7:0]  an
);

    localparam integer MAX_RUNGS   = 8;
    localparam integer LANES       = 3;
    localparam integer LOGIC_COLS  = 7;
    localparam integer CELLS_PER_R = LANES * LOGIC_COLS;   // 21
    localparam integer TOTAL_CELLS = MAX_RUNGS * CELLS_PER_R;

    localparam integer N_INPUTS    = 20;  // sw[14:0] + 5 buttons
    localparam integer N_OUTPUTS   = 16;
    localparam integer N_MARKERS   = 16;
    localparam integer N_TIMERS    = 8;
    localparam integer N_COUNTERS  = 8;

    localparam [1:0] CT_EMPTY = 2'd0;
    localparam [1:0] CT_WIRE  = 2'd1;
    localparam [1:0] CT_NO    = 2'd2;
    localparam [1:0] CT_NC    = 2'd3;

    localparam [2:0] SRC_NONE   = 3'd0;
    localparam [2:0] SRC_I      = 3'd1;
    localparam [2:0] SRC_Q      = 3'd2;
    localparam [2:0] SRC_M      = 3'd3;
    localparam [2:0] SRC_TONDN  = 3'd4;
    localparam [2:0] SRC_TOFDN  = 3'd5;
    localparam [2:0] SRC_CDN    = 3'd6;

    localparam [3:0] ACT_NONE    = 4'd0;
    localparam [3:0] ACT_COIL_Q  = 4'd1;
    localparam [3:0] ACT_SET_Q   = 4'd2;
    localparam [3:0] ACT_RST_Q   = 4'd3;
    localparam [3:0] ACT_COIL_M  = 4'd4;
    localparam [3:0] ACT_SET_M   = 4'd5;
    localparam [3:0] ACT_RST_M   = 4'd6;
    localparam [3:0] ACT_TON     = 4'd7;
    localparam [3:0] ACT_TOF     = 4'd8;
    localparam [3:0] ACT_CTU     = 4'd9;
    localparam [3:0] ACT_RESC    = 4'd10;

    reg [1:0] cell_type      [0:TOTAL_CELLS-1];
    reg [2:0] cell_src_class [0:TOTAL_CELLS-1];
    reg [4:0] cell_src_idx   [0:TOTAL_CELLS-1];

    reg [3:0]  rung_action_type [0:MAX_RUNGS-1];
    reg [3:0]  rung_action_idx  [0:MAX_RUNGS-1];
    reg [15:0] rung_action_pre  [0:MAX_RUNGS-1];

    reg [N_OUTPUTS-1:0] Q_table;
    reg [N_MARKERS-1:0] M_table;

    reg [15:0] TON_accum [0:N_TIMERS-1];
    reg [15:0] TON_preset[0:N_TIMERS-1];
    reg        TON_dn    [0:N_TIMERS-1];
    reg        TON_en    [0:N_TIMERS-1];

    reg [15:0] TOF_accum [0:N_TIMERS-1];
    reg [15:0] TOF_preset[0:N_TIMERS-1];
    reg        TOF_dn    [0:N_TIMERS-1];
    reg        TOF_en    [0:N_TIMERS-1];

    reg [15:0] C_accum [0:N_COUNTERS-1];
    reg [15:0] C_preset[0:N_COUNTERS-1];
    reg        C_dn    [0:N_COUNTERS-1];
    reg        C_prev_en [0:N_COUNTERS-1];

    reg [7:0] rung_true_reg;
    reg [7:0] rung_vis_reg;

    reg [2:0] edit_page;
    reg [2:0] cur_rung;
    reg [1:0] cur_lane;
    reg [2:0] cur_col;
    reg [2:0] active_rungs_m1;
    reg       prog_dirty;
    reg       prog_valid_reg;
    reg [7:0] error_code_reg;
    reg       run_mode_d;

    wire reset_i;
    wire tick_1ms;
    wire tick_disp;
    wire btnc_level, btnu_level, btnd_level, btnl_level, btnr_level;
    wire btnc_pulse, btnu_pulse, btnd_pulse, btnl_pulse, btnr_pulse;
    wire run_mode;

    reg [N_INPUTS-1:0] I_run_vec;

    reg [N_OUTPUTS-1:0] q_scan_comb;
    reg [N_MARKERS-1:0] m_scan_comb;
    reg [N_TIMERS-1:0]  ton_en_comb;
    reg [N_TIMERS-1:0]  tof_en_comb;
    reg [N_COUNTERS-1:0] ctu_en_comb;
    reg [N_COUNTERS-1:0] resc_pulse_comb;
    reg [7:0] rung_true_comb;
    reg [7:0] rung_vis_comb;
    reg [15:0] ton_preset_next [0:N_TIMERS-1];
    reg [15:0] tof_preset_next [0:N_TIMERS-1];
    reg [15:0] c_preset_next   [0:N_COUNTERS-1];

    reg [31:0] disp_hex;
    reg [7:0]  disp_dp;

    reg prog_valid_comb;
    reg [7:0] error_code_comb;

    integer val_r, val_l, val_c, val_idx;
    reg     val_has_any;

    integer scan_r, scan_l, scan_c, scan_idx, scan_t;
    reg     scan_srcbit;
    reg     scan_lane_true;
    reg     scan_lane_any;
    reg     scan_rung_true_local;

    integer disp_idx;
    reg [1:0]  disp_cur_type;
    reg [2:0]  disp_cur_src_class;
    reg [4:0]  disp_cur_src_idx;
    reg [3:0]  disp_cur_act_type;
    reg [3:0]  disp_cur_act_idx;
    reg [15:0] disp_cur_act_pre;
    reg [15:0] led_edit;

    integer seq_i, seq_r, seq_l, seq_c, seq_idx, seq_t;
    integer seq_cnext;

    assign reset_i = ~CPU_RESETN;
    assign run_mode = sw[15];

    function integer CIDX;
        input integer rung_id;
        input integer lane_id;
        input integer col_id;
        begin
            CIDX = (rung_id * CELLS_PER_R) + (lane_id * LOGIC_COLS) + col_id;
        end
    endfunction

    function src_value;
        input [2:0] src_class;
        input [4:0] src_idx;
        input [N_INPUTS-1:0]   I_vec;
        input [N_OUTPUTS-1:0]  Q_vec;
        input [N_MARKERS-1:0]  M_vec;
        begin
            case (src_class)
                SRC_I:     src_value = I_vec[src_idx];
                SRC_Q:     src_value = Q_vec[src_idx];
                SRC_M:     src_value = M_vec[src_idx];
                SRC_TONDN: src_value = TON_dn[src_idx[2:0]];
                SRC_TOFDN: src_value = TOF_dn[src_idx[2:0]];
                SRC_CDN:   src_value = C_dn[src_idx[2:0]];
                default:   src_value = 1'b0;
            endcase
        end
    endfunction

    tick_gen u_tick_gen (
        .clk       (CLK100MHZ),
        .reset     (reset_i),
        .tick_1ms  (tick_1ms),
        .tick_disp (tick_disp)
    );

    debounce_onepulse #(.COUNT_MAX(100000)) u_db_c (
        .clk(CLK100MHZ), .reset(reset_i), .din(BTNC), .level(btnc_level), .pulse(btnc_pulse)
    );
    debounce_onepulse #(.COUNT_MAX(100000)) u_db_u (
        .clk(CLK100MHZ), .reset(reset_i), .din(BTNU), .level(btnu_level), .pulse(btnu_pulse)
    );
    debounce_onepulse #(.COUNT_MAX(100000)) u_db_d (
        .clk(CLK100MHZ), .reset(reset_i), .din(BTND), .level(btnd_level), .pulse(btnd_pulse)
    );
    debounce_onepulse #(.COUNT_MAX(100000)) u_db_l (
        .clk(CLK100MHZ), .reset(reset_i), .din(BTNL), .level(btnl_level), .pulse(btnl_pulse)
    );
    debounce_onepulse #(.COUNT_MAX(100000)) u_db_r (
        .clk(CLK100MHZ), .reset(reset_i), .din(BTNR), .level(btnr_level), .pulse(btnr_pulse)
    );

    sevenseg_driver u_sevenseg (
        .clk      (CLK100MHZ),
        .reset    (reset_i),
        .tick     (tick_disp),
        .hex_data (disp_hex),
        .dp_mask  (disp_dp),
        .seg      (seg),
        .dp       (dp),
        .an       (an)
    );

    always @(*) begin
        I_run_vec[14:0] = sw[14:0];
        I_run_vec[15]   = btnl_level;
        I_run_vec[16]   = btnr_level;
        I_run_vec[17]   = btnu_level;
        I_run_vec[18]   = btnd_level;
        I_run_vec[19]   = btnc_level;
    end

    always @(*) begin
        prog_valid_comb = 1'b1;
        error_code_comb = 8'h00;

        for (val_r = 0; val_r < MAX_RUNGS; val_r = val_r + 1) begin
            if (val_r <= active_rungs_m1) begin
                val_has_any = 1'b0;
                for (val_l = 0; val_l < LANES; val_l = val_l + 1) begin
                    for (val_c = 0; val_c < LOGIC_COLS; val_c = val_c + 1) begin
                        val_idx = CIDX(val_r, val_l, val_c);
                        if (cell_type[val_idx] != CT_EMPTY)
                            val_has_any = 1'b1;
                    end
                end

                if (!val_has_any && prog_valid_comb) begin
                    prog_valid_comb = 1'b0;
                    error_code_comb = 8'h01;
                end
                else if ((rung_action_type[val_r] == ACT_NONE) && prog_valid_comb) begin
                    prog_valid_comb = 1'b0;
                    error_code_comb = 8'h02;
                end
            end
        end
    end

    always @(*) begin
        for (scan_t = 0; scan_t < N_TIMERS; scan_t = scan_t + 1) begin
            ton_preset_next[scan_t] = TON_preset[scan_t];
            tof_preset_next[scan_t] = TOF_preset[scan_t];
        end

        for (scan_t = 0; scan_t < N_COUNTERS; scan_t = scan_t + 1) begin
            c_preset_next[scan_t] = C_preset[scan_t];
        end

        q_scan_comb      = Q_table;
        m_scan_comb      = M_table;
        ton_en_comb      = {N_TIMERS{1'b0}};
        tof_en_comb      = {N_TIMERS{1'b0}};
        ctu_en_comb      = {N_COUNTERS{1'b0}};
        resc_pulse_comb  = {N_COUNTERS{1'b0}};
        rung_true_comb   = 8'h00;
        rung_vis_comb    = 8'h00;

        for (scan_r = 0; scan_r < MAX_RUNGS; scan_r = scan_r + 1) begin
            if (scan_r <= active_rungs_m1) begin
                scan_rung_true_local = 1'b0;

                for (scan_l = 0; scan_l < LANES; scan_l = scan_l + 1) begin
                    scan_lane_true = 1'b1;
                    scan_lane_any  = 1'b0;

                    for (scan_c = 0; scan_c < LOGIC_COLS; scan_c = scan_c + 1) begin
                        scan_idx = CIDX(scan_r, scan_l, scan_c);
                        if (cell_type[scan_idx] != CT_EMPTY) begin
                            scan_lane_any = 1'b1;

                            case (cell_type[scan_idx])
                                CT_WIRE: scan_srcbit = 1'b1;
                                CT_NO: begin
                                    scan_srcbit = src_value(
                                        cell_src_class[scan_idx],
                                        cell_src_idx[scan_idx],
                                        I_run_vec,
                                        q_scan_comb,
                                        m_scan_comb
                                    );
                                end
                                CT_NC: begin
                                    scan_srcbit = ~src_value(
                                        cell_src_class[scan_idx],
                                        cell_src_idx[scan_idx],
                                        I_run_vec,
                                        q_scan_comb,
                                        m_scan_comb
                                    );
                                end
                                default: scan_srcbit = 1'b1;
                            endcase

                            scan_lane_true = scan_lane_true & scan_srcbit;
                        end
                    end

                    if (scan_lane_any && scan_lane_true)
                        scan_rung_true_local = 1'b1;
                end

                rung_true_comb[scan_r] = scan_rung_true_local;

                case (rung_action_type[scan_r])
                    ACT_COIL_Q: begin
                        if (rung_action_idx[scan_r] < N_OUTPUTS)
                            q_scan_comb[rung_action_idx[scan_r]] = scan_rung_true_local;
                    end

                    ACT_SET_Q: begin
                        if (scan_rung_true_local && (rung_action_idx[scan_r] < N_OUTPUTS))
                            q_scan_comb[rung_action_idx[scan_r]] = 1'b1;
                    end

                    ACT_RST_Q: begin
                        if (scan_rung_true_local && (rung_action_idx[scan_r] < N_OUTPUTS))
                            q_scan_comb[rung_action_idx[scan_r]] = 1'b0;
                    end

                    ACT_COIL_M: begin
                        if (rung_action_idx[scan_r] < N_MARKERS)
                            m_scan_comb[rung_action_idx[scan_r]] = scan_rung_true_local;
                    end

                    ACT_SET_M: begin
                        if (scan_rung_true_local && (rung_action_idx[scan_r] < N_MARKERS))
                            m_scan_comb[rung_action_idx[scan_r]] = 1'b1;
                    end

                    ACT_RST_M: begin
                        if (scan_rung_true_local && (rung_action_idx[scan_r] < N_MARKERS))
                            m_scan_comb[rung_action_idx[scan_r]] = 1'b0;
                    end

                    ACT_TON: begin
                        if (rung_action_idx[scan_r][2:0] < N_TIMERS) begin
                            ton_en_comb[rung_action_idx[scan_r][2:0]] = scan_rung_true_local;
                            ton_preset_next[rung_action_idx[scan_r][2:0]] = rung_action_pre[scan_r];
                        end
                    end

                    ACT_TOF: begin
                        if (rung_action_idx[scan_r][2:0] < N_TIMERS) begin
                            tof_en_comb[rung_action_idx[scan_r][2:0]] = scan_rung_true_local;
                            tof_preset_next[rung_action_idx[scan_r][2:0]] = rung_action_pre[scan_r];
                        end
                    end

                    ACT_CTU: begin
                        if (rung_action_idx[scan_r][2:0] < N_COUNTERS) begin
                            ctu_en_comb[rung_action_idx[scan_r][2:0]] = scan_rung_true_local;
                            c_preset_next[rung_action_idx[scan_r][2:0]] = rung_action_pre[scan_r];
                        end
                    end

                    ACT_RESC: begin
                        if (scan_rung_true_local && (rung_action_idx[scan_r][2:0] < N_COUNTERS))
                            resc_pulse_comb[rung_action_idx[scan_r][2:0]] = 1'b1;
                    end

                    default: begin
                    end
                endcase

                case (rung_action_type[scan_r])
                    ACT_COIL_Q,
                    ACT_SET_Q,
                    ACT_RST_Q: begin
                        if (rung_action_idx[scan_r] < N_OUTPUTS)
                            rung_vis_comb[scan_r] = q_scan_comb[rung_action_idx[scan_r]];
                        else
                            rung_vis_comb[scan_r] = scan_rung_true_local;
                    end

                    ACT_COIL_M,
                    ACT_SET_M,
                    ACT_RST_M: begin
                        if (rung_action_idx[scan_r] < N_MARKERS)
                            rung_vis_comb[scan_r] = m_scan_comb[rung_action_idx[scan_r]];
                        else
                            rung_vis_comb[scan_r] = scan_rung_true_local;
                    end

                    ACT_TON: begin
                        if (rung_action_idx[scan_r][2:0] < N_TIMERS)
                            rung_vis_comb[scan_r] = TON_dn[rung_action_idx[scan_r][2:0]];
                        else
                            rung_vis_comb[scan_r] = scan_rung_true_local;
                    end

                    ACT_TOF: begin
                        if (rung_action_idx[scan_r][2:0] < N_TIMERS)
                            rung_vis_comb[scan_r] = TOF_dn[rung_action_idx[scan_r][2:0]];
                        else
                            rung_vis_comb[scan_r] = scan_rung_true_local;
                    end

                    ACT_CTU,
                    ACT_RESC: begin
                        if (rung_action_idx[scan_r][2:0] < N_COUNTERS)
                            rung_vis_comb[scan_r] = C_dn[rung_action_idx[scan_r][2:0]];
                        else
                            rung_vis_comb[scan_r] = scan_rung_true_local;
                    end

                    default: begin
                        rung_vis_comb[scan_r] = scan_rung_true_local;
                    end
                endcase
            end
            else begin
                rung_true_comb[scan_r] = 1'b0;
                rung_vis_comb[scan_r]  = 1'b0;
            end
        end
    end

    always @(*) begin
        disp_idx = CIDX(cur_rung, cur_lane, cur_col);

        disp_cur_type      = cell_type[disp_idx];
        disp_cur_src_class = cell_src_class[disp_idx];
        disp_cur_src_idx   = cell_src_idx[disp_idx];
        disp_cur_act_type  = rung_action_type[cur_rung];
        disp_cur_act_idx   = rung_action_idx[cur_rung];
        disp_cur_act_pre   = rung_action_pre[cur_rung];

        led_edit = 16'h0000;
        led_edit[2:0]   = cur_col;
        led_edit[4:3]   = cur_lane;
        led_edit[7:5]   = cur_rung;
        led_edit[9:8]   = disp_cur_type;
        led_edit[12:10] = disp_cur_src_class;
        led_edit[13]    = prog_valid_reg;
        led_edit[14]    = prog_dirty;
        led_edit[15]    = (error_code_reg != 8'h00);

        if (run_mode) begin
            LED[7:0]  = rung_vis_reg;
            LED[15:8] = I_run_vec[7:0];
        end
        else begin
            LED = led_edit;
        end

        if (run_mode) begin
            disp_hex[31:28] = 4'hA;
            disp_hex[27:24] = {1'b0, active_rungs_m1};
            disp_hex[23:20] = rung_true_reg[3:0];
            disp_hex[19:16] = rung_true_reg[7:4];
            disp_hex[15:12] = rung_vis_reg[3:0];
            disp_hex[11:8]  = rung_vis_reg[7:4];
            disp_hex[7:4]   = Q_table[3:0];
            disp_hex[3:0]   = M_table[3:0];
            disp_dp = 8'hFF;
        end
        else begin
            disp_hex[31:28] = 4'hE;
            disp_hex[27:24] = edit_page;
            disp_hex[23:20] = {1'b0, cur_rung};
            disp_hex[19:16] = {2'b00, cur_lane};
            disp_hex[15:12] = {1'b0, cur_col};

            case (edit_page)
                3'd0: begin
                    disp_hex[11:8] = 4'h0;
                    disp_hex[7:4]  = 4'h0;
                    disp_hex[3:0]  = 4'h0;
                end

                3'd1: begin
                    disp_hex[11:8] = {2'b00, disp_cur_type};
                    disp_hex[7:4]  = {1'b0, disp_cur_src_class};
                    disp_hex[3:0]  = disp_cur_src_idx[3:0];
                end

                3'd2: begin
                    disp_hex[11:8] = disp_cur_act_type;
                    disp_hex[7:4]  = disp_cur_act_idx;
                    disp_hex[3:0]  = 4'h0;
                end

                3'd3: begin
                    disp_hex[11:8] = disp_cur_act_pre[7:4];
                    disp_hex[7:4]  = disp_cur_act_pre[3:0];
                    disp_hex[3:0]  = 4'h0;
                end

                3'd4: begin
                    disp_hex[11:8] = disp_cur_act_pre[15:12];
                    disp_hex[7:4]  = disp_cur_act_pre[11:8];
                    disp_hex[3:0]  = 4'h0;
                end

                default: begin
                    disp_hex[11:8] = {1'b0, active_rungs_m1};
                    disp_hex[7:4]  = error_code_reg[7:4];
                    disp_hex[3:0]  = error_code_reg[3:0];
                end
            endcase

            disp_dp = 8'hFF;
        end
    end

    always @(posedge CLK100MHZ) begin
        if (reset_i) begin
            edit_page        <= 3'd0;
            cur_rung         <= 3'd0;
            cur_lane         <= 2'd0;
            cur_col          <= 3'd0;
            active_rungs_m1  <= 3'd0;
            prog_dirty       <= 1'b0;
            prog_valid_reg   <= 1'b0;
            error_code_reg   <= 8'h00;
            run_mode_d       <= 1'b0;

            Q_table          <= {N_OUTPUTS{1'b0}};
            M_table          <= {N_MARKERS{1'b0}};
            rung_true_reg    <= 8'h00;
            rung_vis_reg     <= 8'h00;

            for (seq_i = 0; seq_i < TOTAL_CELLS; seq_i = seq_i + 1) begin
                cell_type[seq_i]      <= CT_EMPTY;
                cell_src_class[seq_i] <= SRC_NONE;
                cell_src_idx[seq_i]   <= 5'd0;
            end

            for (seq_i = 0; seq_i < MAX_RUNGS; seq_i = seq_i + 1) begin
                rung_action_type[seq_i] <= ACT_NONE;
                rung_action_idx[seq_i]  <= 4'd0;
                rung_action_pre[seq_i]  <= 16'd0;
            end

            for (seq_i = 0; seq_i < N_TIMERS; seq_i = seq_i + 1) begin
                TON_accum[seq_i]  <= 16'd0;
                TON_preset[seq_i] <= 16'd1000;
                TON_dn[seq_i]     <= 1'b0;
                TON_en[seq_i]     <= 1'b0;

                TOF_accum[seq_i]  <= 16'd0;
                TOF_preset[seq_i] <= 16'd1000;
                TOF_dn[seq_i]     <= 1'b0;
                TOF_en[seq_i]     <= 1'b0;
            end

            for (seq_i = 0; seq_i < N_COUNTERS; seq_i = seq_i + 1) begin
                C_accum[seq_i]   <= 16'd0;
                C_preset[seq_i]  <= 16'd5;
                C_dn[seq_i]      <= 1'b0;
                C_prev_en[seq_i] <= 1'b0;
            end

            active_rungs_m1 <= 3'd0;

            cell_type[CIDX(0,0,0)]      <= CT_NO;
            cell_src_class[CIDX(0,0,0)] <= SRC_I;
            cell_src_idx[CIDX(0,0,0)]   <= 5'd0;

            cell_type[CIDX(0,0,1)]      <= CT_NO;
            cell_src_class[CIDX(0,0,1)] <= SRC_I;
            cell_src_idx[CIDX(0,0,1)]   <= 5'd1;

            rung_action_type[0]         <= ACT_COIL_Q;
            rung_action_idx[0]          <= 4'd0;
        end
        else begin
            run_mode_d     <= run_mode;
            prog_valid_reg <= prog_valid_comb;
            error_code_reg <= error_code_comb;

            if (run_mode) begin
                Q_table       <= q_scan_comb;
                M_table       <= m_scan_comb;
                rung_true_reg <= rung_true_comb;
                rung_vis_reg  <= rung_vis_comb;

                for (seq_t = 0; seq_t < N_TIMERS; seq_t = seq_t + 1) begin
                    TON_preset[seq_t] <= ton_preset_next[seq_t];
                    TON_en[seq_t]     <= ton_en_comb[seq_t];

                    if (!ton_en_comb[seq_t]) begin
                        TON_accum[seq_t] <= 16'd0;
                        TON_dn[seq_t]    <= 1'b0;
                    end
                    else if (tick_1ms) begin
                        if (TON_accum[seq_t] < ton_preset_next[seq_t])
                            TON_accum[seq_t] <= TON_accum[seq_t] + 16'd1;

                        if ((TON_accum[seq_t] + 16'd1) >= ton_preset_next[seq_t])
                            TON_dn[seq_t] <= 1'b1;
                    end

                    TOF_preset[seq_t] <= tof_preset_next[seq_t];
                    TOF_en[seq_t]     <= tof_en_comb[seq_t];

                    if (tof_en_comb[seq_t]) begin
                        TOF_accum[seq_t] <= 16'd0;
                        TOF_dn[seq_t]    <= 1'b1;
                    end
                    else begin
                        if (TOF_dn[seq_t]) begin
                            if (tick_1ms) begin
                                if (TOF_accum[seq_t] < tof_preset_next[seq_t])
                                    TOF_accum[seq_t] <= TOF_accum[seq_t] + 16'd1;

                                if ((TOF_accum[seq_t] + 16'd1) >= tof_preset_next[seq_t])
                                    TOF_dn[seq_t] <= 1'b0;
                            end
                        end
                        else begin
                            TOF_accum[seq_t] <= 16'd0;
                        end
                    end
                end

                for (seq_t = 0; seq_t < N_COUNTERS; seq_t = seq_t + 1) begin
                    C_preset[seq_t] <= c_preset_next[seq_t];

                    if (resc_pulse_comb[seq_t]) begin
                        C_accum[seq_t]   <= 16'd0;
                        C_dn[seq_t]      <= 1'b0;
                        C_prev_en[seq_t] <= ctu_en_comb[seq_t];
                    end
                    else begin
                        seq_cnext = C_accum[seq_t];

                        if (ctu_en_comb[seq_t] && !C_prev_en[seq_t])
                            seq_cnext = C_accum[seq_t] + 16'd1;

                        if (ctu_en_comb[seq_t] && !C_prev_en[seq_t])
                            C_accum[seq_t] <= C_accum[seq_t] + 16'd1;

                        C_prev_en[seq_t] <= ctu_en_comb[seq_t];

                        if (seq_cnext >= c_preset_next[seq_t])
                            C_dn[seq_t] <= 1'b1;
                        else
                            C_dn[seq_t] <= 1'b0;
                    end
                end
            end
            else begin
                if (btnl_pulse) begin
                    if (edit_page == 3'd0)
                        edit_page <= 3'd5;
                    else
                        edit_page <= edit_page - 3'd1;
                end

                if (btnr_pulse) begin
                    if (edit_page == 3'd5)
                        edit_page <= 3'd0;
                    else
                        edit_page <= edit_page + 3'd1;
                end

                case (edit_page)
                    3'd0: begin
                        if (btnc_pulse) begin
                            cur_col  <= sw[2:0];
                            cur_lane <= sw[4:3];
                            cur_rung <= sw[7:5];
                        end

                        if (btnu_pulse) begin
                            if (cur_col == 3'd6)
                                cur_col <= 3'd0;
                            else
                                cur_col <= cur_col + 3'd1;
                        end

                        if (btnd_pulse) begin
                            if (cur_col == 3'd0)
                                cur_col <= 3'd6;
                            else
                                cur_col <= cur_col - 3'd1;
                        end
                    end

                    3'd1: begin
                        seq_idx = CIDX(cur_rung, cur_lane, cur_col);
                        if (btnc_pulse) begin
                            cell_type[seq_idx]      <= sw[1:0];
                            cell_src_class[seq_idx] <= sw[4:2];
                            cell_src_idx[seq_idx]   <= sw[9:5];
                            prog_dirty              <= 1'b1;
                        end

                        if (btnd_pulse) begin
                            cell_type[seq_idx]      <= CT_EMPTY;
                            cell_src_class[seq_idx] <= SRC_NONE;
                            cell_src_idx[seq_idx]   <= 5'd0;
                            prog_dirty              <= 1'b1;
                        end
                    end

                    3'd2: begin
                        if (btnc_pulse) begin
                            rung_action_type[cur_rung] <= sw[3:0];
                            rung_action_idx[cur_rung]  <= sw[7:4];
                            prog_dirty                 <= 1'b1;
                        end
                    end

                    3'd3: begin
                        if (btnc_pulse) begin
                            rung_action_pre[cur_rung][7:0] <= sw[7:0];
                            prog_dirty                     <= 1'b1;
                        end
                    end

                    3'd4: begin
                        if (btnc_pulse) begin
                            rung_action_pre[cur_rung][15:8] <= sw[7:0];
                            prog_dirty                      <= 1'b1;
                        end
                    end

                    default: begin
                        if (btnc_pulse) begin
                            active_rungs_m1 <= sw[2:0];

                            if (sw[6]) begin
                                for (seq_l = 0; seq_l < LANES; seq_l = seq_l + 1) begin
                                    for (seq_c = 0; seq_c < LOGIC_COLS; seq_c = seq_c + 1) begin
                                        seq_idx = CIDX(cur_rung, seq_l, seq_c);
                                        cell_type[seq_idx]      <= CT_EMPTY;
                                        cell_src_class[seq_idx] <= SRC_NONE;
                                        cell_src_idx[seq_idx]   <= 5'd0;
                                    end
                                end
                                rung_action_type[cur_rung] <= ACT_NONE;
                                rung_action_idx[cur_rung]  <= 4'd0;
                                rung_action_pre[cur_rung]  <= 16'd0;
                                prog_dirty                 <= 1'b1;
                            end

                            if (sw[4]) begin
                                for (seq_r = 0; seq_r < MAX_RUNGS; seq_r = seq_r + 1) begin
                                    for (seq_l = 0; seq_l < LANES; seq_l = seq_l + 1) begin
                                        for (seq_c = 0; seq_c < LOGIC_COLS; seq_c = seq_c + 1) begin
                                            seq_idx = CIDX(seq_r, seq_l, seq_c);
                                            cell_type[seq_idx]      <= CT_EMPTY;
                                            cell_src_class[seq_idx] <= SRC_NONE;
                                            cell_src_idx[seq_idx]   <= 5'd0;
                                        end
                                    end
                                    rung_action_type[seq_r] <= ACT_NONE;
                                    rung_action_idx[seq_r]  <= 4'd0;
                                    rung_action_pre[seq_r]  <= 16'd0;
                                end
                                prog_dirty <= 1'b1;
                            end

                            if (sw[5]) begin
                                Q_table       <= {N_OUTPUTS{1'b0}};
                                M_table       <= {N_MARKERS{1'b0}};
                                rung_true_reg <= 8'h00;
                                rung_vis_reg  <= 8'h00;

                                for (seq_t = 0; seq_t < N_TIMERS; seq_t = seq_t + 1) begin
                                    TON_accum[seq_t]  <= 16'd0;
                                    TON_preset[seq_t] <= 16'd1000;
                                    TON_dn[seq_t]     <= 1'b0;
                                    TON_en[seq_t]     <= 1'b0;

                                    TOF_accum[seq_t]  <= 16'd0;
                                    TOF_preset[seq_t] <= 16'd1000;
                                    TOF_dn[seq_t]     <= 1'b0;
                                    TOF_en[seq_t]     <= 1'b0;
                                end

                                for (seq_t = 0; seq_t < N_COUNTERS; seq_t = seq_t + 1) begin
                                    C_accum[seq_t]   <= 16'd0;
                                    C_preset[seq_t]  <= 16'd5;
                                    C_dn[seq_t]      <= 1'b0;
                                    C_prev_en[seq_t] <= 1'b0;
                                end
                            end

                            if (sw[3]) begin
                                for (seq_r = 0; seq_r < MAX_RUNGS; seq_r = seq_r + 1) begin
                                    for (seq_l = 0; seq_l < LANES; seq_l = seq_l + 1) begin
                                        for (seq_c = 0; seq_c < LOGIC_COLS; seq_c = seq_c + 1) begin
                                            seq_idx = CIDX(seq_r, seq_l, seq_c);
                                            cell_type[seq_idx]      <= CT_EMPTY;
                                            cell_src_class[seq_idx] <= SRC_NONE;
                                            cell_src_idx[seq_idx]   <= 5'd0;
                                        end
                                    end
                                    rung_action_type[seq_r] <= ACT_NONE;
                                    rung_action_idx[seq_r]  <= 4'd0;
                                    rung_action_pre[seq_r]  <= 16'd0;
                                end

                                active_rungs_m1 <= 3'd2;

                                cell_type[CIDX(0,0,0)]      <= CT_NO;
                                cell_src_class[CIDX(0,0,0)] <= SRC_I;
                                cell_src_idx[CIDX(0,0,0)]   <= 5'd0;
                                cell_type[CIDX(0,0,1)]      <= CT_NO;
                                cell_src_class[CIDX(0,0,1)] <= SRC_I;
                                cell_src_idx[CIDX(0,0,1)]   <= 5'd1;
                                rung_action_type[0]         <= ACT_COIL_Q;
                                rung_action_idx[0]          <= 4'd0;

                                cell_type[CIDX(1,0,0)]      <= CT_NO;
                                cell_src_class[CIDX(1,0,0)] <= SRC_I;
                                cell_src_idx[CIDX(1,0,0)]   <= 5'd2;
                                rung_action_type[1]         <= ACT_SET_M;
                                rung_action_idx[1]          <= 4'd0;

                                cell_type[CIDX(2,0,0)]      <= CT_NC;
                                cell_src_class[CIDX(2,0,0)] <= SRC_I;
                                cell_src_idx[CIDX(2,0,0)]   <= 5'd3;
                                rung_action_type[2]         <= ACT_RST_M;
                                rung_action_idx[2]          <= 4'd0;

                                prog_dirty                  <= 1'b0;
                            end

                            if (btnd_pulse)
                                prog_dirty <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end

endmodule