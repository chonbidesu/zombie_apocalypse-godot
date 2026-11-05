# Original Malton, random worlds and coherent artwork

## Starting a world

Normal launch loads **Original Malton**, a 100×100 city containing all original named squares. The Volunteer opens at Anne General Hospital in Dulston. Choose **Restart → Original Malton / Random city / Legacy test neighbourhood** to select a different world and occupation. Restart replaces the live session; saves retain their own world.

Random city supports a seed, width and height (10–100), exact counts for twenty ordinary building categories, and counts for malls, forts, zoos, cathedrals, mansions, power stations and stadiums. Complex counts now use the original Malton plans: malls occupy two, three or four squares; forts nine; zoos twenty; and power stations two or four. Ordinary counts do not include special fort components. Unallocated squares become streets. Population controls set survivor and zombie/body counts. Most zombies begin dormant, with some indoors. Inadequate map capacity or packing space produces an explanation and preserves the existing game. The generator never silently reduces counts.

Original Malton ignores generation counts: geography is fixed, while the seed controls opening population/state. The legacy 10×10 map remains for old saves and focused regression tests.

The map screen shows a local 10×10 suburb view, with **City**, **Find me** and **W/E/N/S** browsing. City shows all named suburbs; selecting one browses its blocks without moving the player. Normal movement crosses suburb boundaries continuously. Discovery still hides unobserved block details. Downed characters retain no map perception.

## Geography and provenance

`assets/maps/malton.json` contains 10,000 unique coordinate records, block names, types, suburb names, complex identities, fort components and zoo membership. It is imported from [IFTClerk's archived map](https://github.com/IFTClerk/urbandead_map/blob/2392369bac6a20e3ea88a912289dc1926f2cd3a0/map.html), which was assembled from the [Urban Dead Wiki suburb maps](https://wiki.urbandead.com/index.php/Suburb). Source commit and raw SHA-256 are recorded in the JSON. No Wiki room descriptions, group commentary or live danger reports are imported. Later EP/RP/MPM/TRP annotations are stripped from place names.

The archive preserves twenty named malls. Eighteen occupy 2×2 squares; Lumber Mall occupies two squares and Pole Mall three in an L shape. It includes **Fort Creedy and Fort Perryn**, each 3×3, and one **Malton Zoo** spanning 5×4 squares. Original mode preserves the archived coordinates; random mode now relocates the same plans, including the exceptional mall footprints and the original fort component layouts. See [connected minimap](connected-minimap.md).

Phone masts come from the Wiki's [Mobile Phone Mast location table](https://wiki.urbandead.com/index.php/Mobile_Phone_Mast), stored separately in `assets/maps/malton-masts.json`. The table's inconsistent Smither Building coordinate is resolved against the named block at [93,35] in Paynterton. All 100 suburbs receive their original mast. Power and fuel are simulated rather than copied from stale online status reports. Generated districts receive one mast on a suitable building where possible. Calling requires coverage for both characters' current suburbs.

The reproducible converter is `tools/import_malton.py` and uses only Python's standard library:

```powershell
python tools/import_malton.py --input path/to/map.html --suburbs path/to/suburbs.txt
```

This copies geographical data from the credited community map; it does not bundle the original game's server or present this simulation as the original online service.

## Multi-block rules and identification

- Humans and zombies can walk between connected indoor mall squares without Free Running. Large indoor complexes share an identity; leaving for outdoor zoo grounds clears the inside state.
- Fort components remain distinct buildings. Perimeter travel is blocked except via the gatehouse. A character must enter the gatehouse before crossing into the compound. Free Running cannot cross the walls.
- The fourteen open zoo squares are unbarricadable. All six enclosure buildings can be barricaded but have no closable doors. Open land, including fort yards, cannot be barricaded. These rules are normalized when loading older saves.
- Office and NecroTech outside/map images are identical. Untrained humans and zombies see ordinary office identification from outside. NecroTech Employment reveals an **NT** logo and lab identification in either form. Interior laboratory equipment remains visible after entering.
- Minimap and field-map tiles now use the connected aerial renderer, shared roads and multiple mall designs. Every large building is cropped across its footprint, with individual lighting and ruin states. Pole Mall has dedicated L-shaped inner-corner artwork. This supersedes the earlier building-card minimap described in the original artwork pass below.

## Artwork

Eighty selected images replace the legacy runtime location/shared occupation artwork: **25 minimap tiles, 25 outside scenes, 21 inside scenes and nine actor atlases**. Office map/outside images are also copied to the NecroTech aliases, making concealment exact. The discarded first street/cemetery variants are recorded as superseded sources; the final terrain icons depict open terrain clearly.

All bitmap generation used the built-in **image_gen** tool with the newly approved artwork and original actor sheets as references. `assets/generated/style-refresh-manifest.json` records exact prompts, reference paths, selected originals and runtime destinations. `terrain-refinements.json` records the final terrain pass. Earlier artwork is documented in `content-expansion-manifest.json`.

Original replaced runtime PNGs are backed up under `.art-backup/`; the historical Python asset tree is untouched. New location PNGs live in `assets/blocks/` and `assets/settings/`. No image-processing script repaints the generated assets. Runtime atlas selection/cropping is implemented with Godot `AtlasTexture`.

Dedicated human/revived actor atlases cover Private, Medic, Scout, NecroTech Lab Assistant, Doctor, Police Officer, Firefighter, Consumer and the revived vagrant/Corpse. Custom Guard/Scientist/Engineer/Volunteer/Resident jobs map to the appropriate canonical appearance. Undead actors retain the original zombie sheet. Every new sheet is a transparent 1536×1024 image with 24 equal cells arranged 6×4:

| Frames | Sequence |
| --- | --- |
| 0–7 | Idle / walking / breathing |
| 8–14 | Attack windup, strike and recovery |
| 15–20 | Collapse / death, ending still |
| 21–23 | Hurt reactions |

The renderer supports both these grids and original 24-frame strips. Existing health-state player portrait atlases continue to work independently.

Rendered review sheets and previews:

- `tests/refreshed-locations-1.png` and `refreshed-locations-2.png`
- `tests/occupation-animation-gallery.png`
- `tests/occupation-crowd-preview.png`
- `tests/malton-start-preview.png`, `malton-city-preview.png`, `world-setup-preview.png`
- `tests/necrotech-recognition-preview.png`, `connected-mall-preview.png`

Run `launch.ps1 -Gallery` to rebuild the artwork previews. Run `-Test` for the complete validation suite.

## Validation and limits

The suite passes **621 assertions**: 114 core simulation, 65 survival, 39 loot/trust, 161 content-expansion, 37 world, 127 existing UI 25 new rendered world/style checks, 38 encumbrance/door checks and 15 environment/inventory UI checks. World checks cover original coordinates/names and footprints, zoo restrictions, gatehouse access, both forms moving inside malls, suburb boundaries, skill recognition, exact seeded generation, invalid-request isolation and full-city save/load. Rendered checks cover world setup controls, shared office/lab art, NT logo visibility, connected mall crop boundaries, irregular footprints and distinct occupation sheets. All 216 new actor cells are populated and the sheets retain alpha transparency.

On this machine the default 100×100 generated city with 901 actor records built in about 0.28 seconds; advancing its first three simulated minutes took about 0.03 seconds headlessly. These are local regression measurements, not a guarantee of long-term balance or dense-horde performance. City population and basic NPC tactics remain tunable. The game is local and single-player, with no city server messaging, campaign or imported historic player profiles.

Version-three saves include dimensions, mode, generator configuration, geography provenance, original names and complex identities alongside simulation state. Version-one/two 10×10 saves remain supported; loading an old save does not replace its map with Malton.
