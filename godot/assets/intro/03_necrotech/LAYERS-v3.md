# Three-layer specimen revision — v3 (partial)

Delivered layers:

- `specimen_casing-v2.png`: existing static tube, 887 × 1774 RGBA. Outside silhouette is transparent; empty chamber retains green glass and underlight. Reused unchanged.
- `specimen_bubbles-v3.png`: new RGBA bubble-only sheet, 887 × 1774, six frames arranged 3 columns × 2 rows, read left to right then top to bottom. Two columns per frame. Alpha ranges 0–247; transparent pixels are present. Native cell widths are 296, 295, 296 pixels, each 887 pixels tall.
- `specimen_bubbles-v3.tres`: Godot SpriteFrames resource, looping `rise` at 6 fps, atlas regions cover all six cells. Generated bubble shapes/spacing vary between frames; a perfectly matched seamless cycle is not verified.

The requested single-frame nude undead body is NOT delivered: built-in image generation rejected that depiction. The existing v2 body sheet is unchanged and is not a replacement for the missing static transparent body.

Suggested composition: static tube behind static body, then animated bubbles in front. Fit body and bubbles inside the tube viewing chamber (approximately x=170–720, y=285–1380 in the tube image). Because the generation used different sheet proportions than requested, scale the bubble layer to fit the chamber. Preserve the separate tube/body layers when animating bubbles.

The intro and its existing v2 scene remain unchanged because the revised three-layer set is incomplete. `prompts-v3.json` records the exact prompts, metadata, and rejected body status. Built-in image_gen was used; no CLI fallback or alpha-key shader was used for the new bubble PNG.

