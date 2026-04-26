#!/usr/bin/env python3
# =============================================================
# update-md-toc.py — Creates or updates TOC in Markdown files.
#
# Finds a TOC marker heading and replaces the block below it
# (up to the next heading) with auto-generated anchor links.
# Recognized markers: Оглавление, Оглавлние, TOC, Table of contents, Contents.
#
# Key functions:
#   parse_args()          : Parses CLI arguments.
#   iter_headings()       : Yields headings while skipping fenced code blocks.
#   slugify()             : Generates a GitHub-style anchor slug from heading text.
#   build_toc_lines()     : Produces the list of TOC bullet lines.
#   find_toc_range()      : Locates the start/end line indices of the TOC block.
#   update_file()         : Orchestrates read → generate → write for one file.
#   resolve_targets()     : Resolves the list of files to process.
#   resolve_toc_limits()  : Parses --toc-depth (hN format) into min/max levels.
#
# Dependencies:
#   Python 3.9+ - https://www.python.org/downloads/ (stdlib only, no packages needed)
#
# Usage:
#   python update-md-toc.py [--files FILE [FILE ...]] [--dry-run] [--toc-depth hN]
#
# Parameters:
#   --files FILE ...  : Optional. Markdown files to process.
#   --dry-run         : Optional. Show changes without writing.
#   --toc-depth hN    : Optional. Limit entries to H1-HN (e.g. h2, h3).
#
# Examples:
#   python update-md-toc.py
#   python update-md-toc.py --files README.md
#   python update-md-toc.py --files README.md --dry-run --toc-depth h3
# =============================================================
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# ==========================
# In-code settings
# ==========================
# By default, TOC starts at one of the configured heading markers
# and ends before the next heading.
TOC_START_HEADING_TEXTS = (
    "\u041e\u0433\u043b\u0430\u0432\u043b\u0435\u043d\u0438\u0435",
    "\u041e\u0433\u043b\u0430\u0432\u043b\u043d\u0438\u0435",
    "TOC",
    "Table of contents",
    "Contents",
)
TOC_START_HEADING_TEXT = TOC_START_HEADING_TEXTS[0]
TOC_START_HEADING_MARKERS = {item.casefold() for item in TOC_START_HEADING_TEXTS}
# Files to process when --files is not provided.
TARGET_FILE_GLOBS = ("*.md",)
# Heading levels included in generated TOC.
TOC_MIN_LEVEL = 1
TOC_MAX_LEVEL = 6
# TOC formatting.
TOC_BULLET = "-"
TOC_INDENT = "  "


HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Update Markdown TOC block between heading "
            f"{TOC_START_HEADING_TEXTS} and the next heading."
        )
    )
    parser.add_argument(
        "--files",
        nargs="+",
        help="Explicit markdown files to process. Overrides TARGET_FILE_GLOBS.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show which files would change without writing to disk.",
    )
    parser.add_argument(
        "--toc-depth",
        type=str,
        help=(
            "TOC depth in format hN. "
            "Examples: h1=H1 only, h2=H1-H2, h3=H1-H3."
        ),
    )
    return parser.parse_args()


def clean_heading_text(raw_text: str) -> str:
    return re.sub(r"\s+#+\s*$", "", raw_text).strip()


def is_toc_heading_marker(text: str) -> bool:
    return text.casefold() in TOC_START_HEADING_MARKERS


def iter_headings(lines: list[str], start: int = 0):
    in_fence = False
    for index in range(start, len(lines)):
        line = lines[index]
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        match = HEADING_RE.match(line)
        if not match:
            continue

        level = len(match.group(1))
        text = clean_heading_text(match.group(2))
        if text:
            yield index, level, text


def slugify(text: str) -> str:
    normalized = text.strip().lower()
    normalized = re.sub(r"[^\w\s-]", "", normalized, flags=re.UNICODE)
    normalized = re.sub(r"[-\s]+", "-", normalized).strip("-")
    return normalized or "section"


def resolve_toc_limits(toc_depth: str | None) -> tuple[int, int]:
    min_level = TOC_MIN_LEVEL
    max_level = TOC_MAX_LEVEL

    if toc_depth is not None:
        match = re.fullmatch(r"[hH]([1-6])", toc_depth.strip())
        if not match:
            raise ValueError("--toc-depth must be in format hN, where N is 1..6 (example: h2)")
        min_level = 1
        max_level = int(match.group(1))

    if max_level < min_level:
        max_level = min_level

    return min_level, max_level


def build_toc_lines(
    headings: list[tuple[int, str]],
    min_level: int,
    max_level: int,
) -> list[str]:
    if not headings:
        return []

    included = [(level, text) for level, text in headings if min_level <= level <= max_level]
    if not included:
        return []

    base_level = min(level for level, _ in included)
    slug_counts: dict[str, int] = {}
    toc_lines: list[str] = []
    for level, text in included:
        base_slug = slugify(text)
        count = slug_counts.get(base_slug, 0)
        slug_counts[base_slug] = count + 1
        slug = base_slug if count == 0 else f"{base_slug}-{count + 1}"

        indent = TOC_INDENT * max(0, level - base_level)
        toc_lines.append(f"{indent}{TOC_BULLET} [{text}](#{slug})")

    return toc_lines


def find_toc_range(lines: list[str]) -> tuple[int, int] | None:
    start_index: int | None = None
    for index, _, text in iter_headings(lines):
        if is_toc_heading_marker(text):
            start_index = index
            break

    if start_index is None:
        return None

    for index, _, _ in iter_headings(lines, start=start_index + 1):
        return start_index, index

    return start_index, len(lines)


def update_file(
    path: Path,
    dry_run: bool = False,
    toc_depth: str | None = None,
) -> tuple[bool, str, str | None, list[str]]:
    source_text = path.read_text(encoding="utf-8")
    lines = source_text.splitlines()

    toc_range = find_toc_range(lines)
    if toc_range is None:
        return False, "marker not found", None, []

    toc_start, toc_end = toc_range
    toc_heading_line = lines[toc_start].strip()
    min_level, max_level = resolve_toc_limits(toc_depth)
    toc_source_headings = [(level, text) for _, level, text in iter_headings(lines, start=toc_end)]
    toc_lines = build_toc_lines(toc_source_headings, min_level=min_level, max_level=max_level)

    new_lines: list[str] = []
    new_lines.extend(lines[: toc_start + 1])
    new_lines.append("")
    new_lines.extend(toc_lines)
    new_lines.append("")
    new_lines.extend(lines[toc_end:])

    new_text = "\n".join(new_lines)
    if source_text.endswith("\n"):
        new_text += "\n"

    if new_text == source_text:
        return False, "up to date", toc_heading_line, toc_lines

    if not dry_run:
        path.write_text(new_text, encoding="utf-8")
    return True, "updated", toc_heading_line, toc_lines


def resolve_targets(files: list[str] | None) -> list[Path]:
    if files:
        targets = [Path(item) for item in files]
        for path in targets:
            if not path.is_file():
                print(f"Error: file not found: {path}")
                sys.exit(2)
    else:
        found: dict[Path, None] = {}
        for pattern in TARGET_FILE_GLOBS:
            for path in Path(".").glob(pattern):
                if path.is_file():
                    found[path] = None
        targets = sorted(found.keys())
    return targets


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

    args = parse_args()
    try:
        resolve_toc_limits(args.toc_depth)
    except ValueError as exc:
        print(f"Error: {exc}")
        return 2

    targets = resolve_targets(args.files)
    if not targets:
        print("No markdown files found.")
        return 1

    changed_count = 0
    for path in targets:
        changed, status, toc_heading_line, toc_lines = update_file(
            path,
            dry_run=args.dry_run,
            toc_depth=args.toc_depth,
        )
        if changed:
            changed_count += 1
        mode = "would update" if args.dry_run and changed else status
        print(f"{path}: {mode}")
        if changed:
            toc_label = "preview" if args.dry_run else "output"
            print(f"--- TOC {toc_label} for {path} ---")
            print(toc_heading_line or f"## {TOC_START_HEADING_TEXT}")
            print("")
            if toc_lines:
                for line in toc_lines:
                    print(line)
            else:
                print(f"{TOC_BULLET} (empty)")
            print("")

    print(f"Done. changed={changed_count}, total={len(targets)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
