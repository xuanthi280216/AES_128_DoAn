//-----------------------------------------------------------------------------
// tb_AES_128.v
//
// Khoi ma bao boc loi khoi AES_128 (AES_128_Core)
//-----------------------------------------------------------------------------
module tb_AES_128();

//-----------------------------------------------------------------------------
// Dinh danh hang so va tham so
//-----------------------------------------------------------------------------
parameter DEBUG = 0;

parameter CLK_HALF_PERIOD = 1;
parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

// The DUT address map
parameter ADDR_NAME0 = 8'h00;
parameter ADDR_NAME1 = 8'h01;
parameter ADDR_VERSION = 8'h02;

parameter ADDR_CTRL = 8'h08;
parameter CTRL_INIT_BIT = 0;
parameter CTRL_NEXT_BIT = 1;
parameter CTRL_ENCDEC_BIT = 2;
parameter CTRL_KEYLEN_BIT = 3;

parameter ADDR_STATUS = 8'h09;
parameter STATUS_READY_BIT = 0;
parameter STATUS_VALID_BIT = 1;

parameter ADDR_CONFIG = 8'h0a;

parameter ADDR_KEY0 = 8'h10;
parameter ADDR_KEY1 = 8'h11;
parameter ADDR_KEY2 = 8'h12;
parameter ADDR_KEY3 = 8'h13;

parameter ADDR_BLOCK0 = 8'h20;
parameter ADDR_BLOCK1 = 8'h21;
parameter ADDR_BLOCK2 = 8'h22;
parameter ADDR_BLOCK3 = 8'h23;

parameter ADDR_RESULT0 = 8'h30;
parameter ADDR_RESULT1 = 8'h31;
parameter ADDR_RESULT2 = 8'h32;
parameter ADDR_RESULT3 = 8'h33;

parameter AES_128_BIT_KEY = 0;

parameter AES_DECIPHER = 1'b0;
parameter AES_ENCIPHER = 1'b1;

//-----------------------------------------------------------------------------
// (Thanh ghi va duong day) Register and Wire
//-----------------------------------------------------------------------------
reg [31:0] cycle_ctr;
reg [31:0] error_ctr;
reg [31:0] tc_ctr;

reg [31:0] read_data;
reg [127:0] result_data;

reg tb_clk;
reg tb_reset_n;
reg tb_cs;
reg tb_we;
reg [7:0] tb_address;
reg [31:0] tb_write_data;
wire [31:0] tb_read_data;

//-----------------------------------------------------------------------------
// Device Under Test (DUT)
//-----------------------------------------------------------------------------
AES_128 dut(
    .clk(tb_clk),
    .reset_n(tb_reset_n),

    // Dieu khien (Control)
    .cs(tb_cs),
    .we(tb_we),

    // Cac ngo du lieu (data port)
    .address(tb_address),
    .write_data(tb_write_data),
    .read_data(tb_read_data)
);

//-----------------------------------------------------------------------------
// clk_gen
//
// Chay chu ky theo xung nhip
//-----------------------------------------------------------------------------
always begin: clk_gen
    #CLK_HALF_PERIOD;
    tb_clk = !tb_clk;
end

//-----------------------------------------------------------------------------
// sys_monitor
//
// Mot quy trinh luon chay tao ra mot bo dem chu ky va hien thi
// co dieu kien thong tin ve DUT (cycle counter)
//-----------------------------------------------------------------------------
always begin: sys_monitor
    cycle_ctr = cycle_ctr + 1;
    #(CLK_PERIOD);
    if (DEBUG) begin
        dump_dut_state();
    end
end

//-----------------------------------------------------------------------------
// dump_dut_state
//
// Hien trancript kiem tra loi khi can thiet
//-----------------------------------------------------------------------------
task dump_dut_state; 
    begin
        $display("cycle: 0x%016x", cycle_ctr);
        $display("State of DUT");
        $display("------------");
        $display("ctrl_reg:   init   = 0x%01x, next   = 0x%01x", dut.init_reg, dut.next_reg);
        $display("config_reg: encdec = 0x%01x, length = 0x%01x ", dut.encdec_reg, dut.keylen_reg);
        $display("");

        $display("block: 0x%08x, 0x%08x, 0x%08x, 0x%08x",
                dut.block_reg[0], dut.block_reg[1], dut.block_reg[2], dut.block_reg[3]);
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// reset_dut()
//
// Chuyen doi dat lai de dua DUT vao trang thai da biet
//-----------------------------------------------------------------------------
task reset_dut; 
    begin
        $display("*** Toggle reset");
        tb_reset_n = 0;
        #(2 * CLK_PERIOD);
        tb_reset_n = 1;
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// display_test_result()
//
// Hien thi ket qua kiem tra tich luy
//-----------------------------------------------------------------------------
task display_test_result; 
    begin
        if (error_ctr == 0) 
            $display("--- All %02d test cases completed successfully", tc_ctr);
        else
            $display("--- %02d tests completed - %02d test cases did not complete successfully.",
                    tc_ctr, error_ctr);
    end
endtask

//-----------------------------------------------------------------------------
// init_sim()
//
// Khoi tao tat ca cac bo dem va chuc nang cua may kiem
// tra cung nhu thiet lap cac dau vao DUT thanh cac gia
// tri xac dinh
//-----------------------------------------------------------------------------
task init_sim; 
    begin
        cycle_ctr = 0;
        error_ctr = 0;
        tc_ctr = 0;

        tb_clk = 0;
        tb_reset_n = 1;

        tb_cs = 0;
        tb_we = 0;

        tb_address = 8'h0;
        tb_write_data = 32'h0;
    end
endtask

//-----------------------------------------------------------------------------
// write_word()
//
// Write the given word to the DUT using the DUT interface
//-----------------------------------------------------------------------------
task write_word(
    input [11:0] address,
    input [31:0] word
);
    begin
        if (DEBUG)
            begin
                $display("*** Writing 0x%08x to 0x%02x.", word, address);
                $display("");
            end

        tb_address = address;
        tb_write_data = word;
        tb_cs = 1;
        tb_we = 1;
        #(2 * CLK_PERIOD);
        tb_cs = 0;
        tb_we = 0;
    end
endtask

//-----------------------------------------------------------------------------
// write_block()
//
// Write the given block to the dut.
//-----------------------------------------------------------------------------
task write_block(
    input [127:0] block
);
    begin
        write_word(ADDR_BLOCK0, block[127:96]);
        write_word(ADDR_BLOCK1, block[95:64]);
        write_word(ADDR_BLOCK2, block[63:32]);
        write_word(ADDR_BLOCK3, block[31:0]);
    end
endtask

//-----------------------------------------------------------------------------
// read_word()
//
// Read a data word from the given address in the DUT.
// the word read will be available in the global variable
// read_data
//-----------------------------------------------------------------------------
task read_word(
    input [11:0] address
);
    begin
        tb_address = address;
        tb_cs = 1;
        tb_we = 0;
        #(CLK_PERIOD);
        read_data = tb_read_data;
        tb_cs = 0;

        if (DEBUG) begin
            $display("*** Reading 0x%08x from 0x%02x.", read_data, address);
            $display("");
        end
    end
endtask

//-----------------------------------------------------------------------------
// read_result()
//
// Read the result block in the dut
//-----------------------------------------------------------------------------
task read_result; 
    begin
        read_word(ADDR_RESULT0);
        result_data[127:96] = read_data;
        read_word(ADDR_RESULT1);
        result_data[95:64] = read_data;
        read_word(ADDR_RESULT2);
        result_data[63:32] = read_data;
        read_word(ADDR_RESULT3);
        result_data[31:0] = read_data;
    end
endtask

//-----------------------------------------------------------------------------
// init_key()
//
// Nhap khoa trong DUT bang cach viet khoa va do dai khoa
// da cho roi kich hoat xu ly khoi dong
//-----------------------------------------------------------------------------
task init_key(
    input [127:0] key,
    input key_length
);
    begin
        if (DEBUG) begin
            $display("key length: 0x%01x", key_length);
            $display("Initializing key expansion for key: 0x%016x", key);
        end

        write_word(ADDR_KEY0, key[127:96]);
        write_word(ADDR_KEY1, key[95:64]);
        write_word(ADDR_KEY2, key[63:32]);
        write_word(ADDR_KEY3, key[31:0]);

        if (key_length)
            write_word(ADDR_CONFIG, 8'h2);
        else
            write_word(ADDR_CONFIG, 8'h0);
        
        write_word(ADDR_CTRL, 8'h1);

        #(100 * CLK_PERIOD);
    end
endtask

//-----------------------------------------------------------------------------
// ecb_mode_single_block_test()
//
// Perform ECB mode encryption or decryption single block test
//-----------------------------------------------------------------------------
task ecb_mode_single_block_test(
    input [7:0] tc_number,
    input encdec,
    input [255:0] key,
    input key_length,
    input [127:0] block,
    input [127:0] expected
);
    begin
        $display("*** TC %0d ECB mode test started.", tc_number);
        tc_ctr = tc_ctr + 1;

        init_key(key, key_length);
        write_block(block);
        dump_dut_state();

        write_word(ADDR_CONFIG, (8'h0 + (key_length << 1) + encdec));
        write_word(ADDR_CTRL, 8'h2);

        #(100 * CLK_PERIOD);

        read_result();

        if (result_data == expected) begin
            $display("*** TC %0d successful.", tc_number);
            $display("");
        end
        else begin
            $display("*** ERROR: TC %0d NOT successful.", tc_number);
            $display("Expected: 0x%032x", expected);
            $display("Got:      0x%032x", result_data);
            $display("");

            error_ctr = error_ctr + 1;
        end
    end
endtask

//-----------------------------------------------------------------------------
// tb_AES_test
//
// Ham kiem tra chuc nang chinh
//
// Test vectors copied from the follwing NIST documents.
//
// NIST SP 800-38A:
// http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
//
// NIST FIPS-197, Appendix C:
// https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
//
// Test cases taken from NIST SP 800-38A:
// http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
//-----------------------------------------------------------------------------
task AES_test;
    reg [127:0] nist_aes128_key1;
    reg [127:0] nist_aes128_key2;

    reg [127:0] nist_plaintext0;
    reg [127:0] nist_plaintext1;
    reg [127:0] nist_plaintext2;
    reg [127:0] nist_plaintext3;
    reg [127:0] nist_plaintext4;

    reg [127:0] nist_ecb_128_enc_expected0;
    reg [127:0] nist_ecb_128_enc_expected1;
    reg [127:0] nist_ecb_128_enc_expected2;
    reg [127:0] nist_ecb_128_enc_expected3;
    reg [127:0] nist_ecb_128_enc_expected4;

    begin
        nist_aes128_key1 = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        nist_aes128_key2 = 128'h000102030405060708090a0b0c0d0e0f;

        nist_plaintext0 = 128'h6bc1bee22e409f96e93d7e117393172a;
        nist_plaintext1 = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        nist_plaintext2 = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
        nist_plaintext3 = 128'hf69f2445df4f9b17ad2b417be66c3710;
        nist_plaintext4 = 128'h00112233445566778899aabbccddeeff;

        nist_ecb_128_enc_expected0 = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        nist_ecb_128_enc_expected1 = 128'hf5d3d58503b9699de785895a96fdbaaf;
        nist_ecb_128_enc_expected2 = 128'h43b1cd7f598ece23881b00e3ed030688;
        nist_ecb_128_enc_expected3 = 128'h7b0c785e27e8ad3f8223207104725dd4;
        nist_ecb_128_enc_expected4 = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

        $display("ECB 128 bit key tests");
        $display("---------------------");

        ecb_mode_single_block_test(8'h01, AES_ENCIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_plaintext0, nist_ecb_128_enc_expected0);

        ecb_mode_single_block_test(8'h02, AES_ENCIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_plaintext1, nist_ecb_128_enc_expected1);

        ecb_mode_single_block_test(8'h03, AES_ENCIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_plaintext2, nist_ecb_128_enc_expected2);

        ecb_mode_single_block_test(8'h04, AES_ENCIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_plaintext3, nist_ecb_128_enc_expected3);


        ecb_mode_single_block_test(8'h05, AES_DECIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_ecb_128_enc_expected0, nist_plaintext0);

        ecb_mode_single_block_test(8'h06, AES_DECIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_ecb_128_enc_expected1, nist_plaintext1);

        ecb_mode_single_block_test(8'h07, AES_DECIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_ecb_128_enc_expected2, nist_plaintext2);

        ecb_mode_single_block_test(8'h08, AES_DECIPHER, nist_aes128_key1, AES_128_BIT_KEY,
                                   nist_ecb_128_enc_expected3, nist_plaintext3);


        ecb_mode_single_block_test(8'h09, AES_ENCIPHER, nist_aes128_key2, AES_128_BIT_KEY,
                                   nist_plaintext4, nist_ecb_128_enc_expected4);

        ecb_mode_single_block_test(8'h0a, AES_DECIPHER, nist_aes128_key2, AES_128_BIT_KEY,
                                   nist_ecb_128_enc_expected4, nist_plaintext4);
                        
        $display("");
    end
endtask
    
//-----------------------------------------------------------------------------
// main
//
// Ham kiem tra chuc nang chinh
//-----------------------------------------------------------------------------
initial begin: main
    $display("   -= Testbench for AES started =-");
    $display("    ==============================");
    $display("");

    init_sim();
    dump_dut_state();
    reset_dut();
    dump_dut_state();

    AES_test();

    display_test_result();

    $display("");
    $display("*** AES simulation done. ***");
    $finish;
end

//-----------------------------------------------------------------------------
endmodule