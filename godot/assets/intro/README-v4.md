# Facade revision 4

Current art: `01_before/office_facade-v4.png` (845 × 1862). Same tall building, rooftop and continuing lower floors. Five individual single-pane window bays per floor, separated by substantial concrete columns. No warm interior lights: the windows show cool exterior reflections.

The lab is behind the centre fifth-floor pane, native rectangle (375,1030,99,112). Place the lab image and a black backing behind that rectangle, cropping the lab image to fill. The glass reflections remain in front while the lab brightness flickers on. All other windows remain dark.

**Glass transparency is supplied by a material, not baked into the PNG.** Image generation did not reliably produce the requested partial alpha. Apply `01_before/window_glass.tres` to the facade Sprite2D or TextureRect. It uses `window_glass.gdshader` to multiply only the target pane's alpha by 0.28; adjust `glass_opacity` as needed. The rest of the facade and transparent rooftop silhouette retain their source alpha. Use the full texture without atlas trimming because the shader uses normalized full-image coordinates.

The browser preview uses equivalent clipping and 28% opacity on the pane's reflection texture. It stops the descent with the pane near y=486 in a 1920 × 1080 frame; the lower facade continues beyond the bottom. The preview and manifest select v4. Prior accepted versions remain available. `office_facade-v4-glass.png` is an unsuccessful generator transparency attempt, not the active asset.

Generated with built-in image_gen; both edit prompts are in prompts-v4.json. PNG dimensions and source alpha were inspected and preview JavaScript syntax checked. The material has not yet been tested in the running game.
