# Kiếm Tiên Đối Kháng

A 480×270, landscape, two fighter SpriteKit test game for iPhone. All code and game data are included; no external packages are needed. Băng Kiếm Tiên uses the supplied character reference and matching supplemental poses. Missing art for other characters is drawn as labeled pixel placeholders at runtime. The arena uses a widescreen watercolor xianxia painting with a moon, spirit dragon, palaces, and drifting transparent mist. Procedural scenery is retained as a fallback.

## Run

1. Open `SwordDuel.xcodeproj` in Xcode 15 or newer.
2. Select the `SwordDuel` scheme and an iPhone Simulator running iOS 16 or newer.
3. Press Run. The app is landscape only. For a device build, set your signing team and bundle identifier in the target settings.

If `xcodebuild` uses Command Line Tools instead of Xcode, select Xcode in Settings → Locations or run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Controls

Touch the on-screen directional controls and action buttons; multi-touch allows moving while attacking. Down and BLOCK both guard. BOX toggles hitbox outlines. On a hardware keyboard: A/D move, W jump, S block, J attack, K/L skills, I ultimate, B hitbox overlay, P pause.

Light attacks chain through three hits. Skills need energy and have cooldowns. Each match is best of three 60-second rounds. The select screen offers Easy and Normal AI.

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

Arenas are listed in `SwordDuel/Data/Maps.json` and chosen with the `<` / `>` selector on the select screen. `classic` is the illustrated arena above. `cloudpeak`, `lavahell`, `greatruins`, `poisonforest`, `divinetemple`, `thunderplate`, `underwater`, `underworld` and `astralvoid` follow `Art/Design/maps-and-interactions.md`. To give a map real art, add 480×270 layers `<mapId>_far.png`, `<mapId>_mid.png` and `<mapId>_near.png` to `Assets/Backgrounds/`; place the walkable ledge at y = 42 from the bottom. Without them, each map draws a procedural scene from its palette (`sky`, `horizon`, `mountain`, `ground`, `accent`, `structure`, `orb`) and its `ambient` particles. `gravity` and `moveScale` change jump arcs and walking speed, which is how `underwater` and `astralvoid` are implemented. Terrain interactions, timed events and wide scrolling arenas from the spec are not implemented yet; the `summary` text only describes them.

## Roster data

Each character entry in `Characters.json` can also set `role`, `accent` (RGB 0–1), `frameSize`, `walkSpeed` and `jumpVelocity`. Moves accept `projectiles` (skill1 fan size; `0` turns skill1 into a melee hitbox), `dashSpeed`, `dashTime`, `invulnerable` and `teleport`. A negative `knockback` pulls the target. The new fighters reuse the shared SK1 / SK2 / ULT systems approximately; SK3, awakening, counters, traps, slows and summons from the expansion spec are not yet implemented. Missing button and HP-fill art falls back to generated textures in the character's accent color.

The select screen picks a random CPU opponent. For art review, add `--preview-fight --character <id> --opponent <id> --map <mapId>` to the scheme's Run arguments; `--test-ui` now also checks every character's frame counts and builds every arena.

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
