# Sword Duel: Map & Environment Guide

## 1. Map Objects (Interactables)
- **pillar (Breakable Pillar)**: HP 3. Blocks projectiles. Breaks into a low rubble platform for 15s before respawning.
- **runeswitch (Rune Switch)**: Hittable object. Triggers a 5s cooldown that toggles nearby solid `stone` platforms (doors/bridges) and toggles active `lava`/`poison` zones.
- **bell (Bell)**: Triggers a 12s cooldown on hit. Grants the attacker 15 energy and stuns the opponent for 0.6s.
- **mushroom (Healing Mushroom)**: Restores 15 HP on contact. Disappears for 12s.
- **crumble platform**: Stone bridge that collapses 2s after being stepped on, respawning after 8s.
- **lantern, rod, tablet, statue**: Additional props reacting to elemental logic or map events (e.g., rod calls lightning when charged, tablet protects from statue beams).

## 2. Element Reactions
Elements interact dynamically with the arena terrain:
- **Ice + Lava**: Freezes lava for 5s (BĂNG PHONG), making it safe to walk on.
- **Fire + Frozen Lava**: Melts the frozen lava instantly.
- **Fire + Poison Mist**: Triggers an explosion (NỔ ĐỘC), dealing 10 area damage and 150 launch force to anyone nearby (including the attacker), burning away the mist for 10s.
- **Wind + Projectile**: A tailwind boosts projectile speed x1.3 and push force x1.5. A headwind slows projectiles.
- **Lightning + Rune**: Charges a rune zone for 8s (PHÙ VĂN KÍCH HOẠT), providing increased energy regeneration and Awakening charge for standing fighters.

## 3. Event Schemas (Timeline)
Maps execute timed events specified in their `events` array:
- `start`: Initial trigger time (seconds).
- `interval`: Time between repeat occurrences.
- `telegraph`: Warning duration (typically 1.5s). Triggers indicators or screen effects.
- `duration`: Event active time.
*Supported Events*: `wind`, `geyser`, `sandstorm`, `statueBeam`, `roots`, `lightning`, `current`, `souls`, `darkness`, `debris`.

## 4. How to author a new map in Tiled
1. **Create Map**: New Orthogonal map in Tiled. Tile size 16x16.
2. **Tile Layer**: Add a Tile Layer. Paint your visual terrain.
3. **Object Group (`objects`)**: Add an Object Layer.
   - For a standard platform: Add a Rectangle Object, set `type` to `platform`.
   - For a zone (lava/poison): Add a Rectangle Object, set `type` to `zone`, and add a Custom String Property `kind` (e.g., `lava` or `poison`).
   - For an interactable (pillar/runeswitch): Add a Point Object, set `type` to `runeswitch`.
4. **Export**: Export as JSON into `Data/` (e.g., `mymap.json`).
5. **Config**: In `Maps.json`, set `"tiledMap": "mymap"` on your map configuration.
