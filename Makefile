# UPduino v3.x FPGA Example Makefile Project
#
# vim: set noet ts=8 sw=8
#
# SPDX-License-Identifier: MIT-0
# (So pretty much do as you like with this project)
#
# See BUILDING.md for building info
#
# File types:
# *.sv           - SystemVerilog design source files
# *.svh          - SystemVerilog design source include headers
# *.json         - intermediate representation for FPGA deisgn from yosys
# *.asc          - intermediate ASCII "bistream" from nextpnr-ice40
# *.bin          - final binary "bitstream" output file used to program FPGA

# This is a "make hack" have make exit if command fails (even if command after pipe succeeds, e.g., tee)
SHELL := /bin/bash -o pipefail

# SystemVerilog source and include directory (use all *.sv files here in design)
SRCDIR := .

# output directory
OUTDIR := out

# log output directory for tools (spammy, but useful detailed info)
LOGS := logs

# Name of the "top" module for design (in ".sv" file with same name)
TOP := example_top

# Basename of synthesis output files
OUTNAME := example

# Name of the "top" module for simulation test bed (in ".sv" file with same name)
TBTOP := example_tb

# Name of C++ top simulation module (for Verilator)
VTOP := example_top

# Name of simulation output file
TBOUTNAME := example_tb

# UPduino pin definitions file
PIN_DEF := upduino_v3.pcf

# UPduno FPGA device type
DEVICE := up5k

# UPduino FPGA package
PACKAGE := sg48

# Verilog source files for design (with no TOP or TBTOP module)
SRC := $(filter-out $(SRCDIR)/$(TBTOP).sv,$(filter-out $(SRCDIR)/$(TOP).sv,$(wildcard $(SRCDIR)/*.sv)))

# Verilog include files for design
INC := $(wildcard $(SRCDIR)/*.svh)

# icestorm tools
# tool binaries assumed in default path (e.g. oss-cad-suite with:
# source <extracted_location>/oss-cad-suite/environment"
YOSYS := yosys
YOSYS_CONFIG := yosys-config
ICEPACK := icepack
# Use iceprog.exe under WSL (due to USB issues with Linux utlity)
# NOTE: Windows may still require Zadig driver installation. For more info see
# https://gojimmypi.blogspot.com/2020/12/ice40-fpga-programming-with-wsl-and.html
ifneq ($(shell uname -a | grep -i Microsoft),)
ICEPROG := iceprog.exe
else
ICEPROG := iceprog
endif

# Yosys warning/error options
# (makes "no driver" warning an error, you can also suppress spurious warnings
# so they only appear in log file with -w, e.g. adding:  -w "tri-state"
# would suppress the warning shown when you use 1'bZ: "Yosys has only limited
# support for tri-state logic at the moment.")
YOSYS_OPTS := -e "no driver"

# Yosys synthesis options
# ("ultraplus" device, enable DSP inferrence, ABC9 logic optimization and explicitly set top module name)
YOSYS_SYNTH_OPTS := -device u -dsp -abc9 -top $(TOP)

# Invokes yosys-config to find the proper path to the iCE40 simulation library
TECH_LIB := $(shell $(YOSYS_CONFIG) --datdir/ice40/cells_sim.v)
VLT_CONFIG := out/ice40_config.vlt

# Verilator tool
VERILATOR := verilator
# Verilator options (used for "lint" for much more friendly error messages - and also strict warnings)
# If you are getting "annoyed", you can add -Wno-fatal so warnings aren't fatal, but IMHO better to just fix them. :)
# Also, a few overly annoying ones are disabled here, but you can also disable other ones to you don't wish to heed
# e.g. -Wno-UNUSED
# A nice guide to the warnings, what they mean and how to appese them is https://verilator.org/guide/latest/warnings.html
# (SystemVerilog files, language versions, include directory and error & warning options)
#VERILATOR_OPTS := -sv --language 1800-2012 -I$(SRCDIR) -Werror-UNUSED -Wall -Wno-DECLFILENAME
VERILATOR_OPTS := -sv --language 1800-2012 --trace-fst --timing -I$(SRCDIR) -v $(TECH_LIB) $(VLT_CONFIG) -Werror-UNUSED -Wall -Wno-DECLFILENAME
# Note: Using -Os seems to provide the fastest compile+run simulation iteration
# time
VERILATOR_CFLAGS := -CFLAGS "-std=c++14 -Wall -Wextra -Werror -fomit-frame-pointer -Wno-deprecated-declarations -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable -Wno-int-in-bool-context"

# Verillator C++ simulation driver
CSRC := example_vsim.cpp

# Icarus Verilog tool
IVERILOG := iverilog
VVP := vvp
# Icarus Verilog options
# (language version, include directory, library directory, warning & error options)
IVERILOG_OPTS := -g2012 -I$(SRCDIR) -Wall -Wno-portbind -l$(TECH_LIB)

# nextpnr iCE40 tool
NEXTPNR := nextpnr-ice40
# nextpnr-ice40 options
# (promote logic to buffer, optimize for timing, use "heap" placer)
NEXTPNR_OPTS := --promote-logic --opt-timing --placer heap

# SystemVerilog preprocessor definitions common to all modules (this prevents spurious warnings in TECH_LIB files)
DEFINES := -DNO_ICE40_DEFAULT_ASSIGNMENTS

# show info on make targets
info:
	@echo "make targets:"
	@echo "    make all        - synthesize FPGA bitstream and build simulations for design"
	@echo "    make bin        - synthesize UPduino bitstream for design"
	@echo "    make prog       - program UPduino bitstream via USB"
	@echo "    make count      - show design resource usage counts"
	@echo "    make isim       - build Icarus Verilog simulation for design"
	@echo "    make irun       - run Icarus Verilog simulation for design"
	@echo "    make clean      - clean most files that can be rebuilt"

# defult target is to make FPGA bitstream for design
all: isim vsim count bin

# synthesize FPGA bitstream for design
bin: $(VLT_CONFIG) $(OUTDIR)/$(OUTNAME).bin
	@echo === Synthesizing done, use \"make prog\" to program FPGA ===

# program UPduino FPGA via USB (may need udev rules or sudo on Linux)
prog: $(VLT_CONFIG) $(OUTDIR)/$(OUTNAME).bin
	@echo === Programming UPduino FPGA via USB ===
	$(ICEPROG) -d i:0x0403:0x6014 $(OUTDIR)/$(OUTNAME).bin

# run Yosys with "noflatten", which will produce a resource count per module
count: $(VLT_CONFIG) $(SRCDIR)/$(TOP).sv $(SRC) $(INC) $(FONTFILES) $(MAKEFILE_LIST)
	@echo === Couting Design Resources Used ===
	@mkdir -p $(LOGS)
	$(YOSYS) -l $(LOGS)/$(OUTNAME)_yosys_count.log $(YOSYS_OPTS) -p 'verilog_defines $(DEFINES) ; read_verilog -I$(SRCDIR) -sv $(SRCDIR)/$(TOP).sv $(SRC) ; synth_ice40 $(YOSYS_SYNTH_OPTS) -noflatten'
	@sed -n '/Printing statistics/,/Executing CHECK pass/p' $(LOGS)/$(OUTNAME)_yosys_count.log | sed '$$d'
	@echo === See $(LOGS)/$(OUTNAME)_yosys_count.log for resource use details ===

# use Icarus Verilog to build and run simulation executable
isim: $(OUTDIR)/$(TBOUTNAME) $(SRCDIR)/$(TBTOP).sv $(SRC) $(MAKEFILE_LIST)
	@echo === Icarus Verilog files built, use \"make irun\" to run ===

# use Icarus Verilog to run simulation executable
irun: $(OUTDIR)/$(TBOUTNAME) $(MAKEFILE_LIST)
	@echo === Running simulation ===
	@mkdir -p $(LOGS)
	$(VVP) $(OUTDIR)/$(TBOUTNAME) -fst
	@echo === Icarus Verilog simulation done, use "gtkwave logs/$(TBTOP).fst" to view waveforms ===

# build native simulation executable
vsim: obj_dir/V$(VTOP) $(MAKEFILE_LIST)
	@echo === Completed building Verilator simulation, use \"make vrun\" to run.

# run Verilator to build and run native simulation executable
vrun: obj_dir/V$(VTOP) $(MAKEFILE_LIST)
	@mkdir -p $(LOGS)
	obj_dir/V$(VTOP) $(VRUN_TESTDATA)

# use Icarus Verilog to build vvp simulation executable
$(OUTDIR)/$(TBOUTNAME): $(VLT_CONFIG) $(SRCDIR)/$(TBTOP).sv $(SRC) $(MAKEFILE_LIST)
	@echo === Building simulation ===
	@mkdir -p $(OUTDIR)
	@rm -f $@
	$(VERILATOR) $(VERILATOR_OPTS) --lint-only $(DEFINES) --top-module $(TBTOP) $(SRCDIR)/$(TBTOP).sv $(SRC)
	$(IVERILOG) $(IVERILOG_OPTS) $(DEFINES) -o $@ $(SRCDIR)/$(TBTOP).sv $(SRC)

# use Verilator to build native simulation executable
obj_dir/V$(VTOP): $(VLT_CONFIG) $(CSRC) $(INC) $(SRCDIR)/$(TOP).sv $(SRC) $(MAKEFILE_LIST)
	$(VERILATOR) $(VERILATOR_OPTS) --cc --exe --trace  $(DEFINES) -DEXT_CLK $(VERILATOR_CFLAGS) $(LDFLAGS) --top-module $(VTOP) $(SRCDIR)/$(TOP).sv $(SRC) $(CSRC)
	cd obj_dir && make -f V$(VTOP).mk

# disable UNUSED and UNDRIVEN warnings in cells_sim.v library for Verilator lint
$(VLT_CONFIG):
	@mkdir -p $(OUTDIR)
	@echo >$(VLT_CONFIG)
	@echo >>$(VLT_CONFIG) \`verilator_config
	@echo >>$(VLT_CONFIG) lint_off -rule WIDTH  -file \"$(TECH_LIB)\"
	@echo >>$(VLT_CONFIG) lint_off -rule UNUSED  -file \"$(TECH_LIB)\"
	@echo >>$(VLT_CONFIG) lint_off -rule UNDRIVEN  -file \"$(TECH_LIB)\"

# synthesize SystemVerilog and create json description
$(OUTDIR)/$(OUTNAME).json: $(SRCDIR)/$(TOP).sv $(SRC) $(INC) $(MAKEFILE_LIST)
	@echo === Synthesizing design ===
	@rm -f $@
	@mkdir -p $(OUTDIR)
	@mkdir -p $(LOGS)
	$(VERILATOR) $(VERILATOR_OPTS) --lint-only $(DEFINES) --top-module $(TOP) $(SRCDIR)/$(TOP).sv $(SRC) 2>&1 | tee $(LOGS)/$(OUTNAME)_verilator.log
	$(YOSYS) $(YOSYS_OPTS) -l $(LOGS)/$(OUTNAME)_yosys.log -q -p 'verilog_defines $(DEFINES) ; read_verilog -I$(SRCDIR) -sv $(SRCDIR)/$(TOP).sv $(SRC) ; synth_ice40 $(YOSYS_SYNTH_OPTS) -json $@'

# make BIN bitstream from JSON description and device parameters
$(OUTDIR)/$(OUTNAME).bin: $(OUTDIR)/$(OUTNAME).json $(PIN_DEF) $(MAKEFILE_LIST)
	@rm -f $@
	@mkdir -p $(LOGS)
	@mkdir -p $(OUTDIR)
	$(NEXTPNR) -l $(LOGS)/$(OUTNAME)_nextpnr.log -q $(NEXTPNR_OPTS) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PIN_DEF) --asc $(OUTDIR)/$(OUTNAME).asc
	$(ICEPACK) $(OUTDIR)/$(OUTNAME).asc $@
	@rm $(OUTDIR)/$(OUTNAME).asc
	@echo === Synthesis stats for $(OUTNAME) on $(DEVICE) === | tee $(LOGS)/$(OUTNAME)_stats.txt
	@-tabbyadm version | grep "Package" | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@$(YOSYS) -V 2>&1 | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@$(NEXTPNR) -V 2>&1 | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@sed -n '/Device utilisation/,/Info: Placed/p' $(LOGS)/$(OUTNAME)_nextpnr.log | sed '$$d' | grep -v ":     0/" | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@grep "Max frequency" $(LOGS)/$(OUTNAME)_nextpnr.log | tail -1 | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@echo

# delete all targets that will be re-generated
clean:
	rm -f $(OUTDIR)/$(OUTNAME).bin $(OUTDIR)/$(OUTNAME).json $(OUTDIR)/$(OUTNAME).asc $(OUTDIR)/$(TBOUTNAME) $(wildcard obj_dir/*)

# prevent make from deleting any intermediate files
.SECONDARY:

# inform make about "phony" convenience targets
.PHONY: info all bin prog count isim irun vsim vrun clean
