module ALU #(
    parameter BIT_W = 32
)(
    input  [BIT_W-1:0] i_ALUIn1,
    input  [BIT_W-1:0] i_ALUIn2,
    input  [3:0]       i_ALUCtrl,
    
    output reg [BIT_W-1:0] o_ALUResult,
    output reg             o_BranchTaken
);

    always @(*) begin
        o_ALUResult = 32'b0;
        o_BranchTaken = 1'b0;
        case (i_ALUCtrl)
            4'b0000: o_ALUResult = i_ALUIn1 + i_ALUIn2;  // ADD/ADDI
            4'b0001: o_ALUResult = i_ALUIn1 - i_ALUIn2;  // SUB
            4'b0010: o_ALUResult = i_ALUIn1 & i_ALUIn2;  // AND
            4'b0011: o_ALUResult = i_ALUIn1 ^ i_ALUIn2;  // XOR
            4'b0100: o_ALUResult = i_ALUIn1 * i_ALUIn2;  // MUL
            4'b0101: o_ALUResult = i_ALUIn1 << i_ALUIn2[4:0];  // SLLI
            4'b0110: o_ALUResult = ($signed(i_ALUIn1) < $signed(i_ALUIn2)) ? 32'b1 : 32'b0;  // SLTI
            4'b0111: o_ALUResult = $signed(i_ALUIn1) >>> i_ALUIn2[4:0];  // SRAI
            4'b1000: o_BranchTaken = (i_ALUIn1 == i_ALUIn2);  // BEQ
            4'b1001: o_BranchTaken = (i_ALUIn1 != i_ALUIn2);  // BNE
            4'b1010: o_BranchTaken = ($signed(i_ALUIn1) < $signed(i_ALUIn2));  // BLT
            4'b1011: o_BranchTaken = ($signed(i_ALUIn1) >= $signed(i_ALUIn2));  // BGE
            default: o_ALUResult = 32'b0;
        endcase
    end

endmodule
