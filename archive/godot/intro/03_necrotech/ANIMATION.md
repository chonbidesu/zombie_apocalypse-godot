# Single specimen tube — six frames

`specimen_tube_animation-v1.png` is an RGBA sprite sheet, 887 × 1774, three columns by two rows. Read left to right across the upper row, then across the lower row. Each frame is one complete tube, about 295.667 × 887 pixels. Fractional atlas coordinates preserve the generated sheet without resampling.

Use `specimen_tube-v1.tscn` as an AnimatedSprite2D, or assign `specimen_tube_frames-v1.tres` to your own node. Animation `float` has six frames, loops at 3 fps, and lasts two seconds. The main intro preview's NecroTech scene now plays this single tube over the existing laboratory background.

The hunched adult male is viewed from behind, with mottled decaying skin, a few spinal and side biomechanical ports and hoses, bubbles and an eerie upward green light. The image generator rejected the original nude request; the delivered alternative obscures the pelvis in murky fluid. The shell and reflections vary slightly between generated frames, so the animation has some casing jitter; it is not a pixel-locked production loop. No frame-by-frame stabilization has been applied.

The sheet and its six poses were visually inspected; dimensions and alpha range (0–255), atlas regions, file references and browser JavaScript syntax were checked. Playback in Godot remains untested. The original three-tube assets are preserved.

Generated using built-in image_gen. The delivered prompt and animation metadata are in `specimen_tube_animation-v1.json`.
