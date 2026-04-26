@ECHO OFF
:: git-setup.cmd — Shows or updates global Git user name and email.
::
:: Shows current git config user.name and user.email.
:: If arguments are passed, updates the corresponding global Git config values first.
::
:: Dependencies:
::   git - https://git-scm.com/downloads
::         Windows: winget install Git.Git
::
:: Usage:
::   git-setup.cmd [user_name] [user_email]
::
:: Parameters:
::   user_name  : Optional. Git user name.
::   user_email : Optional. Git user email.
::
:: Examples:
::   git-setup.cmd
::   git-setup.cmd "User Name" user@example.com
setlocal

set git_user_name=%~1
set git_user_email=%~2

if defined git_user_name (
  call git config --global user.name "%git_user_name%"
)

if defined git_user_email (
  call git config --global user.email "%git_user_email%"
)

if not defined git_user_name (
  FOR /F "usebackq delims=" %%a in (`git config --global --get user.name 2^>nul`) do SET git_user_name=%%a
)

if not defined git_user_email (
  FOR /F "usebackq delims=" %%a in (`git config --global --get user.email 2^>nul`) do SET git_user_email=%%a
)

if not defined git_user_name goto noUserName
if not defined git_user_email goto noUserEmail

echo.
echo ********************************************************************************
echo * Git user settings:
echo *   user.name  = %git_user_name%
echo *   user.email = %git_user_email%
echo ********************************************************************************

goto EOF

:noUserName
echo ERROR: git user.name is not set.
echo.
echo Usage:
echo   git-setup.cmd "User Name" user@example.com
echo.
echo Or configure it manually:
echo   git config --global user.name "User Name"
goto EOF

:noUserEmail
echo ERROR: git user.email is not set.
echo.
echo Usage:
echo   git-setup.cmd "User Name" user@example.com
echo.
echo Or configure it manually:
echo   git config --global user.email user@example.com
goto EOF

:EOF
endlocal
