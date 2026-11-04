# Legacy investigation and GDScript rewrite brief

Investigation date: 2026-11-03. Scope: existing Python source, data tables, asset inventory, and distribution infrastructure. This is a record of observed implementation and proposed design, not an approved replacement specification. Legacy source was not modified.

## Findings that determine the rewrite

The prototype contains a substantial reusable content library and an interface well suited to a Godot UI game. Its current simulation is not a reliable balance reference: the source has a syntax blocker, human AI is disabled and unfinished, player AP is not enforced, and player time and NPC scheduling use different clocks.

The central design challenge is a shared action economy that supports both readable local encounters and a persistent city. Reproducing the existing implementation literally would preserve several accidental advantages and population sinks.

## Scope and verification

- 71 Python files, 8,445 lines, including menus and UI utilities.
- Parsed all 71 files with Python's AST parser without importing or changing them: 70 parse; `source/ai/human_decisions.py:30` fails on `safehouse_x =`.
- Traced entry point, game initialization, player input, action commands, character state, items, city generation, goal selection, NPC scheduler, day/night cycle, saves, and simulation scripts.
- Inventoried asset folders and image dimensions; visually inspected the hospital exterior and viewport frame as representative assets. This is not a complete visual QA pass.
- Checked all literal block-image references in `block_data.py`: all exist. Environment filenames cover all 21 building interiors/exteriors and five outdoor exteriors.
- Inspected search table semantics and skill implementation references.
- Python environment has pygame, NumPy, and Pillow available. Neither `godot` nor `godot4` was found on PATH; this does not establish whether an editor is installed elsewhere.
- No full gameplay or long-run population test was performed: current source cannot import because of the syntax error. Historical executables were inventoried, not executed, and may differ materially from this source.

## Infrastructure and architecture

`source/main.py` initializes a 1200×800 Pygame window at 60 FPS. It currently sets `debug = True`, which skips normal creation flow and starts a firefighter at (12, 12), with 1,000 humans and 100 zombies. Normal creation uses 500 humans and 500 zombies and places the player at (50, 50). The simulation initializer uses zero human NPCs and 100 zombies.

`core/game.py` owns the state, event handler, UI, menus, sound bank, ticker, and NPC processor. `GameState` groups player, city, and NPC collection. Rules depend directly on the game and UI, including combat animations and death feedback. UI update/draw paths also trigger simulation changes. This prevents a clean headless simulation.

The source reports v0.5.0. `dist/` contains five Windows executables, v0.2.0 through v0.4.1. Resource paths support PyInstaller's `_MEIPASS`; development paths resolve relative to the current working directory, so launching from `source/` matters. Saves use pickle in the user's platform-specific application-data directory. No requirements manifest, build specification, automated test configuration, or existing Godot project was found in the workspace inventory. Compiled Python caches and a debug log are present but are not authoritative source.

The conceptual flow is useful and should survive:

`player input / NPC decision → action command → world state changes → feedback`

The rewrite should make that flow explicit and remove UI calls from its middle.

## City generation

Sources: `world/city.py`, `world/blocks.py`, `data/block_data.py`, `data/neighbourhood_data.py`, and the four CSV tables.

The city has 100×100 blocks, divided into 100 named 10×10 neighbourhoods. There are 26 block types: 21 buildings and five outdoor types. Buildings track doors, barricade level/sublevel/hits, generator installation, fuel expiry, lights, ransack level, and ruin. Blocks track names, generated descriptions, neighbourhood, and discovery.

The generator first builds this pool, then globally shuffles it:

| Pool | Count at size 100 | Selection |
|---|---:|---|
| General buildings | 5,130 | Uniform choice among non-mall buildings, including offices |
| Additional offices | 500 | Office |
| General outdoor blocks | 1,250 | Uniform choice among outdoor types, including streets |
| Additional streets | 3,100 | Street |
| Mall seeds | 20 | Mall |

Consequently, offices and streets occur in both general and dedicated pools. Before mall expansion, expected office count is 756.5 and expected street count is 3,350; these are expectations, not generation guarantees. Population starts uniformly scattered and outdoors. At normal settings there is only about 0.1 NPC per block on average before clustering, so density is a meaningful design parameter.

Neighbourhoods receive names after global placement. There are no service quotas, neighbourhood archetypes, rarity allocations, road connectivity constraints, or deliberate local human/zombie strongholds. The intended balanced, distinctive neighbourhood system is a future extension beyond this generator.

Names are sampled with replacement despite `_get_unique_block_name` naming. Name pools are loaded twice during initialization. Descriptions combine up to three randomly selected phrases for each view. Mall expansion replaces adjacent streets and tracks size by display name rather than a stable mall ID. Its diagonal branch mistakenly looks at the block below, not the diagonal. Multiple mall seeds with the same name interfere with size tracking.

Generation counts scale linearly with `CITY_SIZE`, while capacity scales quadratically, so changing map size is unsafe without redesign. There is no explicit saved seed or separate RNG stream.

Proposed replacement: seeded generation with a fixed default profile, guaranteed minimum services per neighbourhood, weighted remaining slots, and a few distinctive local features. Keep configuration in data so settings can be exposed later. Use stable building/mall IDs independent of names. Decide whether streets need geographic continuity before building a road-generation system.

## Interface and assets

The interface consists of a 3×3 clickable local map, action buttons, location illustration and prose, animated NPCs, event log, portrait/status, inventory/equipped item, skill menu, and a two-scale city map. The map remembers discovered blocks. Keyboard movement currently uses WASD plus Q/E/Z/C diagonals; arrow keys are not implemented in this snapshot.

| Asset folder | Files | Observations |
|---|---:|---|
| `assets/settings` | 47 | All 832×372; complete type-based exterior/interior set |
| `assets/blocks` | 29 | Includes 26 180×180 images and an additional 200×200 image |
| `assets/buttons` | 56 | Multiple dimensions; paired pressed/released action skins |
| `assets/panels` | 8 | Decorative frames/backgrounds, status and HP elements |
| `assets/items` | 28 | Mostly 125×125 |
| `assets/sprite_sheets` | 9 | Five 1536×64 sheets; four 1650×66 portrait sheets |
| `assets/parallax` | 5 | 1080×500 layers |
| `assets/cursor` | 6 | 32×32 cursors; some interaction cursors reuse item textures |
| `assets/music` | 3 | Audio files |
| `assets/sfx` | 24 | Audio files |

Two TTF fonts live under `data/fonts`. Tables contain 274 block-name rows, 575 character-name rows, 846 description rows, and 28 item-search rows.

The representative artwork is textured, painterly pixel-style illustration with elaborate borders. It should be preserved for the first functional recreation; uniform pixel scale, text readability, and border stretching need an explicit visual pass. Skin reuse is straightforward, but reproducing hit targets, contextual availability, layout, focus, and scaling is still real implementation work.

Godot mapping proposal: Control-based scenes, texture buttons for existing states, texture-backed panels, labels for readable dynamic text, reusable inventory slots, and animation resources for sprites. Use nine-slice framing only where the artwork supports slicing. Godot documents this panel approach in [NinePatchRect](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html).

Cache textures and update views on state changes. The Python viewport and location panel currently reload images during updates; drawing the UI should not reload disk assets or mutate the simulation. Expose AP cost, expected time, and rejection reasons on actions. Keep mouse and keyboard routed through the same validation.

## Action points and time: actual behavior

Sources: `characters/__init__.py`, `actions/`, `core/game.py`, `core/npc_processor.py`, `ui/widgets.py`, `ui/utils.py`.

Every character starts with zero AP. New-day processing grants NPCs 60 AP, capped at 60. Night processing first adds 20 NPC AP, also capped at 60, spends NPC actions, then grants the next daytime allocation. The player is not part of those refills. Player commands generally do not require sufficient AP and can reduce AP below zero; AP is absent from the displayed character status.

The player instead advances `game.ticker` through commands. `ClockHUD` converts each tick to 16 game minutes, starting at 08:00. Sixty ticks reach midnight. The night simulation runs, then the display resets to 08:00. There is no 30-minute real-world regeneration implementation.

NPC daytime processing uses a real-time interval of 1,500 ms, queues every NPC, and processes up to 100 per frame. NPC AP expenditure does not advance the global ticker. Thus a slow reader and a fast clicker encounter different opposition despite identical in-game elapsed time. Pausing and opening skills stop the scheduler; opening the map does not.

| Action | AP behavior | Player clock behavior |
|---|---|---|
| Human move | 1 AP | 1 tick |
| Zombie move | 2 AP, or 1 with Lurching Gait | Matching 2 or 1 ticks |
| Enter/leave | Usually 1 AP on success | 1 tick on success |
| Attack | Usually 1 AP per attempt | 1 tick even for some invalid attempts |
| Search | 1 AP even on failure/full inventory | 1 tick |
| Barricade | 1 AP on success, none on failed roll | 2 ticks on success, 1 on failed roll |
| Break barricade | 1 AP | 1 tick |
| Heal | 1 AP on success | 1 tick |
| Revive | 10 AP on success | Only 1 tick |
| Stand | 20 AP, or 1 with Ankle Grab | Matching ticks |
| Equip/drop | Generally free | Generally free |
| Read map / several placeholder item uses | No AP deduction | 1 tick through Use |

Fuel expires according to the player ticker, not NPC elapsed time. NPC standing also waits for 20 ticker units after death. Night processing does not advance that ticker, so these timers do not represent the night passing.

The nighttime queue re-adds all eligible NPCs after each action, duplicating queued references. Its no-progress check examines each single action against all AP totals and can stop the entire night when just one NPC cannot spend AP. This is both a fairness and completion problem.

Provisional design recommendation, pending user preference: a shared simulated timeline, paused during player deliberation, with explicit action duration and AP expenditure, plus rest/wait to recover. Expensive actions must allow proportionate world progress. Rest should use the same scheduler as ordinary play, with danger and interruption rules, rather than a separate overnight approximation. Keep AP recovery, AP cap, action duration, and NPC opportunity frequency as separate tunable values. Do not regenerate one AP for every one-AP player action: that would remove scarcity.

## Combat, inventory, and progression

There are 28 inventory item types, two zombie attacks, nine occupations, and 39 defined skills. Definitions are more complete than implemented behavior.

Characters normally have 50 HP, with skill-based increases to 60. Combat uses percentage rolls. Pistols start at 5% accuracy, 5 damage, six shots; shotguns at 5%, 10 damage, two shots. Firearm training can bring accuracy to 65%. Claws start at 25%/2 damage and teeth at 10%/4 damage. Zombie skills modify accuracy and claw damage. Melee durability decreases on hits, while ammunition is spent on hits and misses. XP usually equals damage plus a kill bonus of 10.

Inventory capacity is ten separate items, with only one portable generator permitted by search. Dropping deletes the inventory item; there is no ground-item persistence. Searching first rolls 20% success unlit, 25% lit, minus one percentage point per ransack level; ruins use 10%. A successful roll then selects an item using CSV values as relative weights, not absolute find probabilities. For example, an unlit hospital has about a 14.29% first-aid-kit probability per search, although its table entry is 0.05. This distinction must survive data conversion or be intentionally redesigned. Resources are generated by searches; buildings have no depleting stock.

Generators and fuel, repair tools, consumables, reloads, healing, DNA tags, and revival have implementations. Binoculars, books, crucifix, GPS use, and newspaper mostly return feedback without the advertised gameplay depth. Speaking is a stub. Shopping, Bargain Hunting, NecroNet Access, infection, digestion, grasp, drag, groan, Brain Rot, and scent-trail mechanics are examples of declared skills without corresponding functional systems. Flesh Rot increases HP but its described firearm resistance is absent.

Combat defects relevant to migration include Surgery reading nonexistent `BlockProperties.type`; a generic science-weapon attack branch calling nonexistent `_science_attack`; revival not consuming the syringe; and revival setting human/dead flags without fully normalizing equipment, UI, or HP. The normal mouse path does use dedicated DNA/revival commands. These should become fully validated action transactions, not copied branches.

NPC skill selection includes already owned skills; learning does not increment NPC level. Occupation and skill categories are different Enum classes, so the intended occupation-priority comparison does not match. Retaining a selected skill across a faction change can also produce inappropriate progression. Shared skill acquisition should enforce prerequisites, uniqueness, cost, faction eligibility, and level changes.

## AI and population dynamics

The goal → decision → action structure is a reasonable foundation. Zombie goals prioritize standing, hunting, or wandering. Decisions attack colocated humans, approach visible humans, break barricades, enter buildings, and move toward lit buildings. Perception searches the current and adjacent blocks and considers inside/outside state.

Human AI is explicitly set to `None` in `GoalManager.evaluate_goal`. Its separate decisions include incomplete code, undefined variables, incompatible method signatures, and references to a former executor API. There is no functioning human strategic response in this snapshot.

Zombie target memory contradicts its comment: the `last_known_target` getter clears memory when a human is no longer visible. Querying memory also performs new perception scans and mutates target state. Goal evaluation repeatedly creates candidate objects. Some target movement uses full coordinate deltas rather than enforcing one-block movement, and `elif target_x` treats coordinate zero as absent. Adjacent-location filtering excludes city-edge coordinates. These are implementation issues before any behavioral tuning.

Spatial queries repeatedly scan the entire NPC list for each block and each actor. This tends toward quadratic work as population increases. No neighbourhood controller, migration model, faction coordination, explicit resupply network, or regional equilibrium system was found. Per-block population fields exist but are not an authoritative maintained simulation model.

Death flips humans into dead zombies; standing returns a character to activity at half-health healing. Revival flips a zombie into a dead human awaiting standing. Headshot marks permanent death. There is no autonomous human revival program or population replacement system. Consequently, durable two-sided population fluctuation is not established. Permanent death is a population sink; revival requires humans who can act and obtain resources. A closed population with no effective revival path risks irreversible human collapse.

Proposed design principles:

1. Represent faction and physical state explicitly: living human, downed zombie, active zombie, revivifying human, and permanent loss if retained. Preserve identity and inventory across transitions according to deliberate rules.
2. Give both factions economic roles. Humans maintain shelters, medicine, power, ammunition, and revival capability; zombies breach shelter, concentrate pressure, and return after defeat. Balance supply chains and recovery costs, not just attack damage.
3. Let regions differ through shelter quality, hospital/lab access, population density, and migration. A local collapse should be possible while neighbouring regions can later support recovery.
4. Avoid secretly resetting every neighbourhood to a fixed 50/50 ratio. If comeback assistance is needed, express it through understandable mechanisms such as migration, reinforcement, or effective revival teams.
5. Start with persistent individual records and spatial indexing; only introduce distant aggregate simulation if profiling and desired scale justify it. Named or encountered NPCs should retain identity. If aggregates are used, transfers between simulation levels must conserve population and avoid duplicating encounters.
6. Measure human/zombie/standing/downed totals, permanent losses, deaths/revivals per day, AP spent by purpose, idle reasons, territory changes, migration, and time to faction collapse over many seeded runs. A static 50/50 result is not evidence of an interesting simulation.

## Save/load integrity

`core/saveload.py` serializes blocks, characters, skills, inventory attributes, portrait, and displayed time. It omits doors, barricade hit progress, permanent death, death timestamps, safehouses, DNA/NecroNet state, AI goals, RNG state, and the global ticker.

Loading constructs characters with starting items, then appends saved items without clearing the starter inventory. Recreating UI calls `start_new_day`, refilling NPC AP regardless of saved time. Saved fuel expiry uses an unsaved ticker, so its meaning is not preserved. A missing save returns None without a caller-side reconstruction guard.

The new save contract should be versioned and deterministic, with stable IDs, simulation time, all durable state, and RNG state. Loading must not grant AP, generate replacement starter items, or advance time. Decide separately whether importing historical pickle saves is worth supporting; it should not constrain the new model by default.

## GDScript architecture proposal

Use GDScript for runtime gameplay and simulation. Separate static definitions, mutable state, rule execution, scheduling, AI, persistence, and presentation.

| Component | Responsibility |
|---|---|
| Definitions | Buildings, items, skills, occupations, default generation/balance profiles |
| WorldState | City blocks, characters, IDs, discovery, inventories, spatial index |
| ActionResolver | Validate actor/target/cost; resolve RNG; commit changes; emit outcome |
| SimulationClock | Advance elapsed time; grant opportunities/recovery; expire timed effects |
| NPCPlanner | Read observations/memory and propose legal actions |
| CityGenerator | Seeded local quotas, weighted diversity, names, mall footprints |
| SaveService | Versioned complete snapshots and migrations |
| UI scenes | Render state and outcomes; issue the same commands used by AI |
| Simulation runner | Run seeded scenarios without UI and export balance metrics |

Custom Resources suit reusable definitions; RefCounted objects or compact collections suit offscreen state. Reserve scene nodes for UI and visible presentation instead of creating a processing node for every city block and NPC. This follows Godot's distinction between [resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) and [alternatives to nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html). Keep mutable inventories separate from shared definition resources.

The first playable slice should exercise one neighbourhood, both inside/outside states, movement, search/equip/attack/heal, barricades, death/standing/revival, and rest using the same action resolver. Expand to the 100×100 city only after the timing and population lifecycle are observable and testable. Preserve the current content library during this process.

Meaningful checks for that implementation: action rejection leaves state unchanged; costly actions advance the appropriate time; AP cannot underflow; movement is adjacent and bounded; corpse/revival transitions preserve identity; loading preserves state and next random outcomes; generation satisfies service constraints; all eligible NPCs receive fair scheduling; rest cannot hang on an idle actor; aggregate transfers conserve population if implemented.

## Confirmed direction from the designer

The designer answered during this investigation:

- Prototype both action-paced play (world pauses during deliberation) and real-time NPC pacing before selecting a default. This is a prototype direction, not a decision to ship two fully supported modes.
- AP exhaustion should lead to rest and advancing simulated time rather than real-world waiting.
- The player remains the same character through repeated faction transitions. Human death leads to zombie play; zombie death leads to rising again as a zombie.
- Zombie players may embrace that side or seek a NecroTech building/scientist for revival. Human NPCs can revive zombie players. A revived player can return to zombie life through death, including jumping from a tall building.

Consequences: player permanent Headshot death conflicts with the intended lifecycle and must change. Scientist AI and a discoverable revival pathway belong in the core slice. Building-jump actions are a requested addition, not an existing implemented mechanic. Rest needs explicit interruption/outcome rules for attack, death, and revival. NPC identity persistence and distant aggregation remain unanswered; do not infer the player's persistence rule settles NPC simulation representation.

Both pacing prototypes should share action rules, AP recovery, RNG, and scenario definitions, changing only how elapsed time is requested. Compare the same encounter and resting scenario across both to assess pressure, readability, click-speed advantage, and simulation cost.

## Decisions to settle with the designer

The immediate pacing, rest, and player-lifecycle questions are answered above. NPC identity and distant simulation remain open.

Follow-up design questions, after those foundations:

- Is the intended experience an endless personal survival sandbox, a recoverable city war, or a campaign with victory/failure conditions?
- Should Headshot remain permanent death, or become a recovery penalty? If permanent loss remains, what replenishes the population?
- What makes a desired neighbourhood distinctive: services, architecture, names, faction presence, rare sites, or all of these?
- How much regional information should players know, and through which in-world tools?
- Should the first UI recreation preserve the 1200×800 composition exactly, or retain its visual language with scalable layout and remappable arrow/WASD controls?
- Are existing saves and historical executable behavior important compatibility targets?

No final pacing model, NPC population abstraction, or new generation policy has been approved. Rest and the player lifecycle above are confirmed requirements.
