#!/usr/bin/env python3
"""Numerical pass/fail gate for reproduced NCO and full-DFE measurements."""

import json
from pathlib import Path

TB = Path(__file__).resolve().parent


def data(name):
    return json.loads((TB / name).read_text())


def main():
    nco = data("results_nco_sfdr.json")
    chain = data("results_nco_adc12.json")
    stress = data("results_nco_adc12_stress.json")
    synth = data("results_xc7.json")["counts"]

    assert len(nco["frequencies"]) == 5
    for test in nco["frequencies"]:
        s = test["modes"]
        assert s["14on"]["sfdr_db_c"] - s["12on"]["sfdr_db_c"] > 10
        assert s["16on"]["sfdr_db_c"] - s["14on"]["sfdr_db_c"] > 4

    assert len(chain["cases"]) >= 8
    for case in chain["cases"]:
        delta = case["modes"]["14_18"]["delta_vs_12_16_db"]
        assert case["adc_clipped_samples"] == 0
        assert delta > 0.10, ("14/18 inband SINAD did not improve", case["name"], delta)
        if case["name"] in ("237k AWGN seed1", "237k AWGN seed2", "450k edge AWGN"):
            assert delta > 1.0, ("No appreciable gain for regular signal", case["name"], delta)

    assert len(stress["cases"]) == 2
    for case in stress["cases"]:
        delta = case["modes"]["14_18"]["delta_vs_12_16_db"]
        assert case["adc_clipped_samples"] == 0
        assert delta > -0.15, ("ADC noise stress regression", case["name"], delta)

    base, opt = synth["optimized20"], synth["nco14_mix18"]
    assert opt["dsp48e1"] == base["dsp48e1"] == 4
    assert 0 < opt["lut_total_estimated"] - base["lut_total_estimated"] < 75
    assert 0 < opt["ff"] - base["ff"] < 100
    assert opt["bram18_equiv"] - base["bram18_equiv"] == 2

    print("PASS: all 5 oscillator LO SFDR gates, 8 ADC12 full-chain gains, "
          "2 noisy-ADC stability cases, and XC7 resource budget", flush=True)


if __name__ == "__main__":
    main()
