
module Cache#(
        parameter BIT_W = 32,
        parameter ADDR_W = 32
    )(
        input i_clk,
        input i_rst_n,
        // processor interface
            input i_proc_cen,
            input i_proc_wen,
            input [ADDR_W-1:0] i_proc_addr,
            input [BIT_W-1:0]  i_proc_wdata,
            output [BIT_W-1:0] o_proc_rdata,
            output o_proc_stall,
            input i_proc_finish,
            output o_cache_finish,
        // memory interface
            output o_mem_cen,
            output o_mem_wen,
            output [ADDR_W-1:0] o_mem_addr,
            output [BIT_W*4-1:0]  o_mem_wdata,
            input [BIT_W*4-1:0] i_mem_rdata,
            input i_mem_stall,
            output o_cache_available,
        // others
        input  [ADDR_W-1: 0] i_offset
    );

    assign o_cache_available = 0; // Cache is implemented
    assign o_cache_finish = i_proc_finish;

    // Cache Parameters (Direct-Mapped, 4 Blocks)
    localparam CACHE_SIZE = 4;
    localparam INDEX_BITS = 2;
    localparam BLOCK_OFFSET_BITS = 2;
    localparam BYTE_OFFSET_BITS = 2;
    localparam TAG_BITS = ADDR_W - INDEX_BITS - BLOCK_OFFSET_BITS - BYTE_OFFSET_BITS;

    // Cache Storage
    reg [127:0] data_array [0:CACHE_SIZE-1];
    reg [TAG_BITS-1:0] tag_array [0:CACHE_SIZE-1];
    reg valid_array [0:CACHE_SIZE-1];

    // Address Decoding
    wire [ADDR_W-1:0] logic_addr = i_proc_addr - i_offset;
    wire [TAG_BITS-1:0] addr_tag = logic_addr[ADDR_W-1 : INDEX_BITS+BLOCK_OFFSET_BITS+BYTE_OFFSET_BITS];
    wire [INDEX_BITS-1:0] addr_index = logic_addr[INDEX_BITS+BLOCK_OFFSET_BITS+BYTE_OFFSET_BITS-1 : BLOCK_OFFSET_BITS+BYTE_OFFSET_BITS];
    wire [BLOCK_OFFSET_BITS-1:0] addr_block_offset = logic_addr[BLOCK_OFFSET_BITS+BYTE_OFFSET_BITS-1 : BYTE_OFFSET_BITS];
    wire [ADDR_W-1:0] block_addr = {logic_addr[ADDR_W-1:BLOCK_OFFSET_BITS+BYTE_OFFSET_BITS], {BLOCK_OFFSET_BITS+BYTE_OFFSET_BITS{1'b0}}};

    // Hit/Miss Detection
    wire cache_hit = valid_array[addr_index] && (tag_array[addr_index] == addr_tag);

    // Data Selection from cache
    reg [BIT_W-1:0] selected_word;
    always @(*) begin
        case (addr_block_offset)
            2'b00: selected_word = data_array[addr_index][31:0];
            2'b01: selected_word = data_array[addr_index][63:32];
            2'b10: selected_word = data_array[addr_index][95:64];
            2'b11: selected_word = data_array[addr_index][127:96];
        endcase
    end

    // FSM States
    localparam IDLE = 2'b00;
    localparam ALLOCATE = 2'b01;
    localparam WRITE_MEM = 2'b10;
    
    reg [1:0] state, state_next;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            state <= IDLE;
        else
            state <= state_next;
    end

    // FSM Next State Logic
    always @(*) begin
        state_next = state;
        case (state)
            IDLE: begin
                if (i_proc_cen && !i_proc_wen && !cache_hit) begin
                    // Read miss
                    state_next = ALLOCATE;
                end else if (i_proc_cen && i_proc_wen) begin
                    // Write (write-through)
                    state_next = WRITE_MEM;
                end
            end
            ALLOCATE: begin
                if (!i_mem_stall)
                    state_next = IDLE;
            end
            WRITE_MEM: begin
                if (!i_mem_stall)
                    state_next = IDLE;
            end
        endcase
    end

    // Memory Interface
    reg mem_cen, mem_wen;
    reg [ADDR_W-1:0] mem_addr;

    always @(*) begin
        mem_cen = 1'b0;
        mem_wen = 1'b0;
        mem_addr = i_proc_addr;

        case (state)
            IDLE: begin
                if (i_proc_cen && !i_proc_wen && !cache_hit) begin
                    // Read miss - start fetching block
                    mem_cen = 1'b1;
                    mem_wen = 1'b0;
                    mem_addr = block_addr + i_offset;
                end else if (i_proc_cen && i_proc_wen) begin
                    // Write - write through
                    mem_cen = 1'b1;
                    mem_wen = 1'b1;
                    mem_addr = i_proc_addr;
                end
            end
            default: begin
                mem_cen = 1'b0;
                mem_wen = 1'b0;
            end
        endcase
    end

    assign o_mem_cen = mem_cen;
    assign o_mem_wen = mem_wen;
    assign o_mem_addr = mem_addr;
    assign o_mem_wdata = {96'b0, i_proc_wdata};

    // Processor Interface
    // Only stall when: 1) in non-IDLE state, 2) read miss in IDLE, 3) write with memory stall
    assign o_proc_stall = (state == ALLOCATE) || 
                          (state == IDLE && i_proc_cen && !i_proc_wen && !cache_hit) ||
                          (state == IDLE && i_proc_cen && i_proc_wen && i_mem_stall) ||
                          (state == WRITE_MEM && i_mem_stall);
    
    assign o_proc_rdata = (state == ALLOCATE && !i_mem_stall) ? 
                          (addr_block_offset == 2'b00 ? i_mem_rdata[31:0] :
                           addr_block_offset == 2'b01 ? i_mem_rdata[63:32] :
                           addr_block_offset == 2'b10 ? i_mem_rdata[95:64] :
                           i_mem_rdata[127:96]) : 
                          (cache_hit ? selected_word : i_mem_rdata[0+:BIT_W]);

    // Cache Update
    integer i;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                data_array[i] <= 128'b0;
                tag_array[i] <= {TAG_BITS{1'b0}};
                valid_array[i] <= 1'b0;
            end
        end else begin
            if (state == ALLOCATE && !i_mem_stall) begin
                // Allocate new block
                data_array[addr_index] <= i_mem_rdata;
                tag_array[addr_index] <= addr_tag;
                valid_array[addr_index] <= 1'b1;
            end else if (state == WRITE_MEM && !i_mem_stall && cache_hit) begin
                // Update cache on write hit
                case (addr_block_offset)
                    2'b00: data_array[addr_index][31:0] <= i_proc_wdata;
                    2'b01: data_array[addr_index][63:32] <= i_proc_wdata;
                    2'b10: data_array[addr_index][95:64] <= i_proc_wdata;
                    2'b11: data_array[addr_index][127:96] <= i_proc_wdata;
                endcase
            end
        end
    end

endmodule