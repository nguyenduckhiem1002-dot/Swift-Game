# Kiếm Tiên Đối Kháng

A 480×270, landscape, two fighter SpriteKit test game for iPhone. All code and game data are included; no external packages are needed. Băng Kiếm Tiên uses the supplied character reference and matching supplemental poses. Missing art for other characters is drawn as labeled pixel placeholders at runtime. The arena uses a widescreen watercolor xianxia painting with a moon, spirit dragon, palaces, and drifting transparent mist. Procedural scenery is retained as a fallback.

## Run

1. Open `SwordDuel.xcodeproj` in Xcode 15 or newer.
2. Select the `SwordDuel` scheme and an iPhone Simulator running iOS 16 or newer.
3. Press Run. The app is landscape only. For a device build, set your signing team and bundle identifier in the target settings.

If `xcodebuild` uses Command Line Tools instead of Xcode, select Xcode in Settings → Locations or run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Controls

Touch the on-screen directional controls and action buttons; multi-touch allows moving while attacking. Down and BLOCK both guard. BOX toggles hitbox outlines. On a hardware keyboard: A/D move, W jump, S block, J attack, K/L skills, U skill 3, I ultimate, B hitbox overlay, P pause.

Light attacks chain through three hits. Skills need energy and have cooldowns. Each match is best of three 60-second rounds. The select screen offers Easy and Normal AI.

## Awakening and SK3

Each fighter has an awakening meter (the violet bar under energy) that resets every round. Landing a hit adds 6, a successful block adds 4, and taking a hit adds 3. The fighter with less HP gains 50% more.

- **Tier I (30):** unlocks SK3 (20 energy, 8s cooldown). The SK3 button stays dimmed below this tier.
- **Tier II (60):** SK1 and SK2 deal +20% damage and add the character's `enhanced` effect (slow, stun, burn or drain).
- **Tier III (100):** 12 seconds awakened (the bar becomes a countdown): +20% damage, double energy gain, and the first ULT is the awakened ULT. Only one awakening per round.

SK3 applies a timed buff: `guardian` (-50% damage taken, no knockback: frost, elder), `frenzy` (+25% speed, +15% damage, 20% lifesteal: flame, beast), `glide` (extra air jump, slow fall, heal 5: umbrella), `vanish` (projectiles pass through, next hit +50%: tang), `meditate` (2s channel; heals 10 and cleanses slow/burn unless hit: monk), `summon` (phantom strikes 3×5 over 6s: herder) and `clone` (shadow repeats landed hits at 40%, first hit +50%: demon). Awakened ULTs deal a fixed 60 split over their `hits` and may add `reflect`, `superArmor`, `giant`, a heal, a pull or a burn. Awakening bonuses do not scale ULT damage. Frost and flame have no SK3 or awakened ULT in the design spec, so their names and effects here are placeholders to replace.

Until `<charId>_skill3.png` art exists, SK3 reuses the character's `win` animation.

## Imported Frost character

The new Frost art is bundled as transparent atlases with per-frame foot pivots. See `Art/README.md` for source, prompts, animation mappings, and preview launch arguments. Atlas crops retain the supplied artwork's resolution and allow wide sword effects; the standard strip format below remains supported.

## Add art

Put horizontal PNG sprite strips in `SwordDuel/Resources/Assets/Characters/<charId>/<charId>_<animation>.png`. The character IDs are `frost`, `flame`, `umbrella`, `tang`, `monk`, `herder`, `elder`, `demon` and `beast` (see `Art/Design/characters-expansion.md`). Each frame must be 64×64 pixels (`beast` uses 96×96 via `frameSize`), and the strip width must be `frame size × frame count`. All strips should face right; the game mirrors them for left-facing fighters. The runtime loader uses nearest-neighbor filtering. Transparent backgrounds are recommended. If a file is absent or too small, its labeled placeholder appears.

Animations and frame counts for each character:

| Name | Frames | FPS |
| --- | ---: | ---: |
| idle | 6 | 8 |
| walk | 8 | 12 |
| jump | 4 | 12 |
| crouch_block | 2 | 8 |
| attack1 | 5 | 14 |
| attack2 | 5 | 14 |
| attack3 | 6 | 14 |
| skill1 | 6 | 12 |
| skill2 | 6 | 14 |
| ult | 10 | 12 |
| hurt | 3 | 12 |
| ko | 6 | 10 |
| win | 6 | 8 |

Optional VFX strips go in `SwordDuel/Resources/Assets/VFX/`: `projectile_<color>.png` (4 frames), `hit_spark.png` and `skill1_impact.png` (5 frames), `dash_trail.png` (4 frames), and `ult_<color>.png` (8 frames), where `<color>` is the character's `color` key (`ice`, `fire`, `wind`, `poison`, `holy`, `spirit`, `earth`, `shadow`, `wild`). A character-specific `<charId>_projectile.png` or `<charId>_ult.png` takes precedence. Each frame is 96×96 pixels. Missing VFX use simple generated rectangles in the character's accent color.

The bundled painting is `xianxia_moon_dragon.png`, with `xianxia_mist.png` as its transparent moving overlay. See `Art/Background-prompt.md` for prompts and rendering details. Replace those files to change the current arena. If the painting is removed, the legacy layered background loader becomes active.

Optional 480×270 background PNGs for that legacy loader go in `SwordDuel/Resources/Assets/Backgrounds/` as `far.png`, `mid.png`, and `near.png`. Far can be opaque; mid and near should be transparent. Near tiles horizontally. The procedural layers remain as fallbacks.

## Maps

Arenas are listed in `SwordDuel/Data/Maps.json` and chosen with the `<` / `>` selector on the select screen. `classic` is the illustrated arena above. `cloudpeak`, `lavahell`, `greatruins`, `poisonforest`, `divinetemple`, `thunderplate`, `underwater`, `underworld` and `astralvoid` follow `Art/Design/maps-and-interactions.md`. To give a map real art, add 480×270 layers `<mapId>_far.png`, `<mapId>_mid.png` and `<mapId>_near.png` to `Assets/Backgrounds/`; place the walkable ledge at y = 42 from the bottom. Without them, each map draws a procedural scene from its palette (`sky`, `horizon`, `mountain`, `ground`, `accent`, `structure`, `orb`) and its `ambient` particles. `gravity`, `moveScale` and `animSpeed` change jump arcs, walking speed and animation speed (used by `underwater` and `astralvoid`).

### Terrain interactions

Each map's `terrain` block in `Maps.json` drives `Scenes/ArenaTerrain.swift`. The floor stays at y = 42. A standard jump rises about 39 points, so platforms sit about 30 points up, or higher on low-gravity maps.

- **platforms** (`x` center, `y` top, `w`): one-way ledges you land on from above and walk off. Optional `moveX`/`moveY`/`period` make them moving platforms that carry riders. `onTime`/`offTime` make them blink in and out. `crumble` makes a platform collapse after 2s of standing and return after 8s. `cloud` platforms are burned away by fire for 8s.
- **zones** (`x` left edge, `w`, `h`): `lava` (6 damage and a launch), `poison` (slow and 1 HP every 0.6s), `waterfall` (slow), `rune` (+4 energy/s, or +12/s and awakening while lightning-charged) and `void` (8 damage, thrown back to the edge).
- **objects**: `pillar` (blocks projectiles; 3 hits turn it into a rubble ledge until it rebuilds after 15s), `bell` (stuns the hitter's opponent, +15 energy, 12s reuse), `mushroom` (+15 HP, regrows after 12s), `lantern` (hit to light it for 12s; lit lanterns halve darkness), `rod` (3 hits by one fighter call a telegraphed bolt on the opponent), `tablet` (the hitter is spared by the next statue beam), plus `statue` and `tombstone` props.
- **events** (`start`, `interval`, `telegraph`, `duration`): `wind` (flips direction; pushes fighters, and tailwind projectiles fly 30% faster and push 50% harder), `geyser`, `roots` and `lightning` (telegraphed strikes at a fighter or rune), `statueBeam` (low beam; jump or stand on a ledge), `sandstorm`, `current`, `darkness`, `souls` (homing wisps from tombstones) and `debris` (rocks crossing the arena). Every damaging event is telegraphed for 1–2 seconds.
- **Element reactions** use the character's `color`. `ice` freezes lava for 5s, making it safe. `fire` melts frozen lava, dissipates clouds, and detonates poison mist (10 damage to anyone nearby, mist gone for 10s). Lightning activates runes.

Arena damage is unblockable, counts as being hit for awakening, and stops when a round is decided. The AI sidesteps hazards and telegraphed strikes and hops over statue beams. Tiled map loading from the spec is not implemented; layouts live in `Maps.json`.

### Wide arenas and camera

`width` in `Maps.json` sets the arena width (default 480). The themed maps are 960–1440 points wide (2–3 screens), while `classic` stays one screen because its painting does not scroll. Fighters spawn 118 points either side of the center.

- **Camera:** follows the fighters' midpoint and zooms from 1.0× down to 0.75× as they separate (`CameraFraming` in `MapData.swift`). The floor stays at screen y = 42, and the view never shows past the arena edges. Fighters cannot separate by more than 570 points, so both always stay on screen.
- **Screen vs. arena coordinates:** gameplay (fighters, terrain, projectiles, effects, hitbox overlay) lives in a `world` node that the camera moves and scales. The HUD, touch controls, pause panel and weather/darkness overlays stay in screen coordinates.
- **Parallax:** the sky stays fixed, peaks and `<mapId>_mid.png` scroll at 0.5, clouds at 0.3 and `<mapId>_near.png` at 1.2. Mid and near art should tile horizontally.
- **Floor:** drawn across the whole arena in the world. An optional `<mapId>_ground.png` (42 points high, tileable) replaces the procedural floor.
- **Minimap:** wide maps show a strip between the touch controls with both fighters and the current camera view.

## Stage mode

Choose **VƯỢT ẢI** on the title screen, pick a fighter and a stage, then START. One player crosses the stage left to right against monsters. Stages live in `SwordDuel/Data/Stages.json` and monsters in `SwordDuel/Data/Monsters.json`; the code is `Scenes/StageScene.swift` and `Entities/Monster.swift`.

- **Stages:** 2880 points wide (6 screens), split into 4–6 zones that run safe → combat → boss, as in the map spec. A stage takes its look, physics and ambience from `map` and has its own absolute-coordinate `terrain`.
- **Zones and waves:** each zone's exit gate stays locked until its `waves` are cleared in order. A cleared zone heals 15 HP and opens the gate (ĐI TIẾP ▶). Walking into the next zone locks the way back. A zone with no waves, such as Hỏa Sơn's secret cave, opens immediately. Clearing the boss zone wins the stage; reaching 0 HP loses it. RETRY restarts the stage.
- **Monsters:** `behavior` selects the AI.
  - `melee`: lunges.
  - `ranged`: keeps its distance and shoots.
  - `slam`: armored, with a ground-marked area slam.
  - `flyer`: hovers, then dives.
  - `hopper`: hops on you.
  - `boss`: rotates `attacks` (`charge`, `fan`, `slam`, where slam sends shockwaves along the floor that you jump over), speeds up below 50% HP, and summons two `summon` minions at 66% and 33%.

  Every attack is telegraphed by a red flash, and charges and slams also mark the floor. Elites (`"elite": true` in a wave) have 2.5× HP, 1.5× damage and a gold outline. Easy difficulty scales monster damage to 70%.
- **Combat:** the full moveset works on monsters. Melee hits each monster once per swing. Projectiles fans and enhanced effects work as in 1v1. SK2 teleports behind the nearest monster. The ULT and awakened ULT hit every monster on screen. Clones echo hits, the herder's phantom strikes the nearest monster, and reflect sends monster shots back as your projectiles. You can block monster attacks.
- **Awakening:** +6 per hit, +4 per block, +3 when hit, plus kill rewards of +5 normal, +20 elite and +50 boss. Linh Văn Thạch gives +10. Each zone allows a new awakening.
- **Pickups** (`pickups` per zone, `x` from the zone's left edge, `y` above the floor): `peach` +25 HP, `stone` (Linh Văn Thạch) +10 awakening, `elixir` +40 energy. Elites always drop a stone; normal monsters drop a peach 12% of the time.
- **HUD:** player bars on the left; stage, zone, wave and kill count on the right; elapsed time at top; a boss bar during the boss fight; a minimap with zone borders and every monster.
- **Monster art:** optional `Assets/Monsters/<monsterId>.png` horizontal strip with `frames` set in `Monsters.json`. Without it, monsters are colored blocks with eyes.

Preview a stage directly with `--preview-stage <stageId> --character <id>`.

## Roster data

Each character entry in `Characters.json` can also set `role`, `accent` (RGB 0–1), `frameSize`, `walkSpeed` and `jumpVelocity`. Moves accept `projectiles` (skill1 fan size; `0` turns skill1 into a melee hitbox), `dashSpeed`, `dashTime`, `invulnerable`, `teleport`, `reflect`, `onHit` and `enhanced` (`slow`, `stun`, `burn`, `drain`). A negative `knockback` pulls the target. `skill3` and `ultAwakened` add `title`, `buff`, `buffTime`, `heal`, `hits`, `hitInterval`, `delay`, `unblockable` and `pull`. Trap placement and some spec details (exact counter timing, clone mirroring, black-hole projectile pull) are approximated with these shared systems. Missing button and HP-fill art falls back to generated textures in the character's accent color.

The select screen picks a random CPU opponent. For art review, add `--preview-fight --character <id> --opponent <id> --map <mapId>` to the scheme's Run arguments; `--test-ui` now also checks every character's frame counts and SK3/awakened ULT data, runs awakening tier rules on a test fighter, builds every arena, checks that hazards avoid spawn points and platforms are within jump reach, checks camera framing at the walls, the maximum gap and the spawn points, runs 40 seconds of each map's terrain events, validates stage and monster data, and runs every monster type for 12 seconds before killing it.

After adding PNGs, ensure they appear under the blue `Assets` folder reference in Xcode. Xcode copies that folder into the app bundle.

## Tune combat

Edit `SwordDuel/Data/Characters.json`. Each move defines `damage`, `activeStart`, `activeEnd`, `hitbox` (`x`, `y`, `w`, `h` from the fighter's feet toward its facing direction), `knockback`, `energyCost`, and `cooldown` in seconds. Animation entries define `frames`, `fps`, and `loop`. A new build loads the updated JSON; no Swift edits are required for tuning existing moves.

The Quit button calls `exit(0)` because this is a test build. Remove or replace it before any App Store submission.

## UI assets

All UI PNGs are loaded from `SwordDuel/Resources/Assets/UI/`. The imagegen masters are preserved in `Art/UI/`; export uses nearest-neighbor sampling and preserves transparent alpha. There is no magenta matte in the delivered PNGs. The full prompt set is in `Art/UI/prompts.md`.

Menu buttons use 9-slice frames, centered monospaced labels, normal/pressed/disabled textures, 0.92 pressed scale, and light haptics. Difficulty has separate selected/unselected frames. Touch controls preserve independent touch ownership; idle alpha is 0.85 and pressed alpha is 1.0. SK1/SK2 masks follow remaining/total cooldown. ULT uses a locked image below 100 energy and a four-frame pulse at 100. Both HP and energy use crop masks that drain from the outer edge toward the center. Code renders all text, including FIGHT! and K.O., over the empty banner plates.

Pause via the top-center pause icon or keyboard P. Pause freezes the round timer, fixed-step combat, and SpriteKit actions, and clears held gameplay input. The game pauses automatically when its window loses focus. The eye icon or keyboard B toggles hitboxes. Missing or incorrectly sized UI images use generated pixel fallback textures in `UIAssets.swift`.

| Filename | Frame size | PNG size | State |
| --- | --- | --- | --- |
| `dpad_left.png` | 32×32 | 32×32 | static / normal |
| `dpad_left_pressed.png` | 32×32 | 32×32 | pressed |
| `dpad_right.png` | 32×32 | 32×32 | static / normal |
| `dpad_right_pressed.png` | 32×32 | 32×32 | pressed |
| `dpad_up.png` | 32×32 | 32×32 | static / normal |
| `dpad_up_pressed.png` | 32×32 | 32×32 | pressed |
| `dpad_down.png` | 32×32 | 32×32 | static / normal |
| `dpad_down_pressed.png` | 32×32 | 32×32 | pressed |
| `btn_atk.png` | 40×40 | 40×40 | static / normal |
| `btn_atk_pressed.png` | 40×40 | 40×40 | pressed |
| `btn_block.png` | 36×36 | 36×36 | static / normal |
| `btn_block_pressed.png` | 36×36 | 36×36 | pressed |
| `btn_frost_sk1.png` | 36×36 | 36×36 | static / normal |
| `btn_frost_sk1_pressed.png` | 36×36 | 36×36 | pressed |
| `btn_frost_sk2.png` | 36×36 | 36×36 | static / normal |
| `btn_frost_sk2_pressed.png` | 36×36 | 36×36 | pressed |
| `btn_flame_sk1.png` | 36×36 | 36×36 | static / normal |
| `btn_flame_sk1_pressed.png` | 36×36 | 36×36 | pressed |
| `btn_flame_sk2.png` | 36×36 | 36×36 | static / normal |
| `btn_flame_sk2_pressed.png` | 36×36 | 36×36 | pressed |
| `btn_<charId>_sk3.png` | 36×36 | 36×36 | optional; generated fallback in accent color |
| `btn_<charId>_sk3_pressed.png` | 36×36 | 36×36 | optional pressed |
| `btn_frost_ult_locked.png` | 44×44 | 44×44 | locked |
| `btn_frost_ult_ready.png` | 44×44 | 176×44 | 4 pulsing ready frames |
| `btn_flame_ult_locked.png` | 44×44 | 44×44 | locked |
| `btn_flame_ult_ready.png` | 44×44 | 176×44 | 4 pulsing ready frames |
| `btn_pause.png` | 24×24 | 24×24 | static / normal |
| `btn_pause_pressed.png` | 24×24 | 24×24 | pressed |
| `btn_debug_off.png` | 24×24 | 24×24 | off |
| `btn_debug_on.png` | 24×24 | 24×24 | on |
| `portrait_frame.png` | 32×32 | 32×32 | static / normal |
| `btn_menu_normal.png` | 96×28 | 96×28 | normal |
| `btn_menu_pressed.png` | 96×28 | 96×28 | pressed |
| `btn_menu_disabled.png` | 96×28 | 96×28 | disabled |
| `hp_frame.png` | 128×14 | 128×14 | static / normal |
| `hp_frost_fill.png` | 124×10 | 124×10 | static / normal |
| `hp_flame_fill.png` | 124×10 | 124×10 | static / normal |
| `energy_frame.png` | 96×8 | 96×8 | static / normal |
| `energy_fill.png` | 92×4 | 92×4 | static / normal |
| `awaken_fill.png` | 92×4 | 92×4 | optional; violet fallback |
| `timer_frame.png` | 48×24 | 48×24 | static / normal |
| `round_empty.png` | 16×16 | 16×16 | empty |
| `round_filled.png` | 16×16 | 16×16 | filled |
| `btn_difficulty_unselected.png` | 64×24 | 64×24 | unselected |
| `btn_difficulty_selected.png` | 64×24 | 64×24 | selected |
| `banner_fight.png` | 160×40 | 160×40 | empty ornamented plate; text rendered in Swift |
| `banner_ko.png` | 160×40 | 160×40 | empty ornamented plate; text rendered in Swift |
| `cooldown.png` | 36×36 | 288×36 | 8 clockwise wipe frames: full → empty |

To regenerate PNGs from the preserved masters, run `swift -module-cache-path /tmp/SwordDuelSwiftCache Scripts/export_ui.swift`. To check file sizes, alpha, radial progression, and pulse frames, run `swift -module-cache-path /tmp/SwordDuelSwiftCache Scripts/validate_ui_assets.swift`.

Simulator review arguments: `--preview-ui-states` shows partial HP, energy, round wins, a pressed ATK, active cooldown masks, and a ready ULT; add `--flame` for the other icon set. `--preview-paused` shows the pause panel. `--test-ui` runs in-app assertions for synthetic shared touch ownership, independent held keys, pause/resume, frozen timer, disabled/pressed menu feedback, missing-file fallback, and both ULT strips, then exits. It checks input routing and state behavior; it does not simulate two physical fingers on a device.
