module color(
    input CLK25M,  // 25MHz clock input
    input Reset, 
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
    // initial block position
    localparam INITIAL_BLOCK    = 16'b0000_0000_0010_0000;
    // define fill block in horizontal direction
    localparam FILL_BLOCK_H     = 16'b0000_0011_1111_1111;
    
    wire    [127:0] map;
    reg     [127:0] background;
    reg     [127:0] block;
    wire    [6:0]   pos;
    reg     [3:0]   posX; // 0 < x < 7
    reg     [2:0]   posY;
    wire            clk1;
    wire            clk10;
    reg     [3:0]   clkCount;  // make 1Hz clock from 10Hz clock
    reg             debugFlag;
    reg     [3:0]   score;

    clockDivider1Hz clk_divider1Hz(
        .CLK25M(CLK25M),
        .Reset(Reset),
        .clk1_out(clk1)
    );

    clockDivider10Hz clk_divider10Hz(
        .CLK25M(CLK25M),
        .Reset(Reset),
        .clk10_out(clk10)
    );

    bcd7seg segment(
        .score(score),
        .SSEG_CA(SSEG_CA),
        .SSEG_AN(SSEG_AN)
    );

    initial begin
        background = BORDER | (BORDER<<16)
                            | (BORDER<<32)
                            | (BORDER<<48)
                            | (BORDER<<64)
                            | (BORDER<<80)
                            | (BORDER<<96) 
                            | (BORDER<<112);
        block = INITIAL_BLOCK;
        posX = 4;
        posY = 0;
        clkCount = 0;
        score = 0;
    end

    // Move block
    always @(posedge clk10) begin
        // Move block to the right or left or down
        if (buttonL && !leftBlockExists(block)) begin
            block = block >> 1;
        end else if (buttonR && !rightBlockExists(block)) begin
            block = block << 1;
        end else if (buttonD && posY < 7 && !underBlockExists(block)) begin
            block = block << 16;
            posY = posY + 1;
        end

        if (clkCount == 10) begin
            // block down
            if (underBlockExists(block)) begin
                background = background | block;
                block = INITIAL_BLOCK;
                posY = 0;
            end else if (posY < 7) begin
                block = block << 16;
                posY = posY + 1;
            end else begin
                background = background | block;
                block = INITIAL_BLOCK;
                posY = 0;
            end
            clkCount = 0;
        end else begin
            clkCount = clkCount + 1;
        end

        // check if the block is filled
        background = blockFilled(background);

        // blink the debug LED
        debugFlag = ~debugFlag;
    end

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
            if (background[127:112] == FILL_BLOCK_H) begin
                background[127:112] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[111:96] == FILL_BLOCK_H) begin
                background[111:96] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[95:80] == FILL_BLOCK_H) begin
                background[95:80] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[79:64] == FILL_BLOCK_H) begin
                background[79:64] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[63:48] == FILL_BLOCK_H) begin
                background[63:48] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[47:32] == FILL_BLOCK_H) begin
                background[47:32] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[31:16] == FILL_BLOCK_H) begin
                background[31:16] = BORDER;
                background = background << 16 | BORDER;
                score = score + 1;
            end else if (background[15:0] == FILL_BLOCK_H) begin
                background[15:0] = BORDER;
                background = background << 16 | BORDER;
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
    localparam DIVISOR = 25000000;

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
 * BCD to 7-segment decoder
 */

module bcd7seg (
    input [3:0] score,
    output wire [7:0] SSEG_CA,
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

    function [7:0] showSegment;
        input [3:0] score;
        begin
            case(score)
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
                default: showSegment = 7'b111_1111;
            endcase
        end
    endfunction
    assign SSEG_AN = 4'b1110;
    assign SSEG_CA = showSegment(score);
endmodule
