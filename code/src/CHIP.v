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
// Instruction Decode
// -------------------------------------------------------
    wire [6:0]  opcode = i_IMEM_data[6:0];
    wire [2:0]  funct3 = i_IMEM_data[14:12];
    wire [6:0]  funct7 = i_IMEM_data[31:25];
    wire [4:0]  rs1_addr = i_IMEM_data[19:15];
    wire [4:0]  rs2_addr = i_IMEM_data[24:20];
    wire [4:0]  rd_addr = i_IMEM_data[11:7];

// -------------------------------------------------------
// Control Signals
// -------------------------------------------------------
    reg         reg_write;
    reg  [1:0]  alu_op;
    reg         alu_src;
    reg         mem_read;
    reg         mem_write;
    reg         mem_to_reg;
    reg         branch;
    reg         jal;
    reg         jalr;
    reg         auipc_sel;
    reg         is_ecall;

    // ALU Control
    reg  [3:0]  alu_control;
    
    // Opcode decode
    localparam OP_R     = 7'b0110011;
    localparam OP_I     = 7'b0010011;
    localparam OP_LOAD  = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_BRANCH= 7'b1100011;
    localparam OP_JAL   = 7'b1101111;
    localparam OP_JALR  = 7'b1100111;
    localparam OP_AUIPC = 7'b0010111;
    localparam OP_SYSTEM= 7'b1110011;

    always @(*) begin
        // Default values
        reg_write = 1'b0;
        alu_src = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        branch = 1'b0;
        jal = 1'b0;
        jalr = 1'b0;
        auipc_sel = 1'b0;
        is_ecall = 1'b0;
        alu_control = 4'b0000;

        case (opcode)
            OP_R: begin  // R-type
                reg_write = 1'b1;
                alu_src = 1'b0;
                case ({funct7, funct3})
                    10'b0000000_000: alu_control = 4'b0000; // ADD
                    10'b0100000_000: alu_control = 4'b0001; // SUB
                    10'b0000000_111: alu_control = 4'b0010; // AND
                    10'b0000000_100: alu_control = 4'b0011; // XOR
                    10'b0000001_000: alu_control = 4'b0100; // MUL
                    default: alu_control = 4'b0000;
                endcase
            end
            OP_I: begin  // I-type (ADDI, SLLI, SLTI, SRAI)
                reg_write = 1'b1;
                alu_src = 1'b1;
                case (funct3)
                    3'b000: alu_control = 4'b0000; // ADDI
                    3'b001: alu_control = 4'b0101; // SLLI
                    3'b010: alu_control = 4'b0110; // SLTI
                    3'b101: alu_control = 4'b0111; // SRAI
                    default: alu_control = 4'b0000;
                endcase
            end
            OP_LOAD: begin  // LW
                reg_write = 1'b1;
                alu_src = 1'b1;
                mem_read = 1'b1;
                mem_to_reg = 1'b1;
                alu_control = 4'b0000; // ADD for address
            end
            OP_STORE: begin  // SW
                alu_src = 1'b1;
                mem_write = 1'b1;
                alu_control = 4'b0000; // ADD for address
            end
            OP_BRANCH: begin  // BEQ, BNE, BLT, BGE
                branch = 1'b1;
                case (funct3)
                    3'b000: alu_control = 4'b1000; // BEQ
                    3'b001: alu_control = 4'b1001; // BNE
                    3'b100: alu_control = 4'b1010; // BLT
                    3'b101: alu_control = 4'b1011; // BGE
                    default: alu_control = 4'b1000;
                endcase
            end
            OP_JAL: begin  // JAL
                reg_write = 1'b1;
                jal = 1'b1;
            end
            OP_JALR: begin  // JALR
                reg_write = 1'b1;
                jalr = 1'b1;
                alu_src = 1'b1;
            end
            OP_AUIPC: begin  // AUIPC
                reg_write = 1'b1;
                auipc_sel = 1'b1;
                alu_src = 1'b1;  // Use immediate
                alu_control = 4'b0000;  // ADD PC + imm
            end
            OP_SYSTEM: begin  // ECALL
                if (funct3 == 3'b000 && i_IMEM_data[31:20] == 12'b0)
                    is_ecall = 1'b1;
            end
        endcase
    end

// -------------------------------------------------------
// Immediate Generator
// -------------------------------------------------------
    reg [BIT_W-1:0] imm;
    always @(*) begin
        case (opcode)
            OP_I, OP_LOAD, OP_JALR:  // I-type
                imm = {{20{i_IMEM_data[31]}}, i_IMEM_data[31:20]};
            OP_STORE:  // S-type
                imm = {{20{i_IMEM_data[31]}}, i_IMEM_data[31:25], i_IMEM_data[11:7]};
            OP_BRANCH:  // B-type
                imm = {{19{i_IMEM_data[31]}}, i_IMEM_data[31], i_IMEM_data[7], i_IMEM_data[30:25], i_IMEM_data[11:8], 1'b0};
            OP_AUIPC:  // U-type
                imm = {i_IMEM_data[31:12], 12'b0};
            OP_JAL:  // J-type
                imm = {{11{i_IMEM_data[31]}}, i_IMEM_data[31], i_IMEM_data[19:12], i_IMEM_data[20], i_IMEM_data[30:21], 1'b0};
            default:
                imm = 32'b0;
        endcase
    end

// -------------------------------------------------------
// Register File
// -------------------------------------------------------
    wire [BIT_W-1:0] rdata1, rdata2;
    wire [BIT_W-1:0] reg_wdata;
    
    Reg_file reg0(               
        .i_clk  (i_clk),             
        .i_rst_n(i_rst_n), 
        .wen    (reg_write && !i_DMEM_stall),
        .rs1    (rs1_addr),
        .rs2    (rs2_addr),
        .rd     (rd_addr),
        .wdata  (reg_wdata),
        .rdata1 (rdata1),
        .rdata2 (rdata2)
    );

// -------------------------------------------------------
// ALU
// -------------------------------------------------------
    wire [BIT_W-1:0] alu_in1 = auipc_sel ? PC : rdata1;
    wire [BIT_W-1:0] alu_in2 = alu_src ? imm : rdata2;
    reg  [BIT_W-1:0] alu_result;
    reg              alu_zero;

    always @(*) begin
        alu_result = 32'b0;
        alu_zero = 1'b0;
        case (alu_control)
            4'b0000: alu_result = alu_in1 + alu_in2;  // ADD/ADDI
            4'b0001: alu_result = alu_in1 - alu_in2;  // SUB
            4'b0010: alu_result = alu_in1 & alu_in2;  // AND
            4'b0011: alu_result = alu_in1 ^ alu_in2;  // XOR
            4'b0100: alu_result = alu_in1 * alu_in2;  // MUL
            4'b0101: alu_result = alu_in1 << alu_in2[4:0];  // SLLI
            4'b0110: alu_result = ($signed(alu_in1) < $signed(alu_in2)) ? 32'b1 : 32'b0;  // SLTI
            4'b0111: alu_result = $signed(alu_in1) >>> alu_in2[4:0];  // SRAI
            4'b1000: alu_zero = (alu_in1 == alu_in2);  // BEQ
            4'b1001: alu_zero = (alu_in1 != alu_in2);  // BNE
            4'b1010: alu_zero = ($signed(alu_in1) < $signed(alu_in2));  // BLT
            4'b1011: alu_zero = ($signed(alu_in1) >= $signed(alu_in2));  // BGE
            default: alu_result = 32'b0;
        endcase
    end

// -------------------------------------------------------
// PC Logic
// -------------------------------------------------------
    reg [BIT_W-1:0] PC, PC_next;
    wire [BIT_W-1:0] PC_plus4 = PC + 4;
    wire [BIT_W-1:0] PC_branch = PC + imm;
    wire [BIT_W-1:0] PC_jalr = (rdata1 + imm) & ~32'b1;
    wire take_branch = branch & alu_zero;

    always @(*) begin
        if (jal)
            PC_next = PC_branch;
        else if (jalr)
            PC_next = PC_jalr;
        else if (take_branch)
            PC_next = PC_branch;
        else
            PC_next = PC_plus4;
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            PC <= 32'h00010000; // Do not modify this value!!!
        else if (!i_DMEM_stall)  // Stall mechanism
            PC <= PC_next;
    end

// -------------------------------------------------------
// Write Back
// -------------------------------------------------------
    assign reg_wdata = mem_to_reg ? i_DMEM_rdata : 
                       (jal | jalr) ? PC_plus4 : 
                       auipc_sel ? alu_result : 
                       alu_result;

// -------------------------------------------------------
// Memory Interface
// -------------------------------------------------------
    assign o_IMEM_addr = PC;
    assign o_IMEM_cen = 1'b1;
    assign o_DMEM_cen = mem_read | mem_write;
    assign o_DMEM_wen = mem_write;
    assign o_DMEM_addr = alu_result;
    assign o_DMEM_wdata = rdata2;

// -------------------------------------------------------
// Finish Signal
// -------------------------------------------------------
    assign o_finish = is_ecall;
    assign o_proc_finish = is_ecall;

endmodule