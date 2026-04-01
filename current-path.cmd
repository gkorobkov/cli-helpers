@echo off
rem Usage: current-path.cmd [list^|add^|delete]
rem No parameter: print YES if the current directory is in the current PATH, otherwise NO.
rem list        : print the current PATH entries line by line.
rem add         : add the current directory to the user PATH if it is missing.
rem delete      : remove the current directory from the user PATH if it is present.
rem Note        : add/delete also update the current cmd.exe session. PowerShell keeps its own PATH snapshot.
rem Output      : always prints the current directory first so it is clear which path is being checked.

set "mode=%~1"
if not defined mode set "mode=check"

if /I "%mode%"=="check" goto run
if /I "%mode%"=="list" goto run
if /I "%mode%"=="add" goto run
if /I "%mode%"=="delete" goto run
goto usage

:run
set "target_path=%CD%"
for %%I in ("%target_path%") do set "target_path=%%~fI"
echo Current path:
echo   %target_path%
set "CURRENT_PATH_MODE=%mode%"
set "CURRENT_PATH_TARGET=%target_path%"
set "status="
set "process_path="

if /I "%mode%"=="list" (
  echo PATH entries from the current cmd.exe session ^(process PATH^):
)

for /f "usebackq tokens=1,* delims=:" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$mode = $env:CURRENT_PATH_MODE;" ^
  "$target = [System.IO.Path]::GetFullPath($env:CURRENT_PATH_TARGET);" ^
  "function Normalize([string]$pathValue) {" ^
  "  if ([string]::IsNullOrWhiteSpace($pathValue)) { return $null };" ^
  "  try { $fullPath = [System.IO.Path]::GetFullPath($pathValue.Trim()) } catch { $fullPath = $pathValue.Trim() };" ^
  "  if ($fullPath.Length -gt 3) { return $fullPath.TrimEnd('\') };" ^
  "  return $fullPath;" ^
  "};" ^
  "function SplitPathList([string]$pathList) {" ^
  "  $entries = New-Object System.Collections.Generic.List[string];" ^
  "  if ([string]::IsNullOrWhiteSpace($pathList)) { return ,$entries.ToArray() };" ^
  "  foreach ($entry in ($pathList -split ';')) {" ^
  "    if ([string]::IsNullOrWhiteSpace($entry)) { continue };" ^
  "    $entries.Add($entry.Trim());" ^
  "  };" ^
  "  return ,$entries.ToArray();" ^
  "};" ^
  "function ContainsPath([string[]]$entries, [string]$needle) {" ^
  "  foreach ($entry in $entries) {" ^
  "    $normalizedEntry = Normalize $entry;" ^
  "    if ($normalizedEntry -and $normalizedEntry -ieq $needle) { return $true };" ^
  "  };" ^
  "  return $false;" ^
  "};" ^
  "function RemovePath([string[]]$entries, [string]$needle) {" ^
  "  $newEntries = New-Object System.Collections.Generic.List[string];" ^
  "  foreach ($entry in $entries) {" ^
  "    $normalizedEntry = Normalize $entry;" ^
  "    if (-not ($normalizedEntry -and $normalizedEntry -ieq $needle)) { $newEntries.Add($entry.Trim()) };" ^
  "  };" ^
  "  return ,$newEntries.ToArray();" ^
  "};" ^
  "$targetNormalized = Normalize $target;" ^
  "$processEntries = SplitPathList([Environment]::GetEnvironmentVariable('Path', 'Process'));" ^
  "$userEntries = SplitPathList([Environment]::GetEnvironmentVariable('Path', 'User'));" ^
  "switch ($mode) {" ^
  "  'check' {" ^
  "    if (ContainsPath $processEntries $targetNormalized) { 'STATUS:PRESENT'; exit 0 };" ^
  "    'STATUS:ABSENT'; exit 1;" ^
  "  };" ^
  "  'list' {" ^
  "    'STATUS:LIST';" ^
  "    foreach ($entry in $processEntries) { 'ITEM:' + $entry };" ^
  "    exit 0;" ^
  "  };" ^
  "  'add' {" ^
  "    $userHasTarget = ContainsPath $userEntries $targetNormalized;" ^
  "    if (-not $userHasTarget) {" ^
  "      $newUserEntries = New-Object System.Collections.Generic.List[string];" ^
  "      foreach ($entry in $userEntries) { $newUserEntries.Add($entry) };" ^
  "      $newUserEntries.Add($target);" ^
  "      [Environment]::SetEnvironmentVariable('Path', ($newUserEntries.ToArray() -join ';'), 'User');" ^
  "    };" ^
  "    if (ContainsPath $processEntries $targetNormalized) { $newProcessEntries = $processEntries } else { $newProcessEntries = @($target) + $processEntries };" ^
  "    if ($userHasTarget) { 'STATUS:ALREADY_SAVED' } else { 'STATUS:ADDED' };" ^
  "    'PROCESS_PATH:' + ($newProcessEntries -join ';');" ^
  "    exit 0;" ^
  "  };" ^
  "  'delete' {" ^
  "    $newUserEntries = RemovePath $userEntries $targetNormalized;" ^
  "    $userChanged = $newUserEntries.Count -ne $userEntries.Count;" ^
  "    if ($userChanged) { [Environment]::SetEnvironmentVariable('Path', ($newUserEntries -join ';'), 'User') };" ^
  "    $newProcessEntries = RemovePath $processEntries $targetNormalized;" ^
  "    $processChanged = $newProcessEntries.Count -ne $processEntries.Count;" ^
  "    if ($userChanged -or $processChanged) { 'STATUS:DELETED' } else { 'STATUS:NOT_FOUND' };" ^
  "    'PROCESS_PATH:' + ($newProcessEntries -join ';');" ^
  "    exit 0;" ^
  "  };" ^
  "  default {" ^
  "    'STATUS:INVALID';" ^
  "    exit 2;" ^
  "  };" ^
  "};"`) do (
  if /I "%%A"=="STATUS" set "status=%%B"
  if /I "%%A"=="PROCESS_PATH" set "process_path=%%B"
  if /I "%mode%"=="list" if /I "%%A"=="ITEM" echo %%B
)

if /I "%mode%"=="list" goto :EOF

if /I "%mode%"=="check" (
  if /I "%status%"=="PRESENT" (
    echo YES
    goto :EOF
  )
  if /I "%status%"=="ABSENT" (
    echo NO
    exit /b 1
  )
  goto error
)

if defined process_path set "PATH=%process_path%"

if /I "%mode%"=="add" (
  if /I "%status%"=="ADDED" (
    echo Added current directory to PATH:
    echo   %target_path%
    echo Saved in the user PATH and updated the current cmd.exe session.
    goto :EOF
  )
  if /I "%status%"=="ALREADY_SAVED" (
    echo Current directory is already saved in PATH:
    echo   %target_path%
    echo The current cmd.exe session was synchronized as well.
    goto :EOF
  )
  goto error
)

if /I "%mode%"=="delete" (
  if /I "%status%"=="DELETED" (
    echo Removed current directory from PATH where it was found:
    echo   %target_path%
    goto :EOF
  )
  if /I "%status%"=="NOT_FOUND" (
    echo Current directory was not found in PATH:
    echo   %target_path%
    exit /b 1
  )
  goto error
)

:usage
echo Usage:
echo   current-path.cmd
echo   current-path.cmd list
echo   current-path.cmd add
echo   current-path.cmd delete
exit /b 2

:error
echo ERROR: Failed to process PATH for:
echo   %target_path%
exit /b 1
