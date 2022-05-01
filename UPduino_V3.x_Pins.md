# UPduino Pinout Quick Reference

```plain-text
            PCF   Pin#  _____  Pin#   PCF
                 /-----| USB |-----\
           <GND> |  1   \___/   48 | spi_ssn   (16)
           <VIO> |  2           47 | spi_sck   (15)
           <RST> |  3           46 | spi_mosi  (17)
          <DONE> |  4           45 | spi_miso  (14)
<RGB2>   led_red |  5           44 | gpio_20   <G3>
<RGB0> led_green |  6     U     43 | gpio_10
<RGB1>  led_blue |  7     P     42 | <GND>
      <+5V/VUSB> |  8     d     41 | <12M>     <12 MHz out>
         <+3.3V> |  9     u     40 | gpio_12
           <GND> | 10     i     39 | gpio_21
         gpio_23 | 11     n     38 | gpio_13
         gpio_25 | 12     o     37 | gpio_19
         gpio_26 | 13           36 | gpio_18
         gpio_27 | 14     V     35 | gpio_11
         gpio_32 | 15     3     34 | gpio_9
<G0>     gpio_35 | 16     .     33 | gpio_6
         gpio_31 | 17     x     32 | gpio_44   <G6>
<G1>     gpio_37 | 18           31 | gpio_4
         gpio_34 | 19           30 | gpio_3
         gpio_43 | 20           29 | gpio_48
         gpio_36 | 21           28 | gpio_45
         gpio_42 | 22           27 | gpio_47
         gpio_38 | 23           26 | gpio_46
         gpio_28 | 24           25 | gpio_2
                 \-----------------/
```

See
[nobodywasishere/upduino-pinout](https://github.com/nobodywasishere/upduino-pinout)
for a more printable version of the above (and thanks!)

Notes:

* The names above (not in angle brackets) are the pins names used in Verilog
  (from the `.pcf` file)
* `gpio_20` is not available if the OSC jumper is shorted (since this pin will
  be used for the 12MHz clock)
* When `gpio_35` is used as an input (other than a clock input) you cannot use a
  PLL in your design (it can be an output however)
* `gpio_35`, `gpio_37`, `gpio_20` and `gpio_44` are high-drive, low skew buffers
  typically used for clocks inputs (or other high fan-out signals)
* PLL using `gpio_20` (G3) for input clock (e.g., `OSC` jumper shorted)
  typically uses PLL primitive `SB_PLL40_PAD` (with `PACKAGEPIN` input)
* PLL using `gpio_35` (G0) for input clock typically uses PLL primitive
  `SB_PLL40_CORE` (with `REFERENCECLK` pin input)
* `<GND>` and `<12M>` were reversed on the silkscreen on V3.0 boards (GND will
  be the closest to the USB socket)
* `<RGB0>`, `<RGB1>` and `<RGB2>` pins can be used for gpio inputs (as well as
  LED high-current outputs), but to avoid excessive input current draw from RGB
  LED, cut jumper R28 (carefully) to disable LED
* UPduino can be powered from USB or +5V on pin 8 (when not using USB, avoid
  connecting power to both at once)
* More UPduino documentation is available from
  [UPduino Documentation](https://upduino.readthedocs.io/en/latest/index.html)
* For PDFs with detailed info on the Lattice iCE40 UltraPlus 5K FPGA see
  [Lattice website](https://www.latticesemi.com/en/Products/FPGAandCPLD/iCE40UltraPlus)
* Also more information about iCE40 family from [iCEStorm project](http://bygone.clairexen.net/icestorm/)
* Detailed information is also available from Yosys wiki about
  [iCE40 PLL](<https://github.com/YosysHQ/icestorm/wiki/iCE40-PLL-documentation>)
* For open source FPGA tools, you can get nightly binaries for most operating
  systems from
  [YosysHQ oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)
