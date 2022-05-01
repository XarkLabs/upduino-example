// example_main.sv
//
// vim: set et ts=4 sw=4
//
// Simple main module of for example design (above is either FPGA top or
// testbench).
//
// This module has the example LED control logic, counter and buttons
//
`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

module example_main (
    // outputs
    output      logic           red_o,      // red LED output
    output      logic           green_o,    // green LED output
    output      logic           blue_o,     // blue LED output
    // inputs
    input       logic [2:0]     button_i,   // optional R, G and B active-low "button" inputs
    input  wire logic           clk         // clock for module input
);

// constants for bit for each color
localparam      RED_B = 0;
localparam      GRN_B = 1;
localparam      BLU_B = 2;

// counter increment block
`ifdef SYNTHESIS
localparam      CNT_BITS = 26;              // constant for number of bits in counter in FPGA (human speed)
`else
localparam      CNT_BITS = 4;               // constant for number of bits in counter in simulation (super fast)
`endif
logic [CNT_BITS-1:0] counter;               // CNT_BITS bit counter with default FPGA reset value

always_ff @(posedge clk) begin
    counter <= counter + 1'b1;
end

// button input synchronizer block (for more info search for "two flip-flop
// synchronizer", or see:
// https://daffy1108.wordpress.com/2014/06/08/synchronizers-for-asynchronous-signals/
logic [2:0]     but_ff;                     // 1st synchronizer flip-flops for button_i
logic [2:0]     button;                     // final synchronizer result flip-flips for buttons

always_ff @(posedge clk) begin
    but_ff  <=  ~button_i;                  // set 1st flip-flops from inverted active-low inputs
    button  <=  but_ff;                     // set result flip-flops from 1st flip-flops
end

// example button logic block (sets LEDs based on counter bits XOR'd with
// corresponding button)
logic [1:0]     seq;
assign          seq = counter[CNT_BITS-3+:2]; // use top two bits for sequence state
// NOTE: notation [r+:w] (r for right-most bit, w for bit width) means bits
// [r+w-1:r] e.g. [0+:8] is the same as [7:0]

always_ff @(posedge clk) begin

    // default LEDs to button
    red_o   <= button[RED_B];
    green_o <= button[GRN_B];
    blue_o  <= button[BLU_B];

    case (seq)
        2'b00: begin
            red_o    <= 1'b1;               // red only
        end
        2'b01: begin
            green_o    <= 1'b1;             // green only
        end
        2'b11: begin
            blue_o    <= 1'b1;              // blue only
        end
        default: begin
            ;                               // leave all off
        end
    endcase

end

// initialize signals (in simulation, or on FPGA reconfigure)
initial begin
    counter =  '0;

    but_ff  =  '0;
    button  =  '0;
end



endmodule
`default_nettype wire               // restore default for other modules
