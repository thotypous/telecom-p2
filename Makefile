BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

all: project.fs

TESTS := $(wildcard Test*.bsv)
$(TESTS:.bsv=.exe): $(wildcard *.bsv)
	bsc -u -check-assert -verilog "$(@:.exe=).bsv" && bsc -verilog -e "mk$(@:.exe=)" -o "$@"

mkTop.v: $(wildcard *.bsv)
	bsc -p +:%/Libraries/FPGA/Misc/ -u -verilog -show-module-use Top.bsv

# Synthesis
project.json: top.v mkTop.v
	yosys -p "\
		$(shell cat mkTop.use | while read m; do \
			echo "read_verilog /opt/bluespec/lib/Verilog/$$m.v; "; \
		  done)\
		read_verilog mkTop.v; \
		read_verilog pll_main.v; \
		read_verilog pll_uart.v; \
		read_verilog top.v; \
		synth_gowin -top top -json project.json"

# Place and Route
project_pnr.json: project.json
	nextpnr-gowin --json project.json --write project_pnr.json --freq 27 --device ${DEVICE} --family ${FAMILY} --cst ${BOARD}.cst --pre-pack pre-pack.py

# Generate Bitstream
project.fs: project_pnr.json
	gowin_pack -d ${FAMILY} -o project.fs project_pnr.json

# Program Board
load: project.fs
	openFPGALoader -b ${BOARD} project.fs

# Cleanup build artifacts
clean:
	rm *.bo *.ba mk*.v mk*.cxx mk*.h model_*.cxx model_*.h *.o *.so *.use *.fs *.exe

.PHONY: load clean
.INTERMEDIATE: project_pnr.json project.json
