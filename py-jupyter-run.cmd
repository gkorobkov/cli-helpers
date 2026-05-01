@echo off
REM py-jupyter-run.cmd — Starts Jupyter Notebook in the current directory.
REM Runs: start jupyter notebook --notebook-dir %cd%
REM Opens in a separate window and returns to the prompt immediately.
REM Dependencies:
REM   Python 3 - https://www.python.org/downloads/
REM   Jupyter  - pip install notebook
REM              or: conda install notebook
REM Usage:
REM   py-jupyter-run.cmd
REM Examples:
REM   py-jupyter-run.cmd
start jupyter notebook --notebook-dir %cd%
