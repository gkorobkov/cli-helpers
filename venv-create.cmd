@echo off
REM venv-create.cmd — Creates a local Python virtual environment in .venv.
REM Runs: python -m venv .venv
REM Creates a new virtual environment in the current directory.
REM Run venv-req-install.cmd next to install dependencies.
REM Dependencies:
REM   Python 3 - https://www.python.org/downloads/
REM              Windows: winget install Python.Python.3
REM Usage:
REM   venv-create.cmd
REM Examples:
REM   venv-create.cmd
python -m venv .venv
