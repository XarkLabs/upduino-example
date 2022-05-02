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

# Name of the "top" module for design (in ".sv" file with same name)
TOP := example_top

# Basename of synthesis output files
OUTNAME := example

# Name of the "top" module for simulation test bed (in ".sv" file with same name)
TBTOP := example_tb

# Name of simulation output file
TBOUTNAME := example_tb

# UPduino pin definitions file
PIN_DEF := upduino_v3.pcf

# UPduno FPGA device type
DEVICE := up5k

# UPduino FPGA package
PACKAGE := sg48

# Verilog source directories
VPATH := $(SRCDIR)

# Verilog source files for design (with TOP module first and no TBTOP)
SRC := $(SRCDIR)/$(TOP).sv $(filter-out $(SRCDIR)/$(TBTOP).sv,$(filter-out $(SRCDIR)/$(TOP).sv,$(wildcard $(SRCDIR)/*.sv)))

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


# Yosys synthesis options
# ("ultraplus" device, enable DSP inferrence and explicitly set top module name)
YOSYS_SYNTH_OPTS := -device u -dsp -top $(TOP)
# NOTE: Options that can often produce a more "optimal" size/speed for design, but slower:
#       YOSYS_SYNTH_ARGS := -device u -dsp -abc9 -top $(TOP)

# Invokes yosys-config to find the proper path to the iCE40 simulation library
TECH_LIB := $(shell $(YOSYS_CONFIG) --datdir/ice40/cells_sim.v)

# Verilator tool
VERILATOR := verilator
# Verilator options (used for "lint" for much more friendly error messages - and also strict warnings)
# If you are getting "annoyed", you can add -Wno-fatal so warnings aren't fatal, but IMHO better to just fix them. :)
# Also, a few overly annoying ones are disabled here, but you can also disable other ones to you don't wish to heed
# e.g. -Wno-UNUSED
# A nice guide to the warnings, what they mean and how to appese them is https://verilator.org/guide/latest/warnings.html
# (SystemVerilog files, language versions, include directory and error & warning options)
VERILATOR_OPTS := --sv --language 1800-2012 -I$(SRCDIR) -Werror-UNUSED -Wall -Wno-DECLFILENAME

# Icarus Verilog tool
IVERILOG := iverilog
# Icarus Verilog options
# (language version, include directory, library directory, warning & error options)
IVERILOG_ARGS := -g2012 -I$(SRCDIR) -Wall -Wno-portbind -l$(TECH_LIB)

# nextpnr iCE40 tool
NEXTPNR := nextpnr-ice40
# nextpnr-ice40 options
# (use "heap" placer)
NEXTPNR_ARGS := --placer heap
# NOTE: Options that can often produce a more "optimal" size/speed for design, but slower:
#       NEXTPNR_ARGS := --promote-logic --opt-timing --placer heap

# log output directory for tools (spammy, but useful detailed info)
LOGS := logs

# SystemVerilog preprocessor definitions common to all modules (this prevents spurious warnings in TECH_LIB files)
DEFINES := -DNO_ICE40_DEFAULT_ASSIGNMENTS

# show info on make targets
info:
	@echo "make targets:"
	@echo "    make all        - synthesize FPGA bitstream and build simulation for design"
	@echo "    make bin        - synthesize UPduino bitstream for design"
	@echo "    make prog       - program UPduino bitstream via USB"
	@echo "    make count      - show design resource usage counts"
	@echo "    make isim       - build Icarus Verilog simulation for design"
	@echo "    make irun       - run Icarus Verilog simulation for design"
	@echo "    make clean      - clean most files that can be rebuilt"

# defult target is to make FPGA bitstream for design
all: isim bin

# synthesize FPGA bitstream for design
bin: $(OUTDIR)/$(OUTNAME).bin
	@echo === Synthesizing done, use \"make prog\" to program FPGA ===

# program UPduino FPGA via USB (may need udev rules or sudo on Linux)
prog: $(OUTDIR)/$(OUTNAME).bin
	@echo === Programming UPduino FPGA via USB ===
	$(ICEPROG) -d i:0x0403:0x6014 $(OUTDIR)/$(OUTNAME).bin

# run Yosys with "noflatten", which will produce a resource count per module
count: $(SRC) $(INC) $(FONTFILES) $(MAKEFILE_LIST)
	@echo === Couting Design Resources Used ===
	@mkdir -p $(LOGS)
	$(YOSYS) -l $(LOGS)/$(OUTNAME)_yosys_count.log -w ".*" -q -p 'verilog_defines $(DEFINES) ; read_verilog -I$(SRCDIR) -sv $(SRC) $(FLOW3) ; synth_ice40 $(YOSYS_SYNTH_ARGS) -noflatten'
	@sed -n '/Printing statistics/,/Executing CHECK pass/p' $(LOGS)/$(OUTNAME)_yosys_count.log | sed '$$d'
	@echo === See $(LOGS)/$(OUTNAME)_yosys_count.log for resource use details ===

# use Icarus Verilog to build and run simulation executable
isim: $(OUTDIR)/$(TBOUTNAME) $(TBTOP).sv $(SRC) $(MAKEFILE_LIST)
	@echo === Simulation files built, use \"make irun\" to run ===

# use Icarus Verilog to run simulation executable
irun: $(OUTDIR)/$(TBOUTNAME) $(MAKEFILE_LIST)
	@echo === Running simulation ===
	$(OUTDIR)/$(TBOUTNAME) -fst
	@echo === Simulation done, use "gtkwave logs/$(TBTOP).fst" to view waveforms ===

# use Icarus Verilog to build vvp simulation executable
$(OUTDIR)/$(TBOUTNAME): $(TBTOP).sv $(SRC) $(MAKEFILE_LIST)
	@echo === Building simulation ===
	@mkdir -p $(OUTDIR)
	@rm -f $@
	$(VERILATOR) $(VERILATOR_ARGS) -Wno-STMTDLY --lint-only $(DEFINES) -v $(TECH_LIB) --top-module $(TBTOP) $(TBTOP).sv $(SRC)
	$(IVERILOG) $(IVERILOG_ARGS) $(DEFINES) -o $@ $(TBTOP).sv $(SRC)

# synthesize SystemVerilog and create json description
$(OUTDIR)/$(OUTNAME).json: $(SRC) $(INC) $(MAKEFILE_LIST)
	@echo === Synthesizing design ===
	@rm -f $@
	@mkdir -p $(OUTDIR)
	@mkdir -p $(LOGS)
	$(VERILATOR) $(VERILATOR_ARGS) --lint-only $(DEFINES) --top-module $(TOP) $(TECH_LIB) $(SRC) 2>&1 | tee $(LOGS)/$(OUTNAME)_verilator.log
	$(YOSYS) -l $(LOGS)/$(OUTNAME)_yosys.log -w ".*" -q -p 'verilog_defines $(DEFINES) ; read_verilog -I$(SRCDIR) -sv $(SRC) $(FLOW3) ; synth_ice40 $(YOSYS_SYNTH_ARGS) -json $@'

# make ASCII bitstream from JSON description and device parameters
$(OUTDIR)/$(OUTNAME).asc: $(OUTDIR)/$(OUTNAME).json $(PIN_DEF) $(MAKEFILE_LIST)
	@rm -f $@
	@mkdir -p $(LOGS)
	@mkdir -p $(OUTDIR)
	$(NEXTPNR) -l $(LOGS)/$(OUTNAME)_nextpnr.log -q $(NEXTPNR_ARGS) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PIN_DEF) --asc $@
	@echo === Synthesis stats for $(OUTNAME) on $(DEVICE) === | tee $(LOGS)/$(OUTNAME)_stats.txt
	@-tabbyadm version | grep "Package" | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@$(YOSYS) -V 2>&1 | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@$(NEXTPNR) -V 2>&1 | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@sed -n '/Device utilisation/,/Info: Placed/p' $(LOGS)/$(OUTNAME)_nextpnr.log | sed '$$d' | grep -v ":     0/" | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@grep "Max frequency" $(LOGS)/$(OUTNAME)_nextpnr.log | tail -1 | tee -a $(LOGS)/$(OUTNAME)_stats.txt
	@echo

# make binary bitstream from ASCII bitstream
$(OUTDIR)/$(OUTNAME).bin: $(OUTDIR)/$(OUTNAME).asc $(MAKEFILE_LIST)
	@rm -f $@
	$(ICEPACK) $< $@

# delete all targets that will be re-generated
clean:
	rm -f $(OUTDIR)/$(OUTNAME).bin $(OUTDIR)/$(OUTNAME).json $(OUTDIR)/$(OUTNAME).asc $(OUTDIR)/$(TBOUTNAME)

# prevent make from deleting any intermediate files
.SECONDARY:

# inform make about "phony" convenience targets
.PHONY: info all bin prog lint isim irun count clean
