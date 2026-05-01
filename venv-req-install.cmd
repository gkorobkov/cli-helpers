@echo off
REM venv-req-install.cmd — Installs Python requirements into the local .venv.
REM Runs: .venv\Scripts\python.exe -m pip install -r requirements.txt
REM Use after venv-create.cmd to install all project dependencies inside .venv.
REM Dependencies:
REM   .venv            - created by venv-create.cmd
REM   requirements.txt - must exist in the current directory
REM Usage:
REM   venv-req-install.cmd
REM Examples:
REM   venv-req-install.cmd
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
