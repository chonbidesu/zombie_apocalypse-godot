# Single specimen, fixed casing — version 2

`specimen_tube-v2.tscn` combines one stationary casing with six animated content frames. Instance this scene to use the complete animated tube. The casing, cap, base, glass-side reflections and underlight are rendered from the SAME unchanged image at every frame, eliminating casing animation wobble by construction.

- `specimen_casing-v2.png`: 887 × 1774 RGBA stationary tube.
- `specimen_body_frames-v2.png`: 1086 × 1448, 3 columns × 2 rows. Six exact 362 × 724 cells in row-major order. Adult nude male specimen, rear view only, with mottled decay, bowed posture, spinal/side ports and flexible hoses. No frontal nudity or obscuring pelvis cloud.
- `specimen_body_frames-v2.tres`: six-frame looping SpriteFrames, 2 fps / three-second cycle.
- `specimen_contents-v2.gdshader`: removes the near-white source backdrop at render time. Required: source PNG did not receive usable cutout alpha, and a subsequent image-generator extraction request was rejected. White source pixels are preserved in the PNG; this is not a standalone transparent content sheet.

Only the body, attached hoses and bubbles change frames. No scale, position, color or brightness animation is applied to the casing. Content frames have natural generated pose/detail variation; casing is nevertheless identical. The scene fits animated content within the fixed viewing chamber. In-game shader playback is not yet tested.

The main intro preview now uses the stationary casing and animates only the content sheet. For direct local-file browser compatibility it uses multiply blending to suppress the white backdrop, so its content is darker than the Godot color-key shader's output. Use the Godot scene for the intended runtime transparency.

Generated with built-in image_gen. Prompts are in `prompts-v2.json`. Both images were visually inspected, dimensions checked, six atlas regions verified and preview JavaScript syntax checked. Previous versions remain available.
