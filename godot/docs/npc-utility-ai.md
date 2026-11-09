# NPC utility AI design

The live offline simulation runs this policy through `_clock_step()` and `_npc_turn()` in `simulation.gd`. It uses the current catalog, map IDs and fixed-step clock. The curves below define the scoring primitives. The planner combines them with action-specific thresholds and priorities. [Balance trials](ai-balance-results.md)

## Ownership and decision flow

| Component | Owns |
| --- | --- |
| `Simulation` and action resolver | Authoritative AP, XP, inventory, skills, position, damage, visibility, action costs and effects. A single writer applies transactions in simulation order. |
| [ActionGate](../scripts/npc_utility/action_gate.gd) and [Scheduler](../scripts/npc_utility/scheduler.gd) | Earliest action step and a queue indexed by due step. The gate checks current AP against command costs. A packed bulk filter is available for callers that hold dense AP and cost lanes. |
| [Planner](../scripts/npc_utility/planner.gd) and [Supplies](../scripts/npc_utility/supplies.gd) | Read the spatial index and observed state, rank feasible actions, and retain a goal and cached route for pursuits and supply trips. |
| [Desire](../scripts/npc_utility/desire.gd) | Pure normalized utility curves. Candidate selection and hard legality stay in the planner and resolver. |
| [LocationMemory](../scripts/npc_utility/location_memory.gd) | Bounded survivor observations keyed by actor and site ID. Zombie trails and calls use separate short-lived signals. |
| [Progression](../scripts/npc_utility/progression.gd) | A reserved skill unlock selected by faction, prerequisites and equipment. Skill prices and purchases use the existing rules. |

1. Wake a due NPC and apply AP regeneration through the current step. Remove dormant actors from the decision queue until the reanimation event. Downed actors consider standing only when their stand timer and actual stand cost allow it.
2. Dispatch the due bucket in rotating actor order. Reject a recovering actor, a body that cannot yet stand or afford standing, or an exhausted actor with no available purchase or scouting discount. Requeue the actor for recovery, affordability or a relevant local event.
3. Build a bounded context for each eligible actor. Enumerate candidates as an intent and a single executable next command. Gate each candidate against `cost(actor, command, target, data)` and check its prerequisites before scoring. Cost can be zero for equipping, learning or a discounted command. Cost can also exceed one for standing, moving as an untrained zombie or repairing a ruin.
4. Choose from feasible candidates. A lethal emergency takes priority, then compare candidate scores. A supply trip remains active while its target and return budget remain viable. Recheck the winner's exact cost, cooldown and legality against the current world at commit.
5. Commit one action through the existing resolver. A missed attack, unsuccessful search or failed barricade roll consumed a turn and starts recovery. A rejected command spends nothing. Clear or briefly defer invalid intents and wake on a relevant event. A `Rest` decision parks the NPC until a future AP threshold or change in local danger. Entering a building to rest is a regular command.

### Clock, AP and recovery

Use the project clock of ten steps per game minute. At normal speed a minute is one real second. Integrate elapsed monotonic real time at the active speed, including changes partway through a cooldown.

```text
virtual_minutes(t) = initial_minutes + integral(speed(real_time) d real_time)
now_step           = floor(10 * virtual_minutes)
ready_step         = last_action_step + 10
eligible           = cost >= 0 && AP >= cost && now_step >= ready_step
AP                 = min(50, synced_AP + floor(now_step/300) - floor(synced_step/300))
```

The AP formula preserves the project's shared 30-minute refill boundaries. A bulk refill and lazy `ap_at()` produce the same result if each actor is synced before AP changes and only one method is used. At a constant 16× rest speed a cooldown lasts 62.5 ms of wall time. At 128× sleep speed it lasts 7.8125 ms. If an action has completed 0.4 seconds at 1× and speed then rises to 16×, it needs a further 37.5 ms. Advance in chronological steps during catch-up, including AP ticks and danger that interrupts sleep. Apply the new rate after the interruption. Stamp every committed NPC action on its simulation step, including purchases and zero-AP commands.

The UI supplies active frame time and retains elapsed backlog under a frame budget. `elapse()` changes rate on the simulation step where rest is interrupted. The save stores the recovery deadline and decision wakeup in simulation time. A separate wall-time adapter could use the monotonic `Time.get_ticks_usec()`. [Godot Time](https://docs.godotengine.org/en/stable/classes/class_time.html)

### Scheduling and concurrency

- Use a queue keyed by next due step. Bucket by step if profiling warrants it. Schedule the later of recovery and affordability, or the next AP tick at which rest can end. A movement, breach, threat, groan, faction change or XP event can advance a decision wakeup, subject to the action gate. Deduplicate queued IDs and invalidate old tickets when rescheduling.
- Use actor IDs as dense array indices. The filter walks `D` due IDs in `O(D)` and writes a prefix of a caller-owned buffer. Keep AP and cost lanes in sync with the authoritative action resolver. Revalidate batched candidates after earlier actions mutate the world. At 0 AP a survivor with an eligible zero-cost action can still pass. [Godot packed integer arrays](https://docs.godotengine.org/en/stable/classes/class_packedint32array.html)
- Index occupants by site and compartment. Cache counts for standing humans, hostile zombies and nearby zombie packs on move, enter, leave and death. Refresh light and groan indexes on change or expiry. Read bounded neighborhoods and a few signals. Compute weighted routes only for finalists and cache the chosen route. The off-camera simulation needs no scene nodes or per-NPC timers.
- Dispatch each due bucket in stable rotating order. Under load, cap planner and pathfinding work per frame and carry pending work forward in simulation order. Start with a single simulation thread. Any later parallel scoring must read immutable snapshots and return proposals. Apply AP, target and map mutations on the owner thread with version checks or fresh validation.

## Utility curves

All scores are between 0 and 1. `u(x) = clamp(x, 0, 1)` and `smooth(x) = u(x)²(3 − 2u(x))`. Use equal action weights initially. When tuning, keep separate shared human and zombie presets for weights and thresholds. Read the presets once per session. Derive small role differences from the actor's seed and keep them stable across decisions and saves.

### Survivors

| Desire | Formula or inputs |
| --- | --- |
| Danger `T` | `max(breach_urgency, proximity × odds × exposure)`. `proximity = 1 / (1 + 0.65d²)` and `odds = u((hostile_power / max(0.65, friendly_power) − 0.5) / 2)`. `d` is distance to a reachable threat. Standing allies and zombies contribute effective power in proportion to HP and expected damage per AP. The actor contributes to friendly power. Exposure is 1 in direct contact and near 0 behind an intact barricade. |
| Flee | `T × [0.72 + 0.18(1 − HP/max_HP) + 0.10(1 − smooth(AP/16))]`. Force an escape attempt when a reachable threat has at least 2.5× local power or predicted breach urgency reaches 0.85. Use the safest affordable local entry first. Otherwise choose an escape route, factoring in arrival AP and danger along the route. If no escape is legal, score healing, defense and movement that buys time. |
| Scavenge | `need × cache_quality × (1 − T) × [0.20 + 0.80 smooth((AP − trip_AP)/18)]`, gated by `AP >= trip_AP`. `trip_AP` includes outward movement, entry, a search allowance, the return route and an escape reserve. Start with a reserve of 4 AP and increase it with danger. Stop searching when another attempt would consume the return budget. |
| Rest | `(1 − smooth(AP/28)) × shelter_quality × (1 − T)`. Shelter quality uses observed barricades, interior hostiles and exit options. Rest regenerates regular AP. Healing comes from supplies or allies. |
| Heal and defend | `max(smooth((1 − HP/max_HP)/0.70), infection_urgency)` for a usable first aid kit. Defend is `D/(D+2) × defense_value × (1 − 0.65T)` for expected damage per AP `D`. Use the existing weapon stats, effective damage and reload cost. In a lethal encounter, a heal that enables an otherwise impossible escape can take the emergency slot. |
| Barricade | Below the assigned target, `P(build succeeds) × shelter_value × [0.20 + 0.45 smooth((target − strength)/10) + 0.35 breach_urgency]`. Use the resolver's current construction probability and interference penalties. |

Start with `power_per_actor = (0.5 + 0.5 × HP/max_HP) × (0.5 + 0.5 × u(expected_damage_per_AP/2))`. Downed actors and those unable to reach the engagement contribute zero. Estimate time to breach in simulation minutes as `strength / max(ε, observed_removals_per_minute)`. Use recent pounding and visible attackers as evidence, decay old evidence, and set `breach_urgency = u(1 − time_to_breach / escape_window)`. The escape window includes remaining recovery and expected time to complete the escape route. Rank feasible escapes by `destination_safety × (1 − peak_route_danger) / (1 + escape_AP/4)`. Need for a supply starts at `u((desired_count − carried_count) / max(1, desired_count))`.

Five comparable zombies against one survivor in the same compartment give `T = 1` and trigger the emergency escape tier. At 35 AP, a 17-AP trip with need 0.8, cache quality 0.7 and danger 0.1 scores 0.504.

### Connected shelters

For each managed refuge, verify a directed Free Running edge **from the street entry to the refuge interior**. The live planner checks adjacent buildings, including legal same-building movement, and respects fort, gatehouse, Armoury and ruined-roof rules. A survivor without Free Running uses a directly enterable shelter and an affordable ground exit.

- Designate one stable exterior entry per connected refuge group. Favor a currently enterable site with low street exposure and short interior routes. Give it a shared VSB target of strength 10. Connected refuges with confirmed ingress get an EHB target of strength 21. A refuge without confirmed ingress stays at VSB until access is restored.
- Store the entry and target assignments centrally per group so two builders cannot disagree. Maintain at least one assigned constructor when staffing permits. Recompute when topology, route legality or the entry's safety changes. Establish a new legal entry before raising the old one. If there is no alternate entry, fall back to VSB-capable shelter and relocate if needed.
- Just before each barricade commit, recheck the target and current strength. An occupied or ruined entry can become unusable even at strength 10. Consult regular movement and entry validation. Leave a ground retreat for allies without Free Running. Switch expensive late EHB work to escape, healing or maintaining the entry when the local threat demands it.
- Working generators improve indoor search odds and enable powered services such as syringe manufacture and hospital Surgery. Zombies can converge on a visible light from up to three blocks away. Maintainers defer lighting under active siege unless the garrison and barricades can support it. Standing constructors with AP reduce predicted breach danger. A weak garrison can lose both the shelter and its generator.

The original game used Construction for barricades and XP for skill purchases. Exact strengths and legal fort routes here come from the prototype. [Urban Dead FAQ](https://www.urbandead.com/faq.html), [project traversal rules](fort-and-free-running.md)

### Zombies

| Desire | Formula or inputs |
| --- | --- |
| Attack | `0.80 + 0.10 D/(D+2) + 0.06 vulnerability + 0.04 crowd`, for a legal same-compartment attack. `crowd = u((pack_size − 1)/4)` counts standing zombies including self. Set `vulnerability = 0.7 × detectable_wounds + 0.3 × u(other_attackers/3)`, treating unknown wounds as zero. Prefer an existing grasp on ties. Score claws and bite using expected damage, healing and infection value. |
| Hunt | `cue × (0.68 + 0.10 crowd) / (1 + distance/4)`. `cue = max(sighting_confidence, 0.85 groan_strength, 0.50 if visibly lit)`. Use distance in movement AP for routed finalists. Sighting and groan strengths decay by age. Nearby zombies converge on the same heard groan, observed prey or visible light. |
| Breach or enter | `cue × [0.30 + 0.32/(1 + work_AP/(8 pack_size)) + 0.12 crowd]`, with pack size at least 1. `work_AP` is remaining wall strength divided by structural success probability and multiplied by attack cost. Re-score after each hit. At zero strength, choose legal door opening or entry with the same cue. Against the same 32-AP barricade and a 0.50 cue, one zombie scores 0.182 and five score about 0.299. |
| Vandalize | `0.19 + 0.06 site_value + 0.03` if already committed, omitting the final term for a fresh target. Gate on an accessible, undefended building. Use the existing actions to destroy power, ransack and then ruin once the structural threshold is reached. Clear the intent when fully ruined or prey becomes reachable. |
| Wander | `(0.05 + 0.13 exploration) × (1 − 0.85 best_signal)`. Explore a legal neighboring tile, biasing away from the last few visited tiles and toward signals. Keep movement AP as a real cost until the zombie learns a movement skill. |

Use a shared expiring signal per groan with its actual hearing radius. A zombie with Feeding Groan can call when prey is reachable and reinforcements are available, once per local engagement with a cooldown. Promote this support action above a single attack only when reinforcements are likely to change the outcome. Signals are local and capped. A lone zombie can abandon an expensive breach when a much stronger cue appears. A zombie seeking revival keeps the project's separate revival behavior.

Bellow uses the same recruitment mechanism and reaches farther against a large group. Scent Trail uses actual contact through combat, a DNA sample, first aid or an attempted Brain Rot revival. Immediate sightings can prompt pursuit while visible. No general noise signal attracts zombies. The historical developer notes describe DNA extraction detecting Brain Rot and zombies following groans or scent trails. [Urban Dead development news](https://urbandead.com/oldnews.html)

## Observation memory and progression

Survivors record local visits and complete observations of a building. Exterior sightings can seed exploration leads or temporary threat data. A glimpse from the street should not overwrite known interior information with zeros. Never use the player's discovery flag as NPC knowledge. For unseen sites, consult observations, static terrain and known route geometry. Read live occupancy, light and ruin only from perception or an in-world report. The resolver still validates the next action against the real world.

Each actor with observations gets 12 packed slots. Each slot stores an `int32` site ID, an `int32` last-seen game minute and five quality bytes for shelter, medicine, ammo, hardware and revival. The raw payload is 13 bytes per slot, or 156 bytes per remembering actor plus a four-byte actor-to-row index for each actor ID and spare capacity in 64-row chunks. Store `id = y × width + x` and decode `Vector2i(id % width, floor(id / width))`. Protect the current home and designated entry from eviction. Replace the lowest `peak_quality × confidence / (1 + distance/6)` record when full. Preserve exact site IDs for route reuse and save the observations as sparse records so padding and array offsets stay runtime details.

For a resource observation, quantize `q = u(expected useful finds per search / 0.20)` to a byte. Estimate useful finds from observed building state and the project's search tables, accounting for light, ruin, store and applicable skills. Shelter quality is a separate channel. To shortlist, use `q × 720/(720 + age_minutes) / (1 + Chebyshev_distance/4)`. An observation loses half its confidence after 12 game hours. Route up to three candidates, then rank them with real AP, path risk and the exact resource need. A hospital with a stored find probability of 0.17 has `q ≈ 0.85`. After 720 minutes and at distance four its shortlist score is about 0.213. Refresh on arrival. Temporarily exclude a failed route or entry from the shortlist and try the next candidate, respecting movement skill and directed access rules. Use local legal exploration if no relevant memory exists.

Award XP only through ordinary resolved actions such as damaging enemies, healing allies, diagnosing or reviving where the existing rules award XP, and successful zombie structural damage. Use a small XP incentive in safe situations, such as prioritizing a nearby heal when allies are at similar risk. Reserve XP for the highest-priority reachable unlock, even when a lower-priority skill is cheaper. Reconsider the reserve when role, usable equipment, faction or prerequisites change. Gate the purchase through `skill_reason()` and apply `learn()` as a zero-AP transaction with standard NPC recovery.

- **Human** progression starts with Free Running and Construction, then a usable weapon's baseline combat bonus. Favor firearms only with a credible ammo supply. Choose the specialist branch for assigned clinic staff. Other survivors take First Aid and Body Building before advancing their weapon branch. Reuse existing skill checks for movement, construction, combat and healing.
- **Zombie** progression starts with Vigour Mortis for reliable XP and Lurching Gait for mobility. Then buy Ankle Grab, Death Grip and Memories of Life, followed by Feeding Groan and Ransack. Continue into claw, bite, scent and coordination upgrades. Lurching Gait plus Ankle Grab takes priority over overlapping Death Lurch benefits. Original undead who prefer that faction can eventually buy Brain Rot and Flesh Rot.

### Revival routes

Human-origin NPCs seek a staffed NecroTech lab, a field medic or an exterior tile tagged `Revive point`. Spraying over the marker clears it. While undead, they can spend XP on Lurching Gait and Ankle Grab before standing, and retain the standing discount after revival. A lab technician with a DNA extractor screens standing patients before committing a syringe. The one-day tag records a snapshot of acquired zombie skills. Medics use it to prioritize dangerous hostiles and avoid opportunistic revivals of dangerous zombies. A blocked Brain Rot sample leaves the syringe in inventory. Revival of a Brain Rot patient requires a powered NecroTech interior, a NecroNet practitioner and 10 AP. Most original undead head to an accessible tall building to return to the horde after revival. A minority remain survivors until their next death.

### Intelligence and coordination

NecroNet reports counts of standing tagged zombies per block within four blocks of the terminal. The NPC planner uses a scan to avoid the largest tagged hostile group while choosing supply routes. A scan is a snapshot, with the tag and the tactical avoidance timer expiring independently.

A survivor can install a transmitter inside a powered, intact building and use the public band from 28.01 to 29.00 MHz. Radio Operation opens 26.00–28.00 MHz. Each handheld receiver tunes independently. Receivers and powered stations hear matching channels, including the loss of a transmitter to zombies. Graffiti and broadcasts allow up to 50 characters. [GameFAQs items guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/weapons-and-items), [Urban Dead development news](https://urbandead.com/oldnews.html)

Paint on the interior and exterior is separate. A fresh can lasts for two sprays, or three when its first user knows Tagging. Fixed charges replace random exhaustion in this offline version, and a partially used can carries its remaining paint through trades and saves. Tagging still awards XP for new exterior messages at eligible landmarks. A legacy save with a single graffiti field loads that message on the exterior. [Urban Dead FAQ](https://www.urbandead.com/faq.html), [GameFAQs building guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/building-types)

New receivers and stations start at 28.01 MHz so survivors can communicate with their starting equipment. Older handhelds inherit their actor's saved channel. Players and NPCs can include a channel when broadcasting, which tunes the station as part of that action. An NPC can broadcast a short defense request when a siege is still defensible. A player can send `Defend` from a powered transmitter to issue the same request. An available builder or survivor with first aid within three blocks can reinforce an enterable refuge. Other recipients can route supplies away from the danger. The call expires after 90 game minutes. NPCs use eligible blank walls for their own tags and keep existing messages when deciding whether to paint.

Structural repairs in dark ruins require light. A maintainer with a toolbox can prioritize installing and fueling a generator before attempting the repair. A standing human inside a building blocks Ransack and Ruin in the shared resolver. Garrisoned survivors hold when local odds favor defense and escape when staying would exhaust their AP or put them in reach of an overwhelming force.

## Integration and verification

The live scheduler keeps `cost()`, `reason()`, `execute()`, the spatial index, search tables and the existing fort and Free Running rules. Older saves start with empty location observations. Zombie scent memory stays separate. The queue is rebuilt from actor wakeups on load, and legacy recovery deadlines round up to the next eligible step.

The headless tests exercise cooldown, interrupted sleep, save continuation, Brain Rot screening, Bellow recruitment, contact-based scent, and VSB ingress. The seeded balance harness reports cohort survival, standing faction totals, revivals, skill purchases, failed moves and action counts. [Balance trials](ai-balance-results.md)
