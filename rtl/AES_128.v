// AES_128.v
//
// Khoi ma bao boc loi khoi AES (AES_Core)
//-----------------------------------------------------------------------------
module AES_128(
    // Clock va Reset
    input wire clk,
    input wire reset_n,

    // Dieu khien (Control)
    input wire cs,
    input wire we,

    // Cac ngo du lieu (data port)
    input wire [7:0] address,
    input wire [31:0] write_data,
    output wire [31:0] read_data
);

//-----------------------------------------------------------------------------
// Cac tham so va hang so (Constant and parameter)
//-----------------------------------------------------------------------------
localparam ADDR_NAME0 = 8'h00;
localparam ADDR_NAME1 = 8'h01;
localparam ADDR_VERSION = 8'h02;

localparam ADDR_CTRL = 8'h08;
localparam CTRL_INIT_BIT = 0;
localparam CTRL_NEXT_BIT = 1;

localparam ADDR_STATUS = 8'h09;
localparam STATUS_READY_BIT = 0;
localparam STATUS_VALID_BIT = 1;

localparam ADDR_CONFIG = 8'h0a;
localparam CTRL_ENCDEC_BIT = 0;
localparam CTRL_KEYLEN_BIT = 1;

localparam ADDR_KEY0 = 8'h10;
localparam ADDR_KEY3 = 8'h13;

localparam ADDR_BLOCK0 = 8'h20;
localparam ADDR_BLOCK3 = 8'h23;

localparam ADDR_RESULT0 = 8'h30;
localparam ADDR_RESULT3 = 8'h33;

localparam CORE_NAME0 = 32'h61657320;   // "aes "
localparam CORE_NAME1 = 32'h20202020;   // "    "
localparam CORE_VERSION = 32'h302e3630; // "0.60"

//-----------------------------------------------------------------------------
// Thanh ghi bao gom cac bien cap nhat va cho phep ghi
//-----------------------------------------------------------------------------
reg init_reg;
reg init_new;

reg next_reg;
reg next_new;

reg encdec_reg;
reg keylen_reg;
reg config_we;

reg [31:0] block_reg [0:3];
reg block_we;

reg [31:0] key_reg [0:3];
reg key_we;

reg [127:0] result_reg;
reg valid_reg;
reg ready_reg;

//-----------------------------------------------------------------------------
// Day (Wires)
//-----------------------------------------------------------------------------
reg [31:0] tmp_read_data;

wire core_encdec;
wire core_init;
wire core_next;
wire core_ready;
wire [127:0] core_key;
wire core_keylen;
wire [127:0] core_block;
wire [127:0] core_result;
wire core_valid;

//-----------------------------------------------------------------------------
// Ket noi toi cac port
//-----------------------------------------------------------------------------
assign read_data = tmp_read_data;

assign core_key = {key_reg[0], key_reg[1], 
                   key_reg[2], key_reg[3]};

assign core_block = {block_reg[0], block_reg[1],
                     block_reg[2], block_reg[3]};
assign core_init = init_reg;
assign core_next = next_reg;
assign core_encdec = encdec_reg;
assign core_keylen = keylen_reg;

AES_128_Core core (
    .clk(clk),
    .reset_n(reset_n),
    .encdec(core_encdec),
    .init(core_init),
    .next(core_next),
    .key(core_key),
    .block(core_block),
    
    .ready(core_ready),
    .result(core_result),
    .result_valid(core_valid)
);

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
        for (i = 0; i < 4; i = i + 1)
            block_reg[i] <= 32'h0;

        for (i = 0; i < 4; i = i + 1)
            key_reg[i] <= 32'h0;

        init_reg <= 1'b0;
        next_reg <= 1'b0;
        encdec_reg <= 1'b0;
        keylen_reg <= 1'b0;

        result_reg <= 128'h0;
        valid_reg <= 1'b0;
        ready_reg <= 1'b0;
    end
    else begin
        ready_reg <= core_ready;
        valid_reg <= core_valid;
        result_reg <= core_result;
        init_reg <= init_new;
        next_reg <= next_new;

        if (config_we) begin
            encdec_reg <= write_data[CTRL_ENCDEC_BIT];
            keylen_reg <= write_data[CTRL_KEYLEN_BIT];
        end

        if (key_we)
            key_reg[address[2:0]] <= write_data;

        if (block_we)
            block_reg[address[1:0]] <= write_data;
    end
end

//-----------------------------------------------------------------------------
// api
//
// Cac lenh logic giai ma
//-----------------------------------------------------------------------------
always @(*) begin: api
    init_new = 1'b0;
    next_new = 1'b0;
    config_we = 1'b0;
    key_we = 1'b0;
    block_we = 1'b0;
    tmp_read_data = 32'h0;

    if (cs) begin
        if (we) begin
            if (address == ADDR_CTRL) begin
                init_new = write_data[CTRL_INIT_BIT];
                next_new = write_data[CTRL_NEXT_BIT];
            end

            if (address == ADDR_CONFIG)
                config_we = 1'b1;

            if ((address >= ADDR_KEY0) && (address <= ADDR_KEY3))
                key_we = 1'b1;

            if ((address >= ADDR_BLOCK0) && (address <= ADDR_BLOCK3))
                block_we = 1'b1;
        end
        else begin
            case (address)
                ADDR_NAME0: tmp_read_data = CORE_NAME0;
                
                ADDR_NAME1: tmp_read_data = CORE_NAME1;
                
                ADDR_VERSION: tmp_read_data = CORE_VERSION;
                
                ADDR_CTRL: tmp_read_data = {28'h0, keylen_reg, encdec_reg, next_reg, init_reg};
                
                ADDR_STATUS: tmp_read_data = {30'h0, valid_reg, ready_reg};

                default: begin
                end
            endcase

            if ((address >= ADDR_RESULT0) && (address <= ADDR_RESULT3))
                tmp_read_data = result_reg[(3 - (address - ADDR_RESULT0)) * 32 +: 32];
        end
    end
end

//------------------------------------------------------------------------------
endmodule