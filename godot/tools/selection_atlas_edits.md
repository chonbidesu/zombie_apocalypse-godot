# Selection atlas pixel edits

The game loads `assets/character_creation/corrected/`. The eighteen original
atlas PNGs in the parent directory are retained unchanged. The original
dimensions, 4-by-3 layout, and twelve frame slots
are preserved.

From the repository root, with Pillow installed:

```powershell
python godot/tools/repair_selection_atlases.py
python godot/tools/verify_selection_atlases.py
```

The builder copies RGBA pixels from the original drawings and writes the
finished sheets atomically. The stationary furniture and planted lower bodies
use shared references. The female private and police officer use their own
sleeves and the chair visible behind them. Pillow feathers those joins in the
upholstery. The female officer's cloth comes from her own hanging and resting
poses. Her studded chair front, right trouser leg and boot use one registered
original drawing through every pose. Both officers' idle drawings include the collar.
The male officer's confirmation poses use one continuous knee, cloth and
armrest drawing. Each moving arm includes the chair revealed beneath it.
The placement frame retains the fingers touching the cloth.

Both medics retain the full reclining silhouette and the fingers that cross
the mug. Their reclining poses carry the belt and fly into the upper thighs.
The male uniform uses his original cargo pocket and a fuller seated front fold. Both lab assistants retain their lapels and the glove holding the vial.
The scouts' poses keep the full hip against the seat. The chair uses one set of
spindles with transparent openings, exposed as the shirt leans forward.
The firefighters use their original coat, gloves and axe through row 231.
A 22-pixel band in the trousers aligns their outlines with the stationary legs.

For both scouts, frame 4 uses the standalone card-turn drawing in
`assets/character_creation/frames/`. The grip was generated for the turn.
The printed faces come from frame 5, foreshortened in their reveal order.
Stationary pixels come from frame 3.

Both doctors use the same corrected legs and jukebox. The jaw, collar, stethoscope and reaching fingers come from the same pose.
The extra calf is erased
along the surviving trouser contour. Frames 9–11 relight the complete arched
window in the PNG; the reaching hand is drawn in front of it. The existing
`doctor_portrait.png` supplies the default doctor's complete drawing, replacing
the former runtime face substitution.

Each consumer uses the original felt, balls, shadows and cue motion blur from
the corresponding frame. The surrounding table rails and legs stay registered.
The Arab male consumer source is a complete redraw based on the female pose,
with concentrated aiming and subtle breathing in the first four frames. His
head, torso, bridge hand, cue and felt are copied together, without the older
head/hand/felt joins. Only stationary furniture regions use the shared table.
Both consumers' break frames contain one white cue ball; the former duplicate is red.
The two side pockets are authored once in `frames/consumer_table_pockets.png`.
The Pillow builder copies only its two small furniture regions into every male
and female output frame after pose assembly. These are baked PNG pixels, not
runtime nodes, overlays, materials or shaders. The source animation sheets do
not need regenerating. The verifier checks exact donor equality in all 24 frames,
the unchanged playing surface elsewhere and the furniture source hash.
The verifier checks continuity against the source across the entire upper body
and bridge hand, plus the corrected ball colours in the break frame.
Near-transparent export noise is
cleared, and existing hair wisps/syringe mist fade within the top cell margin.

`ActorLayer` displays each complete frame without a corrective material. Alpha
bitmaps remain exclusively for mouse hit tests and projected shadow contacts;
they do not replace or hide any artwork. The old shader resource is inert and
unused by selection actors.

The verifier checks original/output hashes, full RGBA equality in independently
specified stationary furniture and body regions across all frames and both
genders, source equality on the repaired anatomy and props, idle body stability,
transparent cell boundaries, distinct confirmation
drawings, the removed calf, and the complete registered jukebox illumination.
The exact checked regions are listed in `verify_selection_atlases.py`; moving
upper bodies, exposed skin, faces, and foreground occlusions are intentionally
outside the shared stationary checks.

`corrected/manifest.json` records source and output hashes;
`corrected/verification.json` records the latest verification result.
Contact sheets are written to the ignored `tools/atlas_review/` directory.
Godot's character creation and gender tests also verify the corrected paths,
absence of corrective materials, stable placement, hit tests, shadows, actions,
and the selection-to-save/load flow. The creation test's `--motion-review`
option renders all twelve frames of each occupation through the real renderer.
