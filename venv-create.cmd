@echo off
:: venv-create.cmd — Creates a local Python virtual environment in .venv.
::
:: Runs: python -m venv .venv
:: Creates a new virtual environment in the current directory.
:: Run venv-req-install.cmd next to install dependencies.
::
:: Dependencies:
::   Python 3 - https://www.python.org/downloads/
::              Windows: winget install Python.Python.3
::
:: Usage:
::   venv-create.cmd
::
:: Examples:
::   venv-create.cmd
python -m venv .venv
