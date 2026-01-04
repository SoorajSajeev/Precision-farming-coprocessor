# Makefile for Cocotb simulation
# This runs the testbench (test.py) on the Verilog design

# Defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/../src/project.v

# Path to the Python test file
MODULE = test

# Testbench module name (top-level in project.v)
TOPLEVEL = tt_um_SoorajSajeev_precision_farming_coprocessor

# Include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
