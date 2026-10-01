# Generated concept-art manifest

The images generated during design are **concept/reference boards**. They intentionally contain labels, multi-panel layouts, magenta key backgrounds, uneven spacing and cinematic illustration. Do **not** drop these boards directly into `Resources/Assets` as runtime strips.

Production workflow:
1. keep original boards in `Art/References/Generated/`;
2. extract/redraw individual frames on a single pixel grid;
3. remove labels and magenta matte to transparent alpha;
4. normalize frame size / pivot / facing;
5. export runtime sprites into `SwordDuel/Resources/Assets`;
6. validate nearest-neighbor rendering and frame counts.

## Reference boards produced in the design session

Suggested repository names:
- `frost-character-reference.png` — full-body white/blue xianxia swordsman.
- `frost-idle-reference.png` — six-frame idle concept.
- `frost-animation-pack-reference.png` — walk / attack / run / float concepts.
- `frost-dragon-slash-reference.png` — special dragon slash / ice VFX board.
- `flame-character-pack-reference.png` — demonic flame swordsman full move-set board.
- `umbrella-character-pack-reference.png` — Vũ Tán Tiên Tử concept / animation / VFX board.
- `roster-3-5-reference.png` — umbrella + Tang hidden-weapon master + monk board.
- `roster-6-9-reference.png` — herder + elder + demon + beast board.
- `maps-monsters-reference.png` — initial 5-map / monster / tile concept board.
- `maps-interactions-reference.png` — five-map terrain-interaction board.
- `cloudpeak-detailed-reference.png` — detailed Cloudpeak level design with large map and interactables.
- `all-maps-expanded-reference.png` — expanded 9-map concept board.

The binary boards are not considered production-complete until they are sliced and normalized. See:
- `Art/Design/characters-expansion.md`
- `Art/Design/maps-and-interactions.md`
