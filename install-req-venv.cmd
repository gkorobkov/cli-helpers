@echo off
:: install-req-venv.cmd — Installs Python requirements into the local .venv.
::
:: Runs: .venv\Scripts\python.exe -m pip install -r requirements.txt
:: Use after create-venv.cmd to install all project dependencies inside .venv.
::
:: Dependencies:
::   .venv            - created by create-venv.cmd
::   requirements.txt - must exist in the current directory
::
:: Usage:
::   install-req-venv.cmd
::
:: Examples:
::   install-req-venv.cmd
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
