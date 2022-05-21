// AES_128_Encipher_Block.v
//
// Cipher()
// 
// To hop lai initial round, main round va final round
// cho cac hoat dong cua Encipher
//-----------------------------------------------------------------------------
module AES_128_Encipher_Block(
    input wire clk,
    input wire reset_n,
    input wire next,
    input wire [127:0] round_key,
    input wire [31:0] new_sbox,
    input wire [127:0] block,

    output wire [3:0] round,
    output wire [31:0] sbox,
    output wire [127:0] new_block,
    output wire ready
);

//-----------------------------------------------------------------------------
// Cac tham so va hang so
//-----------------------------------------------------------------------------
localparam AES_128_BIT_KEY = 1'h0;

localparam AES128_ROUNDS = 4'ha;

localparam NO_UPDATE = 3'h0;
localparam INIT_UPDATE = 3'h1;
localparam SBOX_UPDATE = 3'h2;
localparam MAIN_UPDATE = 3'h3;
localparam FINAL_UPDATE = 3'h4;

localparam CTRL_IDLE = 2'h0;
localparam CTRL_INIT = 2'h1;
localparam CTRL_SBOX = 2'h2;
localparam CTRL_MAIN = 2'h3;

//-----------------------------------------------------------------------------
// Cac function
//-----------------------------------------------------------------------------
function [7:0] gm2;
    input [7:0] op;

    begin
        // {op}.{02}
        // Dich 1 bit ngo vao va thuc hien phep XOR
        // voi {01}{1b} tren GF(2^8)
        gm2 = {op[6:0], 1'b0} ^ (8'h1b & {8{op[7]}});
    end
endfunction
//-------------------------------------
function [7:0] gm3;
    input [7:0] op;

    begin
        // {op}.{03} = {op}.({01} ^ {02})
        gm3 = gm2(op) ^ op;
    end
endfunction
//-------------------------------------
function [31:0] mixw;
    input [31:0] w;

    reg [7:0] b0, b1, b2, b3;
    reg [7:0] mb0, mb1, mb2, mb3;

    // s'(0,c) = ({02}.s(0,c)) ^ ({03}.s(1,c)) ^ s(2,c) ^ s(3,c)
    // s'(1,c) = s(0,c) ^ ({02}.s(1,c)) ^ ({03}.s(2,c)) ^ s(3,c)
    // s'(2,c) = s(0,c) ^ s(1,c) ^ ({02}.s(2,c)) ^ ({03}.s(3,c))
    // s'(3,c) = ({03}.s(0,c)) ^ s(1,c) ^ s(2,c) ^ ({02}.s(3,c))
    begin
        b0 = w[31:24];
        b1 = w[23:16];
        b2 = w[15:8];
        b3 = w[7:0];

        mb0 = gm2(b0) ^ gm3(b1) ^ b2 ^ b3;
        mb1 = b0 ^ gm2(b1) ^ gm3(b2) ^ b3;
        mb2 = b0 ^ b1 ^ gm2(b2) ^ gm3(b3);
        mb3 = gm3(b0) ^ b1 ^ b2 ^ gm2(b3);

        mixw = {mb0, mb1, mb2, mb3};
    end
endfunction
//-------------------------------------
// MixColumns()
//-------------------------------------
function [127:0] mixcolumns;
    input [127:0] data;
    
    reg [31:0] w0, w1, w2, w3;
    reg [31:0] ws0, ws1, ws2, ws3;

    begin
        w0 = data[127:96];
        w1 = data[95:64];
        w2 = data[63:32];
        w3 = data[31:0];

        ws0 = mixw(w0);
        ws1 = mixw(w1);
        ws2 = mixw(w2);
        ws3 = mixw(w3);

        mixcolumns = {ws0, ws1, ws2, ws3};
    end
endfunction
//-------------------------------------
// ShiftRows()
//-------------------------------------
function [127:0] shiftrows;
    input [127:0] data;
    
    reg [31:0] w0, w1, w2, w3;
    reg [31:0] ws0, ws1, ws2, ws3;

    begin
        w0 = data[127:96];
        w1 = data[95:64];
        w2 = data[63:32];
        w3 = data[31:0];

        ws0 = {w0[31:24], w1[23:16], w2[15:8], w3[7:0]};
        ws1 = {w1[31:24], w2[23:16], w3[15:8], w0[7:0]};
        ws2 = {w2[31:24], w3[23:16], w0[15:8], w1[7:0]};
        ws3 = {w3[31:24], w0[23:16], w1[15:8], w2[7:0]};

        shiftrows = {ws0, ws1, ws2, ws3};
    end 
endfunction
//-------------------------------------
// AddRoundKey()
//-------------------------------------
function [127:0] addroundkey;
    input [127:0] data;
    input [127:0] rkey;

    begin
        addroundkey = data ^ rkey;
    end
endfunction

//-----------------------------------------------------------------------------
// Thanh ghi bao gom cac bien cap nhat va cho phep ghi
//-----------------------------------------------------------------------------
reg [1:0] sword_ctr_reg;
reg [1:0] sword_ctr_new;
reg sword_ctr_we;
reg sword_ctr_inc;
reg sword_ctr_rst;

reg [3:0] round_ctr_reg;
reg [3:0] round_ctr_new;
reg round_ctr_we;
reg round_ctr_inc;
reg round_ctr_rst;

reg [127:0] block_new;
reg [31:0] block_w0_reg;
reg [31:0] block_w1_reg;
reg [31:0] block_w2_reg;
reg [31:0] block_w3_reg;
reg block_w0_we;
reg block_w1_we;
reg block_w2_we;
reg block_w3_we;

reg ready_reg;
reg ready_new;
reg ready_we;

reg [1:0] enc_ctrl_reg;
reg [1:0] enc_ctrl_new;
reg enc_ctrl_we;

//-----------------------------------------------------------------------------
// Day (Wires)
//-----------------------------------------------------------------------------
reg [2:0] update_type;
reg [31:0] muxed_sbox;

//-----------------------------------------------------------------------------
// Ket noi toi cac port
//-----------------------------------------------------------------------------
assign round = round_ctr_reg;
assign sbox = muxed_sbox;
assign new_block = {block_w0_reg, block_w1_reg, block_w2_reg, block_w3_reg};
assign ready = ready_reg;

//-----------------------------------------------------------------------------
// reg_update
//
// Cap nhat cac function trong cac thanh ghi. Tat ca cac 
// thanh ghi duoc kich hoat voi muc thap hoat dong khong 
// dong bo. Tat ca cac thanh ghi deu cho phep ghi
//-----------------------------------------------------------------------------
always @(posedge clk or negedge reset_n) begin: reg_update
    if (!reset_n) begin
        block_w0_reg <= 32'h0;
        block_w1_reg <= 32'h0;
        block_w2_reg <= 32'h0;
        block_w3_reg <= 32'h0;
        sword_ctr_reg <= 2'h0;
        round_ctr_reg <= 4'h0;
        ready_reg <= 1'b1;
        enc_ctrl_reg <= CTRL_IDLE;
    end
    else begin
        if (block_w0_we)
            block_w0_reg <= block_new[127:96];
        if (block_w1_we)
            block_w1_reg <= block_new[95:64];
        if (block_w2_we)
            block_w2_reg <= block_new[63:32];
        if (block_w3_we)
            block_w3_reg <= block_new[31:0];
        if (sword_ctr_we)
            sword_ctr_reg <= sword_ctr_new;
        if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;
        if (ready_we)
            ready_reg <= ready_new;
        if (enc_ctrl_we)
            enc_ctrl_reg <= enc_ctrl_new;
    end
end

//-----------------------------------------------------------------------------
// round_logic
//
// Cap nhat cac thanh ghi tin hieu
//-----------------------------------------------------------------------------
always @(*) begin: round_logic
    reg [127:0] old_block, shiftrows_block, mixcolumns_block;
    reg [127:0] addkey_init_block, addkey_main_block, addkey_final_block;

    block_new = 128'h0;
    muxed_sbox = 32'h0;
    block_w0_we = 1'b0;
    block_w1_we = 1'b0;
    block_w2_we = 1'b0;
    block_w3_we = 1'b0;

    old_block = {block_w0_reg, block_w1_reg, block_w2_reg, block_w3_reg};
    shiftrows_block = shiftrows(old_block);
    mixcolumns_block = mixcolumns(shiftrows_block);
    addkey_init_block = addroundkey(block, round_key);
    addkey_main_block = addroundkey(mixcolumns_block, round_key);
    addkey_final_block = addroundkey(shiftrows_block, round_key);

    case (update_type)
        INIT_UPDATE: begin
            block_new = addkey_init_block;
            block_w0_we = 1'b1;
            block_w1_we = 1'b1;
            block_w2_we = 1'b1;
            block_w3_we = 1'b1;
        end

        SBOX_UPDATE: begin
            block_new = {new_sbox, new_sbox, new_sbox, new_sbox};

            case (sword_ctr_reg)
                2'h0: begin
                    muxed_sbox = block_w0_reg;
                    block_w0_we = 1'b1;
                end
                2'h1: begin
                    muxed_sbox = block_w1_reg;
                    block_w1_we = 1'b1;
                end
                2'h2: begin
                    muxed_sbox = block_w2_reg;
                    block_w2_we = 1'b1;
                end
                2'h3: begin
                    muxed_sbox = block_w3_reg;
                    block_w3_we = 1'b1;
                end
            endcase
        end

        MAIN_UPDATE: begin
            block_new = addkey_main_block;
            block_w0_we = 1'b1;
            block_w1_we = 1'b1;
            block_w2_we = 1'b1;
            block_w3_we = 1'b1;
        end

        FINAL_UPDATE: begin
            block_new = addkey_final_block;
            block_w0_we = 1'b1;
            block_w1_we = 1'b1;
            block_w2_we = 1'b1;
            block_w3_we = 1'b1;
        end

        default: begin
        end
    endcase
end

//------------------------------------------------------------------------------
// sword_ctr
//
// Bo dem subbytes voi chuc nang reset va tang bien dem
//------------------------------------------------------------------------------
always @(*) begin: sword_ctr
    sword_ctr_new = 2'h0;
    sword_ctr_we = 1'b0;

    if (sword_ctr_rst) begin
        sword_ctr_new = 2'h0;
        sword_ctr_we = 1'b1;
    end
    else if (sword_ctr_inc) begin
        sword_ctr_new = sword_ctr_reg + 1'b1;
        sword_ctr_we = 1'b1;
    end
end

//------------------------------------------------------------------------------
// round_ctr
//
// Bo dem round voi chuc nang reset va tang bien dem
//------------------------------------------------------------------------------
always @(*) begin: round_ctr
    round_ctr_new = 4'h0;
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

//------------------------------------------------------------------------------
// encipher_ctrl
//
// Kiem soat may trang thai (FSM) cua cach hoat dong encipher
//------------------------------------------------------------------------------
always @(*) begin: encipher_ctrl
    reg [3:0] num_rounds;

    // Gan thanh ghi mac dinh
    sword_ctr_inc = 1'b0;
    sword_ctr_rst = 1'b0;
    round_ctr_inc = 1'b0;
    round_ctr_rst = 1'b0;
    ready_new = 1'b0;
    ready_we = 1'b0;
    update_type = NO_UPDATE;
    enc_ctrl_new = CTRL_IDLE;
    enc_ctrl_we = 1'b0;
    
    num_rounds = AES128_ROUNDS;
    
    case (enc_ctrl_reg)
        CTRL_IDLE: begin
            if (next) begin
                round_ctr_rst = 1'b1;
                ready_new = 1'b0;
                ready_we = 1'b1;
                enc_ctrl_new = CTRL_INIT;
                enc_ctrl_we = 1'b1;
            end
        end

        CTRL_INIT: begin
            round_ctr_inc = 1'b1;
            sword_ctr_rst = 1'b1;
            update_type = INIT_UPDATE;
            enc_ctrl_new = CTRL_SBOX;
            enc_ctrl_we = 1'b1;
        end

        CTRL_SBOX: begin
            sword_ctr_inc = 1'b1;
            update_type = SBOX_UPDATE;
            
            if (sword_ctr_reg == 2'h3) begin
                enc_ctrl_new = CTRL_MAIN;
                enc_ctrl_we = 1'b1;
            end
        end

        CTRL_MAIN: begin
            sword_ctr_rst = 1'b1;
            round_ctr_inc = 1'b1;

            if (round_ctr_reg < num_rounds) begin
                update_type = MAIN_UPDATE;
                enc_ctrl_new = CTRL_SBOX;
                enc_ctrl_we = 1'b1;
            end
            else begin
                update_type = FINAL_UPDATE;
                ready_new = 1'b1;
                ready_we = 1'b1;
                enc_ctrl_new = CTRL_IDLE;
                enc_ctrl_we = 1'b1;
            end
        end

        default: begin
        end
    endcase
end

//------------------------------------------------------------------------------
endmodule