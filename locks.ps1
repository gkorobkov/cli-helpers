<#
locks.ps1 - Finds processes whose command lines reference a file or directory.
Optionally terminates all matching processes or selected PIDs.

Dependencies:
  Windows PowerShell 5.1+ or PowerShell 7+

Usage:
  .\locks.ps1 [path] [--kill] [--help]

Examples:
  .\locks.ps1
  .\locks.ps1 package.json
  .\locks.ps1 "C:\Projects\my-app"
  .\locks.ps1 --kill
  .\locks.ps1 "C:\Projects\my-app" --kill

Notes:
  Without a path, the current working directory is checked.

  Detection is based on process command lines containing the target path.

  Directory matching respects path boundaries. For example, a target
  C:\Projects\app matches C:\Projects\app\server.js, but does not match
  C:\Projects\application or C:\Projects\app-old.

  This is not a complete Windows file-handle scan. A process may still
  hold a file or directory handle even when the target path does not
  appear in its command line.
#>


# ----------------------------------------------------------------------
# Command-line arguments
# ----------------------------------------------------------------------

$targetArgument = $null
$killMode = $false
$showHelp = $false

foreach ($argument in $args) {

    switch -Regex ($argument) {

        '^--kill$' {
            $killMode = $true
            continue
        }

        '^--help$' {
            $showHelp = $true
            continue
        }

        '^--' {
            Write-Host ""
            Write-Host "ERROR: Unknown option: $argument" -ForegroundColor Red
            Write-Host "Run 'locks --help' for usage."
            exit 2
        }

        default {

            if ($null -ne $targetArgument) {
                Write-Host ""
                Write-Host "ERROR: More than one target path was specified." `
                    -ForegroundColor Red
                Write-Host "Run 'locks --help' for usage."
                exit 2
            }

            $targetArgument = $argument
        }
    }
}


# ----------------------------------------------------------------------
# Help
# ----------------------------------------------------------------------

function Show-Help {

    Write-Host @"

LOCKS - find processes referencing a file or directory

Usage:
  locks
  locks <path>
  locks --kill
  locks <path> --kill
  locks --help

Standalone PowerShell:
  .\locks.ps1
  .\locks.ps1 <path>
  .\locks.ps1 --kill
  .\locks.ps1 <path> --kill
  .\locks.ps1 --help

Parameters:
  <path>
      File or directory to check.
      Defaults to the current working directory.

  --kill
      Offer to terminate matching processes.

  --help
      Show this help.

Kill selection:
  y
      Terminate all listed processes.

  N or Enter
      Cancel without terminating processes.

  20532
      Terminate one listed PID.

  20532,23160
      Terminate selected listed PIDs.

Examples:
  locks
  locks package.json
  locks "C:\Projects\my-app"
  locks --kill
  locks "C:\Projects\my-app" --kill

Detection method:
  Process command lines are searched for the normalized target path.

  Directory boundaries are respected. For example:

      C:\Projects\app

  matches:

      C:\Projects\app\server.js

  but does not match:

      C:\Projects\application
      C:\Projects\app-old

Limitation:
  This is not a complete Windows file-handle scan.

  A process can hold a file or directory handle even when the target
  path does not appear in its command line. Therefore, an empty result
  does not guarantee that the resource is unlocked.

"@
}


if ($showHelp) {
    Show-Help
    exit 0
}


# ----------------------------------------------------------------------
# Resolve target path
# ----------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($targetArgument)) {

    $target = (Get-Location).Path
}
else {

    try {

        $resolvedPath = Resolve-Path `
            -LiteralPath $targetArgument `
            -ErrorAction Stop

        $target = $resolvedPath.Path
    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Path does not exist:" -ForegroundColor Red
        Write-Host "  $targetArgument"

        exit 2
    }
}


$target = [IO.Path]::GetFullPath($target)
$targetRoot = [IO.Path]::GetPathRoot($target)

# Remove the trailing backslash from normal paths, but preserve filesystem
# roots such as C:\.
if ($target -ne $targetRoot) {
    $target = $target.TrimEnd('\')
}

$targetNormalized =
    $target.Replace('/', '\').ToLowerInvariant()

$targetIsDirectory =
    Test-Path -LiteralPath $target -PathType Container


# ----------------------------------------------------------------------
# Path matching
# ----------------------------------------------------------------------

function Test-CommandLinePathMatch {

    param(
        [Parameter(Mandatory=$true)]
        [string]$CommandLine,

        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [bool]$IsDirectory
    )


    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $false
    }


    $commandLineNormalized =
        $CommandLine.Replace('/', '\').ToLowerInvariant()

    $targetNormalizedLocal =
        $Target.Replace('/', '\').ToLowerInvariant()

    $escapedTarget =
        [Regex]::Escape($targetNormalizedLocal)


    # A valid path may start:
    #
    #   - at the beginning of the command line
    #   - after whitespace
    #   - after a quote
    #   - after =, which covers arguments such as --cwd=C:\Projects\app
    #
    # For directories, a trailing "\" is also accepted so that:
    #
    #   C:\Projects\app
    #
    # matches:
    #
    #   C:\Projects\app\server.js
    #
    # but not:
    #
    #   C:\Projects\application
    #   C:\Projects\app-old

    $prefix = '(^|["''=\s])'

    if ($IsDirectory) {

        $suffix = '(?=$|["'';,)\s]|\\)'
    }
    else {

        $suffix = '(?=$|["'';,)\s])'
    }


    $pattern =
        $prefix +
        $escapedTarget +
        $suffix


    return [Regex]::IsMatch(
        $commandLineNormalized,
        $pattern,
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
}


# ----------------------------------------------------------------------
# Header
# ----------------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " LOCKS"
Write-Host "============================================================"
Write-Host " Target path : $target"

if ($targetIsDirectory) {
    Write-Host " Target type : directory"
}
else {
    Write-Host " Target type : file"
}

if ($killMode) {
    Write-Host " Kill mode   : enabled"
}
else {
    Write-Host " Kill mode   : disabled"
}

Write-Host " Method      : process CommandLine path match"
Write-Host "============================================================"
Write-Host ""


# ----------------------------------------------------------------------
# Read process information
# ----------------------------------------------------------------------

$allProcesses =
    @(Get-CimInstance Win32_Process)

$selfPid = $PID


# Find the PowerShell process that is executing this script.
$selfProcess =
    $allProcesses |
        Where-Object ProcessId -eq $selfPid |
        Select-Object -First 1


# When locks.ps1 is started through locks.cmd, its parent is the temporary
# cmd.exe process created to execute locks.cmd. Exclude that launcher so
# the helper does not report itself when it resides inside the target path.
$launcherPid = if ($selfProcess) {
    $selfProcess.ParentProcessId
}
else {
    $null
}


# ----------------------------------------------------------------------
# Find matching processes
# ----------------------------------------------------------------------

$foundProcesses = @()


foreach ($process in $allProcesses) {

    # Exclude this PowerShell process.
    if ($process.ProcessId -eq $selfPid) {
        continue
    }


    # Exclude cmd.exe that launched locks.cmd.
    if (
        $launcherPid -and
        $process.ProcessId -eq $launcherPid
    ) {
        continue
    }


    if ([string]::IsNullOrWhiteSpace($process.CommandLine)) {
        continue
    }


    $matchesTarget =
        Test-CommandLinePathMatch `
            -CommandLine $process.CommandLine `
            -Target $target `
            -IsDirectory $targetIsDirectory


    if (-not $matchesTarget) {
        continue
    }


    $parent =
        $allProcesses |
            Where-Object ProcessId -eq $process.ParentProcessId |
            Select-Object -First 1


    $parentName = if ($parent) {
        $parent.Name
    }
    else {
        ""
    }


    $foundProcesses += [PSCustomObject]@{

        PID         = [int]$process.ProcessId
        PPID        = [int]$process.ParentProcessId
        Process     = $process.Name
        Parent      = $parentName
        CommandLine = $process.CommandLine
    }
}


$foundProcesses = @(
    $foundProcesses |
        Sort-Object PID -Unique
)


# ----------------------------------------------------------------------
# Nothing found
# ----------------------------------------------------------------------

if ($foundProcesses.Count -eq 0) {

    Write-Host `
        "No processes referencing this path were found." `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "NOTE:"
    Write-Host "A process may still hold a file or directory handle without"
    Write-Host "the target path appearing in its command line."
    Write-Host ""

    exit 0
}


# ----------------------------------------------------------------------
# Display results
# ----------------------------------------------------------------------

Write-Host `
    "Found: $($foundProcesses.Count) process(es)" `
    -ForegroundColor Yellow

Write-Host ""


foreach ($process in $foundProcesses) {

    Write-Host "------------------------------------------------------------"
    Write-Host "PID         : $($process.PID)"
    Write-Host "PPID        : $($process.PPID)"
    Write-Host "Process     : $($process.Process)"
    Write-Host "Parent      : $($process.Parent)"
    Write-Host "CommandLine : $($process.CommandLine)"
}


Write-Host "------------------------------------------------------------"
Write-Host ""


# ----------------------------------------------------------------------
# No termination requested
# ----------------------------------------------------------------------

if (-not $killMode) {

    Write-Host "To terminate matching processes, run:"
    Write-Host ""


    if ([string]::IsNullOrWhiteSpace($targetArgument)) {

        Write-Host "  locks --kill"
    }
    else {

        Write-Host "  locks `"$target`" --kill"
    }


    Write-Host ""

    exit 0
}


# ----------------------------------------------------------------------
# Termination selection
# ----------------------------------------------------------------------

Write-Host `
    "Terminate processes? [y/N/PID]" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "  y           = terminate ALL listed processes"
Write-Host "  N / Enter   = cancel"


$firstPid =
    $foundProcesses[0].PID

Write-Host "  $firstPid       = terminate one PID"


if ($foundProcesses.Count -gt 1) {

    $secondPid =
        $foundProcesses[1].PID

    Write-Host `
        "  $firstPid,$secondPid = terminate selected PIDs"
}


Write-Host ""


$answer =
    (Read-Host "Selection").Trim()


# ----------------------------------------------------------------------
# Cancel
# ----------------------------------------------------------------------

if (
    [string]::IsNullOrWhiteSpace($answer) -or
    $answer -match '^(n|no)$'
) {

    Write-Host ""
    Write-Host "No processes terminated."

    exit 0
}


# ----------------------------------------------------------------------
# Select all
# ----------------------------------------------------------------------

if ($answer -match '^(y|yes)$') {

    $selectedProcesses =
        @($foundProcesses)
}


# ----------------------------------------------------------------------
# Select individual PIDs
# ----------------------------------------------------------------------

else {

    $ids = @()
    $invalidValues = @()


    foreach ($part in ($answer -split '[,; ]+')) {

        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }


        $parsedPid = 0


        if ([int]::TryParse($part, [ref]$parsedPid)) {

            $ids += $parsedPid
        }
        else {

            $invalidValues += $part
        }
    }


    if ($invalidValues.Count -gt 0) {

        Write-Host ""
        Write-Host `
            "ERROR: Invalid selection:" `
            -ForegroundColor Red

        Write-Host `
            "  $($invalidValues -join ', ')"

        exit 3
    }


    $ids =
        @(
            $ids |
                Sort-Object -Unique
        )


    $unknownIds =
        @(
            $ids |
                Where-Object {
                    $foundProcesses.PID -notcontains $_
                }
        )


    if ($unknownIds.Count -gt 0) {

        Write-Host ""
        Write-Host `
            "ERROR: PID not in the found process list:" `
            -ForegroundColor Red

        Write-Host `
            "  $($unknownIds -join ', ')"

        exit 3
    }


    $selectedProcesses =
        @(
            $foundProcesses |
                Where-Object {
                    $ids -contains $_.PID
                }
        )
}


# ----------------------------------------------------------------------
# Nothing selected
# ----------------------------------------------------------------------

if ($selectedProcesses.Count -eq 0) {

    Write-Host ""
    Write-Host "No processes selected."

    exit 0
}


# ----------------------------------------------------------------------
# Terminate selected processes
# ----------------------------------------------------------------------

Write-Host ""


$terminatedCount = 0
$failedCount = 0


foreach ($process in $selectedProcesses) {

    Write-Host `
        -NoNewline `
        "Terminating PID $($process.PID) ($($process.Process))... "


    try {

        Stop-Process `
            -Id $process.PID `
            -ErrorAction Stop


        Start-Sleep -Milliseconds 300


        if (
            Get-Process `
                -Id $process.PID `
                -ErrorAction SilentlyContinue
        ) {

            Write-Host "FAILED" -ForegroundColor Red

            $failedCount++
        }
        else {

            Write-Host "OK" -ForegroundColor Green

            $terminatedCount++
        }
    }
    catch {

        Write-Host "FAILED" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)"

        $failedCount++
    }
}


# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " Terminated : $terminatedCount"
Write-Host " Failed     : $failedCount"
Write-Host "============================================================"
Write-Host ""


if ($failedCount -gt 0) {
    exit 1
}


exit 0