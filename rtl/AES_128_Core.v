// AES_128_Core.v
// 
// Core AES. Ho tro voi kich thuoc 128 bits.
// Ket noi voi cac module con
//-----------------------------------------------------------------------------
module AES_128_Core(
    input wire clk,
    input wire reset_n,
    input wire encdec,
    input wire init,
    input wire next,
    input wire [127:0] key,
    input wire [127:0] block,
    
    output wire ready,
    output wire [127:0] result,
    output wire result_valid
);

//-----------------------------------------------------------------------------
// Cac tham so va hang so
//-----------------------------------------------------------------------------
localparam CTRL_IDLE = 2'h0;
localparam CTRL_INIT = 2'h1;
localparam CTRL_NEXT = 2'h2;

//-----------------------------------------------------------------------------
// Thanh ghi bao gom cac bien cap nhat va cho phep ghi
//-----------------------------------------------------------------------------
reg [1:0] aes_core_ctrl_reg;
reg [1:0] aes_core_ctrl_new;
reg aes_core_ctrl_we;

reg result_valid_reg;
reg result_valid_new;
reg result_valid_we;

reg ready_reg;
reg ready_new;
reg ready_we;

//-----------------------------------------------------------------------------
// Day (Wires)
//-----------------------------------------------------------------------------
reg init_state;

wire [127:0] round_key;
wire key_ready;

reg enc_next;
wire [3:0] enc_round_nr;
wire [127:0] enc_new_block;
wire enc_ready;
wire [31:0] enc_sbox;

reg dec_next;
wire [3:0] dec_round_nr;
wire [127:0] dec_new_block;
wire dec_ready;

reg [127:0] muxed_new_block;
reg [3:0] muxed_round_nr;
reg muxed_ready;

wire [31:0] keymem_sbox;

reg [31:0] muxed_sbox;
wire [31:0] new_sbox;

//-----------------------------------------------------------------------------
// Khoi tao va ket noi
//-----------------------------------------------------------------------------
AES_128_Encipher_Block enc_block (
    .clk(clk),
    .reset_n(reset_n),
    .next(enc_next),
    .round_key(round_key),
    .new_sbox(new_sbox),
    .block(block),

    .round(enc_round_nr),
    .sbox(enc_sbox),
    .new_block(enc_new_block),
    .ready(enc_ready)
);

AES_128_Decipher_Block dec_block (
    .clk(clk),
    .reset_n(reset_n),
    .next(dec_next),
    .round_key(round_key),
    .block(block),

    .round(dec_round_nr),
    .new_block(dec_new_block),
    .ready(dec_ready)
);

AES_128_Key_Mem keymem (
    .clk(clk),
    .reset_n(reset_n),
    .key(key),
    .init(init),
    .round(muxed_round_nr),
    .sbox(keymem_sbox),

    .round_key(round_key),
    .ready(key_ready),
    .new_sbox(new_sbox)
);

AES_Sbox sbox_inst (
    .sbox(muxed_sbox),
    .new_sbox(new_sbox)
);

//-----------------------------------------------------------------------------
// Ket noi voi cac port
//-----------------------------------------------------------------------------
assign ready = ready_reg;
assign result = muxed_new_block;
assign result_valid = result_valid_reg;

//-----------------------------------------------------------------------------
// reg_update
//
// Cap nhat cac function trong cac thanh ghi. Tat ca cac 
// thanh ghi duoc kich hoat voi muc thap hoat dong khong 
// dong bo. Tat ca cac thanh ghi deu cho phep ghi
//-----------------------------------------------------------------------------
always @(posedge clk or negedge reset_n) begin: reg_update
    if (!reset_n) begin
        result_valid_reg <= 1'b0;
        ready_reg <= 1'b1;
        aes_core_ctrl_reg <= CTRL_IDLE;
    end
    else begin
        if (result_valid_we)
            result_valid_reg <= result_valid_new;
        if (ready_we)
            ready_reg <= ready_new;
        if (aes_core_ctrl_we)
            aes_core_ctrl_reg <= aes_core_ctrl_new;
    end
end

//-----------------------------------------------------------------------------
// sbox_mux
//
// Dieu khien du lieu ma hoa hoac bo nho chinh duoc truy cap
// vao sbox
//-----------------------------------------------------------------------------
always @(*) begin: sbox_mux
    if (init_state)
        muxed_sbox = keymem_sbox;
    else 
        muxed_sbox = enc_sbox;
end

//-----------------------------------------------------------------------------
// encdex_mux
//
// Cac dieu khien nao trong so cac du lieu nhan duoc tin hieu 
// tiep theo, co quyen truy cap vao bo nho cung nhu ket qua
// xu ly khoi
//-----------------------------------------------------------------------------
always @(*) begin: encdex_mux
    enc_next = 1'b0;
    dec_next = 1'b0;

    if (encdec) begin
        // Cach hoat dong cua Encipher
        enc_next = next;
        muxed_round_nr = enc_round_nr;
        muxed_new_block = enc_new_block;
        muxed_ready = enc_ready;
    end
    else begin
        // Cach hoat dong cua Decipher
        dec_next = next;
        muxed_round_nr = dec_round_nr;
        muxed_new_block = dec_new_block;
        muxed_ready = dec_ready;
    end
end

//-----------------------------------------------------------------------------
// aes_core_ctrl
//
// Kiem soat may trang thai cua aes core. Theo doi cac che do
// khoi dong (init), ma hoa (encipher) hoac giai ma (decipher) 
// va ket noi voi cac submodule khac nhau va cac cong giao dien
// duoc chia se
//-----------------------------------------------------------------------------
always @(*) begin: aes_core_ctrl
    init_state = 1'b0;
    ready_new = 1'b0;
    ready_we = 1'b0;
    result_valid_new = 1'b0;
    result_valid_we = 1'b0;
    aes_core_ctrl_new = CTRL_IDLE;
    aes_core_ctrl_we = 1'b0;
    
    case (aes_core_ctrl_reg)
        CTRL_IDLE: begin
            if (init) begin
                init_state = 1'b1;
                ready_new = 1'b0;
                ready_we = 1'b1;
                result_valid_new = 1'b0;
                result_valid_we = 1'b1;
                aes_core_ctrl_new = CTRL_INIT;
                aes_core_ctrl_we = 1'b1;
            end
            else if (next) begin
                init_state = 1'b0;
                ready_new = 1'b0;
                ready_we = 1'b1;
                result_valid_new = 1'b0;
                result_valid_we = 1'b1;
                aes_core_ctrl_new = CTRL_NEXT;
                aes_core_ctrl_we = 1'b1;
            end
        end

        CTRL_INIT: begin
            init_state = 1'b1;

            if (key_ready) begin
                ready_new = 1'b1;
                ready_we = 1'b1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we = 1'b1;
            end
        end

        CTRL_NEXT: begin
            init_state = 1'b0;

            if (muxed_ready) begin
                ready_new = 1'b1;
                ready_we = 1'b1;
                result_valid_new = 1'b1;
                result_valid_we = 1'b1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we = 1'b1;
            end
        end

        default: begin
        end
    endcase
end

//------------------------------------------------------------------------------
endmodule