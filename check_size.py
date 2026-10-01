import json

with open("/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters/frost/frost_atlas.json", "r") as f:
    atlas = json.load(f)

max_w = 0
max_h = 0
for name, frame in atlas["frames"].items():
    rect = frame["rect"]
    max_w = max(max_w, rect["w"])
    max_h = max(max_h, rect["h"])

print(f"Max W: {max_w}, Max H: {max_h}")
