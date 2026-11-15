# DNA scanning and medical NPC adjustment — 15 November 2026

Implemented shared calendar-day DNA scans, technician revival training and support XP priorities. The two ten-day pilots below use seed 23 on full Malton, with 2,000 humans and 2,000 zombies, paired against the archived controls. One retains the natural dormant opening; the other wakes every zombie. The inactive player is excluded and untargetable. No extra skills, XP, syringes or staffed clinics are granted to the pilots.

Follow-up: standing as a zombie after death now resets scan eligibility, including after revival and another death. The recorded pilots below predate that small change and retain their original rules and measurements.

## Rules used by the recorded pilots

- A successful DNA extraction earns exactly 4 XP and records both human and zombie skills. Each zombie can be scanned once per calendar day by any human, with a shared midnight reset. Death, standing, revival or learning another skill cannot reopen that allowance. Rejected repeat scans award no XP.
- Player scanner use automatically selects a local unscanned standing zombie in the same compartment. A fresh selected target is preferred; stale/scanned selections fall through to another usable target. Brain Rot restrictions remain in the resolver.
- Only a player's extraction produces a clickable skill report in the activity feed and History. Reports retain the recorded skills even after movement, death, later training and saving/loading. Opening one costs no AP or time.
- NPCs that started with NecroTech Employment seek local sampling opportunities and buy Lab Experience before Free Running. Healthy technicians can take a sample before retreating from a lone zombie; overwhelming danger and full-AP recovery remain in force.
- Trained technicians prioritize syringe searches and sampled human-trained revival candidates. A hidden revival preference or a low-threat zombie profile alone cannot identify a former human. Existing player rescue remains available. Both planner backends share this medical policy.
- Useful first aid to someone else earns the existing 5 XP. Support roles prioritize that work; self-healing and curing infection without restoring HP do not award XP.

## Paired ten-day pilots

| Opening | Metric | Before | After |
| --- | --- | ---: | ---: |
| natural | Revivals | 0 | 14 |
| natural | NPCs owning Lab Experience | 0 | 51 |
| natural | Human forms at day ten | 1,490 | 1,522 |
| natural | Standing humans | 1,490 | 1,520 |
| natural | Successful DNA samples | 192 | 2,193 |
| natural | DNA XP earned | 768 | 8,772 |
| natural | XP from healing others | 6,945 | 7,875 |
| awake | Revivals | 0 | 30 |
| awake | NPCs owning Lab Experience | 0 | 100 |
| awake | Human forms at day ten | 1,299 | 1,252 |
| awake | Standing humans | 1,299 | 1,249 |
| awake | Successful DNA samples | 191 | 3,670 |
| awake | DNA XP earned | 764 | 14,680 |
| awake | XP from healing others | 7,510 | 8,485 |

### Technician progression

| Opening | Mean technician XP, before / after | Mean skills purchased, before / after | Trained Lab Assistants, before / after |
| --- | ---: | ---: | ---: |
| natural | 12.94 / 47.20 | 0.000 / 0.198 | 0 / 51 |
| awake | 11.50 / 68.58 | 0.000 / 0.393 | 0 / 100 |

These pilots test whether the requested medical behaviors function at city scale. They do not isolate individual changes or establish a new equilibrium. Population differences include changed travel, exposure, XP progression and the shared random stream; more revivals alone does not prove an overall human survival improvement.

## Sleep throughput check

One rendered six-hour sleep capture with 2,000 humans and 2,000 zombies, seed 4815 and the configured 32× target completed 3,600 ticks and 122,034 actions in 18.207 seconds (19.77× achieved). Frame p99 was 16.807 ms; the 41.158 ms wake frame still fails the existing 20 ms worst-frame limit. This is a completed throughput capture, not a passing frame-budget test or a paired performance experiment. Gameplay remains configured for 32× sleep and 8× rest, with no speed indicator.

[Capture data](../reports/dna-medical-2026-11-15/sleep-performance.json) and [frame CSV](../reports/dna-medical-2026-11-15/sleep-4000.csv).

## Verification

The new headless DNA/medical regression checks exact scan XP, shared rejection, automatic targeting, midnight reset, death/revival lockouts, both skill trees, snapshot persistence, scientist training and useful first aid. The rendered DNA regression checks inventory Use, feed and History links, historical skill lists and no AP/time cost. C# and GDScript comparison covers the same medical decisions. The action-order regression matches every committed action and route at serial, single-worker, four-worker and automatic configurations; threaded recovery retains natural wake, Wake, Escape, pause/resume and save behavior.

Every pilot day audits per-NPC XP income/spending, skill purchases, deaths, revivals and successful actions. This summarizer independently reconciles the exported actor CSVs, checks scan XP is four times successful samples and checks healing XP is a multiple of five. The remaining two existing NPC-balance and nine existing survival assertions are unrelated to the new medical policy; the updated DNA scenarios and general simulation/UI regressions pass.

```powershell
godot --headless --path godot --script res://tests/dna_medical_test.gd
godot --path godot --script res://tests/dna_interface_test.gd
godot --headless --path godot --script res://tests/balance_cohort_runs.gd -- --seed=23 --days=10 --opening=natural --output=res://reports/dna-medical-2026-11-15
godot --headless --path godot --script res://tests/balance_cohort_runs.gd -- --seed=23 --days=10 --opening=awake --output=res://reports/dna-medical-2026-11-15
python godot/tools/summarize_medical_adjustment.py
```

Use Godot .NET with the built assembly to reproduce the same query backend. Standard Godot also passes the new DNA rules. [Detailed comparison JSON](../reports/dna-medical-2026-11-15/comparison.json) includes cohort XP, skill/death maxima and daily revivals. Raw daily JSON and per-NPC CSVs are in the same folder. [Archived six-run baseline](balance-2026-11-14.md).
