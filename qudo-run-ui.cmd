@echo off
REM qudo-run-ui.cmd — Starts Qodo in UI mode.
REM Runs: start qodo --ui
REM Dependencies:
REM   Node.js - https://nodejs.org/
REM             Windows: winget install OpenJS.NodeJS
REM   Qodo    - npm install -g @qodo/command
REM             Login: qodo login
REM             Docs: https://docs.qodo.ai/qodo-documentation/qodo-command/getting-started/setup-and-quickstart
REM Usage:
REM   qudo-run-ui.cmd
REM Examples:
REM   qudo-run-ui.cmd
start qodo --ui
