#!/usr/bin/env python3
"""Report suspicious byte-identical runtime PNGs without modifying assets."""
from __future__ import annotations
import hashlib
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "SwordDuel" / "Resources" / "Assets"

groups: dict[str, list[Path]] = defaultdict(list)
for path in ASSETS.rglob("*.png"):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    groups[digest].append(path.relative_to(ROOT))

suspicious = [paths for paths in groups.values() if len(paths) > 1]
print(f"Duplicate-content groups: {len(suspicious)}")
for paths in sorted(suspicious, key=lambda xs: str(xs[0])):
    print("\n" + "\n".join(f"  - {p}" for p in paths))

# Fail only on the known invalid monster alias. Other duplicates need visual review.
dragon = ASSETS / "Monsters" / "firedragon.png"
wolf = ASSETS / "Monsters" / "wolf.png"
if dragon.exists() and wolf.exists() and dragon.read_bytes() == wolf.read_bytes():
    raise SystemExit("\nERROR: firedragon.png is byte-identical to wolf.png")
