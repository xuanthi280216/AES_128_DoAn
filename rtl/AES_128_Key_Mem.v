// AES_128_Key_Mem.v
//
// Bo nho cua AES bao gom cac trinh tu vong khoa (round key)
//-----------------------------------------------------------------------------
module AES_128_Key_Mem(
    input wire clk,
    input wire reset_n,
    input wire [127:0] key,
    input wire init,
    input wire [3:0] round,
    input wire [31:0] new_sbox,

    output wire [127:0] round_key,
    output wire ready,
    output wire [31:0] sbox
);

//-----------------------------------------------------------------------------
// Tham so (Parameters)
//-----------------------------------------------------------------------------
localparam AES_128_NUM_ROUNDS = 10;

localparam CTRL_IDLE = 3'h0;
localparam CTRL_INIT = 3'h1;
localparam CTRL_GENERATE = 3'h2;
localparam CTRL_DONE = 3'h3;

//-----------------------------------------------------------------------------
// Thanh ghi (Registers)
//-----------------------------------------------------------------------------
reg [127:0] key_mem [0:10];
reg [127:0] key_mem_new;
reg key_mem_we;

reg [127:0] prev_key_reg;
reg [127:0] prev_key_new;
reg prev_key_we;

reg [3:0] round_ctr_reg;
reg [3:0] round_ctr_new;
reg round_ctr_rst;
reg round_ctr_inc;
reg round_ctr_we;

reg [2:0] key_mem_ctrl_reg;
reg [2:0] key_mem_ctrl_new;
reg key_mem_ctrl_we;

reg ready_reg;
reg ready_new;
reg ready_we;

reg [7:0] rcon_reg;
reg [7:0] rcon_new;
reg rcon_we;
reg rcon_set;
reg rcon_next;

//-----------------------------------------------------------------------------
// Day (Wires)
//-----------------------------------------------------------------------------
reg [31:0] tmp_sbox;
reg round_key_update;
reg [127:0] tmp_round_key;

//-----------------------------------------------------------------------------
// Ket noi toi cac port
//-----------------------------------------------------------------------------
assign round_key = tmp_round_key;
assign ready = ready_reg;
assign sbox = tmp_sbox;

//-----------------------------------------------------------------------------
// reg_update
//
// Cap nhat cac function trong cac thanh ghi. Tat ca cac 
// thanh ghi duoc kich hoat voi muc thap hoat dong khong 
// dong bo. Tat ca cac thanh ghi deu cho phep ghi
//-----------------------------------------------------------------------------
always @(posedge clk or negedge reset_n) begin: reg_update
    integer i;

    if (!reset_n) begin
        for (i = 0; i <= AES_128_NUM_ROUNDS; i = i + 1)
            key_mem[i] <= 128'h0;

        ready_reg <= 1'b0;
        rcon_reg <= 8'h0;
        round_ctr_reg <= 4'h0;
        prev_key_reg <= 128'h0;
        prev_key_reg <= 128'h0;
        key_mem_ctrl_reg <= CTRL_IDLE;
    end
    else begin
        if (ready_we)
            ready_reg <= ready_new;
        if (rcon_we)
            rcon_reg <= rcon_new;
        if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;
        if (key_mem_we)
            key_mem[round_ctr_reg] <= key_mem_new;
        if (prev_key_we)
            prev_key_reg <= prev_key_new;
        if (key_mem_ctrl_we)
            key_mem_ctrl_reg <= key_mem_ctrl_new;
    end
end

//-----------------------------------------------------------------------------
// key_mem_read
//
// Combinational read port for the key memory
//-----------------------------------------------------------------------------
always @(*) begin: key_mem_read
    tmp_round_key = key_mem[round];
end

//-----------------------------------------------------------------------------
// round_key_gen
// 
// Trinh tu vong khoa cua AES-128 va AES-256
//-----------------------------------------------------------------------------
always @(*) begin: round_key_gen
    reg [31:0] w0, w1, w2, w3;
    reg [31:0] k0, k1, k2, k3;
    reg [31:0] rconw, rotstw, trw;

    // Gan gia tri ban dau
    key_mem_new = 128'h0;
    key_mem_we = 1'b0;
    prev_key_new = 128'h0;
    prev_key_we = 1'b0;

    k0 = 32'h0;
    k1 = 32'h0;
    k2 = 32'h0;
    k3 = 32'h0;

    rcon_set = 1'b1;
    rcon_next = 1'b0;

    // Gan tung thanh ghi va tinh toan gia tri trung gian
    // Thuc hien vong quay cua cac thanh ghi
    w0 = prev_key_reg[127:96];
    w1 = prev_key_reg[95:64];
    w2 = prev_key_reg[63:32];
    w3 = prev_key_reg[31:0];

    rconw = {rcon_reg, 24'h0};
    tmp_sbox = w3;
    rotstw = {new_sbox[23:0], new_sbox[31:24]};
    trw = rotstw ^ rconw;

    // Tao cac thanh ghi round keys
    if (round_key_update) begin
        rcon_set = 1'b0;
        key_mem_we = 1'b1;

        if (round_ctr_reg == 0) begin
            key_mem_new = key[127:0];
            prev_key_new = key[127:0];
            prev_key_we = 1'b1;
            rcon_next = 1'b1;
        end
        else begin
            k0 = w0 ^ trw;
            k1 = w1 ^ w0 ^ trw;
            k2 = w2 ^ w1 ^ w0 ^ trw;
            k3 = w3 ^ w2 ^ w1 ^ w0 ^ trw;
        
            key_mem_new = {k0, k1, k2, k3};
            prev_key_new = {k0, k1, k2, k3};
            prev_key_we = 1'b1;
            rcon_next = 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// rcon_logic
// 
// Tinh toan gia tri rcon cho moi lan lap mo rong khoa khac nhau
//-----------------------------------------------------------------------------
always @(*) begin: rcon_logic
    reg[7:0] tmp_rcon;

    rcon_new = 8'h00;
    rcon_we = 1'b0;

    tmp_rcon = {rcon_reg[6:0], 1'b0} ^ (8'h1b & {8{rcon_reg[7]}});

    if (rcon_set) begin
        rcon_new = 8'h8d;
        rcon_we = 1'b1;
    end

    if (rcon_next) begin
        rcon_new = tmp_rcon[7:0];
        rcon_we = 1'b1;
    end
end

//-----------------------------------------------------------------------------
// round_ctr
//
// Bo dem round voi chuc nang reset va tang bien dem
//-----------------------------------------------------------------------------
always @(*) begin: round_ctr
    round_ctr_new = 4'b0;
    round_ctr_we = 1'b0;

    if (round_ctr_rst) begin
        round_ctr_new = 4'h0;
        round_ctr_we = 1'b1;
    end
    else if (round_ctr_inc) begin
        round_ctr_new = round_ctr_reg + 1'b1;
        round_ctr_we = 1'b1;
    end
end

//-----------------------------------------------------------------------------
// key_mem_ctrl
//
// May trang thai (FSM) dieu khien vong khoa
//-----------------------------------------------------------------------------
always @(*) begin: key_mem_ctrl
    reg [3:0] num_rounds;

    // Default assignments
    ready_new = 1'b0;
    ready_we = 1'b0;
    round_key_update = 1'b0;
    round_ctr_rst = 1'b0;
    round_ctr_inc = 1'b0;
    key_mem_ctrl_new = CTRL_IDLE;
    key_mem_ctrl_we = 1'b0;

    num_rounds = 4'ha;

    case (key_mem_ctrl_reg)
        CTRL_IDLE: begin
            if (init) begin
                ready_new = 1'b0;
                ready_we = 1'b1;
                key_mem_ctrl_new = CTRL_INIT;
                key_mem_ctrl_we = 1'b1;
            end
        end

        CTRL_INIT: begin
            round_ctr_rst = 1'b1;
            key_mem_ctrl_new = CTRL_GENERATE;
            key_mem_ctrl_we = 1'b1;
        end

        CTRL_GENERATE: begin
            round_ctr_inc = 1'b1;
            round_key_update = 1'b1;
            if (round_ctr_reg == num_rounds) begin
                key_mem_ctrl_new = CTRL_DONE;
                key_mem_ctrl_we = 1'b1;
            end
        end

        CTRL_DONE: begin
            ready_new = 1'b1;
            ready_we = 1'b1;
            key_mem_ctrl_new = CTRL_IDLE;
            key_mem_ctrl_we = 1'b1;
        end

        default: begin
        end
    endcase
end

//-----------------------------------------------------------------------------
endmodule
//-----------------------------------------------------------------------------