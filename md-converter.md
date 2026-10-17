# Markdown converter

`md-converter.cmd` and `md-converter.ps1` convert Markdown without Python, third-party modules, or external executables. The CMD launcher is the simplest interface on Windows.

It supports `html` and `ipynb`. The aliases `notebook` and `jupyter` mean `ipynb`.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+

No external dependencies are required. Pandoc-backed PDF, DOCX, EPUB, RST, ODT, LaTeX, and related formats are intentionally excluded because built-in PowerShell cannot generate them reliably.

## Examples

Run without arguments to display help. This is not treated as an error:

```cmd
md-converter.cmd
```

Quick HTML conversion:

```cmd
md-converter.cmd README.md
```

The CMD launcher accepts the same options as the PowerShell implementation:

```cmd
md-converter.cmd README.md -Format html,ipynb -OutputDirectory dist
md-converter.cmd README.md -Format html -Force
```

Direct PowerShell examples:

```powershell
# Standalone HTML
powershell -NoProfile -File .\md-converter.ps1 -InputFile README.md -Format html

# Jupyter Notebook
powershell -NoProfile -File .\md-converter.ps1 -InputFile README.md -Format ipynb

# Both formats in a separate directory
powershell -NoProfile -File .\md-converter.ps1 -InputFile README.md -Format html,ipynb -OutputDirectory dist

# Exact output path for one format
powershell -NoProfile -File .\md-converter.ps1 -InputFile README.md -Format html -OutputFile export\README.html

# List formats
powershell -NoProfile -File .\md-converter.ps1 -ListFormats
```

## Parameters

- `-InputFile` (`-i`): input Markdown file; required unless `-ListFormats` is used.
- `-Format` (`-f`): one or more formats; default: `html`.
- `-OutputFile` (`-o`): exact output path; valid with one format only.
- `-OutputDirectory`: directory for generated output names.
- `-CodeLanguages`: fenced-code languages converted to notebook code cells; default: `python`, `py`.
- `-KernelDisplayName`: notebook kernel display name; default: `Python 3 (ipykernel)`.
- `-KernelName`: notebook kernel name; default: `python3`.
- `-LanguageName`: notebook language name; default: `python`.
- `-HtmlTheme`: `light`, `dark`, or `auto`; default: `light`.
- `-HtmlTitle`: overrides the HTML title.
- `-HtmlCss`: appends a UTF-8 CSS file to the built-in stylesheet.
- `-HtmlCodeCollapseLines`: collapses longer HTML code blocks; default: `5`, or `0` to disable.
- `-HtmlNoToc`: omits the table of contents.
- `-NoStandalone`: creates an HTML fragment instead of a complete page.
- `-Force`: allows an existing output file to be overwritten.
- `-ListFormats`: lists available formats and exits.
- `-Help`: displays usage and exits successfully.

## Safety and limitations

The input is read only. Existing output files are refused by default. Pass `-Force` to overwrite them explicitly. Errors return a non-zero exit code.

The HTML renderer preserves the original page interface: light/dark/auto themes, sticky collapsible TOC panel, heading-level filters, expandable heading branches, active-heading tracking, collapsible code blocks, line counts, and copy buttons. Every H1-H6 heading is included in the TOC; unlike the old Python filter, H1 is not discarded when H2 headings exist.

Markdown support includes headings, paragraphs, fenced code, simple lists, blockquotes, horizontal rules, links, images, emphasis, strong emphasis, and inline code. It is not a complete CommonMark implementation. Nested content lists, tables, footnotes, raw HTML, and complex inline nesting may not render as expected.
