# Environment, damage and recovery

All 46 location types have randomized environmental descriptions. NecroTech interiors use fixed logo wording in the third sentence for each power state. A local seeded RNG preserves stable descriptions without advancing simulation randomness. Description version 6 migrates old saved prose.

Outside NecroTech laboratories use the same three sentences as offices. NecroTech Employment replaces only the third sentence with logo recognition. Inside, everyone sees science equipment and computer rooms, with a third sentence identifying the logo. Running power selects the glowing logo sentence. Street descriptions and map tooltips describe the entrance first, reveal ransacking through an open entrance, and show ruins regardless of the entrance state. A powered building shows lights as the final building clue. Inside, running power is reported by the generator sentence, and only dark buildings describe an unpowered interior as pitch black.

## Damage and generators

Five successive 1-AP ransacks leave a building ransacked; the sixth action becomes Ruin building. Only the first hit awards 1 XP. Living survivors prevent ransacking. Ruin clears all scouting bonuses for that location, prevents barricading, and applies the ruined Free Running rules. Existing barricades can survive ruin. Junkyards and all six zoo enclosures cannot be ransacked or ruined; old incompatible damage is cleared during initialization.

Anyone can Repair the room after standing zombies are cleared, spending 1 AP to remove ordinary ransacking. Structural repair requires Construction and a toolbox, awards 1 XP, preserves the toolbox, and clears the ruin in one action. It costs 1 AP plus 1 AP per complete 24 hours since ruin, without a cap. Saved timestamps preserve decay.

Generators can be installed and fueled in eligible ruins. Open ground, fort yards, junkyards, stadium fields and both municipal power stations cannot host or run them. Banks, cinemas, nightclubs, fort armouries and mall sections are dark buildings: an unpowered dark ruin requires a running generator before structural repair. Other unlit buildings do not have this repair restriction. Darkness halves barricade success only in those five types; zombie interference remains a separate modifier. No-door types cannot Close doors, including junkyards, churches, cathedrals, gatehouses and zoo enclosures.

Powered ruins use new artwork showing broken structures with surviving electric lights, including each mall style and both fort properties. Each complex square chooses its state independently. Zoo enclosure ruin art and all junkyard lit/ruin states are unused. Generation prompts, source images and installed paths are recorded in [the image manifest](../assets/generated/powered-ruin-manifest.json).

## AP debt and Sleep

A player with at least 1 AP may commit a multi-AP action even when it overdraws their current energy. Negative AP survives save/load and regenerates at 1 AP per 30 game minutes. Further positive-cost actions require AP above zero. NPCs normally reject unaffordable actions; explicit exceptional callers can opt into debt.

Sleep replaces Rest to 50 AP, accelerates time to 128 times normal, and blacks out the scene, minimap, inventory and activity feed. It ends at 50 AP, on manual Wake/Escape, when the last barricade collapses locally, or after two successful injuries within ten game minutes. An isolated hit, nearby enemy, speech, ordinary pounding or partial barricade damage does not interrupt it. Death also ends sleep. Ordinary Rest +10 remains at 16 times speed with danger interruptions. Fast-forward stops spending its pending accelerated slice immediately after a wake-up.

## Display

The interface targets 1920 by 1080. The window defaults to 1536 by 864, scaling the same layout to fit the desktop. F11 or Full screen toggles full-screen mode. The minimap and inventory remain left, the full scene is in the middle, the environmental description sits below it, actions follow the description, and a 460-pixel dialogue/activity column occupies the right side. Menus remain centered and block underlying input.

Validation: `environment_rules_test.gd`, `ruin_debt_test.gd`, `sleep_test.gd` and `widescreen_test.gd`, plus existing simulation, movement, search and rendered UI suites. The widescreen test saves full-resolution normal and sleeping previews.
