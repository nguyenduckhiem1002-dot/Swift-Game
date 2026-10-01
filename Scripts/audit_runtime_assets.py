"""Validate runtime references, frame rectangles and active hitbox coverage (stdlib only)."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "SwordDuel/Resources/Assets"


def dimensions(path):
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", path
    return struct.unpack(">II", raw[16:24])


characters = json.loads((ROOT / "SwordDuel/Data/Characters.json").read_text())
aliases = {"skill3": "win", "crouch_block": "guard", "jump": "float"}
frame_count = move_count = 0
for char in characters:
    folder = ASSETS / "Characters" / char["id"]
    atlas = json.loads((folder / (char["id"] + "_atlas.json")).read_text())
    for animation, spec in char["animations"].items():
        names = atlas["animations"].get(animation)
        if names is None:
            names = atlas["animations"].get(aliases.get(animation, ""))
        assert names and len(names) == spec["frames"], (char["id"], animation)
    for name, frame in atlas["frames"].items():
        w, h = dimensions(folder / (frame["image"] + ".png"))
        r = frame["rect"]
        assert 0 <= r["x"] < r["x"] + r["w"] <= w, (char["id"], name)
        assert 0 <= r["y"] < r["y"] + r["h"] <= h, (char["id"], name)
        frame_count += 1
    for name, move in char["moves"].items():
        if "hitboxes" not in move:
            continue
        assert 0 <= move["activeStart"] <= move["activeEnd"] < char["animations"][name]["frames"]
        for index in range(move["activeStart"], move["activeEnd"] + 1):
            box = move["hitboxes"][str(index)]
            assert box["w"] > 0 and box["h"] > 0
        move_count += 1
    for kind, size in [("hp_" + char["id"] + "_fill", (124, 10)),
                       ("btn_" + char["id"] + "_sk3", (36, 36)),
                       ("btn_" + char["id"] + "_sk3_pressed", (36, 36))]:
        assert dimensions(ASSETS / "UI" / (kind + ".png")) == size, kind
    for kind, count in [("projectile", 4), ("ult", 8)]:
        own = ASSETS / "VFX" / (char["id"] + "_" + kind + ".png")
        shared = ASSETS / "VFX" / (kind + "_" + char["color"] + ".png")
        path = own if own.exists() else shared
        if path.exists():
            assert dimensions(path) == (count * 96, 96), path
        else:
            assert len(atlas["effects"].get(path.stem, [])) == count, path

print(f"PASS: {len(characters)} characters, {frame_count} atlas frame references, {move_count} per-frame melee definitions, HUD and VFX dimensions.")
print("This checks data integrity; it does not certify visual separation of poses in source artwork.")
