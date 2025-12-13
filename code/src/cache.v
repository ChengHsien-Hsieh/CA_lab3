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
    // 1. 參數定義 (Parameters)
    // ---------------------------------------------------------------
    assign o_cache_available = 1; // 啟用 Cache
    assign o_cache_finish = i_proc_finish; // Pass through

    // Cache 規格: 4 Blocks, 每個 Block 128 bits (4 words)
    parameter CACHE_SIZE = 4;
    parameter CACHE_LINE_W = 128; // 4 * 32 bits
    
    // Index 與 Tag 計算
    // Address: [ Tag | Index | BlockOffset | ByteOffset ]
    // ByteOffset: 2 bits (for 4 bytes/word)
    // BlockOffset: 2 bits (for 4 words/block)
    // Index: log2(4) = 2 bits
    localparam INDEX_W = 2; 
    localparam TAG_W   = ADDR_W - INDEX_W - 4; // 32 - 2 - 2 - 2 = 26

    // FSM States
    localparam S_IDLE       = 2'd0;
    localparam S_COMPARE    = 2'd1;
    localparam S_ALLOCATE   = 2'd2; // Read from Mem
    localparam S_WRITE_BACK = 2'd3; // Write to Mem

    // ---------------------------------------------------------------
    // 2. 內部暫存器 (Registers & Arrays)
    // ---------------------------------------------------------------
    reg [1:0] current_state, next_state;

    // Cache Storage
    reg [CACHE_LINE_W-1:0] cache_data  [0:CACHE_SIZE-1];
    reg [TAG_W-1:0]        cache_tag   [0:CACHE_SIZE-1];
    reg                    cache_valid [0:CACHE_SIZE-1];
    reg                    cache_dirty [0:CACHE_SIZE-1]; // Write-Back 需要

    // Loop variable
    integer i;

    // ---------------------------------------------------------------
    // 3. 位址解碼 (Address Decoding)
    // ---------------------------------------------------------------
    // 重要：依照 Spec，內部運算需先減去 offset
    wire [ADDR_W-1:0] proc_addr_real;
    assign proc_addr_real = i_proc_addr - i_offset;

    wire [TAG_W-1:0]   tag_field;
    wire [INDEX_W-1:0] index_field;
    wire [1:0]         word_offset;

    assign tag_field   = proc_addr_real[ADDR_W-1 : ADDR_W-TAG_W];
    assign index_field = proc_addr_real[5:4]; // 假設 Size=4
    assign word_offset = proc_addr_real[3:2]; // 選擇 Block 中的哪一個 Word

    // 讀取當前 Cache Line 的資訊
    wire [CACHE_LINE_W-1:0] current_line_data;
    wire [TAG_W-1:0]        current_tag;
    wire                    current_valid;
    wire                    current_dirty;

    assign current_line_data = cache_data[index_field];
    assign current_tag       = cache_tag[index_field];
    assign current_valid     = cache_valid[index_field];
    assign current_dirty     = cache_dirty[index_field];

    // 判斷 Hit
    wire is_hit;
    assign is_hit = current_valid && (current_tag == tag_field);

    // ---------------------------------------------------------------
    // 4. FSM: Next State Logic
    // ---------------------------------------------------------------
    always @(*) begin
        case (current_state)
            S_IDLE: begin
                if (i_proc_cen) // Valid CPU Request
                    next_state = S_COMPARE;
                else 
                    next_state = S_IDLE;
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

            default: next_state = S_IDLE;
        endcase
    end

    // ---------------------------------------------------------------
    // 5. Output Logic (Combinational)
    // ---------------------------------------------------------------
    
    // Processor Output
    // 根據 word_offset 從 128-bit block 選出 32-bit
    assign o_proc_rdata = current_line_data[(word_offset*32) +: 32];
    
    // Stall Logic: 只要 CPU 有請求 (cen) 且還沒完成 (State 不是 Compare 且 Hit)，就 Stall
    // 這裡的邏輯確保 CPU 停住直到我們處理完 Hit
    assign o_proc_stall = i_proc_cen && !(current_state == S_COMPARE && is_hit);

    // Memory Interface
    // 只有在 Allocate (Read) 或 WriteBack (Write) 時啟用
    assign o_mem_cen = (current_state == S_ALLOCATE) || (current_state == S_WRITE_BACK);
    assign o_mem_wen = (current_state == S_WRITE_BACK); // 1 = Write

    // Memory Data (Write Back 時輸出舊資料)
    assign o_mem_wdata = current_line_data;

    // Memory Address
    // Write Back: 用舊的 Tag 組合出位址
    // Allocate: 用新的 Tag (CPU 請求的) 組合出位址
    // 記得加回 offset
    reg [ADDR_W-1:0] mem_addr_internal;
    always @(*) begin
        if (current_state == S_WRITE_BACK)
            mem_addr_internal = {current_tag, index_field, 4'b0000};
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
            for (i=0; i<CACHE_SIZE; i=i+1) begin
                cache_valid[i] <= 1'b0;
                cache_dirty[i] <= 1'b0;
                cache_tag[i]   <= 0;
                cache_data[i]  <= 0;
            end
        end
        else begin
            current_state <= next_state;

            // Cache Data Update Logic
            case (current_state)
                S_COMPARE: begin
                    if (is_hit && i_proc_wen) begin
                        // Write Hit: Update Data & Set Dirty
                        // 使用 Part-select 寫入對應的 32 bits
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
            endcase
        end
    end

endmodule