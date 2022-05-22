//-----------------------------------------------------------------------------
// tb_AES_128_Encipher_Block.v
//
// Testbech cho module AES Encipher Block
//-----------------------------------------------------------------------------
module tb_AES_128_Encipher_Block();

//-----------------------------------------------------------------------------
// Dinh danh hang so va tham so
//-----------------------------------------------------------------------------
parameter DEBUG = 0;
parameter DUMP_WAIT = 1;

parameter CLK_HALF_PERIOD = 1;
parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

parameter AES_128_BIT_KEY = 0;

parameter AES_DECIPHER = 1'b0;
parameter AES_ENCIPHER = 1'b1;

//-----------------------------------------------------------------------------
// (Thanh ghi va duong day) Register and Wire
//-----------------------------------------------------------------------------
reg [31:0] cycle_ctr;
reg [31:0] error_ctr;
reg [31:0] tc_ctr;

reg tb_clk;
reg tb_reset_n;

reg tb_next;
wire tb_ready;
wire [3:0] tb_round;
wire [127:0] tb_round_key;

wire [31:0] tb_sbox;
wire [31:0] tb_new_sbox;

reg [127:0] tb_block;
wire [127:0] tb_new_block;

reg [127:0] key_mem [0:10];

//-----------------------------------------------------------------------------
// Assignments
//-----------------------------------------------------------------------------
assign tb_round_key = key_mem[tb_round];

//-----------------------------------------------------------------------------
// Device Under Test (DUT)
//-----------------------------------------------------------------------------
// Goi module Sbox
AES_Sbox sbox(
    .sbox(tb_sbox),
    .new_sbox(tb_new_sbox)
);

// DUT
AES_128_Encipher_Block dut(
    .clk(tb_clk),
    .reset_n(tb_reset_n),
    .next(tb_next),
    .round_key(tb_round_key),
    .new_sbox(tb_new_sbox),
    .block(tb_block),

    .round(tb_round),
    .sbox(tb_sbox),
    .new_block(tb_new_block),
    .ready(tb_ready)
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
        $display("State of DUT");
        $display("------------");
        $display("Interfaces");
        $display("ready = 0x%01x, next = 0x%01x",
                dut.ready, dut.next);
        $display("block     = 0x%032x", dut.block);
        $display("new_block = 0x%032x", dut.new_block);
        $display("");

        $display("Control states");
        $display("round = 0x%01x", dut.round);
        $display("enc_ctrl = 0x%01x, update_type = 0x%01x, sword_ctr = 0x%01x, round_ctr = 0x%01x",
                dut.enc_ctrl_reg, dut.update_type, dut.sword_ctr_reg, dut.round_ctr_reg);
        $display("");

        $display("Internal data values");
        $display("round_key = 0x%016x", dut.round_key);
        $display("sbox = 0x%08x, new_sbox = 0x%08x", dut.sbox, dut.new_sbox);
        $display("block_w0_reg = 0x%08x, block_w1_reg = 0x%08x, block_w2_reg = 0x%08x, block_w3_reg = 0x%08x",
                dut.block_w0_reg, dut.block_w1_reg, dut.block_w2_reg, dut.block_w3_reg);
        $display("");
        $display("old_block          = 0x%08x", dut.round_logic.old_block);
        $display("shiftrows_block    = 0x%08x", dut.round_logic.shiftrows_block);
        $display("mixcolumns_block   = 0x%08x", dut.round_logic.mixcolumns_block);
        $display("addkey_init_block  = 0x%08x", dut.round_logic.addkey_init_block);
        $display("addkey_main_block  = 0x%08x", dut.round_logic.addkey_main_block);
        $display("addkey_final_block = 0x%08x", dut.round_logic.addkey_final_block);
        $display("block_w0_new = 0x%08x, block_w1_new = 0x%08x, block_w2_new = 0x%08x, block_w3_new = 0x%08x",
                dut.block_new[127:96], dut.block_new[95:64],
                dut.block_new[63:32],  dut.block_new[31:0]);
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
        $display("--- Toggle reset");
        tb_reset_n = 0;
        #(2 * CLK_PERIOD);
        tb_reset_n = 1;
        $display("");
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

        tb_next = 0;

        tb_block = {4{32'h00000000}};
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
// wait_ready()
//
// Doi co flag trong dut de dat
//-----------------------------------------------------------------------------
task wait_ready; 
    begin
        while (!tb_ready) begin
            #(CLK_PERIOD);

            if (DUMP_WAIT)
                dump_dut_state();
        end
    end
endtask

//-----------------------------------------------------------------------------
// test_ecb_enc()
//
// Perform ECB mode encryption test
//-----------------------------------------------------------------------------
task test_ecb_enc(
    input [127:0] block,
    input [127:0] expected
);
    begin
        tc_ctr = tc_ctr + 1;

        $display("--- ECB mode test started");

        // Thuc hien hoat dong encipher tren khoi
        tb_block = block;
        tb_next = 1;
        #(2 * CLK_PERIOD);
        tb_next = 0;
        #(2 * CLK_PERIOD);

        wait_ready();

        if (tb_new_block == expected) begin
            $display("--- Testcase successful");
            $display("--- Got: 0x%032x", tb_new_block);
        end
        else begin
            $display("--- ERROR: Testcase NOT successful");
            $display("--- Expected: 0x%032x", expected);
            $display("--- Got:      0x%032x", tb_new_block);
            error_ctr = error_ctr + 1;
        end

        $display("--- ECB mode test completed");
    end
endtask

//-----------------------------------------------------------------------------
// load_nist128_key
//-----------------------------------------------------------------------------
task load_nist128_key; 
    begin: load_nist128_key
        key_mem[00] = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        key_mem[01] = 128'ha0fafe1788542cb123a339392a6c7605;
        key_mem[02] = 128'hf2c295f27a96b9435935807a7359f67f;
        key_mem[03] = 128'h3d80477d4716fe3e1e237e446d7a883b;
        key_mem[04] = 128'hef44a541a8525b7fb671253bdb0bad00;
        key_mem[05] = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
        key_mem[06] = 128'h6d88a37a110b3efddbf98641ca0093fd;
        key_mem[07] = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
        key_mem[08] = 128'head27321b58dbad2312bf5607f8d292f;
        key_mem[09] = 128'hac7766f319fadc2128d12941575c006e;
        key_mem[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
    end
endtask

//-----------------------------------------------------------------------------
// load_nist128_key_2
//-----------------------------------------------------------------------------
task load_nist128_key_2; 
    begin: load_nist128_key_2
        key_mem[00] = 128'h000102030405060708090a0b0c0d0e0f;
        key_mem[01] = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
        key_mem[02] = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
        key_mem[03] = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
        key_mem[04] = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
        key_mem[05] = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
        key_mem[06] = 128'h5e390f7df7a69296a7553dc10aa31f6b;
        key_mem[07] = 128'h14f9701ae35fe28c440adf4d4ea9c026;
        key_mem[08] = 128'h47438735a41c65b9e016baf4aebf7ad2;
        key_mem[09] = 128'h549932d1f08557681093ed9cbe2c974e;
        key_mem[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;
    end
endtask

//-----------------------------------------------------------------------------
// test_nist_enc_128_0
//-----------------------------------------------------------------------------
task test_nist_enc_128_0; 
    begin: test_nist_enc_128_0
        reg [127:0] plaintext;
        reg [127:0] ciphertext;

        plaintext = 128'h3243f6a8885a308d313198a2e0370734;
        ciphertext = 128'h3925841d02dc09fbdc118597196a0b32;

        $display("--- test_nist_enc_128_0: Started");

        test_ecb_enc(plaintext, ciphertext);

        $display("--- test_nist_enc_128_0: Completed");
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// test_nist_enc_128_1
//-----------------------------------------------------------------------------
task test_nist_enc_128_1; 
    begin: test_nist_enc_128_1
        reg [127:0] plaintext;
        reg [127:0] ciphertext;

        plaintext = 128'h6bc1bee22e409f96e93d7e117393172a;
        ciphertext = 128'h3ad77bb40d7a3660a89ecaf32466ef97;

        $display("--- test_nist_enc_128_1: Started");

        test_ecb_enc(plaintext, ciphertext);

        $display("--- test_nist_enc_128_1: Completed");
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// test_nist_enc_128_2
//-----------------------------------------------------------------------------
task test_nist_enc_128_2; 
    begin: test_nist_enc_128_2
        reg [127:0] plaintext;
        reg [127:0] ciphertext;

        plaintext = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        ciphertext = 128'hf5d3d58503b9699de785895a96fdbaaf;

        $display("--- test_nist_enc_128_2: Started");

        test_ecb_enc(plaintext, ciphertext);

        $display("--- test_nist_enc_128_2: Completed");
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// test_nist_enc_128_3
//-----------------------------------------------------------------------------
task test_nist_enc_128_3; 
    begin: test_nist_enc_128_3
        reg [127:0] plaintext;
        reg [127:0] ciphertext;

        plaintext = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
        ciphertext = 128'h43b1cd7f598ece23881b00e3ed030688;

        $display("--- test_nist_enc_128_3: Started");

        test_ecb_enc(plaintext, ciphertext);

        $display("--- test_nist_enc_128_3: Completed");
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// test_nist_enc_128_4
//-----------------------------------------------------------------------------
task test_nist_enc_128_4; 
    begin: test_nist_enc_128_4
        reg [127:0] plaintext;
        reg [127:0] ciphertext;

        plaintext = 128'hf69f2445df4f9b17ad2b417be66c3710;
        ciphertext = 128'h7b0c785e27e8ad3f8223207104725dd4;

        $display("--- test_nist_enc_128_4: Started");

        test_ecb_enc(plaintext, ciphertext);

        $display("--- test_nist_enc_128_4: Completed");
        $display("");
    end
endtask

/*
//-----------------------------------------------------------------------------
// test_nist_enc_128_5
//-----------------------------------------------------------------------------
task test_nist_enc_128_5;
    begin: test_nist_enc_128_5
        reg [127:0] plaintext;
        reg [127:0] ciphertext;

        plaintext = 128'h00112233445566778899aabbccddeeff;
        ciphertext = 128'h000102030405060708090a0b0c0d0e0f;

        $display("--- test_nist_enc_128_5: Started");

        test_ecb_enc(plaintext, ciphertext);

        $display("--- test_nist_enc_128_5: Completed");
        $display("");
    end
endtask
*/

//-----------------------------------------------------------------------------
// tb_AES_Encipher_Block
//
// Ham tb chinh
//-----------------------------------------------------------------------------
initial begin: tb_AES_Encipher_Block
    $display("   -= Testbench for aes encipher block started =-");
    $display("     ============================================");
    $display("");

    init_sim();
    reset_dut();

    load_nist128_key();
    test_nist_enc_128_0();
    test_nist_enc_128_1();
    test_nist_enc_128_2();
    test_nist_enc_128_3();
    test_nist_enc_128_4();

/*
    load_nist128_key_2();
    test_nist_enc_128_5();
*/

    display_test_result();
    $display("");
    $display("   -= Testbench for aes encipher block completed =-");
    $display("     ============================================");
    $finish;
end

//-----------------------------------------------------------------------------
endmodule