// example_top.sv
//
// vim: set et ts=4 sw=4
//
// "Top" of the example design (above is the FPGA hardware)
//
// * setup clock
// * setup inputs
// * setup outputs
// * instantiate main module
//
`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

// If UPduino OSC jumper is shorted or a wire connects 12M to gpio_20 then you
// can un-comment the following `define for an accurate 12MHz clock (otherwise
// the approximate ~48 Mhz internal FPGA oscillator / 4 will be used for ~12MHz)
//`define EXT_CLK

module example_top (
    // outputs
    output      logic   spi_ssn,    // SPI flash CS, hold high to prevent UART conflict
    output      logic   led_red,    // red
    output      logic   led_green,  // green
    output      logic   led_blue,   // blue
    // inputs
    input  wire logic   gpio_2,     // optional red external active-low "button"
    input  wire logic   gpio_46,    // optional green external active-low "button"
    input  wire logic   gpio_47,    // optional blue external active-low "button"
    input  wire logic   gpio_20     // optional external clock input
);

always_comb spi_ssn     = 1'b1;     // deselect SPI flash (pins shared with UART)

// clock signals
localparam      CLOCK_HZ    = 12_000_000;   // clock frequency in Hz
logic           clk;                        // clock signal for design

// input signals
logic [2:0]     button;             // internal "button" signals (2=blue, 1=green, 0=red)

// output signals
logic           red, green, blue;   // internal LED signals

// === clock setup

`ifdef EXT_CLK      // if EXT_CLK (12M connected to gpio_20 or OSC jumper shorted)
logic unused_ext_clk;
assign unused_ext_clk = &{ 1'b0, gpio_20, (CLOCK_HZ == 0 ? 1'b0 : 1'b0) };

always_comb     clk = gpio_20;
`else              // else !EXT_CLK
`ifndef VERILATOR   // don't use primitives with VERILATOR
// Lattice documentation for iCE40UP5K oscillators:
// https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/iCE40OscillatorUsageGuide.ashx?document_id=50670
/* verilator lint_off PINMISSING */ // suppress warnings about "missing pin" (default okay here)
SB_HFOSC  #(
    .CLKHF_DIV("0b10")  // 12 MHz = ~48 MHz / 4 (0b00=1, 0b01=2, 0b10=4, 0b11=8)
    ) hf_osc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(clk)
);
/* verilator lint_on PINMISSING */  // restore warnings about "missing pin"
`else               // else !SYNTHESIS, simulating design in simulator
// simulate hf_osc primitive (since doesn't won't work in simulation)
localparam NS_48M   =   (1_000_000_000 / CLOCK_HZ) / 2;   // delay for CLOCK_HZ frequency clk toggle
// suppress verilog warnings that are okay during simulation
/* verilator lint_off STMTDLY */

initial begin
    clk = '0;               // set initial value (or it will be 'X', and !'X' is still 'X'...)
end

always begin
    #(NS_48M)   clk = !clk; // delay ns, then toggle clock
end

logic unused_ext_clk;
assign unused_ext_clk = &{ 1'b0, gpio_20};

/* verilator lint_on STMTDLY */
`endif              // end !VERILATOR
`endif              // end !EXT_CLK

// === input setup

`ifndef VERILATOR
SB_IO #(
    .PIN_TYPE(6'b0000_01),
    .PULLUP(1'b1)
) button_input [2:0] (
    .PACKAGE_PIN({gpio_2, gpio_46, gpio_47 }),
    .D_IN_0({ button[0], button[1], button[2] })
);
`else
// directly assign buttons in simulation
always_comb begin
    button = { gpio_2, gpio_46, gpio_47 };
end
`endif

// === output setup

// LED output using RGB high-current drive primitive (which does nothing in simulation)
// NOTE: This primitive not strictly needed, but by using SB_RGBA_DRV it allows
// us to turn the UPduino RGB LED "photon cannons" power level down to stun (so
// you don't need goggles). :)
`ifndef VERILATOR
// RGB open-drain, high-current LED output
SB_RGBA_DRV #(
    .RGB0_CURRENT("0b000001"),  // set current for LEDs (lowest @ (4mA/2)=2mA)
    .RGB1_CURRENT("0b000001"),
    .RGB2_CURRENT("0b000001")
) rgb_driver (
    .RGBLEDEN(1'b1),    // enable RGB LED output
    .RGB0PWM(green),    // turn green LED on/off
    .RGB1PWM(blue),     // turn blue LED on/off
    .RGB2PWM(red),      // turn red LED on/off
    .CURREN(1'b1),      // 0=full current, 1=half current
    .RGB0(led_green),   // connection to green LED pin
    .RGB1(led_blue),    // connection to blue LED pin
    .RGB2(led_red)      // connection to red LED pin
);
`else               // else simulating design in simulator
// pass through LED signals in simulation
always_comb begin
    led_red     = ~red;     // LEDs are on when low, so invert here
    led_green   = ~green;
    led_blue    = ~blue;
end
`endif

// === instantiate main module

example_main main(
    .red_o(red),
    .green_o(green),
    .blue_o(blue),
    .button_i(button),
    .clk(clk)
);

endmodule
`default_nettype wire               // restore default
