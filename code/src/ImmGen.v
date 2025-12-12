module ImmGen #(
    parameter BIT_W = 32
)(
    input  [BIT_W-1:0] i_Instruction,
    input  [6:0]       i_OPcode,
    
    output reg [BIT_W-1:0] o_Imm
);

    // Opcode decode
    localparam OP_I     = 7'b0010011;
    localparam OP_LOAD  = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_BRANCH= 7'b1100011;
    localparam OP_JAL   = 7'b1101111;
    localparam OP_JALR  = 7'b1100111;
    localparam OP_AUIPC = 7'b0010111;

    always @(*) begin
        case (i_OPcode)
            OP_I, OP_LOAD, OP_JALR:  // I-type
                o_Imm = {{20{i_Instruction[31]}}, i_Instruction[31:20]};
            OP_STORE:  // S-type
                o_Imm = {{20{i_Instruction[31]}}, i_Instruction[31:25], i_Instruction[11:7]};
            OP_BRANCH:  // B-type
                o_Imm = {{19{i_Instruction[31]}}, i_Instruction[31], i_Instruction[7], i_Instruction[30:25], i_Instruction[11:8], 1'b0};
            OP_AUIPC:  // U-type
                o_Imm = {i_Instruction[31:12], 12'b0};
            OP_JAL:  // J-type
                o_Imm = {{11{i_Instruction[31]}}, i_Instruction[31], i_Instruction[19:12], i_Instruction[20], i_Instruction[30:21], 1'b0};
            default:
                o_Imm = 32'b0;
        endcase
    end

endmodule
