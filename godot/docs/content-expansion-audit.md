# Urban Dead content expansion audit

The subsequent [world and art refresh](world-and-art-refresh.md) supersedes the first expansion’s test-district geography, shared actor-sheet mappings and local-only map scope described below. Current builds include original Malton, configurable random cities, connected mall artwork and dedicated occupation atlases.

Research checked against the Urban Dead Wiki and official FAQ, 3 November 2026. The Wiki documents an evolving online game; the prototype intentionally preserves the user's requested balance and rules where these differ.

## Reference material

- [Building Types](https://wiki.urbandead.com/index.php/Building_Types): normal buildings, large structures, forts, zoo and outdoor categories.
- [Items](https://wiki.urbandead.com/index.php/Category:Items), [Useful Items](https://wiki.urbandead.com/index.php/Useful_Items), [Melee Weapons](https://wiki.urbandead.com/index.php/Melee_Weapons), [Miscellaneous Items](https://wiki.urbandead.com/index.php/Assorted/Misc_Items) and [Decorative Items](https://wiki.urbandead.com/index.php/Decorative_Items).
- [Civilian skills](https://wiki.urbandead.com/index.php/Civilian_skills), [Military skills](https://wiki.urbandead.com/index.php/Military_skills), [Science skills](https://wiki.urbandead.com/index.php/Science_skills), [Zombie skills](https://wiki.urbandead.com/index.php/Zombie_skills) and [Headshot](https://wiki.urbandead.com/index.php/Headshot).
- [Official FAQ](https://urbandead.com/faq.html): occupation-dependent XP pricing.

## Coverage

The game now has 37 indoor building categories and nine outdoor categories. Existing office art represents the Wiki's generic Building; nightclub and pub represent Club and Public House. Added cathedral, mansion, power station, stadium, six fort buildings, six zoo enclosures, wasteland, fort exercise/training grounds and zoo grounds. Large churches reuse church art; multi-block structures use a shared complex identity. Fort perimeter movement passes through its gatehouse. The compact test neighbourhood arranges these for access and testing and is not an authentic map of Dulston. Large mall and church layouts can use the same complex mechanism, though the current showcase does not allocate separate multi-block examples of each.

The 53-item catalogue adds missing sports weapons and pipe, flare guns, protective clothing, communications, tools already present as unused assets, books/drinks/miscellany, generic clothes and representative decorations. Added artwork: pipe, cricket bat, foil, pool cue, ski pole, flare gun, flak jacket, phone, receiver, transmitter, spray can, glass, painting, pottery, sculpture, skeleton, statue, stuffed animal, tapestry, Christmas lights, fir tree, plastic Christmas tree, pumpkin, tinsel and clothing. Existing art supplies DNA extractor, binoculars, GPS, maps, drinks, reading matter, candy and crucifix.

Wirecutters are retired gameplay equipment and omitted. Video cameras were specific to Monroeville and are omitted from this Malton-style catalogue. Every named garment, holiday costume, decorative material, museum artwork title and cosmetic variation is not a separate item or generated image. Clothing records an outfit description; it does not redraw the full-body shared sprite sheet.

All 45 skill entries have prerequisites and runtime behavior; their authoritative local definitions are `../scripts/catalog.gd`, with a JSON mirror in `../assets/generated/skill-catalogue.json`. Purchases respect occupation prices and Headshot's level requirement. The two skill trees can still be bought in either form, preserving the prior prototype behavior. Cross-form passive exceptions are explicit in `has_skill`.

## User-directed differences and local adaptations

- Zombies only use hands and bites, even though historic Urban Dead allowed some carried melee attacks. Melee breakage and generator damage/repair use the user's requested survival mechanics.
- Search tables now contain conditional loot weights. A separate state-based find roll precedes item selection; Shopping targets mall stores and Bargain Hunting doubles intact mall yield. Ruins use a flat 10% total instead of multiplied near-zero odds. See [search rules](search-rules.md).
- Safehouse scouting costs 30 AP and discounts five subsequent actions by one AP per day. There is no server IP-hit accounting or group system.
- Scents provide a local text intelligence report; no cross-city group scent direction exists. Scent Trail records recent hostile contact for one game hour, within ten blocks. DNA tags last one day; NecroNet reports tags within four blocks.
- Groans draw simulated zombie attention according to nearby prey, with an ordinary maximum radius of six blocks. Bellow costs ten AP and reaches ten blocks when faced with at least 25 survivors; otherwise it falls back to a normal groan. The normal opening population cannot reach the 25-prey threshold without sandbox changes.
- Radio frequencies, local receivers and powered installed transmitters work inside this simulation. Radio Operation unlocks restricted 26–28 MHz. Phones connect simulated contacts when both carry handsets and the neighbourhood mast has power. Neither sends real messages or reaches other game servers.
- Flak and Flesh Rot are nonstacking firearm protection. Brain Rot needs a powered lab and NecroNet for revival. Headshot adds five AP to standing; it never permanently deletes a character.
- Generic clothing, decorations and holiday loot provide representative interactions, without calendar events or cosmetic variant proliferation. Readable newspaper and poetry text is original, not copied from the Wiki.

## Art and animation

All new bitmap art was generated using the built-in `image_gen` tool with the original assets as references. The canonical prompt/source/destination manifest is `../assets/generated/content-expansion-manifest.json`. Generated art is selected and copied into runtime assets; originals remain recorded by absolute source path. These are style-matched new illustrations, not hand-edited copies of the original sprites. Some atlases retain pale backdrop/edge pixels from generation.

Nine 5×5 portrait atlases cover Private, Medic, Scout, NecroTech Lab Assistant, Doctor, Police Officer, Firefighter, Consumer, and Corpse. The last is a wild-haired survivor with its own undead equivalent. Canonical occupation identity stays unchanged through death/revival, selecting the appropriate frame within the same atlas.

Atlas frames, row-major: healthy 0–4; injured 5–9; critical 10–14; dead 15; undead 16–24. Healthy/injury rows animate breathing. The dead frame never advances. Undead frames use a cosmetic schedule of variable rests, jerks and recovery poses. Portrait cell dimensions are derived from each atlas rather than assuming one output resolution.

Existing full-body actor sheets contain 24 frames: eight idle, seven attack, six death and three hurt. They are now selected by action events. Human occupation groups still share these original full-body sheets; this task adds unique player portraits rather than nine new combat sprite sheets. Zombie idle stepping runs at three ticks per second with repeated holds, versus human five-frame-per-second motion, and crowd placements stagger and overlap.

Ninety PNGs: 25 item icons; 16 new indoor types × three images = 48; four new outdoor types × two = eight; nine portrait atlases. Outdoor sites have no fictitious interior image. Godot-generated contact sheets show every new asset and can be rebuilt with `launch.ps1 -Gallery`.

## Validation

`launch.ps1 -Test` runs 114 core simulation, 65 survival, 39 loot/trust, 161 content-expansion and 127 rendered UI assertions: 506 total. The gallery additionally loads and renders all 90 new assets. The new checks cover prerequisite purchase paths, XP categories, human/zombie attack stats, exclusive grasp ownership and seeded miss release, infection/healing, armor nonstacking, scouting quota, DNA tags, radios, phones, graffiti/decorations, mall shopping, ruined searches, fort entry, content assets, save/load, nine occupation starts, portrait injury/death/form frames, attack/hurt/death sequences, slow zombie gait and the complete skill interface.

These checks verify mechanics and regression invariants. Search rates, AI choices, encounter pacing and the visual consistency of generated art still benefit from ordinary playtesting.
