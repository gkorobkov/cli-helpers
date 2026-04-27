# =============================================================
# md-toc-update.ps1 — Creates or updates TOC in Markdown files.
#
# Finds a TOC marker heading and replaces the block below it
# (up to the next heading) with auto-generated anchor links.
# If no TOC marker is found, inserts "# Table of contents" at the top.
# Recognized markers: Оглавление, Оглавлние, TOC, Table of contents, Contents.
#
# Without file arguments: scans for *.md files, shows TOC status per file,
# and prints ready-to-run example commands — nothing is written.
#
# Key functions:
#   Write-Log          : Outputs an indented log line.
#   Show-MdList        : Lists MD files with TOC status and example commands.
#   Show-Usage         : Prints usage.
#   Get-MarkdownLines  : Reads a file, normalizes line endings and strips BOM.
#   Get-Headings       : Extracts headings while skipping fenced code blocks.
#   Get-Slug           : Generates a GitHub-style anchor slug from heading text.
#   Build-TocLines     : Produces the list of TOC bullet lines.
#   Find-TocRange      : Locates the start/end line indices of the TOC block.
#   Update-File        : Orchestrates read -> generate -> write for one file.
#   Resolve-Targets    : Resolves the list of files to process.
#   Resolve-TocLimits  : Parses --hN flag into min/max level ints.
#
# Dependencies:
#   PowerShell 5.1+ - built-in on Windows 10/11 (no install needed)
#
# Usage:
#   .\md-toc-update.ps1 [-Files <string[]>] [-DryRun] [-HN <string>] [-Help]
#   .\md-toc-update.ps1              (no -Files) List MD files and show commands
#
# Parameters:
#   -Files <string[]> : Optional. Markdown files to process.
#   -DryRun           : Optional. Show changes without writing.
#   -HN hN            : Optional. Limit entries to H1-HN (e.g. h2, h3).
#   -Help             : Optional. Print usage.
#   -FromCmdWrapper   : Internal. Used by md-toc-update.cmd.
#
# Examples:
#   .\md-toc-update.ps1
#   .\md-toc-update.ps1 -Files README.md
#   .\md-toc-update.ps1 -Files README.md -DryRun -HN h3
# =============================================================
param(
    [string[]]$Files = @(),
    [switch]$DryRun,
    [string]$HN,
    [switch]$Help,
    [switch]$FromCmdWrapper
)

$ErrorActionPreference = "Stop"

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$TOC_START_HEADING_TEXTS = @(
    (-join [char[]](0x041E, 0x0433, 0x043B, 0x0430, 0x0432, 0x043B, 0x0435, 0x043D, 0x0438, 0x0435)),
    (-join [char[]](0x041E, 0x0433, 0x043B, 0x0430, 0x0432, 0x043B, 0x043D, 0x0438, 0x0435)),
    "TOC",
    "Table of contents",
    "Contents"
)
$AUTO_INSERT_HEADING = "# Table of contents"
$TARGET_FILE_GLOBS = @("*.md")
$TOC_MIN_LEVEL = 1
$TOC_MAX_LEVEL = 6
$TOC_BULLET = "-"
$TOC_INDENT = "  "

$HEADING_RE = '^(#{1,6})\s+(.*?)\s*$'
$FENCE_RE = '^\s*(```|~~~)'
$UTF8_NO_BOM = [System.Text.UTF8Encoding]::new($false)

function Write-Log {
    param([string]$Message)
    Write-Output "  $Message"
}

function Show-Usage {
    Write-Output "Usage: md-toc-update.cmd [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--hN] [--help]"
    Write-Output "       md-toc-update.sh  [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--hN]"
    Write-Output ""
    Write-Output "  --hN    Limit TOC depth to H1-HN. Examples: --h2, --h3, --h4"
    Write-Output ""
    Write-Output "Without file arguments: scans current directory and shows example commands."
}

function Clean-HeadingText {
    param([string]$RawText)
    return ([regex]::Replace($RawText, '\s+#+\s*$', '')).Trim()
}

function Test-IsTocHeadingMarker {
    param([string]$Text)
    foreach ($marker in $TOC_START_HEADING_TEXTS) {
        if ($marker -ieq $Text) { return $true }
    }
    return $false
}

function Get-MarkdownLines {
    param([string]$Path)

    $sourceText = [System.IO.File]::ReadAllText($Path, $UTF8_NO_BOM)
    if ($sourceText.Length -gt 0 -and $sourceText[0] -eq [char]0xFEFF) {
        $sourceText = $sourceText.Substring(1)
    }
    $lineBreak = if ($sourceText.Contains("`r`n")) { "`r`n" } else { "`n" }
    $endsWithNewline = $sourceText.EndsWith("`n")
    $lines = @()
    if ($sourceText.Length -gt 0) {
        $lines = $sourceText -split '\r?\n'
        if ($endsWithNewline -and $lines.Count -gt 0 -and $lines[-1] -eq "") {
            $lines = $lines[0..($lines.Count - 2)]
        }
    }

    return @{
        SourceText      = $sourceText
        LineBreak       = $lineBreak
        EndsWithNewline = $endsWithNewline
        Lines           = [string[]]$lines
    }
}

function Get-Headings {
    param(
        [string[]]$Lines,
        [int]$Start = 0
    )

    $result = New-Object System.Collections.Generic.List[object]
    $inFence = $false

    for ($index = $Start; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        if ($line -match $FENCE_RE) { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($line -match $HEADING_RE) {
            $level = $matches[1].Length
            $text = Clean-HeadingText $matches[2]
            if ($text) {
                $result.Add([pscustomobject]@{ Index = $index; Level = $level; Text = $text })
            }
        }
    }

    return $result
}

function Get-Slug {
    param([string]$Text)

    $normalized = $Text.Trim().ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '[^\w\s-]', '')
    $normalized = [regex]::Replace($normalized, '[-\s]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($normalized)) { return "section" }
    return $normalized
}

function Resolve-TocLimits {
    param([AllowNull()][string]$HN)

    $minLevel = $TOC_MIN_LEVEL
    $maxLevel = $TOC_MAX_LEVEL

    if (-not [string]::IsNullOrWhiteSpace($HN)) {
        $match = [regex]::Match($HN.Trim(), '^[hH]([1-6])$')
        if (-not $match.Success) {
            throw "--hN must be in format hN where N is 1..6 (example: --h3)"
        }
        $minLevel = 1
        $maxLevel = [int]$match.Groups[1].Value
    }

    if ($maxLevel -lt $minLevel) { $maxLevel = $minLevel }

    return @{ MinLevel = $minLevel; MaxLevel = $maxLevel }
}

function Build-TocLines {
    param(
        [object[]]$Headings,
        [int]$MinLevel,
        [int]$MaxLevel
    )

    if (-not $Headings -or $Headings.Count -eq 0) { return [string[]]@() }

    $included = @($Headings | Where-Object { $_.Level -ge $MinLevel -and $_.Level -le $MaxLevel })
    if ($included.Count -eq 0) { return [string[]]@() }

    $baseLevel = ($included | Measure-Object -Property Level -Minimum).Minimum
    $slugCounts = @{}
    $tocLines = New-Object System.Collections.Generic.List[string]

    foreach ($heading in $included) {
        $baseSlug = Get-Slug $heading.Text
        $count = 0
        if ($slugCounts.ContainsKey($baseSlug)) { $count = [int]$slugCounts[$baseSlug] }
        $slugCounts[$baseSlug] = $count + 1
        $slug = if ($count -eq 0) { $baseSlug } else { "$baseSlug-$($count + 1)" }

        $indentLevel = [Math]::Max(0, $heading.Level - $baseLevel)
        $indent = $TOC_INDENT * $indentLevel
        $tocLines.Add("$indent$TOC_BULLET [$($heading.Text)](#$slug)")
    }

    return [string[]]$tocLines
}

function Find-TocRange {
    param([string[]]$Lines)

    $startIndex = $null
    $headings = Get-Headings -Lines $Lines
    foreach ($heading in $headings) {
        if (Test-IsTocHeadingMarker -Text $heading.Text) {
            $startIndex = $heading.Index
            break
        }
    }

    if ($null -eq $startIndex) { return $null }

    $nextHeadings = @(Get-Headings -Lines $Lines -Start ($startIndex + 1))
    if ($nextHeadings.Count -gt 0) {
        return @{ Start = $startIndex; End = $nextHeadings[0].Index }
    }

    return @{ Start = $startIndex; End = $Lines.Count }
}

function Update-File {
    param(
        [string]$Path,
        [bool]$DryRun,
        [AllowNull()][string]$HN
    )

    Write-Log "Reading file..."
    $content = Get-MarkdownLines -Path $Path
    $lines = $content.Lines
    Write-Log "File has $($lines.Count) lines"

    Write-Log "Searching for TOC marker heading..."
    $tocRange = Find-TocRange -Lines $lines

    $limits = Resolve-TocLimits -HN $HN

    if ($null -eq $tocRange) {
        Write-Log "No TOC marker found"
        $allHeadings = @(Get-Headings -Lines $lines)
        if ($allHeadings.Count -eq 0) {
            Write-Log "No headings found - skipping"
            return [pscustomobject]@{
                Changed       = $false
                Status        = "no headings"
                TocHeadingLine = $null
                TocLines      = [string[]]@()
            }
        }

        Write-Log "Inserting '$AUTO_INSERT_HEADING' at top"
        $sourceHeadings = @($allHeadings | ForEach-Object {
            [pscustomobject]@{ Level = $_.Level; Text = $_.Text }
        })
        Write-Log "Found $($sourceHeadings.Count) heading(s), generating TOC entries (H1-H$($limits.MaxLevel))..."
        $tocLines = Build-TocLines -Headings $sourceHeadings -MinLevel $limits.MinLevel -MaxLevel $limits.MaxLevel
        Write-Log "Generated $($tocLines.Count) TOC entry/entries"

        $newLines = New-Object System.Collections.Generic.List[string]
        $newLines.Add($AUTO_INSERT_HEADING)
        $newLines.Add("")
        foreach ($line in $tocLines) { $newLines.Add($line) }
        $newLines.Add("")
        foreach ($line in $lines) { $newLines.Add($line) }

        $newText = [string]::Join("`n", $newLines)
        if ($content.EndsWithNewline) { $newText += "`n" }

        if (-not $DryRun) {
            Write-Log "Writing file..."
            [System.IO.File]::WriteAllText($Path, $newText, $UTF8_NO_BOM)
        }

        return [pscustomobject]@{
            Changed       = $true
            Status        = "toc inserted"
            TocHeadingLine = $AUTO_INSERT_HEADING
            TocLines      = $tocLines
        }
    }

    $tocStart = $tocRange.Start
    $tocEnd = $tocRange.End
    $tocHeadingLine = $lines[$tocStart].Trim()
    Write-Log "TOC marker found at line $($tocStart + 1): '$tocHeadingLine'"
    Write-Log "TOC block ends at line $($tocEnd + 1)"

    $sourceHeadings = @(
        Get-Headings -Lines $lines -Start $tocEnd |
            ForEach-Object { [pscustomobject]@{ Level = $_.Level; Text = $_.Text } }
    )
    Write-Log "Found $($sourceHeadings.Count) heading(s) after TOC block, generating entries (H1-H$($limits.MaxLevel))..."
    $tocLines = Build-TocLines -Headings $sourceHeadings -MinLevel $limits.MinLevel -MaxLevel $limits.MaxLevel
    Write-Log "Generated $($tocLines.Count) TOC entry/entries"

    $newLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -le $tocStart; $i++) { $newLines.Add($lines[$i]) }
    $newLines.Add("")
    foreach ($line in $tocLines) { $newLines.Add($line) }
    $newLines.Add("")
    for ($i = $tocEnd; $i -lt $lines.Count; $i++) { $newLines.Add($lines[$i]) }

    $newText = [string]::Join("`n", $newLines)
    if ($content.EndsWithNewline) { $newText += "`n" }

    if ($newText -ceq $content.SourceText) {
        Write-Log "Content unchanged"
        return [pscustomobject]@{
            Changed       = $false
            Status        = "up to date"
            TocHeadingLine = $tocHeadingLine
            TocLines      = $tocLines
        }
    }

    if (-not $DryRun) {
        Write-Log "Writing file..."
        [System.IO.File]::WriteAllText($Path, $newText, $UTF8_NO_BOM)
    }

    return [pscustomobject]@{
        Changed       = $true
        Status        = "updated"
        TocHeadingLine = $tocHeadingLine
        TocLines      = $tocLines
    }
}

function Resolve-Targets {
    param([string[]]$Files)

    if ($Files.Count -gt 0) {
        foreach ($f in $Files) {
            if (-not (Test-Path $f -PathType Leaf)) {
                Write-Output "Error: file not found: $f"
                exit 2
            }
        }
        return [string[]]($Files | Sort-Object -Unique)
    }

    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $TARGET_FILE_GLOBS) {
        foreach ($item in Get-ChildItem -Path . -Filter $pattern -File) {
            $targets.Add($item.Name)
        }
    }

    return [string[]]($targets | Sort-Object -Unique)
}

function Show-MdList {
    param(
        [string[]]$Targets,
        [bool]$IsFromCmd
    )

    $scriptName = if ($IsFromCmd) { "md-toc-update.cmd" } else { ".\md-toc-update.ps1 -Files" }
    $actionable = New-Object System.Collections.Generic.List[string]

    Write-Output "Found $($Targets.Count) markdown file(s) in current directory:"
    Write-Output ""

    foreach ($path in $Targets) {
        $content = Get-MarkdownLines -Path $path
        $tocRange = Find-TocRange -Lines $content.Lines
        $headings = @(Get-Headings -Lines $content.Lines)

        if ($null -ne $tocRange) {
            $marker = $content.Lines[$tocRange.Start].Trim()
            Write-Output "  $path"
            Write-Output "    has TOC marker: $marker"
            $actionable.Add($path)
        } elseif ($headings.Count -gt 0) {
            Write-Output "  $path"
            Write-Output "    no TOC marker - '$AUTO_INSERT_HEADING' will be added at top"
            $actionable.Add($path)
        } else {
            Write-Output "  $path"
            Write-Output "    no headings - skipped"
        }
    }

    if ($actionable.Count -eq 0) {
        Write-Output ""
        Write-Output "No files to update."
        return
    }

    Write-Output ""
    Write-Output "To update TOC run:"
    foreach ($path in $actionable) {
        Write-Output "  $scriptName $path"
    }

    if ($actionable.Count -gt 1) {
        Write-Output ""
        Write-Output "To update all at once:"
        $allFiles = $actionable -join " "
        Write-Output "  $scriptName $allFiles"
    }
}

try {
    if ($Help) {
        Show-Usage
        exit 0
    }

    if ($FromCmdWrapper) {
        if ($env:UPDATE_MD_TOC_DRY_RUN -eq "1") { $DryRun = $true }
        if (-not [string]::IsNullOrWhiteSpace($env:UPDATE_MD_TOC_HN)) {
            $HN = $env:UPDATE_MD_TOC_HN
        }
        if (-not [string]::IsNullOrWhiteSpace($env:UPDATE_MD_TOC_FILES)) {
            $Files = @($env:UPDATE_MD_TOC_FILES -split '\|')
        }
    }

    [void](Resolve-TocLimits -HN $HN)

    $targets = Resolve-Targets -Files $Files
    if (-not $targets -or $targets.Count -eq 0) {
        Write-Output "No markdown files found."
        exit 1
    }

    # No file arguments: list mode — show status and example commands, do not write
    if ($Files.Count -eq 0) {
        Show-MdList -Targets $targets -IsFromCmd $FromCmdWrapper
        exit 0
    }

    $changedCount = 0
    foreach ($path in $targets) {
        Write-Output ""
        Write-Output "${path}:"
        $result = Update-File -Path $path -DryRun $DryRun -HN $HN
        if ($result.Changed) { $changedCount++ }

        $mode = if ($DryRun -and $result.Changed) { "would update" } else { $result.Status }
        Write-Log "Result: $mode"

        if ($result.Changed) {
            $tocLabel = if ($DryRun) { "preview" } else { "output" }
            Write-Output ""
            Write-Output "  --- TOC $tocLabel ---"
            $tocHeadingLine = $result.TocHeadingLine
            if ([string]::IsNullOrEmpty($tocHeadingLine)) { $tocHeadingLine = $AUTO_INSERT_HEADING }
            Write-Output "  $tocHeadingLine"
            Write-Output ""
            if ($result.TocLines.Count -gt 0) {
                foreach ($line in $result.TocLines) { Write-Output "  $line" }
            } else {
                Write-Output "  $TOC_BULLET (empty)"
            }
        }
    }

    Write-Output ""
    Write-Output "Done. changed=$changedCount, total=$($targets.Count)"
    exit 0
}
catch {
    Write-Output "Error: $($_.Exception.Message)"
    exit 2
}
