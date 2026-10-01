# Asset pipeline

Runtime assets belong only in `SwordDuel/Resources/Assets/`.

## Source vs runtime
- `Art/References/`: immutable source/reference boards.
- `Art/FrameRepair/`: temporary repair evidence and intermediate exports; never load these at runtime.
- `SwordDuel/Resources/Assets/`: final game-ready assets only.
- `DerivedData/`: local build output; never commit.

## Character frame rules
1. Transparent RGBA PNG.
2. One pose per exported frame; no neighbouring pose pixels or labels.
3. Stable foot pivot and visual scale across one animation.
4. No byte-identical frames inside a motion sequence unless the hold is intentional and documented.
5. Attack/skill animations may not alias another move wholesale.
6. Runtime manifests must reference existing files only.

## Visual QA
Run the asset audit before committing:

```sh
python3 Scripts/audit_runtime_assets.py
python3 Scripts/audit_duplicate_frames.py
```

A duplicate report is a review queue, not an automatic deletion list. UI pressed-state images and deliberate animation holds can be valid duplicates.

## Current known defects
The 2026-10-01 audit found duplicated character frames and a placeholder monster collision: `Monsters/firedragon.png` is byte-identical to `Monsters/wolf.png`. Those should be replaced with independently authored assets rather than renamed copies.
