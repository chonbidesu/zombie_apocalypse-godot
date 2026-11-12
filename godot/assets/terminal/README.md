# NecroTech intake terminal

Three 1536 × 1024 RGBA assets generated with the built-in image generator. Exact generation and revision prompts are in `generation-prompts.json`.

| File | Purpose |
| --- | --- |
| `necrotech_terminal.png` | Fixed dusty chassis and dark glass; composite over black. |
| `record_ascii_frame.png` | Transparent blue PETSCII-style skull and record border, without baked-in text. |
| `screen_dust.png` | Transparent dust/scratch overlay; center pixel alpha is zero. |

The final frame revision has crisp strokes when composited using its alpha channel. Preserve RGBA transparency when exporting these files.

## Godot composition

Open `res://naming_screen.tscn` to preview, or enter through New Game → character selection → naming.

Layers from bottom to top:

1. Black background.
2. Static chassis, on a 1536 × 1024 design canvas.
3. Record frame, only during confirmation.
4. Live blue monospace prompt/input/confirmation controls.
5. Dust overlay at 55% opacity.
6. `terminal_glass.gdshader`: translucent scanlines, blue edge light, a rolling band every seven seconds, and a brief subtle flicker every eleven seconds.

The glass area is `Rect2(220, 130, 1096, 674)`. The full canvas scales uniformly and centers in the window. The chassis uses its own material pass to keep it visible when the record texture appears in the Compatibility renderer.

The command prompt uses drive Z:. Enter submits each field, then opens the recovered-record screen. Enter again confirms. Escape from confirmation restarts at the first prompt, preserving all entries and placing the cursor at the end of the first name. Revisiting any field places its cursor at the end without selecting the text. During intake, Escape edits the previous field or returns to character selection from the first field. Each field accepts up to 32 characters and rejects whitespace-only input. Names remain editable text and are never rasterized into artwork.

Confirmation emits `{first, last, adjective}` to the existing start-screen flow. The game uses first + last while alive and adjective + first after death; the existing game save/load preserves these fields. This does not overwrite a game save during character creation.

The existing reduced-motion option disables moving bands and flicker. Static glass texture and the input caret remain. Font fallback order is Consolas, DejaVu Sans Mono, Liberation Mono, monospace; no proprietary font is bundled.

Audio uses the existing `naming 1.mp3` through `naming 4.mp3`, in prompt/record order, with the previous named clips as fallback for the first three fields.

## Validation

`res://tests/naming_screen_test.gd` exercises actual Enter/Escape input, validation, revisiting fields, review-before-acceptance, duplicate acceptance prevention, longest names, reduced motion and window fitting. Rendered captures include a check that the chassis remains visible.

`res://tests/start_screen_test.gd` covers integration into the intro and gameplay, living/undead display names, and save/load.

Rendered previews: `res://tests/terminal_intake_preview.png` and `res://tests/terminal_record_preview.png`.

Verified on Godot 4.7.2: 24 rendered naming checks pass, including restarting at the first prompt and immediately typing at the retained name's end. The earlier 61 start-screen integration checks also passed. The engine intermittently reports retained MP3 playback resources at process shutdown; the integration diagnostic identified gameplay music (`tunnel.mp3`). This shutdown warning remains unresolved.
