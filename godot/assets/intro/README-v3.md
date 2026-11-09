# Facade revision 3

Current asset: `01_before/office_facade-v3.png`, 845 × 1862 RGBA. Created with built-in image_gen editing; exact prompt in prompts-v3.json. Earlier versions remain available.

The roof and existing architecture are retained. The fifth-floor lab opening is now a single narrow window matching adjacent windows, with four complete floors below it. The bottom continues as facade with no ground or pavement.

The transparent interior is approximately x=349..417, y=986..1082 in native coordinates. Place the lit lab and black backing behind the facade in rectangle (347,984,73,101). Crop the lab image to fill this tall window rather than stretching it. Move all three together.

At logical width 1920 the facade is about 4231 pixels tall. The updated preview moves it from y=1080 to about y=-1863, placing the window centre near y=486. Its lower edge remains at approximately y=2367, well below the 1080-pixel viewport bottom. This supplies continued facade beneath the window throughout the descent and stop.

The manifest and preview select v3. All other layers are unchanged. The image was visually inspected and alpha checked (0–255); preview JavaScript syntax and bottom-edge coverage were checked. In-engine animation remains untested.
