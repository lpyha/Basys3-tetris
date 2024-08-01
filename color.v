module color(
    input CLK25M,  // 25MHz clock input
    input buttonT, 
    input [9:0] Hcount, 
    input [8:0] Vcount, 
    output [7:0] Red, 
    output [7:0] Green,
    output [7:0] Blue,
    input buttonL,
    input buttonD,
    input buttonR,
    output wire [6:0] SSEG_CA,
    output wire [3:0] SSEG_AN,
    output debugLED
);
    // define the border
    localparam BORDER           = 16'b0000_0010_0000_0001;
    // bottom border
    localparam BOTTOM_BORDER    = 16'b1111_1111_1111_1111;
    // initial block position
    localparam INITIAL_BLOCK    = 48'b0000_0000_0010_0000_0000_0000_0000_0000_0000_0000_0000_0000;
    localparam BLOCK2           = 48'b0000_0000_0011_1000_0000_0000_0000_0000_0000_0000_0000_0000;
    localparam BLOCK3           = 48'b0000_0000_0010_0000_0000_0000_0010_0000_0000_0000_0000_0000;
    localparam BLOCK4           = 48'b0000_0000_0010_0000_0000_0000_0010_0000_0000_0000_0010_0000;
    localparam BLOCK5           = 48'b0000_0000_0010_0000_0000_0000_0010_0000_0000_0000_0010_0000;
    localparam BLOCK6           = 48'b0000_0000_0010_0000_0000_0000_0000_0000_0000_0000_0000_0000;
    // define fill block in horizontal direction
    localparam FILL_BLOCK_H     = 16'b0000_0011_1111_1111;
    
    wire    [127:0] map;
    reg     [127:0] background = BORDER | (BORDER<<16)
                                        | (BORDER<<32)
                                        | (BORDER<<48)
                                        | (BORDER<<64)
                                        | (BORDER<<80)
                                        | (BORDER<<96) 
                                        | (BOTTOM_BORDER<<112);
    reg     [127:0] block = INITIAL_BLOCK;
    wire    [6:0]   pos;
    wire            clk10;
    reg     [3:0]   clkCount = 0;  // make 1Hz clock from 10Hz clock
    reg             debugFlag;
    reg     [3:0]   score = 0;
    reg     [3:0]   blockIndex = 1;
    wire            reset = buttonT;

    clockDivider10Hz clk_divider10Hz(
        .CLK25M(CLK25M),
        .Reset(Reset),
        .clk10_out(clk10)
    );

    bcd7seg segment(
        .CLK(CLK25M),
        .score(score),
        .SSEG_CA(SSEG_CA),
        .SSEG_AN(SSEG_AN)
    );

    // Move block
    always @(posedge clk10) begin
        // Move block to the right or left or down
        if (buttonL && !leftBlockExists(block)) begin
            block = block >> 1;
        end else if (buttonR && !rightBlockExists(block)) begin
            block = block << 1;
        end else if (buttonD && !underBlockExists(block)) begin
            block = block << 16;
        end

        if (clkCount == 10) begin
            // block down
            if (underBlockExists(block)) begin
                background = background | block;
                block = changeInitialBlock(blockIndex);
            end else begin
                block = block << 16;
            end
            clkCount = 0;
        end else begin
            clkCount = clkCount + 1;
        end

        // check if the block is filled
        background = blockFilled(background);

        // blink the debug LED
        debugFlag = ~debugFlag;
        if (reset == 1) begin
            resetBlock(block);
        end
    end

    /**
     * @brief Reset block and background
     * @param block 3x3 128bit
     */
    function resetBlock;
        input [127:0] block;
        begin
            block = INITIAL_BLOCK;
            background = BORDER | (BORDER<<16)
                                | (BORDER<<32)
                                | (BORDER<<48)
                                | (BORDER<<64)
                                | (BORDER<<80)
                                | (BORDER<<96) 
                                | (BOTTOM_BORDER<<112);
            score = 0;
        end
    endfunction

    /**
      * @brief change Block structure and add blockIndex
      * @param number
      * @return block
    */
    function [48:0] changeInitialBlock;
        input [2:0] num;
        begin
            if (num == 0) begin
                changeInitialBlock = INITIAL_BLOCK;
            end else if (num == 1) begin
                changeInitialBlock = BLOCK2;
            end else if (num == 2) begin
                changeInitialBlock = BLOCK3;
            end else if (num == 3) begin
                changeInitialBlock = BLOCK4;
            end else if (num == 4) begin
                changeInitialBlock = BLOCK5;
            end else if (num == 5) begin
                changeInitialBlock = BLOCK6;
            end else begin
                changeInitialBlock = INITIAL_BLOCK;
            end
            blockIndex = blockIndex + 1;
            if (blockIndex > 5) begin
                blockIndex = 0;
            end
        end
    endfunction

    /**
      * @brief Check if there is a block under the current block
      * @return 1 if there is a block below, 0 otherwise
    */
    function underBlockExists;
        input [127:0] block;
        begin
            underBlockExists = (block << 16 & background) != 0;
        end
    endfunction

    /**
     * @brief Check if there is a block on the left of the current block
     * @return 1 if there is a block on the left, 0 otherwise
     */
    function leftBlockExists;
        input [127:0] block;
        begin
            leftBlockExists = (block >> 1 & background) != 0;
        end
    endfunction

    /**
     * @brief Check if there is a block on the right of the current block
     */
    function rightBlockExists;
        input [127:0] block;
        begin
            rightBlockExists = (block << 1 & background) != 0;
        end
    endfunction

    /**
     * @ brief If the block in horizontal direction is filled and remove it, score up
     */
    function [127:0]blockFilled;
        input [127:0] background;
        begin
            if (background[111:96] == FILL_BLOCK_H) begin
                background[111:96] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end else if (background[95:80] == FILL_BLOCK_H) begin
                background[95:80] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end else if (background[79:64] == FILL_BLOCK_H) begin
                background[79:64] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end else if (background[63:48] == FILL_BLOCK_H) begin
                background[63:48] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end else if (background[47:32] == FILL_BLOCK_H) begin
                background[47:32] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end else if (background[31:16] == FILL_BLOCK_H) begin
                background[31:16] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end else if (background[15:0] == FILL_BLOCK_H) begin
                background[15:0] = BORDER;
                background = background << 16 | BORDER | (BOTTOM_BORDER<<112);
                score = score + 1;
            end
            blockFilled = background;
        end
    endfunction

    assign debugLED = debugFlag;
    assign map = background;
    assign pos = {Vcount[8:6], Hcount[9:6]};
    assign Red = map[pos] ? 255 : (block[pos] ? 200 : 0);
    assign Green = map[pos] ? 0 : (block[pos] ? 125 : 255);
    assign Blue = map[pos] ? 0 : (block[pos] ? 50 : 0);
endmodule

/**
 * @brief Generate 1Hz clock from 25MHz clock
 */
module clockDivider1Hz(
    input wire CLK25M, 
    input wire Reset, 
    output reg clk1_out
);
    // Division ratio from 25MHz to 1Hz
    localparam DIVISOR = 25_000_000;

    integer count;

    always @(posedge CLK25M or posedge Reset) begin
        if (Reset) begin
            count <= 0;
            clk1_out <= 0;
        end else begin
            if (count == (DIVISOR / 2) - 1) begin
                clk1_out <= ~clk1_out;
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
endmodule

/**
 * @breif Generate 10Hz clock from 25MHz clock
 */
module clockDivider10Hz(
    input wire CLK25M, 
    input wire Reset, 
    output reg clk10_out
);
    // Division ratio from 25MHz to 10Hz
    localparam DIVISOR = 2500000;

    integer count;

    always @(posedge CLK25M or posedge Reset) begin
        if (Reset) begin
            count <= 0;
            clk10_out <= 0;
        end else begin
            if (count == (DIVISOR / 2) - 1) begin
                clk10_out <= ~clk10_out;
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
endmodule

/*
 * @ breif BCD to 7-segment decoder
 */

module bcd7seg (
    input CLK,
    input [12:0] score,
    output wire [6:0] SSEG_CA,
    output wire [3:0] SSEG_AN
    );
    localparam zero     = 7'b100_0000;
    localparam one      = 7'b111_1001;
    localparam two      = 7'b010_0100;
    localparam three    = 7'b011_0000;
    localparam four     = 7'b001_1001;
    localparam five     = 7'b001_0010;
    localparam six      = 7'b000_0010;
    localparam seven    = 7'b111_1000;
    localparam eight    = 7'b000_0000;
    localparam nine     = 7'b001_0000;

    reg [3:0] digit;
    reg [1:0] digit_select;
    reg [3:0] ANODE = 4'b1111;
    reg [10:0] clk_div;
    wire [3:0] thousands, hundreds, tens, units;

    function [7:0] showSegment;
        input [3:0] digit;
        begin
            case(digit)
                4'b0000: showSegment = zero;
                4'b0001: showSegment = one;
                4'b0010: showSegment = two;
                4'b0011: showSegment = three;
                4'b0100: showSegment = four;
                4'b0101: showSegment = five;
                4'b0110: showSegment = six;
                4'b0111: showSegment = seven;
                4'b1000: showSegment = eight;
                4'b1001: showSegment = nine;
                default: showSegment = 7'b000_0000;
            endcase
        end
    endfunction

    always @(posedge CLK) begin
        clk_div <= clk_div + 1;
    end

    always @(posedge clk_div[10]) begin
        digit_select <= digit_select + 1;
    end

    always @* begin
            case (digit_select)
                2'b00: begin
                    digit = units;
                    ANODE = 4'b1110;
                end
                2'b01: begin
                    digit = tens;
                    ANODE = 4'b1101;
                end
                2'b10: begin
                    digit = hundreds;
                    ANODE = 4'b1011;
                end
                2'b11: begin
                    digit = thousands;
                    ANODE = 4'b0111;
                end
                default: begin
                    digit = 4'b1111;
                    ANODE = 4'b0000;
                end
            endcase
    end

    // divide the score into thousands, hundreds, tens and units
    assign thousands = score / 1000;
    assign hundreds = (score / 100) % 10;
    assign tens = (score / 10) % 10;
    assign units = score % 10;
    assign SSEG_AN = ANODE;
    assign SSEG_CA = showSegment(digit);
endmodule
