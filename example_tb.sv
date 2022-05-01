// example_tb.sv
//
// vim: set et ts=4 sw=4
//
// Simulation "testbench" for example design.  This "pretends" to be the FPGA
// hardware by generating a clock input and monitoring the LED outputs.
//

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps

module example_tb();                // module definition

logic red, green, blue;             // outputs from design
logic [2:0] button;                 // input buttons for design
logic clk;                          // simulated 12MHz "external clock" for design

// instantiate the design to test (unit-under-test)
example_main uut(
                .red_o(red),        // red output from design
                .green_o(green),    // green output from design
                .blue_o(blue),      // blue output from design
                .button_i(button),  // active-low "button" inputs for design
                .clk(clk)           // clock input for design
            );

// initial block (run once at startup)
initial begin
    $timeformat(-9, 0, " ns", 9);
    $dumpfile("logs/example_tb.fst");
    $dumpvars(0, uut);
    $display("Simulation started");

    clk = 1'b0; // set initial value for clk

    button = 3'b111;    // active-low, so unpressed
   // the signals we wish to monitor (via console print)
    $monitor("%09t: Buttons In (0=ON): %b    LEDs out (0=ON): R=%x G=%x B=%x", $realtime, button, red, green, blue);

    #500ns;                     // run for a bit
    button = 3'b000;            // simulate press of all buttons
    #500ns;
    button = 3'b001;            // simulate press of all buttons
    #500ns;
    button = 3'b010;            // simulate press of all buttons
    #500ns;
    button = 3'b100;            // simulate press of all buttons
    #500ns;
    button = 3'b111;            // simulate release of all buttons
    #1500ns;                    // complete simulation time

    $display("Ending simulation at %0t", $realtime);
    $finish;
end

// ns for 12 Mhz / 2 (delay for clk toggle)
localparam NS_12M   =   (1_000_000_000 / 12_000_000) / 2;

// toggle clock at 12 Mhz frequency
always begin
    #(NS_12M)   clk = !clk;
end

endmodule

`default_nettype wire               // restore default
