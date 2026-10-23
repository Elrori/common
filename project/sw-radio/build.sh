#!/usr/bin/env bash
# Linux equivalent; requires installed Vivado and XILINX_VIVADO to be set.
set -euo pipefail
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--synth-only" ]]; then
  vivado -mode batch -source "$this_dir/scripts/build.tcl" -tclargs -synth-only
else
  vivado -mode batch -source "$this_dir/scripts/build.tcl"
fi
echo 'WARNING: PROVISIONAL ADC/AD8370 PINS. DO NOT FLASH BITSTREAM.'
