# AI balance results — 4 November 2026

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

652 checks passed across simulation, survival, NPC/rule regressions, loot/trust, content, encumbrance, world and rendered UI suites. The new NPC suite specifically checks local safe entry, AP reserves, fuel conservation, legal fort paths, revival health, pipe barricades and XP accounting. Art checks verify all 24 zombie frames, rendered crowd/corpse placement and the exact original street tile. See the [rules audit](urban-dead-rules-audit.md) and `tests/zombie-animation-preview.png`.
