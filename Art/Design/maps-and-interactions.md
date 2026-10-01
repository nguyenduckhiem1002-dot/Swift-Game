# Map expansion & interaction spec

This document captures the map/art direction agreed in the design conversation. It is a **production spec/reference**, not a claim that the generated concept boards are ready-to-slice runtime assets.

## Shared map art style

```text
strict pixel art, single consistent pixel grid, 32-color palette, no gradients except ordered dithering, no glow or bloom effects, no lens flare, no text or labels, flat 2D side-scrolling game background, asymmetrical composition, weathered and ruined details, clear value separation between background and foreground, one consistent light direction from the upper right, 480x270, [LAYER], [MAP THEME]
```

Negative prompt:

```text
text, labels, UI sheet, concept board, smooth gradient, painterly, high-resolution illustration, mixed pixel sizes, bloom, lens flare, symmetrical centered composition, 3D render, photorealistic
```

Use 3 parallax layers per map:
- `{mapId}_far.png`: sky / moon / distant silhouettes.
- `{mapId}_mid.png`: main scenery, transparent where practical.
- `{mapId}_near.png`: foreground mist / rocks / foliage, horizontally tileable.

Recommended factors: far 0.2, mid 0.5, near 1.2.

## Arena size

- 1v1: 960–1440 logical px wide (2–3 screens), camera follows midpoint between fighters and auto-zooms from 1.0x to 0.75x.
- Stage mode: 4–6 screens wide, split into zones. Exits stay locked until the zone wave is cleared.
- Typical stage flow: safe opening -> challenge/hazard zone -> boss arena.
- Optional shortcut/secret room with consumables or Linh Văn Thạch.

## Existing maps

| id | name | core terrain interaction |
| --- | --- | --- |
| `cloudpeak` | Vân Hải Tiên Sơn | wind changes direction every 15s; moving/cloud platforms; waterfall slow; fire can dissipate cloud platforms |
| `lavahell` | Ma Giới Hỏa Sơn | lava pit; periodic geysers; ice freezes lava into temporary 5s platform; chain bridge can collapse |
| `greatruins` | Đại Khư Hoang Địa | breakable stone pillars; sandstorm; ancient statue beam; rune tablets |
| `poisonforest` | U Minh Độc Lâm | poison mist slow + DoT; fire detonates poison mist; healing mushrooms respawn; roots can bind/slow |
| `divinetemple` | Thần Tàng Cổ Điện | rune floor increases energy gain; bells give arena effects; timed golden bridges; lightning activates rune buffs |

## Additional maps

- `thunderplate` — Thiên Lôi Đài: cyclic lightning strikes, chargeable lightning rods, rune activation.
- `underwater` — Thủy Hải Long Cung: water volumes, higher buoyant jumps, slower attacks/movement underwater.
- `underworld` — Cổ Mộ Âm Phủ: soul-spawning tombstones, blue lanterns, darkness/visibility mechanics.
- `astralvoid` — Hư Không Tinh Hải: low gravity, floating platforms, void gaps and drifting astral debris.

## Interactive objects

Generic object contract should support states, hit reaction, SFX hooks and optional element reactions.

- `BreakablePillar`: hp, breaks into rubble; can create a platform or line-of-fire blocker.
- `RuneSwitch`: toggles doors, bridges or traps.
- `Bell`: hit to trigger light stun or arena buff.
- `Chest` / `Jar`: breakable drops.
- `CrumblingPlatform`: cracks after 2s occupied, collapses, respawns after 8s.
- `HealingMushroom`: restores HP and withers; respawn timer.
- `WallJumpSurface`, `Ladder`, `Vine`.
- Map-specific props: lightning rod, chain bridge, rune tablet, tombstone, lantern, underwater valve/current source.

Art prompt:

```text
strict pixel art sprite sheet, 32-color palette, no glow, no gradients, single pixel grid, magenta background, game asset, 16x16 or 32x32 per frame, [OBJECT], 4 frames: idle, hit, broken, rebuilt/active
```

## Element reaction table

| source | terrain/target | result |
| --- | --- | --- |
| ice | lava | temporary frozen platform for 5s |
| fire | ice platform | melt immediately |
| fire | poison mist | AoE explosion that can hurt either side |
| wind | projectile | range x1.3 + extra push |
| lightning | rune | activate buff zone |
| fire | cloud/mist | dissipate/burn away depending on map |

Element tags: `ice`, `fire`, `poison`, `wind`, `lightning`, `holy`.

## Timed map events

Events are data-driven with `startTime`, `interval`, `telegraphDuration` and `effect`.

Examples:
- sandstorm every 20s for 5s;
- lava rise / geyser patterns;
- hail / ice rain;
- blood moon: awakening gain x1.5;
- bridge collapse / arena shrink at phase change.

Heavy events must telegraph for 1–2 seconds.

## Tiled / data structure

Use Tiled JSON with:
- tile layers: `ground`, `platforms`, `decor`;
- object layers: `spawns`, `hazards`, `interactables`, `zoneTriggers`;
- tile properties: `solid`, `oneWay`, `hazard`.

Recommended implementation order:
1. big-map camera + parallax;
2. Tiled loading + collision;
3. breakable pillar + rune switch + crumbling platform;
4. ice/fire terrain reactions;
5. event timeline;
6. remaining per-map objects and reactions.

## Pixel pipeline rules

Logical resolution remains 480x270 with 16x16 tiles. Use nearest filtering and no smoothing. Avoid non-integer sprite scale factors. Foreground art that overlaps fighters should fade or be depth-masked for readability.
