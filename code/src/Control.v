module Control (
    input  [6:0] i_OPcode,
    input  [2:0] i_Funct3,
    input  [6:0] i_Funct7,
    input  [11:0] imm_system,
    
    output reg        o_ALUSrcA,
    output reg        o_JAL,
    output reg        o_JALR,
    output reg        o_Branch,
    output reg        o_MemRead,
    output reg        o_MemToReg,
    output reg        o_MemWrite,
    output reg        o_ALUSrcB,
    output reg        o_RegWrite,
    output reg [3:0]  o_ALUCtrl,
    output reg        o_is_ecall
);

    // Opcode decode
    localparam OP_R     = 7'b0110011; // R-type: ADD, SUB, AND, XOR, MUL
    localparam OP_I     = 7'b0010011; // I-type: ADDI, SLLI, SLTI, SRAI
    localparam OP_LOAD  = 7'b0000011; // LW
    localparam OP_STORE = 7'b0100011; // SW
    localparam OP_BRANCH= 7'b1100011; // BEQ, BNE, BLT, BGE
    localparam OP_JAL   = 7'b1101111; // JAL
    localparam OP_JALR  = 7'b1100111; // JALR
    localparam OP_AUIPC = 7'b0010111; // AUIPC
    localparam OP_SYSTEM= 7'b1110011; // ECALL

    always @(*) begin
        // Default values
        o_ALUSrcA = 1'b0;
        o_JAL = 1'b0;
        o_JALR = 1'b0;
        o_Branch = 1'b0;
        o_MemRead = 1'b0;
        o_MemToReg = 1'b0;
        o_MemWrite = 1'b0;
        o_ALUSrcB = 1'b0;
        o_RegWrite = 1'b0;
        o_ALUCtrl = 4'b0000;
        o_is_ecall = 1'b0;

        case (i_OPcode)
            OP_R: begin  // R-type
                o_RegWrite = 1'b1;
                o_ALUSrcB = 1'b0;
                case ({i_Funct7, i_Funct3})
                    10'b0000000_000: o_ALUCtrl = 4'b0000; // ADD
                    10'b0100000_000: o_ALUCtrl = 4'b0001; // SUB
                    10'b0000000_111: o_ALUCtrl = 4'b0010; // AND
                    10'b0000000_100: o_ALUCtrl = 4'b0011; // XOR
                    10'b0000001_000: o_ALUCtrl = 4'b0100; // MUL
                    default: o_ALUCtrl = 4'b0000;
                endcase
            end
            OP_I: begin  // I-type (ADDI, SLLI, SLTI, SRAI)
                o_RegWrite = 1'b1;
                o_ALUSrcB = 1'b1;
                case (i_Funct3)
                    3'b000: o_ALUCtrl = 4'b0000; // ADDI
                    3'b001: o_ALUCtrl = 4'b0101; // SLLI
                    3'b010: o_ALUCtrl = 4'b0110; // SLTI
                    3'b101: o_ALUCtrl = 4'b0111; // SRAI
                    default: o_ALUCtrl = 4'b0000;
                endcase
            end
            OP_LOAD: begin  // LW
                o_RegWrite = 1'b1;
                o_ALUSrcB = 1'b1;
                o_MemRead = 1'b1;
                o_MemToReg = 1'b1;
                o_ALUCtrl = 4'b0000; // ADD for address
            end
            OP_STORE: begin  // SW
                o_ALUSrcB = 1'b1;
                o_MemWrite = 1'b1;
                o_ALUCtrl = 4'b0000; // ADD for address
            end
            OP_BRANCH: begin  // BEQ, BNE, BLT, BGE
                o_Branch = 1'b1;
                case (i_Funct3)
                    3'b000: o_ALUCtrl = 4'b1000; // BEQ
                    3'b001: o_ALUCtrl = 4'b1001; // BNE
                    3'b100: o_ALUCtrl = 4'b1010; // BLT
                    3'b101: o_ALUCtrl = 4'b1011; // BGE
                    default: o_ALUCtrl = 4'b1000;
                endcase
            end
            OP_JAL: begin  // JAL
                o_RegWrite = 1'b1;
                o_JAL = 1'b1;
            end
            OP_JALR: begin  // JALR
                o_RegWrite = 1'b1;
                o_JALR = 1'b1;
                o_ALUSrcB = 1'b1;
            end
            OP_AUIPC: begin  // AUIPC
                o_RegWrite = 1'b1;
                o_ALUSrcA = 1'b1;
                o_ALUSrcB = 1'b1;  // Use immediate
                o_ALUCtrl = 4'b0000;  // ADD PC + imm
            end
            OP_SYSTEM: begin  // ECALL
                if (i_Funct3 == 3'b000 && imm_system == 12'b0)
                    o_is_ecall = 1'b1;
            end
        endcase
    end

endmodule
