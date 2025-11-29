// DO NOT MODIFY THE TESTBENCH
`timescale 1 ns/10 ps

`define CYCLE 10          // Do not change this value!!!
`define END_CYCLE 5000 // You can modify your maximum cycles

`define SIZE_DATA 1024  // You can change the size
`define SIZE_STACK 32  // You can change the size
`define COOL_OUTPUT 0  // Modify to 1 for cool output figures
`ifdef DOCKER
    `ifdef I1
        `define MEM_INST "/root/project/code/Pattern/I1/mem_I.dat"
        `define MEM_DATA "/root/project/code/Pattern/I1/mem_D.dat"
        `define MEM_GOLDEN "/root/project/code/Pattern/I1/golden.dat"
    `elsif I2
        `define MEM_INST "/root/project/code/Pattern/I2/mem_I.dat"
        `define MEM_DATA "/root/project/code/Pattern/I2/mem_D.dat"
        `define MEM_GOLDEN "/root/project/code/Pattern/I2/golden.dat"
    `elsif I3
        `define MEM_INST "/root/project/code/Pattern/I3/mem_I.dat"
        `define MEM_DATA "/root/project/code/Pattern/I3/mem_D.dat"
        `define MEM_GOLDEN "/root/project/code/Pattern/I3/golden.dat"
    `elsif I4
        `define MEM_INST "/root/project/code/Pattern/I4/mem_I.dat"
        `define MEM_DATA "/root/project/code/Pattern/I4/mem_D.dat"
        `define MEM_GOLDEN "/root/project/code/Pattern/I4/golden.dat"
    `endif
`elsif LOCAL
    `ifdef I1
        `define MEM_INST "code/Pattern/I1/mem_I.dat"
        `define MEM_DATA "code/Pattern/I1/mem_D.dat"
        `define MEM_GOLDEN "code/Pattern/I1/golden.dat"
    `elsif I2
        `define MEM_INST "code/Pattern/I2/mem_I.dat"
        `define MEM_DATA "code/Pattern/I2/mem_D.dat"
        `define MEM_GOLDEN "code/Pattern/I2/golden.dat"
    `elsif I3
        `define MEM_INST "code/Pattern/I3/mem_I.dat"
        `define MEM_DATA "code/Pattern/I3/mem_D.dat"
        `define MEM_GOLDEN "code/Pattern/I3/golden.dat"
    `elsif I4
        `define MEM_INST "code/Pattern/I4/mem_I.dat"
        `define MEM_DATA "code/Pattern/I4/mem_D.dat"
        `define MEM_GOLDEN "code/Pattern/I4/golden.dat"
    `endif
`endif
module Final_tb;

    reg             clk, rst_n ;
    
    wire            cache_wen, cache_cen, cache_stall;
    wire    [31:0]  cache_addr;
    wire    [31:0]  cache_wdata;
    wire    [31:0]  cache_rdata;

    wire            DMEM_wen, DMEM_cen, DMEM_stall, SMEM_stall, mem_stall;
    wire    [31:0]  DMEM_addr;
    wire    [127:0]  DMEM_wdata;
    wire    [127:0]  DMEM_rdata;
    
    wire    [31:0]  IMEM_addr;
    reg     [31:0]  IMEM_data;
    wire            IMEM_cen;
    reg     [31:0]  mem_inst[0:1023];

    wire    [3:0]   inst_type;

    reg     [31:0]  DMEM_golden [0:`SIZE_DATA-1];
    reg     [31:0]  mem_data;
    reg     [31:0]  mem_inst_offset;
    reg     [31:0]  mem_data_offset;
    reg     [31:0]  mem_stack_offset;
    wire    [31:0]  mem_I_addr;
    wire            cache_available;
    wire            cache_finish;
    wire            proc_finish;

    wire            finish;

    integer i, cyc;
    
    integer eof, DMEM_OS;
    reg eof_find;

    integer error_num;

    assign mem_stall = DMEM_stall | SMEM_stall;
    

    
    CPU cpu0(
        // clock
            .i_clk          (clk),
            .i_rst_n        (rst_n),
        // instruction memory
            .i_IMEM_data    (IMEM_data),
            .o_IMEM_addr    (IMEM_addr),
            .o_IMEM_cen     (IMEM_cen),
        // data memory
            .i_DMEM_stall   (cache_stall),
            .i_DMEM_rdata   (cache_rdata),
            .o_DMEM_cen     (cache_cen),
            .o_DMEM_wen     (cache_wen),
            .o_DMEM_addr    (cache_addr),
            .o_DMEM_wdata   (cache_wdata),
        // finnish procedure
            .o_finish       (finish),
        // cache
            .i_cache_finish (cache_finish),
            .o_proc_finish  (proc_finish)
    );

    memory #(.SIZE(`SIZE_DATA)) DMEM(
        .i_clk      (clk),
        .i_rst_n    (rst_n),
        .i_cen      (DMEM_cen),
        .i_wen      (DMEM_wen),
        .i_addr     (DMEM_addr),
        .i_wdata    (DMEM_wdata),
        .o_rdata    (DMEM_rdata),
        .o_stall    (DMEM_stall),
        .i_offset   (mem_data_offset),
        .i_ubound   (mem_stack_offset),
        .i_cache    (cache_available)
    );

    memory #(.SIZE(`SIZE_STACK)) SMEM(
        .i_clk      (clk),
        .i_rst_n    (rst_n),
        .i_cen      (DMEM_cen),
        .i_wen      (DMEM_wen),
        .i_addr     (DMEM_addr),
        .i_wdata    (DMEM_wdata),
        .o_rdata    (DMEM_rdata),
        .o_stall    (SMEM_stall),
        .i_offset   (mem_stack_offset),
        .i_ubound   (32'hbffffff0),
        .i_cache    (cache_available)
    );

    Cache cache(
        // clock
            .i_clk          (clk),
            .i_rst_n        (rst_n),
        // processor interface
            .o_proc_stall   (cache_stall),
            .o_proc_rdata   (cache_rdata),
            .i_proc_cen     (cache_cen),
            .i_proc_wen     (cache_wen),
            .i_proc_addr    (cache_addr),
            .i_proc_wdata   (cache_wdata),
            .i_proc_finish  (proc_finish),
            .o_cache_finish (cache_finish),
        // memory interface
            .o_mem_cen      (DMEM_cen),
            .o_mem_wen      (DMEM_wen),
            .o_mem_addr     (DMEM_addr),
            .o_mem_wdata    (DMEM_wdata),
            .i_mem_rdata    (DMEM_rdata),
            .i_mem_stall    (mem_stall),
            .o_cache_available (cache_available),
        // others
            .i_offset (mem_data_offset)
    );

    // Initialize the data memory
    initial begin
        $dumpfile("Final.vcd");
        $dumpvars(0,Final_tb);

        `ifdef I1
        $display("------------------------------------------------------------\n");
        $display("START!!! I1 Simulation Start .....\n");
        $display("------------------------------------------------------------\n");
        `elsif I2
        $display("------------------------------------------------------------\n");
        $display("START!!! I2 Simulation Start .....\n");
        $display("------------------------------------------------------------\n");
        `elsif I3
        $display("------------------------------------------------------------\n");
        $display("START!!! I3 Simulation Start .....\n");
        $display("------------------------------------------------------------\n");
        `elsif I4
        $display("------------------------------------------------------------\n");
        $display("START!!! I4 Simulation Start .....\n");
        $display("------------------------------------------------------------\n");
        `endif
        
        clk = 1;
        rst_n = 1'b1;
        cyc = 0;
        mem_inst_offset = 32'h00010000;
        mem_stack_offset = 32'hbffffff0 - `SIZE_STACK*4;
        eof_find = 0;

        $readmemh (`MEM_INST, mem_inst); // initialize data in mem_I

        for (i=0; i<`SIZE_DATA; i=i+1) begin
            if ((mem_inst[i] === 32'bx) && !eof_find) begin
                eof = mem_inst_offset + i*4;
                eof_find = 1;
            end
        end

        mem_data_offset = eof;

        #(`CYCLE*0.5) rst_n = 1'b0;
        #(`CYCLE*2.0) rst_n = 1'b1;
                
        for (i=0; i<`SIZE_DATA; i=i+1) begin
            mem_inst[i] = 32'h0000_0073;
        end
        $readmemh (`MEM_INST, mem_inst); // initialize data in mem_I
        
        for (i=0; i<`SIZE_DATA; i=i+1) begin
            DMEM.mem[i] = 0;
        end

        for (i=0; i<`SIZE_DATA; i=i+1) begin
            DMEM_golden[i] = 0;
        end
        $readmemh (`MEM_DATA, DMEM.mem); // initialize data in mem_D
        $readmemh (`MEM_GOLDEN, DMEM_golden); // initialize data in mem_D
    end

    initial begin
        IMEM_data = 0;
    end

    assign mem_I_addr = (IMEM_addr - mem_inst_offset)>>2;

    always @(negedge clk) begin
        IMEM_data = IMEM_cen ? mem_inst[mem_I_addr] : IMEM_data;
    end

    initial begin
        #(`CYCLE*`END_CYCLE)
        if (`COOL_OUTPUT) begin
            fail_fig;
        end
        $display("============================================================\n");
        $display("Simulation time is longer than expected.");
        $display("The test result is .....FAIL :(\n");
        $display("============================================================\n");
        
        $finish;
    end
    
    initial begin
        // @(IMEM_addr === eof);
        // #(`CYCLE*10)
        @(finish === 1);
        error_num = 0;
        for (i=0; i<`SIZE_DATA; i=i+1) begin
            mem_data = DMEM.mem[i];
            if (mem_data !== DMEM_golden[i]) begin
                if (error_num == 0)
                    $display("Error!");
                error_num = error_num + 1;
                $display("  Addr = 0x%8d  Golden: 0x%8h  Your ans: 0x%8h", (mem_data_offset + i*4), DMEM_golden[i], mem_data);
            end
        end
        if(cyc < 5) begin
            $display("Error! Files read failed.");
        end
        else if (error_num > 0) begin
            if (`COOL_OUTPUT) begin
                fail_fig;
            end
            $display(" ");
            $display("============================================================\n");
            $display("There are total %4d errors in the data memory", error_num);
            $display("The test result is .....FAIL :(\n");
            $display("============================================================\n");
        end
        else begin
            if (`COOL_OUTPUT) begin
                pass_fig;
            end
            $display("============================================================\n");
            $display("Success!");
            $display("The test result is .....PASS :)");
            $display("Total execution cycle : %d", cyc);
            $display("============================================================\n");
        end

        $finish;
    end
        
    always #(`CYCLE*0.5) clk = ~clk;

    always @(negedge clk) begin
        cyc = cyc + 1;
    end


    task fail_fig;
        begin
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmnnnnmmmmmzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmmmmzzzmzzzzzzzzzzzzzzzzzzzzmmzzzzzmmmmmmmmnnnnnnnmmmzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzzzzmmzzzzzzzzmmmmmmmmmmmnmmzzzzzzzzzzzzzzzzzzmzzzzzzmmmmmnnnnnnnnnnnmmzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmmmzmzzmmzzzmmmmmzzzmmmmmmmmmmmmmmmmmmmzzzzzzzzzzzzzzzzzzzmmmnnnnnnnn*nnmmmmmmzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzzzzzzzzzmmmmmmzmmmmmnmmmmmzzzmmmmmmmmmmmmnnnnnmmmzzzzzzzzzzzzzzzznnnnnnnnnnnnnmmmmmmmmmzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmmmmmzmmzmmmmnnmmnmmnmnnnmmmmnmzzzzmmmmmmmmmnnnnnnnmmmmmzzzzzzzzzzzzzmmnn*nn**nnn*nnnnmmmzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzzzmmmmnnmmnnmmnmmnnnnnnnnnnnnnnnnnmzzmmmmmmmmmmmmmnnnnnnnmmmmmmzzzzzzzzzzzmnnn****n*nnnnnmmmzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzmmmmmmnnnnnnnnmnnmnnnnnnnn******nnnnnnnnmmnnnnmzzzzzzmnnnn**nnnmmmmmmmzzzzzzzzzmnnnnnn**nmnnnnmmmzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzmmmmmnnnnnnnnnnmnnnnnnnn**************nnnnnnnnzzzzzzzzzmmn**++*nnmnnmmzzzmzzzzzzzmn**+*****mmmnmmmzmmmmzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzmmmmmmnnnnnnnnnnnnnnnnnn***n***+***********nnnnmzzzzzzzzzmmn*++=+*nmmmmmmmmmzzzzzzzmmmm*++++**nzmnnmmmmmmmmzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzmmmmmnnnmmnnnn*nnn****nnn****+**nm*++++++++********nzzzzzzzzzzmmmn*+-=*nnnmmmmmmzzzzzzzzmzm*+n*+++++*z**nmmmmmmmmzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzmmmmmnnnnnnnnnnnnmmmnm*******++++*nn*+++++==+++****nn*nzzzzzzzzzmmnn*+=-=+*nnnmmzzzzzzzzzzzzn...:nn*+++mm**nmmmmmmmzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzmmmmmmnnnnnnn*****nmn*nmn******+++**nnn*++=======+++++++nzzzzzzzzzmmmn**=--+nnmmmmmmmmmmzzzzzz+.....:n*==*zn**nmmmmmzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzmmmmmmmnnnn*******+===+++*****++**nnnmn*++==:::::===++*nnmzzzzzzzzmmmnn+=-====+*nmmmmnnnmzzzzz+.......=n*+mz**nmmmmmzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzmmmmmmnmmmnnn******+=:.:-+++****+*nmmmmmmn*++=:.....:=+**nnmmzzzzzzzmmmmn*=-:..:+*nnnnmmzzzzzzzzn:.......:*n*zmnnmmmzmzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzmmmnnmnnnnnmmn****++=-:..:-=++****nmmmzmmmm**++-:.....-=++*nnmzzzzzzzmmmmn*+=-...=+nmmmmmmzzzzzzzm=.........*mzzmmmzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzmmmnnnn****nn****++==:....:-=++++nnmmzzzmmmnn**=-:....:==+***mzzzzzzzzmmmmn*+:...:-+*nnnnnnnnmzzzzm=.........mzzzmmzzmmmzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzmnmnn*****nnnn****++++-:....:-==+++nnmzzzmmmnnn*=-:......-+**nmzzzzzzzzznmnn+-....:-+nnnnnnnnnzzzzzzm=.......=mzzzmzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzmnmnnn*++**nnnn*******+=-:.....-=+==+nzzzzzzzmnn*+-:......:=++*nnmzzzzzzzmnnn+-....:-+*nnnnnnmmzzzzzzzm*-....:+*nnzzzmmnmzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzmmmmn**+++*nnnmn******++=-:....:-===+*zzmmmzzmnnn+=:......:-=++*nnmzzzzzzzmnn*-:....:=+nnnnmmzzzzzzzzmnnnn+-+*=++*****+*mzzzmn***nzzzzzzzz");
$display("zzzzzzzzzzzzzmmmn*+=++**nnnnn*******+=:.....-==+**nmnmzzzmnnn*=-:......:-=+**nnmzzzzzzmnnn*=:...-+n*+*nnmmzzzzzzzmn*++nn*+*+++=--+nn*=.....-nzzzzzzzzz");
$display("zzzzzzzzzzzzzmmn*+=-+****nnnnnnn****+=::.....-=+***nmmzzzzmnnn+=::......-=++nmmzzzzzzzzmmnn+-..:-mmmmz**nnmmzzzzzzm*+-------:::*zzn=:..-*zzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzmmn*+===+**n**mzmmn****++=-......:=+***nmnzzzznnn*+-::.....:=+++nmmmzzzzzzmnn*+=-:=mmzzzzzzzzzzzzzzzzn*=--:::::.:mzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzmn+---+**nmzzzzzmnn****++-......:=+*nmmmmzzzmnnn*=-:......-++**nnnmmzzzzzmnn*++=++mzzzzmnn==mzzzzzzzm*=-::::.:mzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzmnn=:..-*nmzzzzzzzzzmn***+-:......:=+**nmmmzmzzmnn+=-::....=+***nnmmmzzzzzmmnn***++mzn*mm*zm*.+mnzzzzzn=-::::-mzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzmmn*=..-+nmzzzzzzzzzmnn**+=-......:-=+**nmmzzmzzmm*+=-::::-=++**nnnmmzzzzzzzmnnnn*++zmnmm*-+::=*=*nzm**=----=nzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzmmn*-:-+*nzzzzzzzzzmnn**++=:......:-+**nmzzzzzzmmn*++=====++***nnmmmmzzzzzzzmmnnnnn*znnmmmzmnnmmn+:mm+mnmmnmzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzmnn*-:-+nmzzzzzzzzzmn***++=:......:=*nnnmmmzmzmmmmnn**++****nnnnmmmzzzzzzzzzmmmmnn:mmnnmmmz*zzzzm=*z+zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzmmmnn+==nnnzzzzzzzzmmnnn*+=-......-+*nnnmmzzzzzmmmmmnnn*nnnnnmmmmmzzzzzzzzzzzzzzzn.*mmzmmnmzmzzzzz*nnzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzmmn*-:=*nnmzzzzzzzmmmnn*+-:.....:+*nnnnmzzzzzzzzmmmmnnnnmmmmmmzzzzzzzzzzzzzzzzzzn:-mmzzzzzzzzzzz+nzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzmnm*+-:*nnmzzzzzzzzmmnnn*+=:....:-=+nnmmzzzzzzzzzzzmmmmmmmmzzzzzzzzzzzzzzzzzzzzzn*=nmzzzzzzzzzzznzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzmmn*++**nmmmzzzzzzzmmmmnnn*=:..-+**nmmzzzzzzzzzzzzzzzmmzzzzzzzzzzzzzzzzzzzzzzzz*zznnzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzmmmmn**nnmmzzzzzzzzzmmmmmmn**nnmmmmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzmnnnnmmmmzzzzzzzzzzzzmmmmmmmmmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzmmmmmmmmmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzmmmmmmmmmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzmmmmmmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzmmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzn*zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz");
$display("");
        end
    endtask

    task pass_fig;
        begin
$display("");
$display("x-------------=---=-------------.=zzzzz=.+..........................................................:.........zx.......................+kx+nxx+.........................................................");
$display("x------------------------------..zzzzz-.==...................................ƒ...............................+zz.......................knnxnx-...........................................................");
$display("x-----------------------------..zzzzz+.---................................................................+zkx:.....................:nk+xz-.............................................................");
$display("x::::::::::::::::::::::::::....kzzzzz..::::--.........-.................................................+kk++n.....................+knkk:...............................................................");
$display("x::::::::::::::::::::......zzzzzzzzz=.:::::::=:.......................................................:kkn:.n.....................zxxk-.................................................................");
$display("+::::::::::::::::::..:z=kzzzzzzzzzzz+.::::::::-:-......k.:...........................................nxxn..xn...................+nxk-...................................................................");
$display("+...................kzzzzzzzzzzzzz:...............:....nn.x...................................+...kzzk+x..+n...................x+k:.....................................................................");
$display("+................+kzzzzzzzzzzz=.................=.......n.+n.................................n...zzzkn+..+x..................-xn........................................................................");
$display("+...........xkzzzzzzzzzzzzn...................-=:.......nx.xn:...=..........................xk..zzzknx...++.:..............:kx..........................................................................");
$display("+...........kzzzzzzzz-.......................-..........=x-.xnn..++........................-z.:zzzzkn:..+xkz..............nn............................................................................");
$display("=..........-zzzzzzz-........................=............-n.:nkz.=zx.....................=xz.xzzzzzkx+.:xkk.............xz=.............................................................................");
$display("=..........zzzzzx................=k.........+...........+==x.xnkz+zzx...................nxkkkzzzzzkn+-=nkk............xn-...............................................................................");
$display("=.........zzzz-................kzz..xz-....-:.............x+.-xnkzzzz=.................zkxzzzzzzzkn:==nkz...........=n:.................................................................................");
$display("=........nzk..................zzz.nzz:...................-:=-.=nkkzzzz+...............knkzzzzzzzkk:+:nkz+.........-x....................................................................................");
$display("=........:...................kzz.xzz...-..................:===.+nkkzzzzz..........:.-z+kzzzzzzzkn==.nkkzx.......kz-.........-zxnzz......................................................................");
$display("-.......................kzzxxzz+:zz...-...................:=xx=-+nkzzzzzznx=x+::=z:.zxkzzzzzzzknx..nnkzk+.....+x...:+n=-..-k=nzzk.....-x-...............................................................");
$display("-....................kzzzzk+zzn.zz........................+++x==+xnkzzzzzzn=+++kzzkzxkzzzzzzkkn=:.xnkzzxxx-==kxnx-z=:-:..n=-kzzzzzzzzzzzzzzzzzk+........................................................");
$display("-...............+kzzzzzzzk=zkk............................-+x+.-=+nnzzzzzzzzk.kzzzznzzzzzzzkk=+..xnkzzkknn+nzzk==+k.+-.=--=nzzzzzzzzzzzzzzzn+=x.........................................................");
$display("-..............zzzzzznzzk=.........=...................+zzzx=x-.n=+nkxzzzzzzzzzzzzz=zzzzzzkk++..=nkzz+-=xzzzzz=.:k.+x.x+++=zzzzzzzzzzzzzk-=+x.......................................................-..:");
$display("-.............xzzk:..zzk...........==...................+zzk:+x.x=x+n+nzzzzzzzzzzzk+zzzzzkkxx..=nnkz=+xzzzzzz+:.z.:=-kx+-xzzzzzzzzzzzk+n+=xn+.................................................kzzzz-....");
$display(":............-z.....zzk.....:.......-....................xzzx-+:.x+xnn:kkzzzzzzzzzxkzzzzzkn+..+nnkk-zzzzzzzz-:.xx.=-xx=+nzzzzzzzzzzzzn++++kzzzzzx.........................:xkk:..............zzzzzzz=xkz");
$display(":..................zzz......:.............................xznn+x.:+n+xx+nkzzzzzzznnzkkzk=x=..xnnzx:zzzzzzzz=-.=z.x-+k=xnzzzzznxnzkkzk-xnzzzzzzzzzzk.:+kx-.........:=+kzzzzzzn..............kzzzzzzzzzz+=");
$display(":.................zzz.........................knxxn+=nzn+nzzk+nx=.+=x+x.xkzzzzzz=kkkzzx....=xnkz+-zzzzzzzzz.::xx-:-nnkzzzzzzzzzzzkxnxxzzzzzzzzzzzzzzzx.....:=xkzzzzzzzzzzzkn-..........=zzzzzknx=......:");
$display(":..............+zzzz-......-....:-..............knx++kkkkkzkkk:xx..+-xxx:nkzzzkk:kkzz-.-=.xnkkz+xzzzzzz++zz=--n+=:xkzzkzzzzzzzzknnnkzzzzzkxkkknxnkzzzzzk....................:::::.......................");
$display(":...........=zzzzzzx............................+nnnxnnkkkkzz-=.+x..:=xx.xkzzzkkn=kk..nknnnzz++knzzzzzzk--:n:-:++-z=nkzzzzzzzkkkzzkzzzzzzzzzzzzzzzzn=...................................................");
$display("-..........zzzx-..................................nnnxxknkkkk.=:.xx..=+=+nnzzzzkxnx.-kkkkxzz=zzxzzzzzzzzzknxx--:kxzzzkkkkzzzzzzzzzzzzzzzzzzkx++n+-+x=...................................................");
$display(":.........nzzn.....................................kzznkkkkk=.nz:=xz+.==+nnzzzzz=:.=kzzk+nzz:z+z+zzzkzzzzzzzk--:-kzzzzz=x==nnzzzzzzzzzzzzzx+-+zzzk=:-.x.................................................");
$display(":........xz=......................................x==kknnxx+xxkz==+nzx.:+kkkkzzn-.nzkzzzx-zknz=kz+zk:-xnkkkn=.==-:nzzzznnnn=+kzzzzzzzzzzzzkkkkkkkkkkk-.-................................................");
$display(":........................+zz...................:n=--x+kkkkx=-:x:=-nnkk-.nkkkkzkn..zzkkkzzxzkknxzzzzzzzzzkkn.x+=+-:--xzzzznxxknxkzzzzzz+=+knxnnnxnnnnnx..:...............................................");
$display(":.......................xzz...................====nn+=-kkkz=+:=+.-xnzzn.+kkkkzzkn.....knxkk=+z+xx==kzzzzkn=nnn::-+-:xxnk=+zxx=++--kzzzzzn-nx++x=xnnnnn:.:...............................................");
$display(":................n+.....zz=...................x+nnnnn-=kkkk-.-:-.::x+.:.xkkkkzzzzkkk.=:.+xx.n+--:+zzn+kkkknn=n=..::-x::nkknzzzkkzzzzzzzzzknnx++xxxxnnnx.n+..............................................");
$display(":.............zzzk.kzk.kzk..................-nnnnnx.x-nnkkx:.=+x....+x.nkknkzzzzzzz....-=:=+nz+zn:xzzzkknn.nnn+:..--...+--nnnzk=:=+=nkxnkknnnnnxxxxxnxn==:=............................................:");
$display(":.......::+zzzzzz.=zz.=zz..................++--...==x+nkkk+-:+kx:..=-.:+nknnzzkzkkx...::.-.nkk++zzzzknn-..kkkx++==...-....++nnnkkkx++=xkknnnnnnnxxxnxx++=---+..........................................:");
$display(":......kzzzzzzzz+.zzx...........................:.-xxx+nkk+:.-kn:..-+x:.-x=.zz+kn=...-.:.=x+-kzzzzknx..xnkkkk-+:...++:=-..:-+xxxkk-nzzkkkk=nnnnnnnxx++=+++nx+-.........................................:");
$display(":.....:zzzz+.=zn.+zk...........................x:---x+xxkk+:--kn:..=xxn:..-xnzxk..++=x+.-xnzzzzzknx-..xnnkkn+=....xnnx+=.-:......=kz=:=k+x:xknnn+=+++++xnxnxnn=xn......................................:");
$display(":....+zz=....zz..z...........................:=++=-+=knnnnn:-.n+=...=xn+.+xxknkkknnnxn+=nkzzknknx+...=+xnxx-...:+nnxzn+=nzn-:--::-kzzx:.+xkkk+x++x++-+=nnnnnnnnx+x=......x.............................:");
$display(":....n......kz=..............................=xk-+-xxkzznkn+:-+=....-.+nn:--:.kzzzzkn=:nkkznxxnx-.............+nk+znkx=nznzzzzzzzzz.=zx..xknx:xxx+.nxn:-nnnnnnnnnknkznxkxnk............................:");
$display(":..........nzz................................kk-x=xxzzzzzn+=-:n-..-=.:-xnn-..xzzzkn:=nk+++++nx.............=xkkzzz+nxnz=zzzzzzzzz:....xkx:-xxxxnx:nnxn+.-xnnnkkkkkkzkxk=n.=...........................:");
$display(":......+zzzzz+...............................:++-==+nnzzzzzzzk=nn-...:+.+:+==..+nnx.nkkz+-=+nx...-+xxxxx+.:xnkkkzkkzkk=-zxzzzzzzz..........-k-...-nnn=nnxnn:nnkkkkkzzzz---..=.........:-=+++xxxx+-.....:");
$display(":.....kzzzzzk................................xx==+xnknzzzzzzzzn-nx-.:.........:.+=.=xnkz+:xxx...xnkkzzzkkkkkkkzzzzzzz:nznkzzzzkx................=x+:-nn=nnnnkkkkkzzzzn+==:..-.-nnx++++xxkkkx:..........:");
$display(":....+zz=:.................................=+++=+nnnkzzzzzzknzzk+:.=x+==...:==:.....:xnk+=nx..=xkkzzzzzzzzzzzzzzzzkn-zzk-zzzzz-.....................:+=+-nkkk:xkkzzzzx=--:..nnzkxx+nnxnnkzkkx-.........-");
$display(".....n....................................-xn+==xknkkzn=n--=xkz.....:k+++-..+nnnx=....xnn:n+.+nkzzzzzzzzzkzzknkk-=kzz+:.nzkkn...........................n..-kkn=zzn:-=-zn:..xkzkn+:....-nzzzzzzzn:.....-");
$display(":........................................==n+=-=nnkkzzzzzkkzzz-.......=kx++nnkkkkknx+-.xnxn:.+nxnxnnkknzkxkkkx...+nkzzzkknnk.............................-==znzzzzkx=nknk-=zn...............:xzzzzzzk=.=");
$display(":.................xz..n:.................+nn+=nxkzznzzzzzzzk.............xzzzzzzzzzknn=+=kkkkkkz+x++++nnnz+zx+...+nkkknkkk-k.................:z..........x:kkzzzzzxznzxxknkz:=.:...............:kzzzzzxn");
$display("-...............:=zk-z=..................xnxxxzzxzzkkzzxkk....................=zzzzkk+.xnkkkkzzzzzzzxknx=kzk+....=+nkknn.+k:...............=zzx........-x=-kkkzzzz+kzkknkzzz+..-:::..............:xzzzzz");
$display("=......n+.nzzzzzk-z.kk..............n...knkzznzzznnznnzz-.........................zkknn+xnnnkkkkkknn+==kkknx-.....=++x..nn=...............nzzzk....=+-=+==++kzzzzzzkzzkknzzz+.n---::::..............+zzz");
$display(":......zzzzzzzzz-zn.z..............==x.zzxkzzknnzz+zk+k...............................-.-:.--::-.kkkkkknx+-...........++n:=n.............kzzzzzkzn+x===+x=-xzzzzzzzzzzzn+kzzx.n:-:::::................-z");
$display("......=zzk=--zzx..................::knkkkzzknzzz=zzkk..................................x.....::xnnnnx.:=xxx=.........+x=:=x-...........:zzzzzzzk+===x-:::::-k=zzzzzzzzznzzzzx.+--:-:::..:xn............-");
$display(":.....zk....nzz...................++kkk--zzzzz=x=++:...................................-n.==xxxx=++.xnkkkknx=......=+x.:=x=::.........:nzzkxnk+xxx=::::::::+.kzzzzzzzzxkzzznx+---:-::-+kzzzz+-.........:");
$display("............zz...................+nz+==++zzzzxxnz-.....................................xx=-.::.-=+xxxxxnx=:+=...==++..:-:+:=+x.......-nk-=:--=+x-----------+zzkzzzzzzz.zzzzxkz--k=nzzzzzzzzzzzzzzzzzzzzz");
$display("...........zz..................xnxkn+===zzzzzz........................................k---n.+:.=...=+.=++++:..-..-.+:..:..+--==....nk-nn:.-n+:--------------=zzzzzzzzn+zzzzxzzzx+zzzzzzzzzzzzn=xnzzzzzzz");
$display(".......kzzzz-.................nxzn++++knzzzxk-......................................+n+x--.k+.-x=:-..........::.....--+n=k-nk+::x++=+xzn+-:::-----------::::--nzzzzzzkzzxkzzzzk.++=-:.................+z");
$display(".....-zzzzn..................-xzkk==+nzzzk+z=.......................................kzk..=.:zk:=n+:..:::::=-=-:=+x+zzzzk.+x+x-.n+=-xzzz::--:--------:::::-++xnkzzzzzzzzz=+xkkk=.=.......................");
$display(".....xzk......................kk=n+nnxzzznkn........................................+=zz-=::xzzk-:::=-+x=-:.-=:nk-zzzznn=k:k=.==++zzzzzzzzzzzzzzzzzzzzzzzznnnnx++xzzzkzkn+kkzz+:+.......................");
$display(".....-.....................:.+kxn+xnxzzk=+z........................................kzx:+z=--x+zzzkkzkkzzn..zzzzn+zz+.++kn--n=++kzzzkkkzzk+---------=+nkzzzn...:::::nkkkzzxzzzz+.+.......................");
$display("........................:k-.:-kk+=nkzzzzz-n........................................:=zx=+zx::++zzzzzzzzzx.-zzz+-x..kzzzx=+x-nn-=nxxnnnx+xkzzzn=---::::...-kzx.......+zzzznzzzzn:=.......................");
$display(".............kz.........:kn-=-kk=kzzzzzzx..........................................n.:n+-+k+-++xzzzzzzzkx++n-=x.:kzzknnnnzk--::---+==xx+zkz+-.:.+--:::...............xzzznzzz++.=..+....................");
$display("............zz-.........+kk=+=nzzzzzzzzk.k.......................................=x:k+:+==nz-=x+-zznn=-+.x-=+::xzzzzknkzzn:=n+n:-...-xx+.-k+kx:.-+-:::................zzzkzzn+xzz.:.....................");
$display("...........zzz-z=.......:kz=+==zzzzzzzz+z-..................................-=....xzzzz+z-=kk=-x+=nzx-=+x:=x.+xkzzxkkzzzx-xn-::......:xnkzn-knk:-.=:::................kzzzzzkkzzk-.=....................");
$display("+......:nznzz.kk.......-.zkxxn+kzzzzzzxn...............................=-...x+n+xk+-kzzzzn=xz+=xk=-xz+kx=--.+xkzznnkzzn-x:-.-::........+nkzzx+xkk.+-:..................zzzzzzzzz=.:=....................");
$display(":...-zzzzz.zn-z:.......::kzzznnzzzzznk............................:+:.-nkzzknn.-++:.+-nkkzkxzkn+kn+=+k=+=.::knzzzzzzk=-=::::..x.--.....=xx=-:--=-x=n=:.................kzzzkzzzzz+--....................");
$display("....kznnz=:..x.........:==zzzzkzzzkk-.........................-xn-=...::.:.....:+x=:=.=-xknnxznnnzx=++k+---nzzzzzzznxx+:+:=:-=x..++-:...........:--+k-.................:zzzxzzzzz+:-....................");
$display("...x=..kk...........n=.-=+kzzzzzzkk......................-x+=:---......:=.--::n-::.:k-+-=-=+knzknzkz==+xn+zzzzzzzzkxnn+-==+.kk.n:=...........:--::..-k:.................nzz+zzzzk+:=....................");
$display("......:z-...........-nz-=xxzzzzzz:......................-.==--........-+--kn-=nxkxxn==n=====nzzzknznk++xxkzzzzzzkknnkn=+-=.nzkk-=:-.:.....+nk+kk+n==+nn:.................kz=kzzznn+:=...................");
$display("......kx............==k-x+nzzzzn......................:.-=........::.=+nnkzkxn:=nzkzzzkxn=+x=zzzkkkzkknnnzzkzzzkkkkzkkx+=x.zzzn-=:=........=xknnxnn-::xz:...............:nn+zzzxnkn-....................");
$display("...nzzz=............++n-n+zzzz-......................-.k+.......:..+nnkkkzzzn-=-:=nkzznnkzkzk+zzzkkzzzznkkzkzzknkkzzknk-x-kzz+=n.x..=-......=xkknnnx-:++++..............+z+zzzxnnzk+....................");
$display("..-zz+-............=.z+kzxzzz-......................:.x:::....:=:xnnkkkkkkkkk-=x=--==kzkknzzzzkzzzkzzzzzzkkknzkkkzzknnk=k:kk==n:+.xkx:.......:xn+znx+----nk..........+...+zzzzx=kk=.....................");
$display("..z..............-.n.xnkzzzz......................=.-........=.+kknnnx-xnkkzk==x+=---=-kxkxkzzkzzzzzzzzzzzzznnnzkzzznknxn-z=-z.x.znn+=.........x-kknx+-=:x+z........-zzzzkkknn+kzn:.....................");
$display("................+zxx-x+kzzz......................-==...::......--n-.nnnnkkkzn==xn+--=++=nxx+xnkkkzzzkzkzzzznkzknzzzznknkk=k+x+::+kx.........:---x-kkxnx=-:-nn......:kknnkkzzzx+kz+:+....................");
$display("................-z+.+nnkzz:....................+=+......=+==...-..xkkkzzzzzz+===+x+-zkkzznknknkknnkzzzzzzx---xk+zzzznknkz+z-z::.zkknx=........-====+kkkx=-:-nnk:..-kzzzzzzn+nxxkn-==....................");
$display(":...............-kn=xxxkzx...................:nn=............xx..-.-zzzzzzzz--x+=z=nnzzzzkknkznnxxx+nnn=::::::::xkzzzknnznknxn.-zkkknxx=.........:.=:xnn+=x--xnzxkzzzzzzzzx+=xkkx+n.....................");
$display(":...............-xz+-knxk...................x+-:.:::......:xnkzz+::-:zzzzzzx=-nnxzxknzzkkkkkzkxxnxnx=------------++zzknnknkkxk:+zzzzzkknx+=:..........+nkxxx:==zzn:nkzzzzzk=nnnx+x+.....................");
$display(":...............n:z+nzzn-.................x=+=..-:.:.-=.=xnkzzzzkk-.:+zzzzk---=+zznkkknkkznxxzzz==+---------------=xzzknkknknkxnzzzzzkkkkkx=--:-......-.=xxkx+nzx......nkkknxnnx=+-.....................");
$display(":...............x-=nzkzk................=-=::::...=:::=:+kzzzzk+nn=+=-zzzzx==nnkznnkkkknxkxzz=:+-:------------------+zkknkzznnkkzzzkkkkkkkkkn===--=.==++=+nkkxzz-........+nnxx++=x=.....................");
$display(":...............n+:+zzk+............-x-n=.:......:.+n=.=:+xkzkxkz+n=n+zzzn+xxnkkkznnx++z+zk:::::---------:::::::::::.=xkkknkknnkzkzk+xkkkkkkkkn=-===++n+:-+nnzzz...-:......x++xx++n.....................");
$display("-...............=n.kzzzx..........+.:zk=.......:::--xzk=++kn+n+zknknnkzzzxnkkkkkkkxnxzzn=....::::--------:::...........:=kzknnx+xzkkk--xkkkkkkkk==++xx....:+nkkx=...........xxxxkkk=....................");
$display("................n::zzznkx.........=zzzznnnnnx==---===xzknknk+znknnkknkzknnknnkzzk=:::........:::::::::::::.................-nnn+-xxxkk:-+kkkknnx=+=x=-:....=+++xxxx..........nknkkzk:...................");
$display("....:...........k+xzznznz=-......n.:.-=:n+====nzx-==+nzknnkznznknnkknzkkkkxzkn.................:::::::::.....................:-kxx+++n:==+kkkxn+x+x--=..=xx+xxnx+xx-..........+zzn-x:n:.................");
$display("...=............k+:++xzzznx.....:..:kn=++=xx-===xkknkkkznkkznknnnnzkzxnnk=......................................................+nkkxxn-:-nkkxnx==xx+.+xx+x=:.+x=x=:............zk+k++kkk+..............");
$display("..=.............kzx+xxzzzz:........=nzzk=++=-====+kzknkknnkzn+xxnkkzkkk.............................................................xkk+=-=kkxkn+=xx:+x+xxxxx-::n++.............+kxxkxnnnn-.............");
$display("-...............nkkkkxnzzzkx......=kk+=+zzzx+==xnnkzznk=kn=-=xnnx+=:...................................................................kn=-xkxnnx=xx+xxx=xx+++-..=+=............:nx=kx.nnnx.............");
$display("-...............nnnxn..+zzzn.:...=kzz+=+n+kzzzknknkzzzzz................................................................................kkxxnk+xn=+++n+xx=x=+x+-..-x............+nx+k+..x=n+............");
$display(":...............=kkn....zzz-.:-.-nzzk+kn++xxkzzkkkkzkk+..................................................................................=nnn+=+===++=x+--xxxxx=-:..n...........nn+nzk:.n..z............");
$display(":..............+:knx....+zz:.:..xkkknnnxxnzzzzzzkzkkkx.......................................................................................:xx===+xn+=--+nnnxx--=::+n........=zz+nzx..+..z+...........");
$display(":..............-n+z.....+zz=.:..xzzzkxkzzzzzzzzxnznz+...............................................xn=..........................................n=xx=.+==+xnnxx=-n:.-nn+xx-...z...zzx.....z............");
$display(":..............nxzz......zz..-..nzzzzzzzkkzzzzkn+zkx...............................................................................................+x.=+===+xnkkn=n+.:+n:.....z...nzz:..................");
$display("-.............n+zn.......k...x:=xkzzzzzzkkkzzknxkz+...................................................-...............................................=xxx+nnkkkk=:=.-xz=-z...-...=zx...................");
$display("-..........:xn-nz.............=xzzzzkk+kkzzzknkkxk:..................................................................................................-=nkx==+++xnnx+:xkz=xkk......z.....................");
$display("-..........+kz-xkz..........--nxzznx++xxkzzknnznxnz:.................................................................................................==nkkkkkknnnxxknxzz+zz.n...........................");
$display("-..........=zk-xn..........-.=n=nzzzzzzzzzknzznk++zn..................................................................................................:xnnkzzkkkn:....-kzzn+.z..........................");
$display("-..........+nz+n+x..........:x+.:=-++zzkzzkkzznxx+zz:.................................................................................................x-+xnkkkkknnx++=-+xx=+-xk.........................");
$display("-...........xnk....:......-.+++k+xkkzzzzzzznknxx+-kz=...................................................................................................=xnnkkkkkkkkn=nxz=+=-z.n........................");
$display("-.............x..........+.=+++nkzzzzzkzzkzzknnnkxzz.....................................................................................................+xnkkkkkkkx+xzz++x-xz-.x.......................");
$display("-.......................:..+=+xkzzzzzzzzzzzkkkxx+zz+.....................................................................................................==+kkkkknkzzn=+=+-=z--:.x......................");
$display("-.......................-..=+xnkzzzzzzzzzzzkknxx+=zz:.....................................................................................................:=xnkkkkkknx++=+x=-z-.:........................");
$display("");
        end
    endtask
endmodule
