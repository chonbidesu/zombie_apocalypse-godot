# Urban Dead research and real-time prototype

Research and implementation review: 3 November 2026.

## What survives

The [Wikipedia overview](https://en.wikipedia.org/wiki/Urban_Dead) establishes the broad context: a low-bandwidth, persistent browser multiplayer game set in quarantined Malton, where survival and conflict emerged from player actions. The [official shutdown notice](https://urbandead.com/shutdown.html) dates closure to 14 March 2025 and discussed preserving the wiki read-only. That intention does not establish present availability. Direct official-page access was intermittent during research; some material was available through indexed text. I did not verify a complete working wiki mirror.

The most useful surviving secondary resource is [whowasphone404's GameFAQs guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/introduction), version 3.2, updated 17 March 2025. It explicitly draws on the wiki and preserves descriptions of skills, items, buildings, maps and community history. Treat it as a preservation guide, not an official rules database or complete wiki replacement. Malton comprised 100 suburbs, each containing 100 blocks; the prototype's 10-by-10 neighbourhood is therefore a sensible unit of experimentation.

## The experience to preserve

The [official FAQ](https://urbandead.com/faq.html) describes a 50 AP cap and recovery of one AP every thirty minutes. An empty bar therefore takes 25 hours to fill; sustained recovery supplies 48 AP per day. Characters remain exposed while their owners are absent. Death is reversible, and skills can become dormant when changing between human and zombie states. These rules make energy, shelter and returning to the same character central to play.

One terminology correction matters: the original threat primarily came from other players, not an autonomous NPC population. Participants acted asynchronously; a refresh revealed activity that had happened since the preceding view. Your AI must reproduce that uncertainty and urgency locally. It need not reproduce network delays or hide current damage until the log catches up.

[Adrian Hon's first-person retrospective](https://mssv.net/2025/03/06/urban-dead/) describes improvised social coordination, sieges, frantic defence and play without a prescribed victory condition. This supports preserving consequential simple actions and fragile safety rather than treating Urban Dead as a conventional combat game with a fixed sequence of encounters. Your eventual player-influenced city outcome is a deliberate extension.

## Systems that connect the city

The preserved [building guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/building-types) makes geography strategically meaningful: services, supplies, shelter and access routes differ by building type. NecroNet information concerned DNA-scanned zombies; it was not an omniscient census of every human and zombie. The prototype's timestamped population scan should consequently be described as an adaptation, or later replaced with coverage and observation rules. Towers and other tall buildings also provided a route from human to undead play.

The preserved [items guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/weapons-and-items) documents the syringe's ten-AP revival cost and the importance of supplies, generators and medical items. Revival turns material scarcity into a population constraint. Killing a zombie and restoring a human are strategically different outcomes; simply rewarding kills cannot model the human side's recovery.

The preserved [skills guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/character-classes-and-skills) documents Ankle Grab, Brain Rot, NecroNet and class-sensitive skill costs. Brain Rot requires special treatment inside a powered NecroTech building. Later Headshot rules increase the cost of standing rather than permanently deleting a zombie. Historical mechanics changed: avoid copying an early update's numbers as if they were the final rules.

The [official historical updates](https://www.urbandead.com/oldnews.html) show how power, scanning, manufacturing and building damage connected the economy over time. This is useful design evidence: restoration is a chain of related jobs, giving engineers, scientists and defenders reasons to depend on one another. The partial [Zombiepedia skill transcription](https://zombie.fandom.com/wiki/Zombie_skills_tree_urban_dead) provides additional corroboration, but is less authoritative than official descriptions.

Your persistent individual identities, alternate zombie names, strictly unusable undead inventory, supply exchange and autonomous occupation-driven helpers are intentional design decisions. They should remain explicit rather than being presented as exact original rules. The [original zombie simulation by Kevan](https://kevan.org/proce55ing/zombies/) is also relevant inspiration for population dynamics, but is not evidence of Urban Dead's combat or AP implementation.

## Chosen hybrid: continuous time, discrete commitments

The recommended prototype has one continuously advancing world clock and independent action recovery for each character. A valid action takes effect immediately, spends its AP, and starts a brief recovery. Choosing an action never jumps the world clock. Invalid or repeated commands during recovery spend nothing and are not queued. NPCs follow the same action restrictions, with individually staggered decision times.

This keeps the readable buttons and individual transactions of the original interface while retaining pressure during hesitation. A shared round or synchronized WEGO resolution was rejected for this iteration because it would recreate the simultaneous NPC burst the user wants to remove. It remains possible to explore action wind-up later, but that would need clear cancellation, target revalidation and AP commitment rules.

Initial tuning, all provisional:

| Quantity | Setting |
|---|---|
| Normal clock | 1 game minute per real second |
| AP recovery | 1 AP per 30 game minutes, cap 50 |
| Movement recovery | 1 real second at normal speed |
| Attack recovery | 1.4 seconds |
| Search recovery | 2.2 seconds |
| Revival | 10 AP, 3 seconds recovery |
| Syringe manufacture | 20 AP, 6 seconds recovery |
| Rest | Visible 8x simulation, cancellable |

A full empty-to-full recovery is approximately 25 real minutes at normal speed or 3 minutes 8 seconds at uninterrupted 8x rest. Those are consequences of the initial scale, not commitments to final balance. AP regeneration phase can shift the exact wait. High AP cost does not imply proportionally long animation or recovery.

Rest runs the same simulation faster; it does not jump to a computed end state. Nearby threats, injury or a state change cancel acceleration. Explicit pause, modal screens and context menus stop the simulation. This is a single-player usability concession; assess whether inventory context-menu pausing undermines tension during playtests. The frontend caps unusually large frame deltas to prevent a stalled window producing a sudden catch-up burst; it does not simulate elapsed time while the application is closed.

## Readable activity without hiding danger

The simulation produces structured, timestamped events. Presentation cannot postpone their effects. Player actions and urgent alerts appear immediately. Routine nearby NPC events appear at a paced interval and become concise summaries when activity is dense. Earlier routine events are summarized before a later urgent event, preserving order rather than displaying yesterday's damage after today's action.

Category labels and colours distinguish PLAYER, ALLY, ENEMY, ALERT and WORLD. Allies and enemies are classified relative to the player's current side when the event occurs. Filters support focused reading; History retains the latest 1,000 individual local events even when the compact feed summarizes them. This is a bounded recent record, not a permanent campaign journal. Offscreen routine activity is excluded rather than flooding the local feed.

The current implementation uses short text recovery indicators and disabled controls, rather than animated progress bars. Recovery timing, chat density and interruption sensitivity need human playtesting. Many genuinely urgent attacks can still produce several alerts together; suppressing actual danger merely to keep the log quiet would be misleading. A later aggregate incoming-damage indicator could help in large sieges.

## Validation and next playtest

The updated Godot prototype passes 67 simulation checks and 14 rendered interface checks. Checks cover AP transactions, cooldown rejection, persistent identity and skills, revival, frame-partition-independent scheduling, save/replay, recovery/rest, event pacing and filters, keyboard/mouse controls and pause. Three seeded two-day simulations conserve 33 character records and keep resources within bounds. These are correctness checks, not proof of faction balance.

The next playtest should answer whether a 1–2 second ordinary action cadence feels responsive, whether search leaves a readable window for danger, whether interrupted rest offers time to respond, and whether friendly activity remains understandable during a breach. Tune these within one neighbourhood before expanding the simulation. The city-wide migration, durable human recovery and eventual player-decided outcome remain future work.
