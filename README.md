# Command-line helper scripts for common local development workflows.

# Table of contents

- [Command Line Utilities](#command-line-utilities)
  - [Checks, lists, adds, or removes the current directory in `PATH`.](#checks-lists-adds-or-removes-the-current-directory-in-path)
- [Git Utilities](#git-utilities)
  - [Shows or updates global Git user name and email.](#shows-or-updates-global-git-user-name-and-email)
  - [Prints the current Git branch name.](#prints-the-current-git-branch-name)
  - [Shows all Git stashes with additional stash details.](#shows-all-git-stashes-with-additional-stash-details)
  - [Pulls the latest changes for a Git branch and optionally builds.](#pulls-the-latest-changes-for-a-git-branch-and-optionally-builds)
  - [Merges one Git branch into another and pushes the result.](#merges-one-git-branch-into-another-and-pushes-the-result)
  - [Runs a Git command across all matching subfolders.](#runs-a-git-command-across-all-matching-subfolders)
- [Markdown Utilities](#markdown-utilities)
  - [Creates or updates TOC in MD (Markdown) files from the command prompt.](#creates-or-updates-toc-in-md-markdown-files-from-the-command-prompt)
  - [Creates or updates TOC in MD (Markdown) files with PowerShell.](#creates-or-updates-toc-in-md-markdown-files-with-powershell)
  - [Creates or updates TOC in MD (Markdown) files with Python.](#creates-or-updates-toc-in-md-markdown-files-with-python)
- [Python Utilities](#python-utilities)
  - [Activates the local Python virtual environment.](#activates-the-local-python-virtual-environment)
  - [Creates a local Python virtual environment in `.venv`.](#creates-a-local-python-virtual-environment-in-venv)
  - [Installs Python requirements into the local virtual environment.](#installs-python-requirements-into-the-local-virtual-environment)
  - [Installs Python requirements with the system `pip3`.](#installs-python-requirements-with-the-system-pip3)
  - [Starts Jupyter Notebook in the current directory.](#starts-jupyter-notebook-in-the-current-directory)
  - [Starts Qodo in UI mode.](#starts-qodo-in-ui-mode)
- [Other Utilities](#other-utilities)

# Command Line Utilities

## Checks, lists, adds, or removes the current directory in `PATH`.

Small helpers for working with the current directory in `PATH`.
Use them when you want to quickly check whether the current folder is already available from the command line, inspect the active `PATH`, or add or remove the folder from `PATH`.

Files: `current-path.cmd`, `current-path.sh`

General form:

```bat
:: Windows CMD / BAT
current-path.cmd [list|add|delete]
```

```bash
# Linux / bash
./current-path.sh [list|add|delete]
```

Parameters:
- No parameter: Checks whether the current working directory is already present in the current `PATH`.
- `list`: Prints the current `PATH` entries one per line and shows which environment they were read from.
- `add`: Adds the current working directory to persistent `PATH` settings if it is missing.
- `delete`: Removes the current working directory from persistent `PATH` settings if it is present.
- Output: The scripts print the current working directory first so it is clear which path is being checked.

Examples:

```bat
:: Windows CMD / BAT
current-path.cmd
```

```bat
:: Windows CMD / BAT
current-path.cmd add
```

Linux note:
- Use `source ./current-path.sh add` or `source ./current-path.sh delete` when you need the current shell session to receive the updated `PATH` immediately. Without `source`, only future shells will pick up the persistent change.


# Git Utilities

## Shows or updates global Git user name and email.

Files: `git-setup.cmd`, `git-setup.sh`

Shows the current global `git config` values for `user.name` and `user.email`.
If one or both parameters are passed, the script updates the corresponding global Git config values first and then prints the resulting settings.
If a required value is still missing, the script prints usage help.

General form:

```bat
:: Windows CMD / BAT
git-setup.cmd [user_name] [user_email]
```

```bash
# Linux / bash
./git-setup.sh [user_name] [user_email]
```

Parameters:
- `user_name`: Optional. Git user name. If omitted, the current `git config --global user.name` value is used.
- `user_email`: Optional. Git user email. If omitted, the current `git config --global user.email` value is used.

Examples:

```bat
:: Windows CMD / BAT
git-setup.cmd
```

```bat
:: Windows CMD / BAT
git-setup.cmd "User Name" user@example.com
```


## Prints the current Git branch name.

File: `git-branch-name.cmd`

Outputs the active branch using `git rev-parse --abbrev-ref HEAD`.
Useful inside other scripts or in a terminal pipeline.

General form:

```bat
:: Windows CMD / BAT
git-branch-name.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
git-branch-name.cmd
```


## Shows all Git stashes with additional stash details.

File: `git-stash-list.cmd`

Prints `git stash list` and then runs `git stash show` for each stash entry.
Use it when the default stash list is too compact.

General form:

```bat
:: Windows CMD / BAT
git-stash-list.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
git-stash-list.cmd
```


## Pulls the latest changes for a Git branch and optionally builds.

File: `git-update.cmd`

Updates a repository folder by optionally fetching, optionally checking out a branch, pulling from `origin`, and printing `git status -s -b -v`.
If the branch argument is omitted, the script resolves the current branch with `git-branch-name.cmd`.
The script also supports optional build and flow-control flags through environment variables.

General form:

```bat
:: Windows CMD / BAT
git-update.cmd [sub_path] [branch_name]
```

Parameters:
- `sub_path`: Optional. Repository folder. Defaults to the current directory.
- `branch_name`: Optional. Branch to update. Defaults to the current branch.

Environment variables:
- `fetch_origin=true`: Run `git fetch origin <branch>` before pull.
- `checkout_branch=true`: Run `git checkout <branch>` before pull.
- `auto_stash=true`: Enable the auto-stash branch of the script. The actual stash command is currently commented out.
- `build-after-update=true`: Run one of the local build scripts after update if available.
- `exitonfinish=true`: Exit the shell when the script finishes.

Examples:

```bat
:: Windows CMD / BAT
git-update.cmd
```

```bat
:: Windows CMD / BAT
set fetch_origin=true
set checkout_branch=true
set auto_stash=true
set build-after-update=true
set exitonfinish=true
git-update.cmd C:\work\my-repo main
```


## Merges one Git branch into another and pushes the result.

File: `git-merge.cmd`

Updates both branches with `git-update.cmd`, checks out the destination branch, merges the source branch with `--allow-unrelated-histories`, pushes, and prints `git status -s`.
The script operates inside the current folder unless a target folder is passed explicitly.

General form:

```bat
:: Windows CMD / BAT
git-merge.cmd <from_branch_name> <to_branch_name> [sub_path]
```

Parameters:
- `from_branch_name`: Required. Source branch to merge from.
- `to_branch_name`: Required. Destination branch to merge into.
- `sub_path`: Optional. Target repository folder. Defaults to the current directory.

Examples:

```bat
:: Windows CMD / BAT
git-merge.cmd feature/main main C:\work\my-repo
```


## Runs a Git command across all matching subfolders.

File: `git-run-allfolders.cmd`

Recursively scans directories, looks for a marker folder such as `.git`, and runs a command in each matching location.
If the first argument is `update`, the script expands it to `git-update.cmd %%path_to_git_folder%%`.
Without arguments, it runs `git -C %%path_to_git_folder%% status -s -b -v`.

General form:

```bat
:: Windows CMD / BAT
git-run-allfolders.cmd [run_command] [search_path] [search_folder]
```

Parameters:
- `run_command`: Optional. Command template to run. May use `%%path_to_git_folder%%`. Default is `git -C %%path_to_git_folder%% status -s -b -v`.
- `search_path`: Optional. Root folder to search. Defaults to the current directory.
- `search_folder`: Optional. Marker folder to detect. Defaults to `.git`.

Examples:

```bat
:: Windows CMD / BAT
git-run-allfolders.cmd
```

```bat
:: Windows CMD / BAT
git-run-allfolders.cmd "git -C %%path_to_git_folder%% pull" C:\work .git
```


# Markdown Utilities

## Creates or updates TOC in MD (Markdown) files from the command prompt.

File: `update-md-toc.cmd`

Windows CMD wrapper around `update-md-toc.ps1`.
Parses CMD-style arguments, passes them through environment variables, and starts the PowerShell implementation.

General form:

```bat
:: Windows CMD / BAT
update-md-toc.cmd [--files <file1> [file2 ...]] [--dry-run] [--toc-depth hN] [--help]
```

Parameters:
- `--files <file1> [file2 ...]`: Optional. Process only the listed Markdown files.
- `--dry-run`: Optional. Print the generated TOC without writing changes.
- `--toc-depth hN`: Optional. Limit generated entries to `H1-HN`.
- `--help`: Optional. Show usage through the PowerShell script.

Examples:

```bat
:: Windows CMD / BAT
update-md-toc.cmd
```

```bat
:: Windows CMD / BAT
update-md-toc.cmd --files README.md docs.md --dry-run --toc-depth h3
```


## Creates or updates TOC in MD (Markdown) files with PowerShell.

File: `update-md-toc.ps1`

PowerShell implementation of the Markdown TOC updater.
Finds a TOC marker heading, replaces the block until the next heading, generates anchor links, and preserves the rest of the document.
Recognized TOC markers include `Оглавление`, `Оглавлние`, `TOC`, and `Table of contents`.

General form:

```powershell
# Windows PowerShell
.\update-md-toc.ps1 [-Files <string[]>] [-DryRun] [-TocDepth hN] [-Help]
```

Parameters:
- `-Files <string[]>`: Optional. Process only the listed Markdown files.
- `-DryRun`: Optional. Print changes without writing files.
- `-TocDepth hN`: Optional. Limit generated entries to `H1-HN`.
- `-Help`: Optional. Print usage.
- `-FromCmdWrapper`: Internal flag used by `update-md-toc.cmd`.

In-code settings:
- `TOC_START_HEADING_TEXTS`: Accepted TOC marker headings.
- `TARGET_FILE_GLOBS`: File patterns used when `-Files` is omitted.
- `TOC_MIN_LEVEL` / `TOC_MAX_LEVEL`: Default heading depth range.
- `TOC_BULLET` / `TOC_INDENT`: Formatting for generated list items.

Examples:

```powershell
# Windows PowerShell
.\update-md-toc.ps1
```

```powershell
# Windows PowerShell
.\update-md-toc.ps1 -Files README.md -DryRun -TocDepth h3
```


## Creates or updates TOC in MD (Markdown) files with Python.

File: `update-md-toc.py`

Python implementation of the Markdown TOC updater.
Finds a TOC marker heading, replaces the block until the next heading, generates anchor links, and preserves the rest of the document.
Recognized TOC markers include `Оглавление`, `Оглавлние`, `TOC`, and `Table of contents`.

General form:

```bash
# Linux / bash
python update-md-toc.py [--files <file1> [file2 ...]] [--dry-run] [--toc-depth hN]
```

Parameters:
- `--files <file1> [file2 ...]`: Optional. Process only the listed Markdown files.
- `--dry-run`: Optional. Print changes without writing files.
- `--toc-depth hN`: Optional. Limit generated entries to `H1-HN`.

In-code settings:
- `TOC_START_HEADING_TEXTS`: Accepted TOC marker headings.
- `TARGET_FILE_GLOBS`: File patterns used when `--files` is omitted.
- `TOC_MIN_LEVEL` / `TOC_MAX_LEVEL`: Default heading depth range.
- `TOC_BULLET` / `TOC_INDENT`: Formatting for generated list items.

Examples:

```bash
# Linux / bash
python update-md-toc.py
```

```bash
# Linux / bash
python update-md-toc.py --files README.md --dry-run --toc-depth h3
```


# Python Utilities

## Activates the local Python virtual environment.

File: `activate-venv.cmd`

Runs the standard Windows activation script from `.venv\Scripts\activate.bat`.
Use it after a virtual environment already exists.

General form:

```bat
:: Windows CMD / BAT
activate-venv.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
activate-venv.cmd
```


## Creates a local Python virtual environment in `.venv`.

File: `create-venv.cmd`

Creates a new virtual environment in the current repository by running `python -m venv .venv`.

General form:

```bat
:: Windows CMD / BAT
create-venv.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
create-venv.cmd
```


## Installs Python requirements into the local virtual environment.

File: `install-req-venv.cmd`

Runs `.venv\Scripts\python.exe -m pip install -r requirements.txt`.
Use it after `create-venv.cmd`.

General form:

```bat
:: Windows CMD / BAT
install-req-venv.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
install-req-venv.cmd
```


## Installs Python requirements with the system `pip3`.

File: `install-req.cmd`

Runs `pip3 install -r ./requirements.txt` from the current folder.
Use it when you intentionally want the global or externally managed Python environment instead of `.venv`.

General form:

```bat
:: Windows CMD / BAT
install-req.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
install-req.cmd
```


## Starts Jupyter Notebook in the current directory.

File: `run-jupyter.cmd`

Launches Jupyter Notebook with `--notebook-dir %cd%`.
The script uses `start`, so it opens in a separate window and returns immediately.

General form:

```bat
:: Windows CMD / BAT
run-jupyter.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
run-jupyter.cmd
```


## Starts Qodo in UI mode.

File: `run-qodo-ui.cmd`

Runs `start qodo --ui`.
The file also contains reminder comments for Qodo installation and login.

General form:

```bat
:: Windows CMD / BAT
run-qodo-ui.cmd
```

Parameters:
- None.

Examples:

```bat
:: Windows CMD / BAT
run-qodo-ui.cmd
```


# Other Utilities
