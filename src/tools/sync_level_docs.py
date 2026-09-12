#!/usr/bin/env python3
"""
Cove Corsair - Level Document & Resource Synchronizer

Synchronizes level configuration between Markdown specifications in
`documents/levels/` and Godot `.tres` resource files in `src/data/resources/levels/`.

Allows designers to directly modify level parameters (such as `completion_doubloon_reward`,
`base_scroll_speed`, etc.) in the level markdown documentation and apply them to the game.

Usage:
    python src/tools/sync_level_docs.py            # Sync docs -> .tres resources
    python src/tools/sync_level_docs.py --dry-run  # Preview changes without writing
    python src/tools/sync_level_docs.py --level 1  # Sync only a specific level
"""

import os
import re
import sys
import argparse

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOCS_DIR = os.path.join(ROOT_DIR, "documents", "levels")
RESOURCES_DIR = os.path.join(ROOT_DIR, "src", "data", "resources", "levels")

# Known aliases mapping level_id -> alternate .tres file
ALIAS_MAP = {
    1: "level_01_smugglers_run.tres",
    2: "level_02_black_tide_bayou.tres",
    3: "level_03_brimstone_bastion.tres",
    4: "level_04_smugglers_nightmare.tres",
    5: "level_05_black_tide_abyss.tres",
    6: "level_06_brimstone_inferno.tres",
}


def parse_frontmatter(file_path: str) -> dict:
    """Extract YAML frontmatter between leading `---` markers."""
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return {}

    frontmatter_text = match.group(1)
    data = {}
    for line in frontmatter_text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip().strip('"').strip("'")

            # Type conversion
            if val.isdigit():
                val = int(val)
            else:
                try:
                    val = float(val)
                except ValueError:
                    pass
            data[key] = val
    return data


def update_tres_file(tres_path: str, params: dict, dry_run: bool = False) -> bool:
    """Updates key-value fields in a Godot .tres text resource."""
    if not os.path.exists(tres_path):
        return False

    with open(tres_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content
    changes = []

    # Keys to potentially update
    keys_to_check = {
        "level_title": 'level_title = "{val}"',
        "base_scroll_speed": "base_scroll_speed = {val}",
        "completion_doubloon_reward": "completion_doubloon_reward = {val}",
        "biome_name": 'biome_name = "{val}"',
        "river_width_world": "river_width_world = {val}",
    }

    for key, template in keys_to_check.items():
        if key not in params:
            continue
        val = params[key]
        formatted = template.format(val=val)
        pattern = re.compile(rf"^{key}\s*=\s*[^\r\n]+", re.MULTILINE)

        if pattern.search(content):
            old_line = pattern.search(content).group(0)
            if old_line != formatted:
                content = pattern.sub(formatted, content)
                changes.append(f"{old_line} -> {formatted}")
        else:
            # If property doesn't exist yet, append before closing lines or after script = ...
            if "script = " in content:
                content = re.sub(
                    r"(script\s*=\s*[^\r\n]+)",
                    rf"\1\n{formatted}",
                    content,
                    count=1,
                )
                changes.append(f"+ Added {formatted}")

    if changes:
        print(f"  [{os.path.basename(tres_path)}]")
        for c in changes:
            print(f"    * {c}")
        if not dry_run:
            with open(tres_path, "w", encoding="utf-8", newline="\n") as f:
                f.write(content)
        return True
    return False


def sync_levels(dry_run: bool = False, target_level: int = None) -> None:
    print("=" * 60)
    print("  COVE CORSAIR - LEVEL DOCUMENT SYNCHRONIZER")
    print("=" * 60)
    if dry_run:
        print("  MODE: DRY-RUN (No files will be modified)\n")

    md_files = [f for f in os.listdir(DOCS_DIR) if f.startswith("level_") and f.endswith(".md")]
    md_files.sort()

    synced_count = 0
    updated_files = 0

    for md_file in md_files:
        md_path = os.path.join(DOCS_DIR, md_file)
        params = parse_frontmatter(md_path)
        if not params or "level_id" not in params:
            continue

        lvl_id = int(params["level_id"])
        if target_level is not None and lvl_id != target_level:
            continue

        synced_count += 1
        main_tres_name = f"level_{lvl_id:02d}.tres"
        main_tres_path = os.path.join(RESOURCES_DIR, main_tres_name)

        target_paths = [main_tres_path]
        if lvl_id in ALIAS_MAP:
            alias_path = os.path.join(RESOURCES_DIR, ALIAS_MAP[lvl_id])
            if os.path.exists(alias_path):
                target_paths.append(alias_path)

        level_changed = False
        for path in target_paths:
            if update_tres_file(path, params, dry_run=dry_run):
                level_changed = True

        if level_changed:
            updated_files += 1

    print("-" * 60)
    print(f"Processed {synced_count} level documents. {updated_files} levels updated.")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="Synchronize level documents with Godot .tres resources")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing to disk")
    parser.add_argument("--level", type=int, default=None, help="Sync only a specific level ID")
    args = parser.parse_args()

    sync_levels(dry_run=args.dry_run, target_level=args.level)


if __name__ == "__main__":
    main()
