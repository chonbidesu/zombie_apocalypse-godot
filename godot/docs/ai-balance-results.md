# AI balance results — 4 November 2026

## Live utility AI — 8 November 2026

Each trial ran the live scheduler and action resolver for ten game days with an inactive player. Both NPC factions started fully awake at 50 AP. The 30×30 trials started with 45 per side. The 20×20 stress trials started with 60 per side and two occupied medical buildings powered for the first day unless a zombie destroyed the generator first. Seeds 307 and 997 were held out from the main three-seed tuning set. Standing zombies in this table include survivors waiting for revival.

| Map | Seed | Standing humans | Standing zombies | Awaiting revival | Revivals | Attack and bite attempts |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 30×30 | 23 | 43 | 47 | 2 | 9 | 2,582 |
| 30×30 | 71 | 41 | 49 | 4 | 13 | 2,620 |
| 30×30 | 119 | 45 | 45 | 0 | 17 | 2,349 |
| 20×20 | 23 | 27 | 93 | 33 | 39 | 5,393 |
| 20×20 | 71 | 26 | 94 | 34 | 36 | 6,371 |
| 20×20 | 119 | 52 | 68 | 8 | 45 | 5,983 |
| 20×20 | 307 | 28 | 92 | 32 | 37 | 6,745 |
| 20×20 | 997 | 47 | 73 | 13 | 34 | 4,610 |

The 30×30 runs averaged **43 humans and 47 zombies** at day ten. The legacy policy averaged 51 and 37 on those same map seeds and population counts, with 99–129 revivals per run. The live policy supports fewer opportunistic conversions and gives returning survivors a clear clinic or field route. These comparisons include the full policy and starting-role changes.

The dense trials averaged **36 humans and 84 zombies**. Twenty-four of those zombies on average were awaiting revival. Across all five seeds the original undead still accounted for 60 standing zombies at day ten. Field technicians increased the ways to obtain a revival, but the medical network did not keep pace with deaths at this density. The dense configuration remains zombie-favored and all five runs ended with their power out. There was sufficient interaction to expose that failure mode, with 4,610–6,745 attacks and 34–45 revivals per run.

During tuning, a prototype generic noise cue made dark shelters too easy to find and was removed. Visible light, direct sight, contact-based scent and skill-gated calls supply pursuit signals in the current game. Survivors now keep AP for escape, group up when isolated, and delay powering a weak shelter when nearby zombies could overwhelm its garrison. The trials record 2–10 skill purchases per 30×30 run and 13–27 per dense run. Separate focused tests exercise late skills and rare situations such as Bellow, Brain Rot screening and powered radio defense calls.

Raw reports include daily counts, actions and source hashes. [Legacy baseline](../reports/balance-npc-equal-baseline.json), [30×30 trials](../reports/balance-npc-live-equal.json), [20×20 trials](../reports/balance-npc-live-dense.json), [held-out maps](../reports/balance-npc-live-holdout.json), [2,160-NPC Malton smoke run](../reports/balance-npc-live-malton.json)

```powershell
godot --headless --path godot --script res://tests/balance_runs.gd -- --label=npc-live-equal --equal=23,71,119
godot --headless --path godot --script res://tests/balance_runs.gd -- --label=npc-live-dense --dense-equal=23,71,119
godot --headless --path godot --script res://tests/balance_runs.gd -- --label=npc-live-holdout --dense-equal=307,997
```

## Population presets — 5 November 2026

The presets change population density and faction mix. Medium is the default for Malton and generated cities. Generated maps scale both counts by area, and Custom accepts exact counts. The legacy test neighbourhood keeps its fixed setup.

| Preset | Survivors per 10,000 blocks | Zombies per 10,000 blocks | Awake at start | Dormant at start |
|---|---:|---:|---:|---:|
| Easy | 720 | 900 | 115 | 785 |
| Medium | 660 | 1,500 | 240 | 1,260 |
| Hard | 540 | 2,400 | 384 | 2,016 |

Each dormant body has a 20% chance of becoming eligible to stand each midnight. On the 30×30 test map, the presets started with 65/81, 59/135 and 49/216 survivors/zombies respectively. The comparison used the actual simulation with the player inactive. Trials ran for five days on seeds 23, 71 and 119. Seed 307 was held back for a check on the final shelter-selection logic.

| Population | Runs | Standing humans, day 5 mean | Standing zombies, day 5 mean | Ruined blocks, day 5 mean |
|---|---:|---:|---:|---:|
| Previous density (27/54) | 3 | 31.0 | 33.7 | 5.7 |
| Easy | 4 | 83.3 | 39.0 | 10.3 |
| Medium | 4 | 85.3 | 69.5 | 17.8 |
| Hard | 4 | 85.0 | 115.3 | 25.8 |

On the holdout seed, Easy, Medium and Hard ended with 41, 72 and 125 standing zombies and 8, 19 and 29 ruined blocks respectively. Standing human counts include revivals, so they measure current faction size. The presets were selected for increasing undead presence and ruin pressure while keeping survivor groups available. Full-size Malton pilots on seed 23 covered the first day for each preset. The five-day figures describe generated cities with an inactive player.

Reproduce a trial with `godot --headless --path godot --script res://tests/balance_runs.gd -- --label=population-hard-307 --population=random,307,5,49,216` from the repository root. Use `malton` with the full-city counts for the original map.

## Earlier AI trials

81 completed scenario/seed trials across iterative versions, totaling 554 simulated game days. Intermediate reports are retained, including completed scenarios from interrupted tuning suites. The diagnostic trace is excluded. The selected `shelter` version has 10 completed scenarios; `holdout` has 4.

## Method

The headless harness advances the actual simulation, not a simplified combat model. The player is down and inactive at (0,0), contributes no actions, and is excluded from NPC population totals. Day zero is 08:00; daily samples are 24-hour intervals. NPCs obey the same AP, item, skill, search, movement and combat validation as the player.

The baseline captures the pre-change behavior. The selected version combines navigation/retreat fixes, supply AP reserves, shared-home constructors, lab staffing, revival-seeking former humans, combat choices, groan policies and the rule corrections listed in the audit. These are combined-system comparisons, not an isolated experiment on one AI parameter. Same map seeds and population sizes are used; deliberate specialist/home initialization changes can change starting positions and random sequences.

### Paired scenario means

Humans means standing human-form NPCs at the final sample. It is not original-cohort survival: reviving an original zombie can increase the count beyond the starting human population. Revivals are cumulative events and may include the same person more than once.

| Scenario | Days | Seeds | Starting humans / zombies | Baseline humans | Selected humans | Baseline / selected revivals | Failed move reduction |
|---|---:|---|---|---:|---:|---:|---:|
| sandbox | 7 | 23, 71, 119 | 14 / 18 | 1.3 | 16.3 | 2.7 / 3.3 | 92.8% |
| random | 7 | 23, 71, 119 | 45 / 90 | 1.7 | 63.0 | 0.0 / 26.0 | 96.8% |
| siege | 5 | 23, 71 | 14 / 18 | 4.0 | 5.5 | 2.0 / 2.5 | 96.4% |
| malton | 7 | 23, 71 | 300 / 600 | 52.5 | 423.5 | 0.0 / 143.5 | 96.7% |

The random city is 30×30. Malton is the original 100×100 map. The siege deliberately puts all fourteen survivors inside one hospital and eighteen awake zombies immediately outside; most zombies start dormant in the other scenarios. This is a horde stress case, not a normal opening.

### Selected results by seed

| Scenario | Seed | Days | Human forms | Standing humans | Standing zombies | Revivals | Powered buildings | Failed moves |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| sandbox | 23 | 7 | 18 | 18 | 6 | 5 | 0 | 521 |
| random | 23 | 7 | 57 | 56 | 64 | 29 | 1 | 1875 |
| sandbox | 71 | 7 | 17 | 17 | 13 | 3 | 0 | 570 |
| random | 71 | 7 | 66 | 66 | 46 | 25 | 1 | 1071 |
| sandbox | 119 | 7 | 14 | 14 | 14 | 2 | 0 | 504 |
| random | 119 | 7 | 67 | 67 | 44 | 24 | 0 | 976 |
| siege | 23 | 5 | 8 | 8 | 24 | 3 | 0 | 603 |
| malton | 23 | 7 | 416 | 411 | 376 | 132 | 14 | 6816 |
| siege | 71 | 5 | 3 | 3 | 29 | 2 | 0 | 307 |
| malton | 71 | 7 | 442 | 436 | 350 | 155 | 19 | 7570 |
| random (holdout) | 307 | 14 | 52 | 51 | 78 | 36 | 1 | 2928 |
| random (holdout) | 997 | 14 | 48 | 48 | 81 | 50 | 0 | 4317 |
| malton (holdout) | 307 | 14 | 401 | 399 | 473 | 240 | 7 | 18787 |
| siege (holdout) | 307 | 5 | 4 | 4 | 28 | 3 | 0 | 763 |

## What changed and why

The largest actionable bug was exhausted humans repeatedly walking away from a safe, enterable local building to find another refuge. They spent each regenerated AP outside until killed. Local entry now takes priority. Resource trips also end before return AP is exhausted. Temporary route failures have cooldowns instead of repeated illegal movement attempts, and fort routes use the gatehouse.

Shared homes retain a constructor while other members fetch resources. Heavy barricading takes companions outside into account. Working laboratories provide a revival service; some former survivor NPCs queue outside for treatment instead of becoming permanent hunters. Human recovery now competes with zombie growth without free healing, automatic revivals, item grants during play or faction-specific AP discounts.

Zombies retain pressure through valid pursuit, light attraction, target selection, grasp/bite choices, feeding, occasional reinforcement calls, generator destruction and subsequent ruin. An experimental opening in which every sixth zombie already knew Feeding Groan produced early collapses; it was rejected. Zombies can still learn that skill normally.

## Limits and interpretation

These runs support a much more functional offline ecology, not a guarantee of perpetual equilibrium. There are few seeds, the player provides no help, and no original server-wide population targets are claimed. Ending human counts include newly revived original zombies; death/revival remains reversible. End-of-day powered counts miss generators that ran and were destroyed between samples; action histories retain installation/fueling/destruction counts.

The fourteen-day seeds were not used for tuning. They test whether the improvement extends beyond the three development seeds. Horde stress runs should still cause losses and relocation. Longer campaigns, unusual building-count parameters, all-zombie starts and active player interventions remain useful playtest cases.

Reproduce the selected tests with `./launch.ps1 -Balance shelter` and `./launch.ps1 -Balance holdout`. Raw JSON contains every daily sample and cumulative action count. `reports/balance-summary.csv` is a compact export. The baseline is an archived measurement of the earlier implementation, not a mode that restores old code. Reports record the simulation source SHA; the holdout report additionally records all four gameplay source hashes. `tools/summarize_balance.py` rebuilds this report from completed records.

## Verification and artwork

652 checks passed across simulation, survival, NPC/rule regressions, loot/trust, content, encumbrance, world and rendered UI suites. The new NPC suite specifically checks local safe entry, AP reserves, fuel conservation, legal fort paths, revival health, pipe barricades and XP accounting. Art checks verify all 24 zombie frames, rendered crowd/corpse placement and the exact original street tile. See the [rules audit](urban-dead-rules-audit.md) and `tests/zombie_animation_preview.png`.
