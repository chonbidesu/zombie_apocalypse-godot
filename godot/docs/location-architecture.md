# Neighbourhood architecture

Repeatable locations use three architectural families: the original stone civic
buildings, brick/timber/copper heritage buildings, and Art Deco/postwar buildings.
The same coordinate and world seed select the minimap, interior and exterior.
The selection is independent of names, power, ruin, actors and simulation RNG.
It works for Malton, generated cities, the sandbox and existing saves without
adding fields to the save format.

`scripts/location_architecture.gd` places jittered district centres about six
blocks apart and chooses the nearest centre's style. Roughly one block in eleven
uses another family as an infill/redevelopment site. This produces small coherent
neighbourhoods with occasional contrasting buildings rather than a checkerboard
or independent random designs on every tile.

All ordinary building types except malls participate. NecroTech map/exterior art
continues to share the matching office design; its interior remains a laboratory.
Parks, cemeteries, monuments, carparks, wasteland and street backgrounds also vary.
Street minimaps retain their six existing road-compatible sprites, grouped into
pairs by neighbourhood style. Open land has no artificial indoor/power/repair
mechanics. Junkyards also reject generators and always select unpowered map art.
Unused atlas lighting columns for open land/junkyards are never selected by the
game, including state previews. Malls, cathedral/mansion/power-station/stadium landmarks, forts and zoo
properties retain their existing art and continuous multi-square footprints.

Hospitals use red cross signs, red facade bands and red interior markings. Police
stations use blue bands, blue entrance canopies and shield emblems. Fire stations
have red apparatus doors, garages orange doors/wrench symbols, warehouses yellow
loading doors and factories yellow safety rails. The original civic resource trio
is refreshed as well so all three families carry the identification colors.

## Assets

`assets/architecture/map-STYLE-GROUP.png` is a four-column, three-row RGBA atlas.
Rows follow `LocationArchitecture.GROUPS`; the tower/park/cemetery sheets use
40%/28%/32% row heights to accommodate the taller tower. Columns use the runtime order:

1. Repaired, unlit.
2. Repaired, lit.
3. Ruined, unlit.
4. Ruined, lit.

Every state is authored artwork. Both ruin states have visible structural damage;
lighting does not restore the building. New single-square map models use 384px
textures and keep consistent cell bounds across states. Existing complex models
retain their 768px textures. Shader regions use the actual texture size.

`assets/architecture/settings-STYLE-GROUP.png` has exterior/interior columns and
three building rows. `settings-STYLE-extra.png` has a laboratory interior above a
street exterior. AtlasTexture regions are cached and filter-clipped.

There are 36 project-local PNG atlases generated with the built-in imagegen tool.
Style 0 ordinarily uses the original assets, except the refreshed resource trio
in group 0. Styles 1 and 2 supply the two new versions. The exact built-in imagegen
prompts and source paths are in `assets/generated/architecture-manifest.json`.

## Validation

Run Godot with `--headless --path godot --script
res://tests/location_architecture_test.gd` after importing assets. The test checks
all repeatable types, states and settings, distinct map pixels, neighbourhood
coherence, seed sensitivity, landmark exclusions, lab disguise, power/ruin state
selection, unchanged gameplay RNG and save/load stability.

`tests/location_architecture_gallery.gd` renders the three resource-building
families, their four map states, matching scene panels and a neighbourhood map.
The existing connected-minimap and environment UI tests cover complex seams,
property layouts, roads, depth and the environment/actor layout.

Validated on 10 November 2026: 795 architecture checks, 431 environment rule
checks, 126 ruin/AP-debt checks and 15 environment/inventory UI checks pass.
The connected-minimap suite also passes with no failures. At seed 1729 the three
styles cover 3,342 / 3,422 / 3,236 coordinates, with 73.5% adjacent agreement.
All 36 manifest destinations exist. The resource and neighbourhood galleries
were rendered and visually inspected in Godot.
