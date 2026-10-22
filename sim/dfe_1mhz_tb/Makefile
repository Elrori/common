.PHONY: test quick adc12 adc12-quick adc12-18 xc7-synth nco-test nco-quick nco-rom-check nco-verify

test:
	python3 run.py --full
	python3 run_adc12.py --full

quick:
	python3 run.py

adc12:
	python3 run_adc12.py --full

adc12-quick:
	python3 run_adc12.py

adc12-18:
	python3 run_adc12.py --bits 18

xc7-synth:
	python3 run_xc7_synth.py

nco-test:
	python3 gen_nco_rom.py --verify
	python3 run_nco_sfdr.py --full
	python3 run_nco_adc12.py --full
	python3 run_nco_adc12.py --stress
	python3 run_xc7_synth.py
	python3 verify_nco_results.py

nco-quick:
	python3 run_nco_sfdr.py
	python3 run_nco_adc12.py

nco-rom-check:
	python3 gen_nco_rom.py --verify

nco-verify:
	python3 verify_nco_results.py
