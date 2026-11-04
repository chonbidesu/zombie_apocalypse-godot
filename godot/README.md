# Malton survival prototype

A standalone Godot 4 / GDScript survival game using the original project's artwork alongside new assets in the same pixel-art style. The historical Python source and builds remain untouched. Tested with Godot 4.7.2 and the Compatibility renderer.

## Run

Open `project.godot` in Godot and run `main.tscn`, or use PowerShell:

```powershell
.\launch.ps1
.\launch.ps1 -Editor
.\launch.ps1 -Test
.\launch.ps1 -Gallery
.\launch.ps1 -Balance shelter
.\launch.ps1 -Balance holdout
```

The launcher finds Godot on PATH or in a `Godot*` folder in Downloads. Override with `-GodotPath 'C:\path\to\godot.exe'`. Child processes use local `.runtime/` application data. Opening the project directly uses Godot's usual save location. Save displays the actual path; the game has one replaceable save slot.

The latest [rules audit](docs/urban-dead-rules-audit.md) distinguishes restored rules, remaining parity gaps and offline adaptations. [AI balance results](docs/ai-balance-results.md) records repeatable multi-day trials. Balance runs save per-day population, action and navigation metrics under `reports/`; the `shelter` suite covers ten scenarios and `holdout` uses additional seeds over fourteen days. The player is an inactive observer in these tests.

The original flat street minimap asset is restored. Zombies now use a matching 24-frame atlas with slow staggering, claw strikes, recoil and a horizontal corpse; see `tests/zombie-animation-preview.png` and the generation manifest in `assets/generated/zombie-refresh-manifest.json`.

## Playing

Normal launch uses the original 100×100 Malton map and starts the Volunteer at Anne General Hospital in Dulston. The Volunteer carries a bat, first aid kit, toolbox and syringe, knowing Construction, NecroTech Employment and Lab Experience. The old Mercy General opening remains available as the Legacy test neighbourhood. Restart opens New Game, with Original Malton, Random city and Legacy test neighbourhood modes. It offers the eight original survivor occupations, Corpse, and Volunteer. Random city exposes a seed, dimensions, exact ordinary building counts, numbers of mall/fort/zoo/cathedral/mansion/power-station/stadium complexes, and survivor/zombie populations. Invalid requests explain capacity or packing errors without replacing the running session. Each canonical occupation has its own portrait, equipment and starting skills. The Corpse's human portrait appears after revival.

Click nearby tiles or use arrows/WASD and Q/E/Z/C to move. Click a sprite to select a target. Right-click inventory items for contextual uses; click to select equipment or an item for Give/Drop. Space pauses; R rests for ten AP; M opens the neighbourhood map; Escape closes dialogs, cancels rest or pauses.

Only contextually supported actions appear. AP and recovery can temporarily disable them. Enter remains available at excessive barricades and explains the blocked entry without spending AP. Inventory uses percentage encumbrance, with ten items shown per page and Previous/Next controls for additional items. Collection stops at 100 items or 100% encumbrance; the last find can take load beyond 100%. Generators/transmitters weigh 20%, toolboxes 16%, fuel 10%, and small supplies usually 2%. Dropping discards an item permanently; there are no ground-item piles.

Humans and zombies retain identity, inventory and learned skills across death and revival. Downed players perceive no environment, map, NPC activity or history. Standing restores perception. Revival produces a downed human who must stand. The rules deliberately prevent permanent character death.

## World and presentation

- Original Malton imports 10,000 named squares across all 100 suburbs from an archived Wiki map. The twenty named malls retain their original footprints, including Lumber (two squares) and Pole (three). Both original 3×3 forts and the original 5×4 zoo are preserved. Random maps use configurable 2×2 malls, 3×3 forts and 4×4 zoos. Movement crosses suburb borders continuously. The map screen offers local 10×10 blocks, city suburb selection, direction browsing and Find me. There are 37 indoor and nine outdoor categories.
- Location text assembles three independently selected visual sentences from concise pools, then adds context-sensitive doors, barricades, lighting, visible interior damage and occupants. Text persists in saves, wraps over the scene and fits without scrolling. Closed doors are mentioned only without barricades. Outside observers see lights rather than generator details; an open entrance reveals interior ruin. Barricade attack sounds belong to the activity feed.
- Minimap and full map use the refreshed building artwork. Adjacent mall squares crop different regions of one shared image, forming one connected building. Offices and NecroTech sites share identical outside/map textures; Employment reveals an NT logo in either form. Yellow outlines convey power; dark grey desaturation conveys ruin. No YOU, LIT or RUIN labels are added to the minimap. Discovery and timestamped scans replace omniscient population information.
- The environment displays its full image height without cropping, with a 1016×572 view. Sprite frames are aligned by their opaque foot bounds and grounded with subtle shadows. Rest controls sit below the portrait, inventory follows beneath, and contextual actions use compact rows directly below the environment.
- Larger selectable sprites face each other: humans left, zombies right. Crowds overlap and stagger in depth. Red HP bars are short and thick; NPC AP remains hidden. Diagnosis and Scent Blood expose relevant health details in tooltips.
- Nine distinct full-body human/revived occupation atlases replace shared generic art. Each 6×4 atlas retains 24 frames and uses all four sequences: idle (0–7), attack (8–14), death (15–20), hurt (21–23). Zombie gait uses slower irregular holds. Combat reactions survive interface rebuilds.
- Nine new 5×5 portrait atlases provide healthy breathing, two injury states, static death and irregular undead lurching. Cosmetic animation randomness does not consume simulation RNG.
- NPC speech appears in bubbles and the local activity feed, with occupation and situation-specific human dialogue and undead noises. Cooldowns keep chatter occasional; fast rest and unconsciousness suppress it.

## Skills and combat

All 45 Urban Dead skills are represented with prerequisites, descriptions, effects and a scrollable purchase interface: 23 human and 22 zombie. Headshot requires level ten. The complete machine-readable tree is in `assets/generated/skill-catalogue.json`; runtime definitions live in `scripts/catalog.gd`.

Military/science occupations pay 75 XP within their category, 150 for the opposite category and 100 for civilian/Hunter skills. Civilian occupations pay 100 for human skills. Zombie skills always cost 100. Both trees can be purchased in either form as in the earlier prototype. Skills normally activate in their matching form; Body Building, Diagnosis and NecroTech recognition survive death, while Ankle Grab and Scent Death remain useful after revival.

Untrained zombie hands hit at 25% for two damage; bites hit at 10% for four. Vigour Mortis, Death Grip, Neck Lurch and Rend Flesh improve these. Tangling Grasp claims a victim on successful hands, adds ten percentage points to subsequent hands/bites, and has a 50% chance of slipping on a miss. Another grasping zombie can take ownership. Movement, death and revival release the grip. Zombies can equip crowbars (5%), baseball bats (10%) and lengths of pipe (10%), each dealing two damage without human or zombie combat bonuses. Claws and bites remain available while a tool is equipped; tools cannot establish Tangling Grasp. Zombie NPCs choose claws for barricades rather than tools or ineffective bites.

Human combat applies firearms, pistol/shotgun, hand-to-hand, knife and axe training. Fists hit at 10% or 25% with Hand-to-Hand Combat. Flare guns hit at 2.5% or 15% with Basic Firearms Training, for 15 damage as a single-use shot; fractional accuracy is preserved. Hockey sticks deal three damage. New firefighters start with Axe Proficiency alone for 25% axe accuracy and can learn Hand-to-Hand Combat to reach 40%. Pistols take a six-round magazine; shotguns load one shell per action, hold two, and deal ten damage. Flare guns are disposable shots or signals. Flak jackets and Flesh Rot reduce firearm damage by 20% without stacking. Melee weapons do not wear out. A pool cue has a 20% chance to splinter on each successful hit and is removed from inventory when it breaks; misses never break it. Bottles still break on successful hits.

Other skill effects include targeted mall stores and Bargain Hunting, 60-HP Body Building/Flesh Rot, tagging, restricted radio channels, building repair, free running, safehouse scouting, DNA extraction/tags, NecroNet and syringe manufacture, First Aid/Surgery/Diagnosis, Headshot standing penalties, scents, corpse feeding, infection, dragging, zombie speech, groans/bellowing, ransacking, gestures, movement and standing discounts, and Brain Rot revival restrictions.

## Shelters, loot and NPCs

Everyone has a 50-AP cap and recovers one AP per thirty game minutes. At normal speed one real second equals one game minute. Actions take effect immediately, then impose individual recovery; there is no global NPC turn. Rest runs at 16× and downed recovery at 32× until standing becomes possible. Pause and dialogs freeze time. Rest stops on injury, danger or state changes.

Barricades have 21 strength points: loose 1, light 2–4, quite strong 5–7, very strong 8–10, heavy 11–13, very heavy 14–16 and extremely heavy 17–21. Attacks roll character-versus-player accuracy, then a separate 50% structural chance; crowbars bypass that second roll. Human melee skills apply, giving a trained crowbar and fully trained axe a 20% total damage chance. Human fists start at 10% before skills and the structural roll. Guns, knives, fuel cans and zombie bites are ineffective. Messages distinguish misses, harmless creaks and actual damage. Each damaging hit removes one point; successful construction restores one point. Survivors can enter from outside through strength 10, with a warning on reaching that limit; stronger barricades require Free Running from an adjacent building. The fourteen original open zoo squares cannot be barricaded; all six enclosures can be barricaded but have no closable doors. Fort compounds can only be entered/exited via their gatehouse; Free Running cannot cross fort walls. Human and zombie mall interiors connect without Free Running. Junkyards have a fence opening rather than doors; churches, cathedrals, fort gatehouses and zoo enclosures also lack closable doors. Zombies require Memories of Life for closed doors, paying one AP to open plus one to enter or leave; doorless entry costs only one AP.

Barricade construction uses the current strength band: 100% at zero, 99.5% loose, 99% light, 97.8% quite strong, 85.1% very strong, 61.5% heavy, 38% very heavy and 20.5% extremely heavy. Successful construction closes functional doors automatically and adds one strength point for one AP, without a separate Close action or a required carried tool. Construction remains the normal skill prerequisite; the existing untrained pipe shortcut remains available for the first loose barricade. Two or more living, standing zombies inside halve the odds; unpowered dark buildings (banks, cinemas, nightclubs, armouries, warehouses and malls) halve them again. A single intruder does not interfere, and intruders no longer prohibit construction. At strength 21, attempts report "The barricade cannot be built any higher." and spend no AP, including when the player has zero AP. Successful builds, failures, interference and the strength-ten entry warning have distinct feedback.

Installed generators prevent ransacking; ruined buildings prevent generator installation. Generators have six HP, descriptive damage, and must be fully repaired before refueling. Construction and a toolbox are required for building and generator repairs. A fuel can tops fuel up to 24 hours and wastes the excess. Ruins cannot be powered. Fuel cans, generators and other supplies use plausible site-specific loot tables.

The catalogue has 54 item types. Searches first roll for any find using building state, then select an item from normalized site/store loot weights. Lit buildings find items at 30% (NecroTech 28%, malls 26%); intact unlit buildings use 20%, inherently dark unpowered sites halve that, any ruin uses a flat 10%, and outside searches use 5% anywhere with one shared street grab bag of junk, tools and survival gear. Outdoor loot excludes syringes, firearms and ammunition. Shopping targets mall stores and Bargain Hunting doubles intact indoor mall yields, producing 52% total finds in a lit mall. Firearms are partially loaded 75% of the time and otherwise empty. The [search rules](docs/search-rules.md) document exact choices and the distinction between total find rates and conditional item weights. Player searches describe discarded junk and usable finds; NPC narration remains concise.

New games begin with 15 of 18 zombies dormant, including indoor bodies. Each dormant body has a 20% chance of becoming eligible to rise at midnight. Dump bodies outside before they reanimate inside. Survivor groups start with two or three members, maintain shelters, heal and defend allies, plan supply trips and install/refuel equipment. Assistance builds trust; strangers refuse supply demands and trusted NPCs protect essentials. NPCs use the same weapon stats, skill bonuses, fractional hit rolls and damage rules as the player. Human weapon choice compares expected damage against the selected target, including armour, remaining HP, ammunition availability and reload AP; equal scores preserve current equipment. Zombie attack choice compares claw and bite damage, adding usable Digestion healing and one prospective infection-damage point for an uninfected survivor who would survive the bite. Zombies pursue prey, investigate light, breach and ransack. NPCs reserve return AP, keep constructors at shared homes, run lab revival queues and conserve generator fuel. Two thirds of former survivor NPCs seek revival after death. New city work parties include experienced specialists; these extra skills and tools do not change player occupation starts. Multi-seed balance reports are in `reports/`; long-term balance still needs playtesting.

Books, newspapers, poetry, drinks, candy, clothing and decorations have contextual uses. Radios can be installed, repaired, tuned and broadcast over local channels; mobile phones require two handsets and powered masts covering both characters’ current suburbs. All 100 original mast sites are imported; generated districts receive one where they contain a suitable building. Binoculars reveal exterior figures from tall buildings; GPS/maps provide location information. Seasonal decorations are available as sandbox loot rather than calendar-gated events.

## Assets and source audit

See `docs/content-expansion-audit.md` for research, coverage and deliberate adaptations. Ninety new PNGs are integrated: 25 item icons, 48 map/interior/exterior images for 16 new buildings, eight map/exterior images for four new outdoor types, and nine portrait atlases. A further 80 selected replacement images are integrated: 71 location images and nine distinct 24-frame occupation/revived-vagrant atlases. Two additional runtime aliases make NecroTech exteriors exactly match offices. Original runtime images are backed up under `.art-backup/`; historical Python assets remain untouched.

`assets/generated/content-expansion-manifest.json` records the exact prompts, generated originals and runtime destinations, using the built-in image generator. Rendered contact sheets are in `tests/building-art-gallery.png`, `tests/outdoor-art-gallery.png`, `tests/item-art-gallery.png` and `tests/portrait-art-gallery.png`. Run `-Gallery` to refresh them. `assets/generated/style-refresh-manifest.json` records the replacement prompts and selected files. Replacement location contact sheets are `tests/refreshed-locations-1.png` and `-2.png`; NPC sequences appear in `tests/occupation-animation-gallery.png`. See `docs/world-and-art-refresh.md` for map provenance and world setup details.

## Architecture and validation

- `scripts/catalog.gd`: item/skill catalogues, occupation mappings and tuning.
- `scripts/simulation.gd`: world, transactions, time, AI and saves, independent of UI.
- `scripts/extended_rules.gd`: item, communication and extended skill actions.
- `scripts/interface.gd`: presentation, animations and contextual controls.
- `scripts/event_feed.gd` and `dialogue.gd`: bounded feedback and NPC speech.
- `scripts/npc_ai.gd`: fort-aware paths, shelters, expeditions, combat choices and revival queues.

`launch.ps1 -Test` imports assets, runs simulation, survival, loot/trust and content-expansion checks, then rendered UI and art-gallery checks. Validation includes full-city and rendered world-setup checks, plus dedicated barricade accuracy, flavour, structural-strength and entry-boundary tests. UI tests require a graphics-capable desktop. Test saves use separate filenames. Tests cover lifecycle, deterministic save/replay, multi-seed population invariants, shelter balance, search/trust, skill purchases, combat/grasp, equipment/communications, atlas health/animation states, crowds and description bounds. They do not establish long-term gameplay balance.

The prototype is a local single-player city simulation: no server messaging, campaigns, audio or remappable controls. Original geography is available offline. New saves include map dimensions, mode, generator settings, provenance, names and complex identities; legacy 10×10 saves still load. Legacy pickle saves are not imported. Clothing is represented by one generic item rather than every named garment; decorative colour/name variants share representative assets. See the audit for additional differences from the original online game.

Encumbrance values, sources, zero-weight/unique items, local custom-item assignments, door/barricade migration and layout checks are documented in `docs/encumbrance-and-layout.md`.
