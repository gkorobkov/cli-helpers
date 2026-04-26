@echo off
:: create-venv.cmd — Creates a local Python virtual environment in .venv.
::
:: Runs: python -m venv .venv
:: Creates a new virtual environment in the current directory.
:: Run install-req-venv.cmd next to install dependencies.
::
:: Dependencies:
::   Python 3 - https://www.python.org/downloads/
::              Windows: winget install Python.Python.3
::
:: Usage:
::   create-venv.cmd
::
:: Examples:
::   create-venv.cmd
python -m venv .venv
