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

    // ---------------------------------------------------------------
    // 1. Parameters
    // ---------------------------------------------------------------
    assign o_cache_available = 1;
    assign o_cache_finish = (current_state == S_DONE);

    // Cache Specification: 4 Blocks, each Block 128 bits (4 words)
    parameter CACHE_SIZE = 4;
    parameter CACHE_LINE_W = 128; // 4 * 32 bits
    
    // Index and Tag Calculation
    // Address: [ Tag | Index | BlockOffset | ByteOffset ]
    // ByteOffset: 2 bits (for 4 bytes/word)
    // BlockOffset: 2 bits (for 4 words/block)
    // Index: log2(CACHE_SIZE) bits
    localparam BLOCK_OFFSET_W = 2; // log2(4 words per block)
    localparam BYTE_OFFSET_W = 2;  // log2(4 bytes per word)
    localparam INDEX_W = $clog2(CACHE_SIZE); // Automatically calculate index bit width
    localparam TAG_W   = ADDR_W - INDEX_W - BLOCK_OFFSET_W - BYTE_OFFSET_W;

    // FSM States
    localparam S_IDLE       = 2'd0;
    localparam S_COMPARE    = 2'd1;
    localparam S_ALLOCATE   = 2'd2; // Read from Mem
    localparam S_WRITE_BACK = 2'd3; // Write to Mem
    localparam S_FLUSH       = 3'd4; // Check dirty
    localparam S_FLUSH_WRITE = 3'd5; // Write back to memory
    localparam S_DONE        = 3'd6; // All done

    // ---------------------------------------------------------------
    // 2. Internal Registers & Arrays
    // ---------------------------------------------------------------
    reg [2:0] current_state, next_state;
    reg [2:0] flush_counter;

    // Cache Storage
    reg [CACHE_LINE_W-1:0] cache_data  [0:CACHE_SIZE-1];
    reg [TAG_W-1:0]        cache_tag   [0:CACHE_SIZE-1];
    reg                    cache_valid [0:CACHE_SIZE-1];
    reg                    cache_dirty [0:CACHE_SIZE-1]; // For Write-Back policy

    // Loop variable
    integer i;

    // ---------------------------------------------------------------
    // 3. Address Decoding
    // ---------------------------------------------------------------
    // Important: According to Spec, internal calculation needs to subtract offset first
    wire [ADDR_W-1:0] proc_addr_real;
    assign proc_addr_real = i_proc_addr - i_offset;

    wire [TAG_W-1:0]   tag_field;
    wire [INDEX_W-1:0] index_field;
    wire [1:0]         word_offset;

    assign tag_field   = proc_addr_real[ADDR_W-1 : ADDR_W-TAG_W];
    assign index_field = proc_addr_real[BLOCK_OFFSET_W + BYTE_OFFSET_W +: INDEX_W]; // Dynamically calculate
    assign word_offset = proc_addr_real[BYTE_OFFSET_W +: BLOCK_OFFSET_W];           // Dynamically calculate

    // Read current Cache Line information
    wire [CACHE_LINE_W-1:0] current_line_data;
    wire [TAG_W-1:0]        current_tag;
    wire                    current_valid;
    wire                    current_dirty;

    assign current_line_data = cache_data[index_field];
    assign current_tag       = cache_tag[index_field];
    assign current_valid     = cache_valid[index_field];
    assign current_dirty     = cache_dirty[index_field];

    // Determine if the current access is a cache hit
    wire is_hit;
    assign is_hit = current_valid && (current_tag == tag_field);

    // ---------------------------------------------------------------
    // 4. FSM: Next State Logic
    // ---------------------------------------------------------------
    always @(*) begin
        case (current_state)
            S_IDLE: begin
                if (i_proc_finish) begin
                    next_state = S_FLUSH; // 1. Received finish signal, start Flush
                end
                else if (i_proc_cen) begin
                    next_state = S_COMPARE;
                end
                else begin
                    next_state = S_IDLE;
                end
            end

            S_COMPARE: begin
                if (is_hit) begin // Cache Hit
                    next_state = S_IDLE;
                end
                else begin // Cache Miss
                    if (current_valid && current_dirty) // Old Block is Dirty
                        next_state = S_WRITE_BACK;
                    else // Old Block is Clean
                        next_state = S_ALLOCATE;
                end
            end

            S_ALLOCATE: begin
                if (!i_mem_stall) // Memory Ready
                    next_state = S_COMPARE;
                else // Memory Not Ready
                    next_state = S_ALLOCATE;
            end

            S_WRITE_BACK: begin
                if (!i_mem_stall) // Memory Ready
                    next_state = S_ALLOCATE;
                else // Memory Not Ready
                    next_state = S_WRITE_BACK;
            end

            // --- Flush FSM ---
            S_FLUSH: begin
                if (flush_counter >= CACHE_SIZE) begin
                    next_state = S_DONE; // Finished scanning all
                end
                else if (cache_valid[flush_counter] && cache_dirty[flush_counter]) begin
                    next_state = S_FLUSH_WRITE; // Found dirty data, write back
                end
                else begin
                    next_state = S_FLUSH; // Clean, continue scanning next (counter increment in sequential logic)
                end
            end

            S_FLUSH_WRITE: begin
                if (!i_mem_stall) begin
                    next_state = S_FLUSH; // Finished writing, continue scanning
                end
                else begin
                    next_state = S_FLUSH_WRITE; // Waiting for Memory
                end
            end

            S_DONE: begin
                next_state = S_DONE; // Stay here and raise o_cache_finish
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ---------------------------------------------------------------
    // 5. Output Logic (Combinational)
    // ---------------------------------------------------------------
    
    // Processor Output
    // Select 32-bit from 128-bit block based on word_offset
    assign o_proc_rdata = current_line_data[(word_offset*32) +: 32];
    
    // Stall Logic: Stall if CPU has request (cen) and not finished (State is not Compare and Hit)
    // This logic ensures CPU stalls until we finish processing Hit
    assign o_proc_stall = i_proc_cen && !(current_state == S_COMPARE && is_hit);

    // Memory Interface
    // Only enable during Allocate (Read) or WriteBack (Write)
    assign o_mem_cen = (current_state == S_ALLOCATE) || 
                    (current_state == S_WRITE_BACK) || 
                    (current_state == S_FLUSH_WRITE); // Added Flush Write

    assign o_mem_wen = (current_state == S_WRITE_BACK) || 
                    (current_state == S_FLUSH_WRITE); // Added Flush Write

    // Memory Data
    assign o_mem_wdata = (current_state == S_FLUSH_WRITE) ? cache_data[flush_counter] : current_line_data;
    
    // Memory Address
    // Write Back: Use old Tag to form address
    // Allocate: Use new Tag (from CPU request) to form address
    // Remember to add back offset
    reg [ADDR_W-1:0] mem_addr_internal;
    always @(*) begin
        if (current_state == S_WRITE_BACK)
            mem_addr_internal = {current_tag, index_field, 4'b0000};
        else if (current_state == S_FLUSH_WRITE)
            // Flush 時，位址來自 counter 指向的 block
            mem_addr_internal = {cache_tag[flush_counter], flush_counter[1:0], 4'b0000};
        else
            mem_addr_internal = {tag_field, index_field, 4'b0000};
    end
    assign o_mem_addr = mem_addr_internal + i_offset;

    // ---------------------------------------------------------------
    // 6. Sequential Logic (Cache Update)
    // ---------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            current_state <= S_IDLE;
            flush_counter <= 0;
            for (i=0; i<CACHE_SIZE; i=i+1) begin
                cache_valid[i] <= 1'b0;
                cache_dirty[i] <= 1'b0;
                cache_tag[i]   <= 0;
                cache_data[i]  <= 0;
            end
        end else begin
            current_state <= next_state;
            
            // Cache Data Update Logic
            case (current_state)
                S_COMPARE: begin
                    if (is_hit && i_proc_wen) begin
                        // Write Hit: Update Data & Set Dirty
                        cache_data[index_field][(word_offset*32) +: 32] <= i_proc_wdata;
                        cache_dirty[index_field] <= 1'b1;
                    end
                end

                S_ALLOCATE: begin
                    if (!i_mem_stall) begin
                        // Memory Read Done: Update entire block
                        cache_data[index_field]  <= i_mem_rdata;
                        cache_tag[index_field]   <= tag_field;
                        cache_valid[index_field] <= 1'b1;
                        cache_dirty[index_field] <= 1'b0;
                    end
                end

                S_FLUSH_WRITE: begin
                    if (!i_mem_stall) begin
                        // After Flush is done, clear dirty bit
                        cache_dirty[flush_counter] <= 1'b0;
                    end
                end
            endcase

            // Counter Logic
            if (current_state == S_IDLE && i_proc_finish) begin
                flush_counter <= 0;
            end
            else if (current_state == S_FLUSH) begin
                if (!(cache_valid[flush_counter] && cache_dirty[flush_counter]))
                    flush_counter <= flush_counter + 1;
            end
            else if (current_state == S_FLUSH_WRITE && !i_mem_stall) begin
                flush_counter <= flush_counter + 1;
            end
        end
    end

endmodule