@echo off
REM py-req-install.cmd — Installs Python requirements with the system pip3.
REM Runs: pip3 install -r ./requirements.txt
REM Use when you want the global Python environment instead of a local .venv.
REM Dependencies:
REM   pip3             - included with Python 3
REM                      https://www.python.org/downloads/
REM   requirements.txt - must exist in the current directory
REM Usage:
REM   py-req-install.cmd
REM Examples:
REM   py-req-install.cmd
pip3 install -r ./requirements.txt
