@echo off
:: py-jupyter-run.cmd — Starts Jupyter Notebook in the current directory.
::
:: Runs: start jupyter notebook --notebook-dir %cd%
:: Opens in a separate window and returns to the prompt immediately.
::
:: Dependencies:
::   Python 3 - https://www.python.org/downloads/
::   Jupyter  - pip install notebook
::              or: conda install notebook
::
:: Usage:
::   py-jupyter-run.cmd
::
:: Examples:
::   py-jupyter-run.cmd
start jupyter notebook --notebook-dir %cd%
