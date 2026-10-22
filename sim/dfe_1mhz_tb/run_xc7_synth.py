#!/usr/bin/env python3
"""Map the existing SDR RTL to Artix-7 cells using open-source Yosys.

This is a synthesis/primitive-count comparison, NOT Vivado timing sign-off.
All generated logs, ROM files and output JSON are in the test directory.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess

from run_adc12 import ROOT, TB, TMP, setup_roms

DEVICE = "xc7a50t-fgg484-1"
CAPACITY = {"lut": 32600, "ff": 65200, "dsp48e1": 120, "bram18_equiv": 150}
BASE = ["dsp_nco.v", "dsp_nco_rom.v", "dsp_mul2.v", "dsp_cic_dec.v",
        "simple_ram.v"]
MODES = {
    "original": ("sys_sw_dfe", ["sys_sw_dfe.v", "dsp_fir_dec.v", "simple_rom.v", *BASE], None, True),
    "optimized18": ("sys_sw_dfe_1mhz", ["sys_sw_dfe_1mhz.v", "dsp_fir_dec_sym.v", *BASE], 18, True),
    "optimized20": ("sys_sw_dfe_1mhz", ["sys_sw_dfe_1mhz.v", "dsp_fir_dec_sym.v", *BASE], None, True),
    "fir_original": ("synth_fir_old", ["dsp_fir_dec.v", "dsp_fir_dec_sym.v", "simple_rom.v", "simple_ram.v"], None, False),
    "fir18": ("synth_fir_18", ["dsp_fir_dec.v", "dsp_fir_dec_sym.v", "simple_rom.v", "simple_ram.v"], None, False),
    "fir20": ("synth_fir_20", ["dsp_fir_dec.v", "dsp_fir_dec_sym.v", "simple_rom.v", "simple_ram.v"], None, False),
}


def primitive_counts(log):
    # The final 'design hierarchy' section is the sum over all submodules.
    section = log[log.rfind("=== design hierarchy ==="):]
    if not section:
        raise RuntimeError("Missing Yosys design hierarchy summary")
    primitives = {k: int(v) for k, v in re.findall(r"^\s{5}([A-Z][A-Z0-9]*)\s+(\d+)\s*$", section, re.M)}
    lut_logic = sum(v for k, v in primitives.items() if re.fullmatch(r"LUT[1-6]", k))
    # RAM32M/RAM64M primitives each occupy four 6-input LUTs in a SLICEM.
    lut_ram = 4 * (primitives.get("RAM32M", 0) + primitives.get("RAM64M", 0))
    bram18_equiv = primitives.get("RAMB18E1", 0) + 2 * primitives.get("RAMB36E1", 0)
    total = lut_logic + lut_ram
    ff = sum(v for k, v in primitives.items() if k.startswith("FD") and k[2:3] in "CRPSE")
    result = {
        "lut_logic": lut_logic,
        "lut_ram_estimated": lut_ram,
        "lut_total_estimated": total,
        "ff": ff,
        "dsp48e1": primitives.get("DSP48E1", 0),
        "bram18_equiv": bram18_equiv,
        "carry4": primitives.get("CARRY4", 0),
        "ram32m": primitives.get("RAM32M", 0),
        "ram64m": primitives.get("RAM64M", 0),
        "cells": primitives,
    }
    result["device_percent"] = {
        "lut": round(total / CAPACITY["lut"] * 100, 3),
        "ff": round(ff / CAPACITY["ff"] * 100, 3),
        "dsp48e1": round(result["dsp48e1"] / CAPACITY["dsp48e1"] * 100, 3),
        "bram18_equiv": round(bram18_equiv / CAPACITY["bram18_equiv"] * 100, 3),
    }
    return result


def synthesize(name):
    top, names, width, full = MODES[name]
    cwd = TMP if full else ROOT
    files = [ROOT / "common" / filename for filename in names]
    if not full:
        files.insert(0, TB / "synth_fir_compare.v")
    stages = ["read_verilog -sv -defer " + " ".join(str(f) for f in files)]
    if width:
        stages.append(f"hierarchy -top {top} -chparam CIC_BITS {width}")
    stages.extend([f"synth_xilinx -family xc7 -top {top}", "stat"])
    logfile = TMP / f"xc7_{name}.log"
    command = ["yosys", "-Q", "-T", "-l", str(logfile), "-p", "; ".join(stages)]
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise RuntimeError(f"{name} failed: {result.stderr[-3000:]}\nSee {logfile}")
    counts = primitive_counts(logfile.read_text())
    print(f"{name:15} LUT~{counts['lut_total_estimated']:5}  FF={counts['ff']:5} "
          f"DSP={counts['dsp48e1']:2}  RAMB18={counts['bram18_equiv']:2} "
          f"CARRY4={counts['carry4']:3}", flush=True)
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="+", choices=MODES,
                        default=list(MODES), help="Selected synthesis tops")
    args = parser.parse_args()
    setup_roms()
    results = {name: synthesize(name) for name in args.only}
    out = {
        "tool": subprocess.check_output(["yosys", "-V"], text=True).strip(),
        "technology_family": "xc7",
        "physical_part_target": DEVICE,
        "target_capacity": CAPACITY,
        "note": "Yosys XC7 cell mapping only; no Vivado synthesis/place/route/timing.",
        "lut_total_method": "sum LUT1..6 plus 4*RAM32M plus 4*RAM64M",
        "counts": results,
    }
    path = TB / "results_xc7.json"
    if set(args.only) == set(MODES):
        path.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
        print(f"Wrote {path.relative_to(ROOT)}")
    else:
        print("Partial run: JSON not overwritten")


if __name__ == "__main__":
    main()
