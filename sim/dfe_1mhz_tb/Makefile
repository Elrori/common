.PHONY: test quick adc12 adc12-quick adc12-18 xc7-synth

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
