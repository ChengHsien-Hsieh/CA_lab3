module PC_Module #(
    parameter BIT_W = 32
)(
    input               i_clk,
    input               i_rst_n,
    input               i_stall,
    input               i_Branch,
    input               i_JAL,
    input               i_JALR,
    input               i_BranchTaken,
    input  [BIT_W-1:0]  i_Imm,
    input  [BIT_W-1:0]  i_RS1Data,
    
    output reg [BIT_W-1:0] o_PC,
    output     [BIT_W-1:0] o_PCPlus4
);

    reg  [BIT_W-1:0] PCNext;
    wire [BIT_W-1:0] BranchAddr;
    wire [BIT_W-1:0] JalrAddr;

    assign o_PCPlus4 = o_PC + 4;
    assign BranchAddr = o_PC + i_Imm;
    assign JalrAddr = (i_RS1Data + i_Imm) & ~32'b1;

    always @(*) begin
        if (i_JAL)
            PCNext = BranchAddr;
        else if (i_JALR)
            PCNext = JalrAddr;
        else if (i_Branch & i_BranchTaken)
            PCNext = BranchAddr;
        else
            PCNext = o_PCPlus4;
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            o_PC <= 32'h00010000;
        else if (!i_stall)
            o_PC <= PCNext;
    end

endmodule
