param(
    [string[]]$Files = @(),
    [switch]$DryRun,
    [string]$TocDepth,
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
    "Table of contents"
)
$TOC_START_HEADING_TEXT = $TOC_START_HEADING_TEXTS[0]
$TARGET_FILE_GLOBS = @("*.md")
$TOC_MIN_LEVEL = 1
$TOC_MAX_LEVEL = 6
$TOC_BULLET = "-"
$TOC_INDENT = "  "

$HEADING_RE = '^(#{1,6})\s+(.*?)\s*$'
$FENCE_RE = '^\s*(```|~~~)'
$UTF8_NO_BOM = [System.Text.UTF8Encoding]::new($false)

function Show-Usage {
    Write-Output "Usage: update_md_toc.cmd [--files FILE [FILE ...]] [--dry-run] [--toc-depth hN]"
}

function Clean-HeadingText {
    param([string]$RawText)

    return ([regex]::Replace($RawText, '\s+#+\s*$', '')).Trim()
}

function Test-IsTocHeadingMarker {
    param([string]$Text)

    foreach ($marker in $TOC_START_HEADING_TEXTS) {
        if ($marker -ieq $Text) {
            return $true
        }
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
        SourceText = $sourceText
        LineBreak = $lineBreak
        EndsWithNewline = $endsWithNewline
        Lines = [string[]]$lines
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
        if ($line -match $FENCE_RE) {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) {
            continue
        }
        if ($line -match $HEADING_RE) {
            $level = $matches[1].Length
            $text = Clean-HeadingText $matches[2]
            if ($text) {
                $result.Add([pscustomobject]@{
                    Index = $index
                    Level = $level
                    Text = $text
                })
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
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return "section"
    }
    return $normalized
}

function Resolve-TocLimits {
    param([AllowNull()][string]$TocDepth)

    $minLevel = $TOC_MIN_LEVEL
    $maxLevel = $TOC_MAX_LEVEL

    if (-not [string]::IsNullOrWhiteSpace($TocDepth)) {
        $match = [regex]::Match($TocDepth.Trim(), '^[hH]([1-6])$')
        if (-not $match.Success) {
            throw "--toc-depth must be in format hN, where N is 1..6 (example: h2)"
        }
        $minLevel = 1
        $maxLevel = [int]$match.Groups[1].Value
    }

    if ($maxLevel -lt $minLevel) {
        $maxLevel = $minLevel
    }

    return @{
        MinLevel = $minLevel
        MaxLevel = $maxLevel
    }
}

function Build-TocLines {
    param(
        [object[]]$Headings,
        [int]$MinLevel,
        [int]$MaxLevel
    )

    if (-not $Headings -or $Headings.Count -eq 0) {
        return [string[]]@()
    }

    $included = @($Headings | Where-Object { $_.Level -ge $MinLevel -and $_.Level -le $MaxLevel })
    if ($included.Count -eq 0) {
        return [string[]]@()
    }

    $baseLevel = ($included | Measure-Object -Property Level -Minimum).Minimum
    $slugCounts = @{}
    $tocLines = New-Object System.Collections.Generic.List[string]

    foreach ($heading in $included) {
        $baseSlug = Get-Slug $heading.Text
        $count = 0
        if ($slugCounts.ContainsKey($baseSlug)) {
            $count = [int]$slugCounts[$baseSlug]
        }
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

    if ($null -eq $startIndex) {
        return $null
    }

    # Force array semantics here. When PowerShell receives exactly one heading,
    # it unwraps the function output into a scalar object and .Count becomes unreliable.
    $nextHeadings = @(Get-Headings -Lines $Lines -Start ($startIndex + 1))
    if ($nextHeadings.Count -gt 0) {
        return @{
            Start = $startIndex
            End = $nextHeadings[0].Index
        }
    }

    return @{
        Start = $startIndex
        End = $Lines.Count
    }
}

function Update-File {
    param(
        [string]$Path,
        [bool]$DryRun,
        [AllowNull()][string]$TocDepth
    )

    $content = Get-MarkdownLines -Path $Path
    $lines = $content.Lines
    $tocRange = Find-TocRange -Lines $lines

    if ($null -eq $tocRange) {
        return [pscustomobject]@{
            Changed = $false
            Status = "marker not found"
            TocHeadingLine = $null
            TocLines = [string[]]@()
        }
    }

    $tocStart = $tocRange.Start
    $tocEnd = $tocRange.End
    $tocHeadingLine = $lines[$tocStart].Trim()
    $limits = Resolve-TocLimits -TocDepth $TocDepth
    $sourceHeadings = @(
        Get-Headings -Lines $lines -Start $tocEnd |
            ForEach-Object {
                [pscustomobject]@{
                    Level = $_.Level
                    Text = $_.Text
                }
            }
    )
    $tocLines = Build-TocLines -Headings $sourceHeadings -MinLevel $limits.MinLevel -MaxLevel $limits.MaxLevel

    $newLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -le $tocStart; $i++) {
        $newLines.Add($lines[$i])
    }
    $newLines.Add("")
    foreach ($line in $tocLines) {
        $newLines.Add($line)
    }
    $newLines.Add("")
    for ($i = $tocEnd; $i -lt $lines.Count; $i++) {
        $newLines.Add($lines[$i])
    }

    $newText = [string]::Join("`n", $newLines)
    if ($content.EndsWithNewline) {
        $newText += "`n"
    }

    if ($newText -ceq $content.SourceText) {
        return [pscustomobject]@{
            Changed = $false
            Status = "up to date"
            TocHeadingLine = $tocHeadingLine
            TocLines = $tocLines
        }
    }

    if (-not $DryRun) {
        [System.IO.File]::WriteAllText($Path, $newText, $UTF8_NO_BOM)
    }

    return [pscustomobject]@{
        Changed = $true
        Status = "updated"
        TocHeadingLine = $tocHeadingLine
        TocLines = $tocLines
    }
}

function Resolve-Targets {
    param([string[]]$Files)

    if ($Files.Count -gt 0) {
        return [string[]]$Files
    }

    $targets = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($pattern in $TARGET_FILE_GLOBS) {
        foreach ($item in Get-ChildItem -Path . -Filter $pattern -File) {
            [void]$targets.Add($item.Name)
        }
    }

    return [string[]]($targets.ToArray() | Sort-Object)
}

try {
    if ($Help) {
        Show-Usage
        exit 0
    }

    if ($FromCmdWrapper) {
        if ($env:UPDATE_MD_TOC_DRY_RUN -eq "1") {
            $DryRun = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($env:UPDATE_MD_TOC_TOC_DEPTH)) {
            $TocDepth = $env:UPDATE_MD_TOC_TOC_DEPTH
        }
        if (-not [string]::IsNullOrWhiteSpace($env:UPDATE_MD_TOC_FILES)) {
            $Files = @($env:UPDATE_MD_TOC_FILES -split '\|')
        }
    }

    [void](Resolve-TocLimits -TocDepth $TocDepth)
    $targets = Resolve-Targets -Files $Files
    if (-not $targets -or $targets.Count -eq 0) {
        Write-Output "No markdown files found."
        exit 1
    }

    $changedCount = 0
    foreach ($path in $targets) {
        $result = Update-File -Path $path -DryRun $DryRun -TocDepth $TocDepth
        if ($result.Changed) {
            $changedCount++
        }

        $mode = if ($DryRun -and $result.Changed) { "would update" } else { $result.Status }
        Write-Output "$path`: $mode"

        if ($result.Changed) {
            $tocLabel = if ($DryRun) { "preview" } else { "output" }
            Write-Output "--- TOC $tocLabel for $path ---"
            $tocHeadingLine = $result.TocHeadingLine
            if ([string]::IsNullOrEmpty($tocHeadingLine)) {
                $tocHeadingLine = "## $TOC_START_HEADING_TEXT"
            }
            Write-Output $tocHeadingLine
            Write-Output ""
            if ($result.TocLines.Count -gt 0) {
                foreach ($line in $result.TocLines) {
                    Write-Output $line
                }
            }
            else {
                Write-Output "$TOC_BULLET (empty)"
            }
            Write-Output ""
        }
    }

    Write-Output "Done. changed=$changedCount, total=$($targets.Count)"
    exit 0
}
catch {
    Write-Output "Error: $($_.Exception.Message)"
    exit 2
}
