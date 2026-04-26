@echo off
:: activate-venv.cmd — Activates the local Python virtual environment.
::
:: Runs .venv\Scripts\activate.bat in the current directory.
:: Use after the virtual environment has been created with create-venv.cmd.
::
:: Dependencies:
::   Python 3  - https://www.python.org/downloads/
::               Windows: winget install Python.Python.3
::   .venv     - virtual environment folder, create first with create-venv.cmd
::
:: Usage:
::   activate-venv.cmd
::
:: Examples:
::   activate-venv.cmd
.venv\Scripts\activate.bat
