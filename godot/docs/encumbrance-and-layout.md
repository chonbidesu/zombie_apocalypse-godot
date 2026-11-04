# Encumbrance, grounded sprites and open locations

## Environment and controls

The environment view is 1016×572 in the 1440×960 design. Godot fits the full source image with its aspect ratio preserved, replacing the short vertically cropped view. Portrait/status and minimap positions remain on the left. Rest controls sit immediately below the portrait, with recovery timing beneath. Inventory follows at y=720. Contextual actions occupy compact rows below the image, followed immediately by the activity feed.

Sprites stand near the bottom of the full environment image. Their feet are aligned per animation frame using opacity measurements in `assets/tables/actor_frame_bounds.json`. These measurements read the existing PNGs; no generated image was repainted. The renderer offsets each frame to keep its visible foot baseline stable and draws a subtle ground shadow. Crowds retain their depth stagger, inward facing and short red health bars.

Inventory displays ten items per page, independently of carrying capacity. Previous/Next reveal all items; paging clears an off-page selection. Consuming/dropping items clamps the current page when necessary. Every slot's tooltip shows its name and percentage weight. The header shows total encumbrance. The existing context menu and Equip/Give/Drop controls work for items on later pages too.

## Carrying rules and sources

The [official 6 March 2007 update](https://urbandead.com/oldnews.html) describes the acquisition threshold: at 100% or greater, characters cannot collect further items. The implementation checks the load before acquisition, allowing a final find below the threshold to take the total over 100%. With the current even-percentage weights the ordinary maximum reached this way is 118%. Overload does not delete belongings or prevent dropping, using or installing carried equipment.

Individual weights come from the Wiki's [Useful Items](https://wiki.urbandead.com/index.php/Useful_Items), [Melee Weapons](https://wiki.urbandead.com/index.php/Melee_Weapons), [Firearms](https://wiki.urbandead.com/index.php/Firearms), [Miscellaneous Items](https://wiki.urbandead.com/index.php/Assorted/Misc_Items) and [Decorative Items](https://wiki.urbandead.com/index.php/Decorative_Items) pages. Every one of the 53 catalogue entries has an explicit `encumbrance` field.

| Percentage | Items |
| --- | --- |
| 0% | Stale candy; one bag maximum |
| 2% | Baseball bat, knife, pistol magazine, shotgun shell, first-aid kit, syringe, flare gun, flak jacket, GPS, mobile phone, spray can, books, poetry, newspaper, crucifix, beer, Christmas lights |
| 4% | Pistol, crowbar, pipe, cricket bat, fencing foil, golf club, hockey stick, pool cue, ski pole, tennis racket, binoculars, DNA extractor, radio, wine |
| 6% | Fire axe, shotgun |
| 10% | Fuel can |
| 16% | Toolbox |
| 20% | Portable generator, radio transmitter, museum/decorative pieces, pumpkin, tinsel, either Christmas tree |

Three existing local additions need local assignments: shovel 4%, paper city map 2%, and a carried clothing bundle 2%. Wearing the bundle consumes it and its outfit description adds no encumbrance. These values are adaptations rather than claims about original Urban Dead items. Skeletons represent whole museum skeletons, not the lighter skull variant, which is not a separate catalogue entry.

Loaded ammunition adds no weight beyond the firearm; spare magazines and individual shells each weigh 2%. Reloading consumes a spare item and frees its encumbrance. All carried equipment counts, including equipped weapons and a flak jacket. Candy is reusable, zero-weight and limited to one bag. Only one Christmas tree of either type may be acquired at a time.

Flashlights weigh 2% and can be inspected.

Searches, syringe manufacture, gifts, supply requests and NPC supply planning use percentage capacity. A separate hard ceiling of 100 item instances also prevents collection; searches at that ceiling are rejected before AP or RNG is spent. A single validated transfer can cross the threshold; later acquisitions are blocked. Initialization/test fixtures retain a low-level item-adder, while player and NPC actions validate carrying rules. Saves retain item instances and derive their load from current catalogue definitions. Existing overloaded saves are preserved intact and can use/drop items to make room.

## Barricades and doors

Based on [Building Types](https://wiki.urbandead.com/index.php/Building_Types) and the user's clarified rules:

- Streets and named roads/squares/lanes, parks, cemeteries, wasteland, monuments, carparks, fort exercise/training grounds and open zoo land have no barricadable entrance.
- The original zoo has fourteen open squares and six enclosure buildings. Only the open squares are unbarricadable. The generator's 4×4 zoo has ten open squares around the same six enclosures.
- Churches, cathedrals, fort gatehouses, junkyards and all six zoo enclosures can be barricaded but have no closable door. Junkyards retain their fence-hole description.
- Once barricades are gone, an untrained zombie can enter a doorless structure for the normal one movement AP. Closed ordinary doors require Memories of Life; the combined open-and-enter action costs two AP. Closing a nonexistent door is unavailable.

World creation and save loading normalize these structural rules from each block's type. This corrects the earlier whole-zoo prohibition and stale door flags in existing saves, and removes impossible barricades from outdoor land. The imported source map converter produces the same corrected zoo flags as the bundled data.

## Verification

`launch.ps1 -Test` passes 621 assertions. The new checks cover heavy versus small loads, inventories larger than ten, threshold crossing, immediate capacity recovery, loaded ammo, uniqueness rules, transfers/manufacture, overloaded save/load, every outdoor and doorless category, zoo enclosure eligibility, entry AP, full-height fitting, animated foot alignment, page selection/drop/clamping and downed darkness.

Rendered examples: `tests/malton-start-preview.png`, `tests/occupation-crowd-preview.png`, `tests/encumbrance-inventory-preview.png` and `tests/full-height-downed-preview.png`.
