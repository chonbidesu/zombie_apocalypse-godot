# Rules audit — 4 November 2026

This is an implementation audit, not a claim of complete Urban Dead parity. The existing [content audit](content-expansion-audit.md), [world audit](world-and-art-refresh.md), and [encumbrance audit](encumbrance-and-layout.md) cover the earlier content work. Wiki pages describe different eras of the live game; explicit design requests in this project take precedence.

## Corrections implemented in this pass

| Rule | Current behavior |
|---|---|
| Healing experience | Restoring another character's HP earns 5 XP. Self-healing and curing infection without restoring HP earn none. Humans can also treat standing zombies. |
| Revived health | Standing after revival restores half maximum HP, including 30 HP with Body Building. |
| Building repair | Standing zombies prevent repair. Successful repair earns 1 XP and retains the project's Construction/toolbox requirements. |
| Generator experience | A repair action earns 1 XP; a zombie earns 5 XP when it finishes destroying a generator. Partial damage gives no destruction XP. |
| Transmitter experience | Repair earns 1 XP; final destruction earns 5 XP rather than farming XP on every hit. |
| Barricades | A zombie earns 1 XP when a complete visible level falls. An untrained human carrying a pipe can build the first loose barricade, consuming the pipe on success. Successful barricading closes normal doors. |
| Search hierarchy | Global find odds depend on location state; normalized site/store weights determine the item only after a successful find. Population share no longer modifies these odds. |

The [Useful Items reference](https://wiki.urbandead.com/index.php/Useful_Items) supports medical effects, revive health, equipment XP and population-dependent medical loot. The [Barricades reference](https://wiki.urbandead.com/index.php/Barricades) supports crude pipe barricades and automatic door closure. [Zombie skills](https://wiki.urbandead.com/index.php/Zombie_skills) supports zombie combat, coordination and structure destruction abilities.

## Offline behavior replacing player coordination

These are NPC policies, not extra player powers. NPCs still pay ordinary AP, need actual items, roll ordinary searches/attacks, and respect doors, barricades, fort entrances and skill requirements.

- Route finding uses an eight-direction graph with actual fort gate access. NPCs cache paths and abandon temporarily blocked supply destinations. Humans avoid visible outdoor zombies when an alternative route exists.
- Expeditions reserve AP for returning and entering shelter. Exhausted humans enter a safe building at their current square before looking farther afield. This fixes a retreat loop that left them wandering outside safe entrances.
- Small work parties include an experienced constructor with a toolbox. Doctors and lab assistants include working specialists; player occupation starting equipment and skills are unchanged. Some parties establish homes at laboratories.
- A constructor stays with a shared home while companions gather resources. Isolated survivors can regroup. Defenders preserve very-strong entry while companions are away; they consider heavier barricades when five or more hostile zombies gather and the party is inside.
- Lab workers stay at their home lab, acquire syringes and treat the outside queue. Two thirds of former survivor NPCs seek revival after death instead of permanently becoming predators. They wait outside a known living specialist's home; if none remains, they try a lab. This approximates public revive-point coordination. Original zombie NPCs do not automatically become passive.
- Zombie hunters choose targets, retain a grasp, use appropriate hand/bite attacks, feed when hurt, and groan when nearby reinforcements can respond. Empty-building zombies destroy installed generators before ransacking. Brain Rot is a late NPC purchase, preserving a meaningful revival cycle.
- NPCs share needed supplies, use suitable weapons, reload, and avoid topping off generators that still have more than six hours of fuel.

Public resource/clinic knowledge replaces external multiplayer maps and coordination. Nearby hazard avoidance uses the local view. NPC resource planning and regrouping use simulation-wide location/party information; this is deliberately more informed than a completely unexplored player.

## Preserved project rules and adaptations

| Topic | Project decision |
|---|---|
| Ruins and generators | Installed generators must be destroyed before ruin; ruined buildings must be repaired before generator installation. A lit ruin remains impossible, as requested. Later online rules allow a different combination. |
| Fuel | A can tops off 24 game hours and wastes the excess. Original fuel lasts much longer; the shorter cycle supports offline resource trips. |
| Barricade structure | 21 strength points across seven visible bands: 1 / 2–4 / 5–7 / 8–10 / 11–13 / 14–16 / 17–21. Each damaging hit removes one point and each successful build restores one. Attacks roll combat accuracy then a separate 50% structural penalty, except crowbars. Outside survivor entry ends at strength 10. Progressive construction rates follow the requested table; loose uses 99.5% for the approximate 99%+ value. Dark buildings and 2+ living, standing indoor zombies each halve construction odds, multiplicatively. |
| Zombie equipment | Claws and bites, plus crowbar, baseball bat and pipe at base 5–10% accuracy for two damage. Human combat bonuses do not apply. |
| Skills | All 45 entries exist; form-specific effects and occupation XP prices are implemented. Purchasing either tree in either form remains an existing prototype convenience; original purchasing rules are stricter. |
| Search and durability | Two-stage searches use lit/unlit/dark/ruined/outdoor totals and normalized loot weights. Mall targeting and Bargain Hunting are supported. Melee weapons are permanent except pool cues (20% break chance on successful hits); bottles remain fragile. See [search rules](search-rules.md). |
| Time and bodies | Daily dormant-body awakening, accelerated rest/death recovery and pausable offline time replace real-world server scheduling. |
| Dead visibility | Environment, map and NPC activity remain hidden until standing, as requested. |

The [Gameplay reference](https://wiki.urbandead.com/index.php/Gameplay) documents the original AP/recovery/form framework. [Building Types](https://wiki.urbandead.com/index.php/Building_Types) documents structural access differences. Existing map and door rules retain the original named geography and user corrections.

## Remaining differences and candidates for later implementation

These have been identified, not silently treated as implemented:

1. **Exact combat tuning:** human unarmed base accuracy remains 25%; the item reference describes punching-equivalent attacks at 10%. This deserves a separate combat pass with weapon availability measurements. Barricade attacks use combat accuracy with the crowbar structural exception; construction uses the requested progressive rates, with darkness and zombie interference penalties.
2. **Ruin age:** building repair currently uses fixed local ruin levels/costs, without the online accumulation of long-term repair costs.
3. **DNA scan lifetime:** tags currently use a time window rather than resetting eligibility on the tagged zombie's next action. NecroNet is a local report rather than the complete online interface.
4. **Signals and binoculars:** flare signals currently have a ten-block radius and lack the original outdoor-only launch restriction. Binoculars provide a local summary rather than the original directional tall-building 3×3 view and separate outdoor landmark survey.
5. **Communications:** radio/tag text uses the general 255-character input rather than all original per-channel limits. Phones have powered-mast checks but no reciprocal contact list or queued offline delivery.
6. **Special access consequences:** exact Free Running falls into ruins, all fort armoury traversal details, and special corpse-dumping costs need individual parity tests.
7. **Server/social systems:** account/IP limits, player-killing/bounty systems, player groups and contact networks, global seasonal events and cosmetic variants are not recreated. NPC trust, local chatter and public clinic knowledge serve some of their offline purposes.
8. **Zero-AP presentation:** the player retains map visibility while exhausted; death still blacks it out. The original exhaustion UI has additional restrictions.

These are useful follow-up candidates rather than reasons to overwrite requested mechanics. The simulation results and remaining ecological limits are reported separately in [AI balance results](ai-balance-results.md).

## Art restoration and validation

`assets/blocks/streets.png` is byte-for-byte identical to `.art-backup/blocks/streets.png` (SHA-256 `04b1f1f64762d28995f09efac0f66f1a0b1ccc28aa51f522882a3137157a4ba7`). Other minimap/environment art is unchanged by this restoration.

The built-in image generator produced `assets/sprite_sheets/zombie_sprite_sheet.png`, a transparent 1536×1024 atlas with 24 cells: stagger 0–7, claw attack 8–14, collapse 15–20 and recoil 21–23. Frame 20 is a horizontal corpse. The existing human occupation sheets supplied the style references; foot-anchor metadata was regenerated from the new frame silhouettes. The exact prompt and provenance are in `assets/generated/zombie-refresh-manifest.json`. The former zombie sheet is retained in `.art-backup/zombie_sprite_sheet.png`.

See `tests/zombie-animation-preview.png` for the rendered sequence and `tests/occupation-crowd-preview.png` for the in-game crowd/corpse view.
