@echo off
:: install-req.cmd — Installs Python requirements with the system pip3.
::
:: Runs: pip3 install -r ./requirements.txt
:: Use when you want the global Python environment instead of a local .venv.
::
:: Dependencies:
::   pip3             - included with Python 3
::                      https://www.python.org/downloads/
::   requirements.txt - must exist in the current directory
::
:: Usage:
::   install-req.cmd
::
:: Examples:
::   install-req.cmd
pip3 install -r ./requirements.txt
