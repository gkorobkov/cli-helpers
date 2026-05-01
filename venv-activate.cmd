@echo off
REM venv-activate.cmd — Activates the local Python virtual environment.
REM Runs .venv\Scripts\activate.bat in the current directory.
REM Use after the virtual environment has been created with venv-create.cmd.
REM Dependencies:
REM   Python 3  - https://www.python.org/downloads/
REM               Windows: winget install Python.Python.3
REM   .venv     - virtual environment folder, create first with venv-create.cmd
REM Usage:
REM   venv-activate.cmd
REM Examples:
REM   venv-activate.cmd
.venv\Scripts\activate.bat
