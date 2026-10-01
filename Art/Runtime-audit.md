# Runtime asset and hitbox audit — 2026-10-01

## Applied to the game

- `Characters.json` defines standing, guarding and airborne hurtboxes for all nine fighters, plus 37 melee moves with active-frame hitboxes. These are authored gameplay rectangles, not pixel-perfect silhouette traces. Weapon glow and transparent sprite padding do not enlarge the body collider.
- Fighter hitboxes mirror with facing and scale with awakening. A swing keeps its facing through a crossover. Startup and recovery do not deal melee damage; a swing can damage each target once. Rejected invulnerable contacts do not consume that hit.
- Projectiles use swept segment/expanded-rectangle collision and select the earliest target. Collision resolves before an off-screen projectile is removed; the impact effect appears at the contact point.
- Reset clears held movement and guard inputs. Touch hit tests choose the nearest normalized circle when padding overlaps. Idle button artwork fades when it obscures a fighter; touch regions remain fixed.
- The portrait frame now loads at its real 32×32 native size before displaying at 40×40. HP fills and SK3 icons exist for all fighters. Missing UI resources are recorded and checked by the simulator test.
- Nine supplied map panels now load, preserve aspect ratio, and suppress the procedural oval clouds. Illustrated wide arenas now create their physical floor and ambient layer.
- Stage monsters have supplied-art skins and silhouette-shaped hit flashes. Character animation tests now reject placeholder fallback.

## Resource provenance and limitations

`Scripts/complete_runtime_assets.swift` extracts supplied boards and produces the added resources reproducibly. It does not synthesize new animation poses.

- SK3 icons are SK2-derived variants marked with a violet ring and three gold pips. SK3 body animation still borrows the win sequence.
- Large ULT panels for umbrella, tang, monk, herder, elder, demon and beast are held intact across eight texture frames. They are not eight independently drawn animation poses. Slicing a single large illustration into eight pieces produced broken effects.
- Ice shots reuse the cyan rain-needle silhouette. Eight stage enemies use one extracted pose each; fire-dragon currently reuses the lava-hound silhouette. Dedicated enemy animations and a dragon boss sheet are still absent.
- Imported character PNGs are connected to runtime atlas metadata. Some source-board poses retain magenta edge pixels or clipped/overlapping effects. Passing reference/dimension tests does **not** certify that all poses are visually clean.
- Map panels are low-resolution crops, not full-resolution parallax exports. Ground, some terrain objects and geometry remain procedural. Aspect-fill avoids distortion but crops the sides of wide panels.

## Verification

- `python3 Scripts/audit_runtime_assets.py`: validates nine character animation manifests, 713 atlas frame references, 37 per-frame melee definitions, and HUD/VFX sizes.
- Simulator launch with `--test-ui`: checks touch ownership, pause/resume, menu states, missing resources, all nine rosters, ULT resources, ten arenas and combat behavior.
- Hitbox assertions cover startup/active timing, guard posture, mirrored bounds, inactive move rejection, swept projectile crossing and a diagonal near-miss.
- `--preview-ui-states --character flame --opponent demon --map cloudpeak` provides a reproducible visual review state. Screenshot: `Art/Preview-hitbox-hud.png`.

Manual device playtesting is still needed for combat feel; these checks establish code/data behavior and resource loading.
