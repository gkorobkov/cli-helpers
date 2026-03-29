# Repo with scripts that help with useful tasks or run other scripts

## Table of contents

- [`update_md_toc.py`](#update_md_tocpy)

## `update_md_toc.py`

Check changes without writing to the file (`--dry-run`):

```bash
python update_md_toc.py --files README.md --dry-run
```

Limit TOC depth (`hN` format: from H1 to HN):

```bash
python update_md_toc.py --files README.md --dry-run --toc-depth h3
```

The script prints the TOC block in both `output` mode and `--dry-run` mode:
- the TOC section heading
- the full list of items that will be inserted

Update one file:

```bash
python update_md_toc.py --files README.md --toc-depth h3
```

Update all `.md` files using the built-in settings (`TARGET_FILE_GLOBS`):

```bash
python update_md_toc.py
```

Windows CMD entry point:

```bat
update_md_toc.cmd --files README.md --dry-run
```

By default, the script looks for the heading `Оглавление`, `Оглавлние`, `TOC`, or `Table of contents`.
After that heading, all levels `H1-H6` are included in the TOC.
The `--toc-depth hN` option narrows that range to `H1-HN`.

In-code settings:
- `TOC_START_HEADING_TEXTS` (default markers include `Оглавление`)
- `TOC_MIN_LEVEL` / `TOC_MAX_LEVEL`
- `TARGET_FILE_GLOBS`

CLI options:
- `--toc-depth h1` -> H1 only
- `--toc-depth h2` -> H1-H2
- `--toc-depth hN` -> H1-HN
