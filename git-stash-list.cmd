@echo off

REM Git stash list script
REM Lists all stashes with additional details

echo Git Stash List
echo ==============
echo.

REM Get the list of stashes
git stash list
for /f "tokens=1 delims=:" %%i in ('git stash list') do (
    echo === %%i ===
    git stash show  %%i 
    echo.
    rem TODO: add simplified output for the stash
    echo.
)

echo.
echo Stash listing completed.
rem pause
