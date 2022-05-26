//-----------------------------------------------------------------------------
// tb_AES_128_Core.v
//
// Testbench for the AES block cipher core
//-----------------------------------------------------------------------------
module tb_AES_128_Core();

//-----------------------------------------------------------------------------
// Dinh danh hang so va tham so
//-----------------------------------------------------------------------------
parameter DEBUG = 0;
parameter DUMP_WAIT = 0;

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
reg tb_encdec;
reg tb_init;
reg tb_next;

reg [127:0] tb_key;
reg [127:0] tb_block;

wire tb_ready;
wire [127:0] tb_result;
wire tb_result_valid;

//-----------------------------------------------------------------------------
// Device Under Test (DUT)
//-----------------------------------------------------------------------------
AES_128_Core dut(
    .clk(tb_clk),
    .reset_n(tb_reset_n),
    .encdec(tb_encdec),
    .init(tb_init),
    .next(tb_next),
    .key(tb_key),
    .block(tb_block),
    
    .ready(tb_ready),
    .result(tb_result),
    .result_valid(tb_result_valid)
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
// Dump the state of the dump when needed
//-----------------------------------------------------------------------------
task dump_dut_state; 
    begin
        $display("State of DUT");
        $display("------------");
        $display("Inputs and outputs:");
        $display("encdec = 0x%01x, init = 0x%01x, next = 0x%01x",
                dut.encdec, dut.init, dut.next);
        $display("key    = 0x%032x ", dut.key);
        $display("block  = 0x%032x", dut.block);
        $display("");
        $display("ready        = 0x%01x", dut.ready);
        $display("result_valid = 0x%01x, result = 0x%032x",
                dut.result_valid, dut.result);
        $display("");
        $display("Encipher state::");
        $display("enc_ctrl = 0x%01x, round_ctr = 0x%01x",
                dut.enc_block.enc_ctrl_reg, dut.enc_block.round_ctr_reg);
        $display("");
    end
endtask

//-----------------------------------------------------------------------------
// dump_keys()
//
// Dua cac khoa vao bo nho khoa cua DUT
//-----------------------------------------------------------------------------
task dump_keys; 
    begin
        $display("State of key memory in DUT:");
        $display("key[00] = 0x%016x", dut.keymem.key_mem[00]);
        $display("key[01] = 0x%016x", dut.keymem.key_mem[01]);
        $display("key[02] = 0x%016x", dut.keymem.key_mem[02]);
        $display("key[03] = 0x%016x", dut.keymem.key_mem[03]);
        $display("key[04] = 0x%016x", dut.keymem.key_mem[04]);
        $display("key[05] = 0x%016x", dut.keymem.key_mem[05]);
        $display("key[06] = 0x%016x", dut.keymem.key_mem[06]);
        $display("key[07] = 0x%016x", dut.keymem.key_mem[07]);
        $display("key[08] = 0x%016x", dut.keymem.key_mem[08]);
        $display("key[09] = 0x%016x", dut.keymem.key_mem[09]);
        $display("key[10] = 0x%016x", dut.keymem.key_mem[10]);
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
        tb_encdec = 0;
        tb_init = 0;

        tb_next = 0;
        tb_key = {4{32'h00000000}};

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
// wait_valid()
//
// Doi co result_valid trong DUT duoc set len
//-----------------------------------------------------------------------------
task wait_valid;
    begin
        while (!tb_result_valid) 
            #(CLK_PERIOD);
    end
endtask

//-----------------------------------------------------------------------------
// ecb_mode_single_block_test()
//
// Thuc thi ECB mode encryption or decryption single block test
//-----------------------------------------------------------------------------
task ecb_mode_single_block_test(
    input [7:0] tc_number,
    input encdec,
    input [127:0] key,
    input [127:0] block,
    input [127:0] expected
);
    begin
        $display("*** TC %0d ECB mode test started.", tc_number);
        tc_ctr = tc_ctr + 1;

        // Khoi tao mat ma voi khoa va chieu dai
        tb_key = key;
        tb_init = 1;
        #(2 * CLK_PERIOD);
        tb_init = 0;
        wait_ready();

        $display("Key expansion done");
        $display("");

        dump_keys();

        // Thuc thi hoat dong cua khoi ma hoa hoac giai ma
        tb_encdec = encdec;
        tb_block = block;
        tb_next = 1;
        #(2 * CLK_PERIOD);
        tb_next = 0;
        wait_ready();

        if (tb_result == expected) begin
            $display("*** TC %0d successful", tc_number);
            $display("");
        end
        else begin
            $display("*** ERROR: TC %0d NOT successful", tc_number);
            $display("Expected: 0x%032x", expected);
            $display("Got:      0x%032x", tb_result);
            $display("");

            error_ctr = error_ctr + 1;
        end
    end
endtask

//-----------------------------------------------------------------------------
// tb_AES_core_test
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
initial begin: tb_AES_core_test
    reg [127:0] nist_aes128_key1;
    reg [127:0] nist_aes128_key2;

    reg [127:0] nist_plaintext0;
    reg [127:0] nist_plaintext1;
    reg [127:0] nist_plaintext2;
    reg [127:0] nist_plaintext3;
    reg [127:0] nist_plaintext4;
    reg [127:0] nist_plaintext5;

    reg [127:0] nist_ecb_128_enc_expected0;
    reg [127:0] nist_ecb_128_enc_expected1;
    reg [127:0] nist_ecb_128_enc_expected2;
    reg [127:0] nist_ecb_128_enc_expected3;
    reg [127:0] nist_ecb_128_enc_expected4;
    reg [127:0] nist_ecb_128_enc_expected5;

    nist_aes128_key1 = 256'h2b7e151628aed2a6abf7158809cf4f3c;
    nist_aes128_key2 = 256'h000102030405060708090a0b0c0d0e0f;

    nist_plaintext0 = 128'h6bc1bee22e409f96e93d7e117393172a;
    nist_plaintext1 = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
    nist_plaintext2 = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
    nist_plaintext3 = 128'hf69f2445df4f9b17ad2b417be66c3710;
    nist_plaintext4 = 128'h00112233445566778899aabbccddeeff;
    nist_plaintext5 = 128'h3243f6a8885a308d313198a2e0370734;

    nist_ecb_128_enc_expected0 = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
    nist_ecb_128_enc_expected1 = 128'hf5d3d58503b9699de785895a96fdbaaf;
    nist_ecb_128_enc_expected2 = 128'h43b1cd7f598ece23881b00e3ed030688;
    nist_ecb_128_enc_expected3 = 128'h7b0c785e27e8ad3f8223207104725dd4;
    nist_ecb_128_enc_expected4 = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    nist_ecb_128_enc_expected5 = 128'h3925841d02dc09fbdc118597196a0b32;

    $display("   -= Testbench for aes core started =-");
    $display("     ================================");
    $display("");

    init_sim();
    dump_dut_state();
    reset_dut();
    dump_dut_state();

    $display("ECB 128 bit key tests");
    $display("---------------------");

    ecb_mode_single_block_test(8'h01, AES_ENCIPHER, nist_aes128_key1,
                               nist_plaintext0, nist_ecb_128_enc_expected0);

    ecb_mode_single_block_test(8'h02, AES_ENCIPHER, nist_aes128_key1,
                               nist_plaintext1, nist_ecb_128_enc_expected1);

    ecb_mode_single_block_test(8'h03, AES_ENCIPHER, nist_aes128_key1,
                               nist_plaintext2, nist_ecb_128_enc_expected2);

    ecb_mode_single_block_test(8'h04, AES_ENCIPHER, nist_aes128_key1,
                               nist_plaintext3, nist_ecb_128_enc_expected3);


    ecb_mode_single_block_test(8'h05, AES_DECIPHER, nist_aes128_key1,
                               nist_ecb_128_enc_expected0, nist_plaintext0);

    ecb_mode_single_block_test(8'h06, AES_DECIPHER, nist_aes128_key1,
                               nist_ecb_128_enc_expected1, nist_plaintext1);

    ecb_mode_single_block_test(8'h07, AES_DECIPHER, nist_aes128_key1,
                               nist_ecb_128_enc_expected2, nist_plaintext2);

    ecb_mode_single_block_test(8'h08, AES_DECIPHER, nist_aes128_key1,
                               nist_ecb_128_enc_expected3, nist_plaintext3);


    ecb_mode_single_block_test(8'h09, AES_ENCIPHER, nist_aes128_key2,
                               nist_plaintext4, nist_ecb_128_enc_expected4);

    ecb_mode_single_block_test(8'h0a, AES_DECIPHER, nist_aes128_key2,
                               nist_ecb_128_enc_expected4, nist_plaintext4);

    ecb_mode_single_block_test(8'h0b, AES_ENCIPHER, nist_aes128_key1,
                               nist_plaintext5, nist_ecb_128_enc_expected5);

    $display("");

    display_test_result();
    $display("");
    $display("*** AES core simulation done. ***");
    $finish;
end

//-----------------------------------------------------------------------------
endmodule