// AES_128_Decipher_Block.v
//
// InvCipher()
// 
// To hop lai initial round, main round va final round
// cho cac hoat dong cua Decipher
//-----------------------------------------------------------------------------
module AES_128_Decipher_Block(
    input wire clk,
    input wire reset_n,
    input wire next,
    input wire [127:0] round_key,
    input wire [127:0] block,

    output wire [3:0] round,
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
function [7:0] gm02;
    input [7:0] op;

    begin
        // {op}.{02}
        // Dich 1 bit ngo vao va thuc hien phep XOR
        // voi {01}{1b} tren GF(2^8)
        gm02 = {op[6:0], 1'b0} ^ (8'h1b & {8{op[7]}});
    end
endfunction
//-------------------------------------
function [7:0] gm03;
    input [7:0] op;

    begin
        // {op}.{03} = {op}.({02} ^ {01})
        gm03 = gm02(op) ^ op;
    end
endfunction
//-------------------------------------
function [7:0] gm04;
    input [7:0] op;

    begin
        // {op}.{04}
        gm04 = gm02(gm02(op));
    end
endfunction
//-------------------------------------
function [7:0] gm08;
    input [7:0] op;

    begin
        // {op}.{08}
        gm08 = gm02(gm04(op));
    end
endfunction
//-------------------------------------
function [7:0] gm09;
    input [7:0] op;

    begin
        // {op}.{09} = {op}.({08} ^ {01})
        gm09 = gm08(op) ^ op;
    end
endfunction
//-------------------------------------
function [7:0] gm11;
    input [7:0] op;

    begin
        // {op}.{11} = {op}.({08} ^ {02} ^ {01})
        gm11 = gm08(op) ^ gm02(op) ^ op;
    end
endfunction
//-------------------------------------
function [7:0] gm13;
    input [7:0] op;

    begin
        // {op}.{13} = {op}.({08} ^ {04} ^ {01})
        gm13 = gm08(op) ^ gm04(op) ^ op;
    end
endfunction
//-------------------------------------
function [7:0] gm14;
    input [7:0] op;

    begin
        // {op}.{14} = {op}.({08} ^ {04} ^ {02})
        gm14 = gm08(op) ^ gm04(op) ^ gm02(op);
    end
endfunction
//-------------------------------------
function [31:0] inv_mixw;
    input [31:0] w;

    reg [7:0] b0, b1, b2, b3;
    reg [7:0] mb0, mb1, mb2, mb3;

    // s'(0,c) = ({0e}.s(0,c)) ^ ({0b}.s(1,c)) ^ ({0d}.s(0,c)) ^ ({09}.s(3,c))
    // s'(1,c) = ({09}.s(0,c)) ^ ({0e}.s(1,c)) ^ ({0b}.s(0,c)) ^ ({0d}.s(3,c))
    // s'(2,c) = ({0d}.s(0,c)) ^ ({09}.s(1,c)) ^ ({0e}.s(0,c)) ^ ({0b}.s(3,c))
    // s'(3,c) = ({0b}.s(0,c)) ^ ({0d}.s(1,c)) ^ ({09}.s(0,c)) ^ ({0e}.s(3,c))
    begin
        b0 = w[31:24];
        b1 = w[23:16];
        b2 = w[15:8];
        b3 = w[7:0];

        mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm09(b3);
        mb1 = gm09(b0) ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
        mb2 = gm13(b0) ^ gm09(b1) ^ gm14(b2) ^ gm11(b3);
        mb3 = gm11(b0) ^ gm13(b1) ^ gm09(b2) ^ gm14(b3);

        inv_mixw = {mb0, mb1, mb2, mb3};
    end
endfunction
//-------------------------------------
function [127:0] inv_mixcolumns;
    input [127:0] data;
    
    reg [31:0] w0, w1, w2, w3;
    reg [31:0] ws0, ws1, ws2, ws3;

    begin
        w0 = data[127:96];
        w1 = data[95:64];
        w2 = data[63:32];
        w3 = data[31:0];

        ws0 = inv_mixw(w0);
        ws1 = inv_mixw(w1);
        ws2 = inv_mixw(w2);
        ws3 = inv_mixw(w3);

        inv_mixcolumns = {ws0, ws1, ws2, ws3};
    end
endfunction
//-------------------------------------
// ShiftRows()
//-------------------------------------
function [127:0] inv_shiftrows;
    input [127:0] data;
    
    reg [31:0] w0, w1, w2, w3;
    reg [31:0] ws0, ws1, ws2, ws3;

    begin
        w0 = data[127:96];
        w1 = data[95:64];
        w2 = data[63:32];
        w3 = data[31:0];

        ws0 = {w0[31:24], w3[23:16], w2[15:8], w1[7:0]};
        ws1 = {w1[31:24], w0[23:16], w3[15:8], w2[7:0]};
        ws2 = {w2[31:24], w1[23:16], w0[15:8], w3[7:0]};
        ws3 = {w3[31:24], w2[23:16], w1[15:8], w0[7:0]};

        inv_shiftrows = {ws0, ws1, ws2, ws3};
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
reg round_ctr_set;
reg round_ctr_dec;

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

reg [1:0] dec_ctrl_reg;
reg [1:0] dec_ctrl_new;
reg dec_ctrl_we;

//-----------------------------------------------------------------------------
// Day (Wires)
//-----------------------------------------------------------------------------
reg [2:0] update_type;
reg [31:0] tmp_sbox;
wire [31:0] new_sbox;

//-----------------------------------------------------------------------------
// InvSubBytes()
//-----------------------------------------------------------------------------
AES_Inv_Sbox inv_sbox_inst(.sbox(tmp_sbox), .new_sbox(new_sbox));

//-----------------------------------------------------------------------------
// Ket noi toi cac port
//-----------------------------------------------------------------------------
assign round = round_ctr_reg;
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
        dec_ctrl_reg <= CTRL_IDLE;
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
        if (dec_ctrl_we)
            dec_ctrl_reg <= dec_ctrl_new;
    end
end

//-----------------------------------------------------------------------------
// round_logic
//
// Cap nhat cac thanh ghi tin hieu
//-----------------------------------------------------------------------------
always @(*) begin: round_logic
    reg [127:0] old_block, inv_shiftrows_block, inv_mixcolumns_block;
    reg [127:0] addkey_block;

    inv_shiftrows_block = 128'h0;
    inv_mixcolumns_block = 128'h0;
    addkey_block = 128'h0;
    block_new = 128'h0;
    tmp_sbox = 32'h0;
    block_w0_we = 1'b0;
    block_w1_we = 1'b0;
    block_w2_we = 1'b0;
    block_w3_we = 1'b0;

    old_block = {block_w0_reg, block_w1_reg, block_w2_reg, block_w3_reg};

    case (update_type)
        INIT_UPDATE: begin
            old_block = block;
            addkey_block = addroundkey(old_block, round_key);
            inv_shiftrows_block = inv_shiftrows(addkey_block);
            block_new = inv_shiftrows_block;
            block_w0_we = 1'b1;
            block_w1_we = 1'b1;
            block_w2_we = 1'b1;
            block_w3_we = 1'b1;
        end

        SBOX_UPDATE: begin
            block_new = {new_sbox, new_sbox, new_sbox, new_sbox};

            case (sword_ctr_reg)
                2'h0: begin
                    tmp_sbox = block_w0_reg;
                    block_w0_we = 1'b1;
                end
                2'h1: begin
                    tmp_sbox = block_w1_reg;
                    block_w1_we = 1'b1;
                end
                2'h2: begin
                    tmp_sbox = block_w2_reg;
                    block_w2_we = 1'b1;
                end
                2'h3: begin
                    tmp_sbox = block_w3_reg;
                    block_w3_we = 1'b1;
                end
            endcase
        end

        MAIN_UPDATE: begin
            addkey_block = addroundkey(old_block, round_key);
            inv_mixcolumns_block = inv_mixcolumns(addkey_block);
            inv_shiftrows_block = inv_shiftrows(inv_mixcolumns_block);
            block_new = inv_shiftrows_block;
            block_w0_we = 1'b1;
            block_w1_we = 1'b1;
            block_w2_we = 1'b1;
            block_w3_we = 1'b1;
        end

        FINAL_UPDATE: begin
            block_new = addroundkey(old_block, round_key);
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
// Bo dem round voi chuc nang reset va giam bien dem
//------------------------------------------------------------------------------
always @(*) begin: round_ctr
    round_ctr_new = 4'h0;
    round_ctr_we = 1'b0;

    if (round_ctr_set) begin
        round_ctr_new = AES128_ROUNDS;
        round_ctr_we = 1'b1;
    end
    else if (round_ctr_dec) begin
        round_ctr_new = round_ctr_reg - 1'b1;
        round_ctr_we = 1'b1;
    end
end

//------------------------------------------------------------------------------
// decipher_ctrl
//
// Kiem soat may trang thai (FSM) cua cach hoat dong decipher
//------------------------------------------------------------------------------
always @(*) begin: decipher_ctrl
    reg [3:0] num_rounds;

    // Gan thanh ghi mac dinh
    sword_ctr_inc = 1'b0;
    sword_ctr_rst = 1'b0;
    round_ctr_dec = 1'b0;
    round_ctr_set = 1'b0;
    ready_new = 1'b0;
    ready_we = 1'b0;
    update_type = NO_UPDATE;
    dec_ctrl_new = CTRL_IDLE;
    dec_ctrl_we = 1'b0;
    
    case (dec_ctrl_reg)
        CTRL_IDLE: begin
            if (next) begin
                round_ctr_set = 1'b1;
                ready_new = 1'b0;
                ready_we = 1'b1;
                dec_ctrl_new = CTRL_INIT;
                dec_ctrl_we = 1'b1;
            end
        end

        CTRL_INIT: begin
            sword_ctr_rst = 1'b1;
            update_type = INIT_UPDATE;
            dec_ctrl_new = CTRL_SBOX;
            dec_ctrl_we = 1'b1;
        end

        CTRL_SBOX: begin
            sword_ctr_inc = 1'b1;
            update_type = SBOX_UPDATE;
            
            if (sword_ctr_reg == 2'h3) begin
                round_ctr_dec = 1'b1;
                dec_ctrl_new = CTRL_MAIN;
                dec_ctrl_we = 1'b1;
            end
        end

        CTRL_MAIN: begin
            sword_ctr_rst = 1'b1;

            if (round_ctr_reg > 0) begin
                update_type = MAIN_UPDATE;
                dec_ctrl_new = CTRL_SBOX;
                dec_ctrl_we = 1'b1;
            end
            else begin
                update_type = FINAL_UPDATE;
                ready_new = 1'b1;
                ready_we = 1'b1;
                dec_ctrl_new = CTRL_IDLE;
                dec_ctrl_we = 1'b1;
            end
        end

        default: begin
        end
    endcase
end

//------------------------------------------------------------------------------
endmodule