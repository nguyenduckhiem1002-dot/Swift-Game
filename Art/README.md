# Frost swordsman reference import

The player-provided reference is preserved at `References/frost-reference.png`.

The built-in imagegen tool produced two transparent atlases, saved in the game bundle at:

- `SwordDuel/Resources/Assets/Characters/frost/frost_reference_atlas.png`: background and annotation removal from the supplied sheet.
- `SwordDuel/Resources/Assets/Characters/frost/frost_extra_atlas.png`: supplemental guard, hurt, KO, victory, and dash poses using the same reference.
- `SwordDuel/Resources/Assets/Characters/frost/frost_atlas.json`: source rectangles, foot pivots, display scale, and the mapping for all 13 animation states.

The original artwork has unequal frame widths and large slash effects. Atlas frames therefore retain their source resolution, with nearest-neighbor filtering and per-frame pivots. The displayed body remains approximately 64 logical points tall; the sword and dragon can extend beyond the body. The ordinary 64×64 horizontal-strip loader remains available and takes precedence when a named strip is supplied.

The reference's six attack poses are reused in the three combo sequences. The supplemental poses were generated from the reference and are not hand-drawn production animation. The dragon VFX reuses the extracted dragon pose while the cast animation changes pose.

To inspect the new art directly, add `--preview-select` or `--preview-fight` under the Xcode scheme's Run → Arguments. With no arguments the app opens its normal title screen.

## Built-in imagegen prompts

### Reference extraction

Use case: background-extraction. Edit target: supplied xianxia swordsman sprite reference sheet. Create a production sprite atlas by changing ONLY the background and annotations. Keep the exact original canvas aspect ratio, arrangement, position, scale, identity, costumes, colors, poses, all sprite frames and all blue magical effects unchanged. Remove the solid dark background to genuine transparent alpha; remove ALL headings, letters, numbers, dividers, and horizontal baseline rules. Preserve dark black hair, navy cloth, fine pale blue ribbons, white robes, orange tassels, blades, and translucent ice dragon effects without erasing them. No added artwork, no rearrangement, no resizing individual sprites, no checkerboard drawn into image. Keep the 6 idle poses top-left, 6 float poses top-right, 8 walk poses second-row left, 8 run poses second-row right, 6 attack poses third row, and the original special skill poses bottom row, at exactly their original positions. Clean transparent-background game asset, original reference likeness is paramount.

### Supplemental poses

Create a supplemental GAME SPRITE ATLAS for the EXACT same white-and-blue male xianxia swordsman in the reference. Preserve his long flowing black hair with blue ribbons, pale white flowing hanfu with navy/ice-blue details, youthful face, orange sword tassel, proportions and detailed pixel-art appearance. Genuine transparent background. No text, no labels, no grid lines, no background haze. STRICT layout: 1536 by 1024 pixels, SIX equal columns and FOUR equal rows, every cell 256 by 256. All 24 cells contain exactly one pose, with generous transparent margins, no overlap. Character side view FACING RIGHT; head at local y=55 and feet grounded at local y=235 in upright poses, body centered on local x=128. Consistent figure scale across all cells, animate pose not zoom. Row 1: cell1 begins crouching guard, cell2 holds deep crouching sword guard, cell3 small hurt flinch backward, cell4 stronger hurt flinch backward, cell5 recovering from hurt, cell6 neutral idle. Row 2: six consecutive KO frames, hit recoil then losing balance then falling backward then lower falling then almost on ground then lying completely down on ground, last frame horizontal body at y=210. Row 3: six consecutive subtle looping victory frames standing upright with sword raised and proud calm expression, cloth and hair fluttering. Row 4: six consecutive forward sword dash poses leaning and stretching forward with restrained small icy speed streaks contained within each cell. Keep art detailed and character IDENTICAL to reference; exact clean 6x4 uniform sprite sheet layout is essential for slicing in game.

Both prompts requested transparent backgrounds. The output PNGs contain actual alpha; the generated supplemental atlas needed explicit per-pose rectangles because its rows were not a perfect regular grid.
