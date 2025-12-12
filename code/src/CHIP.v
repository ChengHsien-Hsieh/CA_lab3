//----------------------------- DO NOT MODIFY THE I/O INTERFACE!! ------------------------------//
module CPU #(                                                                                  //
    parameter BIT_W = 32                                                                        //
)(                                                                                              //
    // clock                                                                                    //
        input               i_clk,                                                              //
        input               i_rst_n,                                                            //
    // instruction memory                                                                       //
        input  [BIT_W-1:0]  i_IMEM_data,                                                        //
        output [BIT_W-1:0]  o_IMEM_addr,                                                        //
        output              o_IMEM_cen,                                                         //
    // data memory                                                                              //
        input               i_DMEM_stall,                                                       //
        input  [BIT_W-1:0]  i_DMEM_rdata,                                                       //
        output              o_DMEM_cen,                                                         //
        output              o_DMEM_wen,                                                         //
        output [BIT_W-1:0]  o_DMEM_addr,                                                        //
        output [BIT_W-1:0]  o_DMEM_wdata,                                                       //
    // finnish procedure                                                                        //
        output              o_finish,                                                           //
    // cache                                                                                    //
        input               i_cache_finish,                                                     //
        output              o_proc_finish                                                       //
);                                                                                              //
//----------------------------- DO NOT MODIFY THE I/O INTERFACE!! ------------------------------//

// -------------------------------------------------------
// Control Unit
// -------------------------------------------------------
    /* Control Signals */
    wire        ALUSrcA;
    wire        JAL;
    wire        JALR;
    wire        Branch;
    wire        MemRead;
    wire        MemToReg;
    wire        MemWrite;
    wire        ALUSrcB;
    wire        RegWrite;
    wire [3:0]  ALUCtrl;
    wire        is_ecall;

    Control control_unit(
        .i_OPcode    (i_IMEM_data[6:0]),
        .i_Funct3    (i_IMEM_data[14:12]),
        .i_Funct7    (i_IMEM_data[31:25]),
        .imm_system  (i_IMEM_data[31:20]),
        .o_ALUSrcA   (ALUSrcA),
        .o_JAL       (JAL),
        .o_JALR      (JALR),
        .o_Branch    (Branch),
        .o_MemRead   (MemRead),
        .o_MemToReg  (MemToReg),
        .o_MemWrite  (MemWrite),
        .o_ALUSrcB   (ALUSrcB),
        .o_RegWrite  (RegWrite),
        .o_ALUCtrl   (ALUCtrl),
        .o_is_ecall  (is_ecall)
    );

// -------------------------------------------------------
// Immediate Generator
// -------------------------------------------------------
    wire [BIT_W-1:0] Imm;
    
    ImmGen #(.BIT_W(BIT_W)) imm_gen(
        .i_Instruction (i_IMEM_data),
        .i_OPcode      (i_IMEM_data[6:0]),
        .o_Imm         (Imm)
    );

// -------------------------------------------------------
// Register File
// -------------------------------------------------------
    wire [BIT_W-1:0] RS1Data, RS2Data;
    wire [BIT_W-1:0] WriteData;
    
    Reg_file reg0(               
        .i_clk   (i_clk),             
        .i_rst_n (i_rst_n), 
        .wen     (RegWrite && !i_DMEM_stall),
        .rs1     (i_IMEM_data[19:15]),
        .rs2     (i_IMEM_data[24:20]),
        .rd      (i_IMEM_data[11:7]),
        .wdata   (WriteData),
        .rdata1  (RS1Data),
        .rdata2  (RS2Data)
    );

// -------------------------------------------------------
// PC Module
// -------------------------------------------------------
    wire [BIT_W-1:0] PC;
    wire [BIT_W-1:0] PC_plus4;
    wire             BranchTaken;
    
    PC_Module #(.BIT_W(BIT_W)) pc_module(
        .i_clk         (i_clk),
        .i_rst_n       (i_rst_n),
        .i_stall       (i_DMEM_stall),
        .i_Branch      (Branch),
        .i_JAL         (JAL),
        .i_JALR        (JALR),
        .i_BranchTaken (BranchTaken),
        .i_Imm         (Imm),
        .i_RS1Data     (RS1Data),
        .o_PC          (PC),
        .o_PCPlus4     (PC_plus4)
    );

// -------------------------------------------------------
// ALU
// -------------------------------------------------------
    wire [BIT_W-1:0] ALUIn1 = ALUSrcA ? PC : RS1Data;
    wire [BIT_W-1:0] ALUIn2 = ALUSrcB ? Imm : RS2Data;
    wire [BIT_W-1:0] ALUResult;
    
    ALU #(.BIT_W(BIT_W)) alu(
        .i_ALUIn1      (ALUIn1),
        .i_ALUIn2      (ALUIn2),
        .i_ALUCtrl     (ALUCtrl),
        .o_ALUResult   (ALUResult),
        .o_BranchTaken (BranchTaken)
    );

// -------------------------------------------------------
// Write Back
// -------------------------------------------------------
    assign WriteData = MemToReg ? i_DMEM_rdata : 
                       (JAL | JALR) ? PC_plus4 : 
                       ALUResult;

// -------------------------------------------------------
// Memory Interface
// -------------------------------------------------------
    assign o_IMEM_addr = PC;
    assign o_IMEM_cen = 1'b1;
    assign o_DMEM_cen = MemRead | MemWrite;
    assign o_DMEM_wen = MemWrite;
    assign o_DMEM_addr = ALUResult;
    assign o_DMEM_wdata = RS2Data;

// -------------------------------------------------------
// Finish Signal
// -------------------------------------------------------
    assign o_finish = is_ecall;
    assign o_proc_finish = is_ecall;

endmodule