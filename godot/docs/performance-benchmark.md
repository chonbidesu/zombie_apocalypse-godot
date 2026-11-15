# City simulation performance baseline

The Godot 4.7.2 project stores the city as a flat array of block dictionaries addressed by `y * width + x`. NPCs are actor dictionaries with a spatial index and a shared tick scheduler. Movement uses a directed `AStar2D` graph that accounts for fort entrances, plus per-actor routes and on-demand reroutes. The harness generates a 100 × 100 city and runs these simulation systems headlessly.

## Capture gameplay

Open a game in a debug build and press **F9** to show the overlay and start writing a CSV. Play through the scene you want to measure, then press **F9** again to hide the overlay and finish the capture. The Godot console prints the absolute path under `user://benchmarks/`. The overlay belongs to the gameplay scene.

## Run the stress harness

Run these from the repository root. If Godot is outside PATH, use the absolute path to the Godot console executable in place of `godot`.

```powershell
godot --headless --path godot --script res://tests/performance_stress.gd -- --scenario=baseline --waves=250,500,1000 --warp=60
godot --headless --path godot --script res://tests/performance_stress.gd -- --scenario=baseline --waves=250,500,1000 --warp=60 --frame-budget-ms=4
godot --headless --path godot --script res://tests/performance_stress.gd -- --scenario=burst --waves=500 --warp=60 --minutes=60
godot --headless --path godot --script res://tests/performance_stress.gd -- --scenario=paced --waves=500 --warp=60
```

Each wave starts a fresh seeded city with roughly one survivor per two zombies, all NPCs initially awake, and a downed player. Each wave gets its own CSV. Add `--seed=4815` to select the seed explicitly. Use `--minutes=1` for a smoke run or omit it for a full 1,440-minute day.

- **Baseline** uses the game's native decision scheduler, AP recovery and route logic. NPCs awakened by the harness receive staggered first turns across the same opening window as naturally active NPCs. Earlier captures queued those newly awakened NPCs together on the first tick. Planner call and successful action counts depend on the run.
- **Paced** invokes the real planner 50 times per NPC per full day, using an evenly spaced sequence of calls for each actor. The planner and action rules still determine which calls produce an action. Use this workload to compare runs with the same planner call count.
- **Burst** schedules all first NPC decisions at the first 30-minute AP boundary, starts each NPC one AP below the cap, and then issues one extra synchronous route query per NPC at that same tick. At 500 NPCs this forces 500 AP grants and 500 extra route queries. The dedicated `burst` row captures those counts along with any other AP or route work in the same frame.

The game advances one in-game minute per real second at 1×. A full day targets 24 minutes at 1×, 144 seconds at 10×, or 24 seconds at 60×. The harness uses the monotonic wall clock to request whole simulation steps and executes every requested step, up to 14,400 per day. Heavy workloads can miss the target duration. Headless runs default to a 60 FPS cap, and an explicit Godot `--max-fps` before the argument separator can select a different cap. Use the same cap, seed, warp, and Godot build when comparing runs.

Add `--frame-budget-ms=4` to test a soft main-thread time budget for simulation advance. The harness checks the budget after each complete tick and carries overdue ticks forward in order. A single expensive tick can exceed the budget. The default step cap for budgeted runs is 16 per frame. Set `--max-steps-per-frame` to vary it. With the frame budget omitted, the harness executes all due ticks in the current frame.

## Check the rendered frame limits

```powershell
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=rest
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep --main-thread-sleep
```

Rest and sleep use a dedicated simulation thread on machines with multiple logical CPUs. During rest, the interface animates an isolated world copy and receives local actor/block snapshots every 250 ms. During sleep, it reads published progress. `--rest-handoffs` selects the older rest implementation that joins the worker before each presentation frame. `--main-thread-recovery` selects the original 4 ms rest or 8 ms sleep foreground budget. `--main-thread-sleep` remains an alias. Run comparisons sequentially on the same rendered setup. Each run exits with code `1` if the nearest-rank p99 reaches 18 ms or any wall frame reaches 20 ms. The CSV includes every measured frame and is written before the limits are checked. The explicit `--unbounded` and `--frame-budget-ms` controls use the main thread and report frame times without applying the limits.

`godot --headless --max-fps 60 --path godot --script res://tests/threaded_sleep_test.gd` compares the ordered NPC action trace, final world state and wake tick with the main-thread implementation. It also exercises Wake, Escape, interruption, pause, quicksave, telemetry, teardown and rest handoffs. Rest handoffs account for worker and interface elapsed time once.

The default workload retains 1,000 NPCs for comparison with the earlier captures. Use `--npcs=4000 --humans=2000` for 2,000 humans and 2,000 zombies. At that density, the fixture can select an unoccupied office with populated surroundings when every three-block halo is occupied. It preserves the population and places the same twelve shelter residents. Captures allow up to five minutes of wall time for the larger workload.

Planner worker counts adapt to measured tick cost. The automatic CPU budget reserves two logical CPUs for the interface and simulation owner. Separate workload sizes compare serial planning with progressively larger worker counts using five timing samples per configuration. A parallel configuration needs a measured advantage of at least 3% over the serial sample. `--planner-threads=0` disables planner workers while retaining the simulation thread. `--planner-threads=4` requests up to four workers. The console records the actual worker peak, reuse counts and tuning samples.

```powershell
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep --npcs=4000 --humans=2000
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=rest --npcs=4000 --humans=2000
godot --headless --path godot --script res://tests/parallel_planner_test.gd -- --npcs=4000 --humans=2000 --ap=12
```

The planner regression compares each action, each directed A* route, actors, map state, events, RNG state and bounded observation memory at serial, one-thread, four-thread and automatic settings. Its default one-AP fixture is also part of `launch.ps1 -Test`. The larger twelve-AP command above covers six simulated hours.

### Optional C# spatial queries

Build the solution in Godot .NET before running these commands. Set `$godotNet` to the .NET console executable. The C# query kernel activates during recovery, and complete-tick samples select between C# batches and GDScript scoring. Each workload-size group collects five samples per backend, and C# needs a 3% measured advantage. `--managed-planner` forces C# batches for comparison. `--gdscript-planner` retains C# spatial queries while using GDScript decision scoring. `--gdscript-queries` selects the complete GDScript query/planner backend. Both backends use the same action resolver and A* graph. `--planner-threads=0` runs preparation serially while retaining the simulation thread. `--no-route-cache` forces every route request to search the graph. The console separates logical requests, actual searches, cache hits and temporary-obstacle bypasses.

Gameplay remains at 32× sleep and 8× rest. The benchmark-only `--target-speed=512` override requests enough work to measure capacity beyond 32× without changing game constants or adding a speed control to the UI. Completing this six-hour fixture above 32× requires less than 11.25 seconds.

```powershell
$godotNet = 'C:\Program Files (x86)\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
& $godotNet --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep --npcs=4000 --humans=2000
& $godotNet --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep --npcs=4000 --humans=2000 --gdscript-queries
& $godotNet --headless --path godot --script res://tests/parallel_planner_test.gd -- --npcs=4000 --humans=2000 --ap=12
& $godotNet --headless --path godot --script res://tests/managed_queries_test.gd
& $godotNet --headless --path godot --script res://tests/managed_planner_test.gd
& $godotNet --headless --path godot --script res://tests/route_cache_test.gd
& $godotNet --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep --npcs=4000 --humans=2000 --target-speed=512
```

Under .NET, the trace regression uses GDScript queries for its serial reference and asserts that the C# backend was exercised by the other configurations. The query regression compares targets at map edges, tied distances, door states, powered and unpowered generators, clinic staffing, revive markers and changed mirror records. It skips under standard Godot.

### 4,000-NPC recovery results

These captures predate the rate adjustment to 32× sleep and 8× rest. They used the previous 512× sleep and 16× rest targets. Current gameplay shows recovery status and AP progress without speed indicators.

Final sequential captures on 2026-11-14 used Godot .NET 4.7.2, an i5-13400F with 16 logical CPUs, an RTX 4060, Compatibility rendering and a 60 FPS cap. The requested window was 1536 × 864 and the captured viewport was 1229 × 692. Each run used seed 4815, 2,000 humans and 2,000 zombies, the same twelve shelter residents, and AP 38 → 50. Every run executed 3,600 ticks and 147,216 NPC actions over six simulated hours. These are individual captures, rather than medians.

| Query backend | Recovery | Wall time | Achieved speed | Frame p99 | Worst frame |
| --- | --- | ---: | ---: | ---: | ---: |
| Optimized GDScript | Sleep | 37.639 s | 9.56× | 16.861 ms | 174.197 ms |
| C# | Sleep | 29.578 s | 12.17× | 16.800 ms | 168.737 ms |
| Optimized GDScript | Rest | 40.910 s | 8.80× | 58.894 ms | 82.454 ms |
| C# | Rest | 32.384 s | 11.12× | 47.506 ms | 87.127 ms |

C# reduced elapsed time by 21.4% for sleep and 20.8% for rest compared with GDScript queries in the same .NET engine. Both used automatic worker selection. The original planner baseline, captured earlier with standard Godot on the same machine and fixture, took 43.367 seconds for dedicated-thread sleep and 59.474 seconds for foreground rest. Those historical controls also predate the GDScript algorithm improvements and threaded rest.

The worker tuner includes candidate collection, conflict filtering, dispatch, invalidation and ordered resolution in its samples. Selecting serial planning skips candidate collection. Final C# captures tested up to thirteen concurrent planner workers, then selected serial planning in all sampled workload groups. An explicit C# serial-planner control took 29.350 seconds for sleep, within 0.8% of the final automatic capture. Splitting the remaining GDScript planner work did not establish a throughput advantage for this fixture after the C# query migration. Worker capacity remains available for workloads that benefit from it.

Neither backend meets the frame gates at this population. Sleep passes p99, but rebuilding the dashboard on wake produces the longest frame. Rest exceeds both frame limits. The 512× sleep target would require roughly 0.703 seconds for this workload, and the 16× rest target would require 22.5 seconds. The C# port improves throughput but does not reach either target here. A* remains on the simulation owner, and route results match the GDScript reference.

Raw final logs and CSVs are under the local `.runtime/managed-verified/` directory. The four `*-4000-*-final.log` files identify the corresponding CSVs. Earlier exploratory repetitions and the explicit serial control remain there too.

Validation passed the .NET build with zero warnings and errors, 404 query checks, the 4,000-NPC action/route trace, and 23 threaded recovery checks covering Wake, Escape, interruption, pause, save, telemetry, teardown and rest timing. The full trace compared all worker settings before the tuning correction, and the final automatic configuration was checked again against serial GDScript: all 147,216 actions, 70,895 directed routes, actors, blocks, metrics, events, RNG state and bounded memory matched. The standard-engine fallback passed 21 planner checks. Simulation (234), sleep (15), and recovery-budget (13) checks also passed.

The broader AI suites still have six failures in `npc_balance_test.gd` and nine in `survival_test.gd`. The original planner, AI and supply implementations reproduce the same failures. Those existing rule/expectation failures are separate from these recovery changes, so the full `launch.ps1 -Test` run remains red.

### Planner batches, route cache and rest snapshots

This follow-up used the same machine, rendering setup, seed, population and six-hour fixture. An isolated copy of the preceding implementation provided the before control, including the C# spatial queries and the requested 32× sleep / 8× rest game constants. Sleep capacity captures used `--target-speed=512` for both implementations. All captures executed exactly 3,600 ticks, 147,216 NPC actions and 70,895 logical route requests.

| Configuration | Recovery | Seconds | Achieved speed | Frame p99 | Worst frame |
| --- | --- | ---: | ---: | ---: | ---: |
| Before these changes | Sleep capacity | 29.345 | 12.27× | 17.059 ms | 179.493 ms |
| Complete version, including stock-table invalidation | Sleep capacity | 24.715 | 14.57× | 16.810 ms | 165.869 ms |
| Automatic planner selection | Sleep capacity | 23.549 | 15.29× | 16.794 ms | 166.564 ms |
| Automatic selection, repeat | Sleep capacity | 23.817 | 15.12× | 16.792 ms | 167.838 ms |
| Force C# batches | Sleep capacity | 24.251 | 14.85× | 16.759 ms | 168.537 ms |
| Force GDScript scoring, retain C# queries | Sleep capacity | 23.198 | 15.52× | 16.771 ms | 165.534 ms |
| Force C# batches, disable route cache | Sleep capacity | 24.398 | 14.76× | 16.801 ms | 165.810 ms |
| Before these changes | Rest at 8× | 44.891 | 8.02× | 45.257 ms | 85.502 ms |
| Automatic planner, UI snapshots | Rest at 8× | 45.027 | 8.00× | 16.911 ms | 89.043 ms |
| Automatic planner, per-frame handoffs | Rest at 8× | 44.889 | 8.02× | 35.550 ms | 86.338 ms |

The last capture includes the stock-cache regression fix that detects edited loot tables and took 24.715 seconds, 15.8% less time than the before control. Earlier automatic captures took 23.549 and 23.817 seconds. These are individual runs with timing-dependent backend/worker calibration, rather than a controlled median. C# batching alone did not beat the refactored GDScript scorer on this fixture: the forced comparison was about 4.5% slower. The automatic selector therefore keeps C# for sampled groups where its complete-tick measurement wins, with GDScript handling most of this workload. The C# batch implementation covers human context, combat, healing and revival candidates. The owner still runs maintenance, supply policy, validation, RNG and mutations. This is a hybrid planner rather than a complete simulation rewrite.

The cache reduced real A* searches from 70,895 to 27,657, with 43,238 hits and 2,789 temporary-obstacle bypasses. The forced C# pair differed by only 0.147 seconds with caching enabled, so these single captures do not establish a large wall-time benefit. Baseline instrumentation measured A* itself at about 0.39 seconds. Refactoring impossible maintenance choices, donor supply checks, stock observations, repeated AP-cost calculation and neighbour readiness checks did more to reduce total decision work. Instrumented validation calls fell from about 708,000 to about 240,000 without removing any committed actions.

Rest remains limited to its requested 8× rate, so the expected six-hour duration is 45 seconds. Snapshots improve frame pacing instead of trying to finish earlier than that rate permits. Rest p99 fell from 45.257 ms before these changes to 16.911 ms. The longest rest frame is now startup, where the isolated UI copy is created. Sleep's longest frame remains wake. The worst-frame gate still fails in both modes.

The normal 32× sleep capture with automatic selection took 24.198 seconds, or 14.88× achieved speed. Raising only the benchmark target to 512× did not approach the 11.25-second threshold required to exceed 32×. Gameplay remains configured for 32× sleep and 8× rest, without visible speed indicators.

The full before/after trace and the forced C# serial, four-worker and automatic-worker trials matched every action, directed route, final actor/block/metric, event, RNG state, bounded memory record and exact wake tick. Query, planner, route-cache, UI, search, simulation, sleep and recovery tests passed. Rest checks also verify that UI actors and blocks are separate objects from the worker-owned world. The standard Godot fallback passed its planner comparison. Existing AI/survival rule failures remain as described above.

Raw logs and CSVs are under `.runtime/planner-batch-verified/`. `sleep-baseline.log` and `rest-baseline.log` are the isolated before controls. The feature controls and final captures identify their CSV paths in each log. `--managed-planner`, `--gdscript-planner`, `--no-route-cache`, `--rest-handoffs` and `--target-speed` make those comparisons repeatable without editing game constants.

### Full AP recovery, turn-time planning and local awareness

The 2026-11-14 follow-up uses the same Godot .NET build, machine, seed 4815, 100 × 100 city, 2,000 humans, 2,000 zombies, twelve shelter residents and player AP 38 → 50. Every run advances 3,600 ticks (six simulated hours) and wakes on step 8400. The before control is a frozen copy of the preceding implementation. The capacity runs request 512× only in the harness; gameplay remains at 32× sleep and 8× rest, with no player speed indicator.

| Implementation | Six-hour wall time | Achieved speed | NPC actions | Planner calls | Route requests | Actual A* searches |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Before, two-run median | 23.957 s | 15.03× | 147,216 | 200,067 | 70,895 | 27,657 |
| New defaults, two-run median | 17.815 s | 20.21× | 116,668 | 142,517 | 41,212 | 12,875 |

The paired times were 24.213/17.790 seconds and 23.700/17.840 seconds. Elapsed time fell 25.6%. This is partly a deliberate behavior change: exhausted or voluntarily resting NPCs now wait for 50 AP, and ordinary live perception is restricted to the current block plus eight neighbours. Successful actions fell 20.8%, planner calls 28.8%, route requests 41.9%, and actual A* searches 53.4%. The navigation graph, directed route rules and exact path results remain unchanged for a given request.

Single-run controls isolate the practical effects. Their timings are descriptive and should not be added together:

| Control relative to new defaults | Seconds | NPC actions | Planner calls |
| --- | ---: | ---: | ---: |
| Format all action narration | 18.124 | 116,668 | 142,517 |
| Restore previous partial AP recovery | 21.726 | 141,310 | 185,925 |
| Enable previous speculative planning | 17.657 | 116,668 | 142,517 |
| Restore previous wide awareness | 16.206 | 108,945 | 135,190 |
| New defaults at the actual 32× target | 17.573 | 116,668 | 142,517 |

Full AP recovery gives the largest isolated saving. Lazy narration gives a smaller saving: only 132 actions are formatted and 116,536 (99.9%) skip formatting. Turn-time planning removes all speculative batches and invalidation replans, with similar elapsed time to the speculative control in this fixture. Local awareness enforces the requested information rules but does not independently improve integrated runtime here: it leads to more actions and fewer recovery entries than the wide-awareness control. These comparisons are not behavior-equivalent except for narration and speculative preparation controls.

Normal 32× sleep achieved 20.49×. Exceeding 32× would require finishing this six-hour fixture in less than 11.25 seconds, so this implementation still does not reach that threshold. Median p99 frame time is about 16.8 ms. Worst frames fall from 164–167 ms to about 41 ms and occur on wake. Every rendered capture still fails the existing 20 ms worst-frame assertion; these are completed throughput measurements, not passing frame-budget tests.

Validation includes a 4,000-NPC differential narration run: all 116,668 ordered actions, final actors/blocks/metrics, RNG, memory and player messages match with formatting forced on and off. Separate flavour-RNG and remote-signal cases cover reading, barricading, searching, groans, Bellow, broadcasts and phones. The GDScript reference and forced C# turn-time planner at one, four and automatic worker limits match all 116,668 actions and 41,212 route results. Recovery checks cover no decisions below 50 AP, ignored early wakeups, stale scheduler tickets, save/load, safe-entry attempts, outdoor recovery, local landmarks, hidden roof occupants and explicit Scent Death range. Threaded sleep tests retain action order, natural wake, Wake, Escape, pause/resume, quicksave and threaded rest behavior. The standard Godot fallback also passes its planner and recovery checks. The existing six NPC-balance and nine survival failures remain unchanged from the preceding implementation.

Repeat the default capacity run with:

```powershell
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep --npcs=4000 --humans=2000 --target-speed=512
```

Add one of `--full-narration`, `--legacy-npc-rest`, `--speculative-planning` or `--wide-awareness` for a control. Omit `--target-speed` to measure the gameplay setting. New regressions are `npc_recovery_test.gd` and `npc_narration_test.gd`; the latter accepts `--npcs=4000 --ap=12` for the full six-hour trace. Raw logs, retained per-run CSVs and `results.json` are under `.runtime/npc-recovery-verified/`. One before-run CSV was overwritten after Windows reused its process ID; its log retains the timing, and the other before CSV retains its counters.

### Dedicated sleep thread comparison

Three paired runs on Windows with Godot 4.7.2, Compatibility rendering on an RTX 4060, and a 60 FPS cap measured the 1,000-NPC busy shelter at seed 4815. Each recovered 12 AP, ran 3,600 ticks, and resolved 31,987 NPC actions before waking on tick 8400.

| Sleep mode | Median time to 50 AP | NPC actions/s at median time | Median p99 frame | Worst frame across runs |
| --- | ---: | ---: | ---: | ---: |
| Main thread, 8 ms budget | 11.275 s | 2,837 | 18.284 ms | 46.331 ms |
| Dedicated simulation thread | 7.336 s | 4,360 | 16.805 ms | 20.107 ms |

The dedicated thread reduced median sleep time by 35%. All threaded runs passed the p99 limit. Two passed the worst-frame limit. The longest frame in every run was the wake frame. The six raw captures are in the local `.runtime/threaded-sleep-final/` user-data directory.

## Run a multi-day soak

```powershell
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_soak.gd -- --days=24
```

Use a debug build. The soak advances every simulation tick in 12-minute batches with 1,000 NPCs. It alternates rest and sleep in a reinforced shelter and updates the gameplay scene after each batch. It checks for orphan nodes after deferred cleanup on every frame and writes hourly memory, node, object, and resource counts under `user://benchmarks/`, including a sample after scene teardown. The soak measures retention over simulated time. The rendered frame-limit checks above exercise the normal frame budgets.

## Read the CSV

- **Frame cost.** Rows normally summarize about one second. `mean_wall_frame_ms` and `peak_wall_frame_ms` measure elapsed time between frame callbacks, including waits. Godot updates `fps`, `engine_process_ms`, and `engine_physics_ms` on its own roughly one-second interval. Those engine readings can carry over between CSV rows, including the first row after setup. A `burst` row isolates one frame's wall time and simulation counters. Headless frame timings characterize the simulation and engine loop. Capture gameplay for timings with rendering and UI work. [Godot 4.7.2 engine timing](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp#L4741-L4762)
- **Script and decision cost.** `script_ms` and `peak_script_ms` time the gameplay scene's frame callback or the harness's simulation advance. The gameplay callback includes nested simulation time. `simulation_ms` and `peak_simulation_ms` isolate the measured simulation entry points and their nested work. `decision_mean_us` divides timed planner work by planner calls, and `npc_actions` counts successful NPC actions. The Godot editor profiler provides timings for other script functions. [Godot profiler documentation](https://docs.godotengine.org/en/latest/tutorials/scripting/debug/the_profiler.html)
- **Path and AP load.** `path_queries` counts logical route requests, including cache hits, reroutes and supply lookups. The gameplay console reports actual A* searches, cache hits and obstacle bypasses separately. `peak_path_queries` is the largest frame count in the window. `ap_updates` counts actors visited by the recovery loop, including the player, while `ap_grants` counts actual increments. In a burst row, `forced_path_ms` measures the synthetic route batch and `ap_ms` measures the recovery loop.
- **Memory and node counts.** `static_memory_bytes`, `static_peak_bytes`, `nodes`, and `orphan_nodes` come from Godot's Performance singleton. The dynamic-memory field is blank because Godot 4.7 exposes no separate dynamic-memory monitor. Use a debug build for memory and orphan counts. [Godot Performance monitors](https://docs.godotengine.org/en/latest/classes/class_performance.html)
- **Setup cost.** `setup_ms` includes city generation, navigation graph construction, NPC creation, and harness setup. The frame capture starts after setup. `sim_minute` uses the simulation's absolute clock, which starts at minute 480.
- **Fast-forward budget.** `frame_budget_ms` and `max_steps_per_frame` identify the stress harness limits. `peak_steps_per_frame` is the largest tick batch in the row. `backlog_steps` gives the ticks still due after the last frame in the row, and `peak_backlog_steps` gives the largest such backlog in the row. `achieved_warp` divides simulated minutes completed since capture started by wall seconds elapsed. The [rendered gameplay capture](performance-optimization.md#integrated-budgets-in-a-busy-shelter) records recovery-mode budgets and deferred time.
- **Frame percentiles.** `wall_frame_p95_ms` and `wall_frame_p99_ms` are cumulative since capture started. Values are upper bounds rounded into 0.25 ms histogram bins. Values beyond the histogram range appear as `>4096`. Use the last row for whole-run percentiles.
- **Periodic UI refresh.** In gameplay, `periodic_refreshes` counts scheduled dashboard refreshes in the window. `periodic_refresh_ms` totals their synchronous time and `peak_periodic_refresh_ms` records the largest frame total. Measure the wall interval to include deferred layout and node cleanup.
