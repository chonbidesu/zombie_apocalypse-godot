# Intro art revision 2

Four revised layers were made with built-in image_gen editing. Originals remain available without the `-v2` suffix. The manifest and animated preview now select the revised files. Exact edit prompts are in prompts-v2.json.

| Layer | Revised asset | Native dimensions |
| --- | --- | --- |
| Office | 01_before/office_facade-v2.png | 1024 × 1536 |
| Security perimeter | 02_quarantine/soldiers-v2.png | 2172 × 724 |
| Specimen tubes | 03_necrotech/specimen_tubes-v2.png | 1671 × 941 |
| Corpse awakened | 05_corpse/body_open-v2.png | 1670 × 941 |

The office includes rooftop equipment and parapet, four ordinary floors, and a broad transparent lab opening on the next floor. Sky above the roof and the lab opening have actual alpha transparency. At a logical width of 1920, display this layer at height 2880, not stretched into a 1080-high frame. Its window opening is approximately native x=226..795, y=1199..1404. Put the lab plate over a black backing at native rectangle (223,1196,577,212), behind the facade, and keep all three in one parent. The preview moves this parent from y=1094 to about y=-1898 over nine seconds, then flickers the light. The roof enters first, followed by the upper floors and finally the lab window.

The perimeter now has twelve soldiers and a much longer barrier line. Keep its 3:1 aspect ratio. The preview starts at logical 1920 × 640 with top at y=378, then zooms to 1.8× around a lower-centre anchor. The existing street and civilian art are unchanged. For a unified production camera move, coordinate background and foreground scales with this middle layer; the preview emphasizes the new middle-layer zoom.

The three adult specimens are unclothed, seen strictly from behind, with visible early decay on backs and limbs. Tanks remain a single transparent layer.

The corpse's open-eye state now has wide milky eyes and a tense, hungry stare. Retain the existing face-only transition over the closed-eye body, normalizing both source canvases to the same logical frame. Do not replace the whole body during the eye animation: small texture differences remain outside the face in the generated edit.

Validation: all four revised PNGs decode and have genuine transparent regions. The facade's maximum alpha is 254/255; the other revised layers reach 255. These revisions were inspected individually. Preview references and JavaScript syntax were checked; in-engine animation remains untested.
