@echo off
:: venv-req-install.cmd — Installs Python requirements into the local .venv.
::
:: Runs: .venv\Scripts\python.exe -m pip install -r requirements.txt
:: Use after venv-create.cmd to install all project dependencies inside .venv.
::
:: Dependencies:
::   .venv            - created by venv-create.cmd
::   requirements.txt - must exist in the current directory
::
:: Usage:
::   venv-req-install.cmd
::
:: Examples:
::   venv-req-install.cmd
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
