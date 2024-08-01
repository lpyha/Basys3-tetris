`timescale 1ns / 1ps

module video(
        input CLK100M,               // 100MHz clock input
        input [4:0] BTN,             // Button (top, left, right, bottom, center)
        input [3:0] SW,              // Switch (SW3,SW2,SW1,SW0)
        output [4:0] LED,            // LED    (LD3,LD2,LD1,LD0)
        output [3:0] VGA_RED,
        output [3:0] VGA_GREEN,
        output [3:0] VGA_BLUE,
        output VGA_HS,    // VGA signals
        output VGA_VS,
        output wire [6:0] SSEG_CA,
        output wire [3:0] SSEG_AN
    );
    // make 25MHz clock from 100MHz clock
    reg [1:0]    count = 0;
    wire 	    CLK25M;
    
    always @(posedge CLK100M) begin 
        count <= count + 1;
    end
    
    assign CLK25M = count[1];
    // LED
    assign LED[3:0] = {SW[3],SW[2],SW[1],SW[0]};
    
    // generate VGA video timing
    wire VtcVde;
    wire [10:0] VtcHCnt, VtcVCnt;
    VGAtiming VGAtiming(
        CLK25M,BTN[0],
        VtcVde,
        VGA_HS,
        VGA_VS,
        VtcHCnt,
        VtcVCnt
    );
    assign VGA_RED   = VtcVde==0 ? 0:Red[7:4];
    assign VGA_GREEN = VtcVde==0 ? 0:Green[7:4];
    assign VGA_BLUE  = VtcVde==0 ? 0:Blue[7:4];

    // specify color for each pixel
    wire [7:0] Red,Green,Blue;
    color color(
        .CLK25M(CLK25M),
        .buttonT(BTN[0]),
        .Hcount(VtcHCnt[9:0]),
        .Vcount(VtcVCnt[8:0]),
        .Red(Red),
        .Green(Green),
        .Blue(Blue),
        .buttonL(BTN[1]),
        .buttonR(BTN[2]),
        .buttonD(BTN[3]),
        .SSEG_CA(SSEG_CA[6:0]),
        .SSEG_AN(SSEG_AN[3:0]),
        .debugLED(LED[4])
    );
endmodule
