#!/bin/bash

OUT_FILE="cache_sim_bin"
VCD_FILE="cache_sim.vcd"

echo "Cleaning old artifacts..."
rm -f $OUT_FILE $VCD_FILE

echo "Compiling Verilog sources..."
iverilog -o $OUT_FILE \
    src/primitives/comparator.v \
    src/primitives/encoder_4to2.v \
    src/cache/cache_line.v \
    src/cache/lru_unit.v \
    src/cache/cache_set.v \
    src/cache/cache_array.v \
    src/fsm/next_state.v \
    src/fsm/output_logic.v \
    src/fsm/cache_fsm.v \
    cache_controller.v \
    sim/cache_controller_tb.v

if [ $? -ne 0 ]; then
    echo "Compilation FAILED"
    exit 1
fi

echo "Compilation successful."
echo "Running simulation..."
vvp $OUT_FILE

if [ "$1" == "--view" ]; then
    echo "Opening GTKWave..."
    gtkwave $VCD_FILE &
fi

echo "Done."
