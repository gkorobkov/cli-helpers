@echo off
:: qudo-run-ui.cmd — Starts Qodo in UI mode.
::
:: Runs: start qodo --ui
::
:: Dependencies:
::   Node.js - https://nodejs.org/
::             Windows: winget install OpenJS.NodeJS
::   Qodo    - npm install -g @qodo/command
::             Login: qodo login
::             Docs: https://docs.qodo.ai/qodo-documentation/qodo-command/getting-started/setup-and-quickstart
::
:: Usage:
::   qudo-run-ui.cmd
::
:: Examples:
::   qudo-run-ui.cmd
start qodo --ui
