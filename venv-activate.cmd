@echo off
:: venv-activate.cmd — Activates the local Python virtual environment.
::
:: Runs .venv\Scripts\activate.bat in the current directory.
:: Use after the virtual environment has been created with venv-create.cmd.
::
:: Dependencies:
::   Python 3  - https://www.python.org/downloads/
::               Windows: winget install Python.Python.3
::   .venv     - virtual environment folder, create first with venv-create.cmd
::
:: Usage:
::   venv-activate.cmd
::
:: Examples:
::   venv-activate.cmd
.venv\Scripts\activate.bat
