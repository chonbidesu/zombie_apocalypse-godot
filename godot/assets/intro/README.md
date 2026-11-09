# Malton intro art pack

**Current specimen animation: v2.** Rear-view nude specimen with six content frames and one fixed casing, removing casing wobble. Use [03_necrotech/ANIMATION-v2.md](03_necrotech/ANIMATION-v2.md) for the scene, shader and preview details.

**Current NecroTech concept:** One specimen tube with six animation frames. The preview plays the new loop; Godot resources and limitations are documented in [03_necrotech/ANIMATION.md](03_necrotech/ANIMATION.md).

**Current facade: revision 4.** Single-pane bays between concrete columns, unlit reflective glass, and a lab-pane transparency material. See [README-v4.md](README-v4.md); it supersedes earlier facade instructions.

**Facade revision 3:** The current office layer has a standard-size transparent window and four floors beneath it. [README-v3.md](README-v3.md) supersedes earlier facade dimensions and placement instructions.

**Revision 2:** The current preview and manifest use four updated layers. See [README-v2.md](README-v2.md) for the tall roof-to-window facade, panoramic security line, revised specimens and awakened corpse. Its dimensions and motion instructions supersede the corresponding original notes below.

28 PNG assets generated with the built-in image_gen tool. Detailed muted cinematic pixel illustration. All eight playable human occupations have unique environment and transparent foreground assets. This pack supplies art and a browser preview; the game's intro flow has not been changed.

Open **preview.html** locally in a browser to inspect layered scenes, replay the skyline descent and window light, or trigger Rise. No server or dependencies required. Text remains separate from artwork. Exact supplied copy is in manifest.json. Full generation/edit prompts are in prompts.json.

## Files and stacking

Paths below are relative to this folder. Stack back to front.

| Scene | Layers |
| --- | --- |
| 1 Before | 01_before/skyline_far.png, skyline_mid.png, then a moving office group containing lab_window_interior.png behind office_facade.png |
| 2A Outbreak | Solid black engine ColorRect; no bitmap necessary |
| 2B Quarantine | 02_quarantine/background.png, soldiers.png, civilians.png |
| 3 NecroTech | 03_necrotech/background.png, specimen_tubes.png |
| 4A Survivor | 04_origins/{occupation}/background.png, foreground.png |
| 4B Corpse | 05_corpse/background.png, body_closed.png; body_open.png is the Rise variant |

Occupation folders: private (barracks), medic (field treatment tent), scout (rooftop observation room), necro (research workroom), doctor (hospital), police (precinct changing room), firefighter (fire station locker room), consumer (shopping centre).

## Coordinates and motion

Use a 1920 × 1080 logical frame. Native plates are 1672 × 941 except body_open.png (1671 × 941). These are near 16:9, not native 1080p. Set all full-frame textures to the SAME destination rectangle. Do not trim alpha margins or independently fit to visible content.

For gentle pans, enlarge full-frame layers to 108% around centre before translation. At 1080p, keep background movement within ±10 px, middle within ±24 px, and foreground within ±42 px horizontally (vertical motion roughly half these values). The extra image area is obtained by cropping into the supplied canvas, not extra painted pixels beyond it. These plates are not seamless or suitable for continuous scrolling. Nearest filtering emphasizes pixels; linear filtering softens fractional scaling.

Scene 1: far skyline moves slowly; mid rooftops move faster. Place the facade and lab in one parent. Animate that parent from y=1080 to y=0 over about 6 seconds, easing to rest. Fit the lab plate into the facade window rectangle, approximately x=435, y=290, width=1055, height=500 in logical 1920 × 1080 coordinates, with a black rectangle behind it. Keep lab and facade locked together. Start the lab dark, then flicker brightness through 0.04, 0.65, 0.08, 1.0 over about 0.5 seconds. The facade's central opening has real alpha; the black rectangle prevents the skyline showing through the unlit window.

Scene 2A: fade to black and display the two sentences in sequence. No parallax.

Scene 2B: pan background, soldiers and civilians at different rates. Keep civilians in front. Suggested slow 8-second drift, then hold for reading.

Scene 3: room background drifts slowly behind the tank layer. All three tanks are in one transparent PNG, so they move together. Optional light pulse can be done with engine modulation.

Scene 4A: room drifts at 0.2× the foreground speed. Hold as long as the player needs. Add a dark translucent text panel or scrim for readability.

Scene 4B: use slow background/body parallax, stop motion at Rise. The eye-open variant retains the composition but is AI-edited and is not pixel-identical outside the eyes. Normalize both frames to the same logical rectangle, and reveal only the face area of the open variant with a soft mask (approximately x=74%, y=31%, width=13%, height=18%) over the closed frame. This prevents sheet/gurney texture changes during transition. The browser preview demonstrates a face-only clip; production can use a soft shader mask. Hold about 0.8 seconds before fading into gameplay.

## Validation

All 28 files decoded successfully. All 15 requested alpha layers contain fully transparent and fully opaque pixels. The office window centre has alpha 0. Dimensions and alpha ranges are recorded in validation.json. Generated assets were visually inspected individually; final game integration and in-engine motion are still to be tested. Minor generated edge fringes may need art cleanup if visible with the chosen engine filtering.

