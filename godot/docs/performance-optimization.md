# Phase 3 simulation performance plan

## What the full-day captures show

All three supplied captures completed 14,400 clock steps on 10,000 blocks at seed 4815 and requested 60× speed. The figures below use frame counts divided by elapsed wall time for mean FPS, and the largest recorded frame peak across each CSV.

| NPCs | Wall time | Mean headless FPS | Worst wall frame | Peak paths/frame | Planner calls | Actions | AP recovery CPU over the day |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 250 | 24.02 s | 59.41 | 42.11 ms | 57 | 22,600 | 11,244 | 13.42 ms |
| 500 | 24.02 s | 50.96 | 928.36 ms | 168 | 48,600 | 23,070 | 17.02 ms |
| 1,000 | 24.03 s | 32.67 | 2,218.73 ms | 947 | 96,286 | 43,585 | 19.42 ms |

- **Simulation work drove the largest stalls.** The 1,000-NPC peak was a single frame that advanced 1,315 ticks, called the planner 12,985 times, and spent 2,218.64 ms in simulation. It issued 535 routes. The 500-NPC opening window also hit 523.48 ms with zero route queries in the entire window. The planner and its nested work account for about 96–97% of measured simulation time across all three runs. Path counts alone cannot assign a share of that time to A*.
- **The original opening amplified the load.** The harness woke dormant NPCs whose due times had been cleared. The scheduler clamped all of those first turns to the next tick, including 561 NPCs in the 1,000-NPC run. At 60× a slow frame also increases the next frame's catch-up batch. The corrected baseline assigns the newly awakened actors stable offsets across the native opening window. The burst scenario still schedules its deliberate synchronized work.
- **AP and node counts are lower priorities.** The AP loop accounted for less than 0.2% of measured simulation time in each run. All waves held at four scene-tree nodes and zero orphan nodes. Sampled static memory increased by 0.20–0.69 MiB from first to last sample. A longer soak with repeated world loads would give better evidence about retention. [Benchmark metric definitions](performance-benchmark.md)

The CSV holds window aggregates and peaks. A frame-time p95 or p99 needs per-frame samples or a frame-time histogram. Headless runs measure simulation and engine-loop timing. Gameplay captures include the UI and renderer.

## Follow-up runs after the harness fix

At 1,000 NPCs and 1×, the original setup peaked at **162.99 ms** in the first 30 simulated minutes. With staggered first turns, the same opening at the same seed peaked at **22.75 ms**. The corrected run still spent 22.66 ms in simulation on that frame, and the surrounding window contained zero path queries.

The corrected 60× runs still stalled during the first 360 simulated minutes. The 500-NPC run peaked at **1,002.24 ms** and averaged **59.7×**. The 1,000-NPC run peaked at **2,600.07 ms** and averaged **51.0×**. This is the workload for the catch-up budget experiment. The 500-NPC burst still produced 500 AP grants and 500 forced queries in one frame. Its recovery loop took 0.86 ms of the 219.48 ms spent in simulation.

## Full-day frame budget comparison

The supplied corrected 60× captures each reached 14,400 ticks. The supplied 1× run at 1,000 NPCs peaked at 24.51 ms over its first 60 simulated minutes. For the budget comparison, each run used seed 4815, the 60 FPS headless cap, and a request of 60×.

| NPCs | Corrected baseline worst frame | 4 ms budget worst frame | 4 ms budget p99 | 4 ms achieved speed | Peak overdue ticks |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 250 | 28.31 ms | 17.06 ms | 17.00 ms | 59.63× | 1,813 |
| 500 | 864.10 ms | 17.01 ms | 17.00 ms | 31.23× | 8,420 |
| 1,000 | 2,554.06 ms | 19.67 ms | 17.00 ms | 25.53× | 9,975 |

The budgeted runs finished all 14,400 ticks and matched the corrected captures' planner calls, successful actions, route queries, and AP grants. Each finished with zero overdue ticks. A fresh unbounded 1,000-NPC control with the new telemetry reached 59.94× with a 181.25 ms p99 and a 2,669.56 ms worst frame.

An 8 ms budget at 1,000 NPCs reached **46.76×** with a **17.00 ms p99** and an **18.81 ms worst frame**. Peak overdue ticks fell to 3,918, and the workload counts matched the control. Use 8 ms as the next headless comparison point. In the separate 500-NPC burst, a single tick still took 219.35 ms under the 4 ms budget. That frame included all 500 AP grants and all 500 forced path queries.

## Single-tick profile at 1,000 NPCs

The full-day trace used seed 4815 and the corrected baseline setup. It completed 14,400 ticks with 97,916 planner calls and 44,032 actions. The p95 tick took **6.59 ms**, the p99 took **9.79 ms**, and the maximum was **13.71 ms**. There were 1,196 ticks above 4 ms and 497 above 8 ms. Each timing scope includes its callees, and the probe adds stopwatch overhead.

- The slowest tick ran 42 decisions and spent 13.47 ms inside the planner. Its two A* requests totaled 0.019 ms. The slowest tick with zero route requests took 12.23 ms.
- Zombie decisions used 3.73 s of the 4.59 s of planner time in ticks above 8 ms. Across the day, `nearby_light()` used 2.85 s and `_visible_human()` used 1.49 s. Start with these neighbourhood scans. A bounded index of installed generators could narrow the light scan while leaving fuel and power checks at query time. For human visibility, reuse the existing occupant ID buckets while preserving search order and visibility rules.
- The largest human supply-planning outlier took 9.25 ms inside `_supply_turn()`. A* used 73.36 ms over the whole day, and AP recovery used 16.88 ms. Profile supply scoring separately if those human ticks still stand out after the scan improvements.

## Rendered rest and sleep in a quiet office

Six captures ran the actual gameplay scene on the RTX 4060 with the Compatibility renderer, VSync disabled, and a 60 FPS cap. Each run started fresh at seed 4815, used the same quiet office, and recovered 12 AP over 360 simulated minutes. The rest scene reported 153 draw calls per frame, and the sleep scene reported 43 before wake. Frame percentiles below use individual wall intervals between process callbacks. The uncapped sleep p99 is also its maximum because that run drew 38 frames.

| Mode | Simulation budget | Recovery wall time | Effective speed | p99 frame | Worst frame |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rest | Unbounded | 22.74 s | 15.83× | 148.73 ms | 182.51 ms |
| Rest | 4 ms | 22.50 s | 16.00× | 26.44 ms | 29.98 ms |
| Rest | 8 ms | 22.50 s | 16.00× | 29.43 ms | 34.32 ms |
| Sleep | Unbounded | 6.96 s | 51.76× | 1,139.41 ms | 1,139.41 ms |
| Sleep | 4 ms | 20.77 s | 17.34× | 16.72 ms | 19.80 ms |
| Sleep | 8 ms | 11.37 s | 31.67× | 19.77 ms | 23.22 ms |

These runs led to the **4 ms rest and 8 ms sleep gameplay budgets**. The 4 ms rest run finished at 16× overall and spent up to 7.12 s of deferred wall time catching up later. The 8 ms rest run cut that peak to 1.73 s and had a higher p99. A 4 ms sleep budget ran closer to the 60 FPS target and took longer to complete recovery.

Rest still exceeded 16.67 ms outside simulation on 84 frames in each capture. In the 4 ms run, p99 UI callback time outside simulation was 15.03 ms, and the draw interval was 1.45 ms. The next rest improvement is to time and reduce the periodic scene refresh, then repeat the capture in a busier shelter. The draw interval measures CPU-side time between Godot's draw signals. [Godot RenderingServer signals](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#signals)

The exploratory captures carried deferred time in a benchmark subclass. The 4 ms sleep capture recorded four extra normal-speed ticks on its wake frame and had 17.55 s of deferred wall time at capture end. Gameplay now clears that time on wake, cancel, and recovery interruptions.

## Integrated budgets in a busy shelter

The gameplay scene now uses 4 ms for rest and 8 ms for sleep. It carries time forward while recovery is active, finishes each tick in order, and drops queued accelerated time when recovery ends. The budgeted run stops on the exact wake or interruption tick. The next frame uses the current gameplay speed.

The follow-up used the same 1,000 NPCs, seed 4815, Compatibility renderer, and 60 FPS cap. It placed 12 active survivors in a barricaded interior office. The rest capture showed a median of 11 visible NPCs. All four runs recovered 12 AP over 3,600 ticks and produced 36,422 planner calls, 21,078 actions, and 1,794 route requests. Both gameplay budgets ended with an empty time queue.

| Mode | Simulation budget | Time to 50 AP | p99 frame | Worst frame |
| --- | ---: | ---: | ---: | ---: |
| Rest | Unbounded control | 22.91 s | 152.50 ms | 173.01 ms |
| Rest | **4 ms gameplay** | **22.40 s** | **34.64 ms** | **41.26 ms** |
| Sleep | Unbounded control | 7.07 s | 1,151.22 ms | 1,151.22 ms |
| Sleep | **8 ms gameplay** | **11.37 s** | **18.87 ms** | **36.88 ms** |

- **Rest.** The 85 periodic refreshes took 18.82 ms at the median and 21.48 ms at p95 inside `refresh()` alone. They coincided with 85 of the 86 frames over 20 ms. Frames without a periodic refresh had a 16.94 ms p99.
- **Sleep.** The 42 periodic refreshes took 4.79 ms at the median and 4.93 ms at p95. The 36.88 ms maximum occurred on the wake frame, which rebuilt the visible shelter with 12 NPCs. The capture recorded zero queued time at wake.

```powershell
godot --headless --path godot --script res://tests/performance_tick_profile.gd
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=rest
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_gameplay.gd -- --mode=sleep
```

The scripts print the CSV paths under `user://benchmarks/`. The rendered capture uses the gameplay budgets by default and saves screenshots before timing begins. Use `--unbounded` for a control, `--quiet` for the original shelter, and `--frame-budget-ms` to compare another budget.

## Periodic dashboard refresh results

The periodic update changes the clock, speed, health, AP text and AP bar in place. It keeps the minimap terrain and location artwork, updates changed tile art and occupant captions, and reuses the actor layer when its visible content matches. Inventory and action changes replace their own controls. At this stage, recovery completion still built the dashboard for the new state.

The rerun used the same seed, busy office, 1,000 NPCs, 60 FPS cap, and gameplay budgets. Both modes reached 50 AP after 3,600 ticks, 36,422 planner calls, 21,078 actions, and 1,794 route requests with zero deferred time.

| Mode | Previous p99 | Current p99 | Previous worst frame | Current worst frame | Median periodic refresh |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rest, 4 ms | 34.64 ms | **16.91 ms** | 41.26 ms | **29.16 ms** | 18.82 → **0.99 ms** |
| Sleep, 8 ms | 18.87 ms | **17.38 ms** | 36.88 ms | **31.81 ms** | 4.79 → **0.03 ms** |

Rest recovered 12 AP in 22.39 seconds and sleep in 11.28 seconds. The only frame over 20 ms in each rerun was recovery completion. Use these captures as the before-and-after comparison for periodic work and measure the completion frame separately when working on transitions.

## Dashboard reuse at recovery completion

Rest updates the existing controls when recovery starts or ends. Sleep hides the perception, inventory, and action controls under the blackout, then restores them on wake. The dashboard reconciles current occupancy, map art, and action eligibility before the wake frame draws. The full layout builder handles structural changes such as becoming downed.

On the same 1,000-NPC busy shelter, the built-in Profiler measured the sleep completion update at **1.75 ms**, with **zero calls to `button()`**. The earlier completion refresh took **24.24 ms inclusive**, including **44 calls to `button()`**. The frame timings below come from separate runs without the Profiler.

| Mode | Previous p99 | Current p99 | Previous worst | Current worst | Previous completion | Current completion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Rest, 4 ms | 16.91 ms | **16.87 ms** | 29.16 ms | **19.07 ms** | 29.16 ms | **16.64 ms** |
| Sleep, 8 ms | 17.38 ms | **17.29 ms** | 31.81 ms | **18.31 ms** | 31.81 ms | **16.67 ms** |

Both runs recovered 12 AP on tick 8400 with zero deferred time. Each matched the earlier 3,600 clock steps, 36,422 planner calls, 21,078 NPC actions, and 1,794 route requests.

## NPC visibility and light scans

`_visible_human()` walks the existing occupant buckets directly in the original map and actor order. `nearby_light()` skips blocks without generators and candidates that cannot beat the nearest light, and reads generator power live. The deterministic one-day comparison matched the original return values on all 93,180 calls, including edge cells, indoor visibility, doors, generator ties, expired fuel, and damage.

| Profiled cost over one simulated day | Before | After |
| --- | ---: | ---: |
| `_visible_human()` total | 1,493.67 ms | 179.69 ms |
| `nearby_light()` total | 2,850.24 ms | 645.85 ms |
| Simulation tick p99 | 9.788 ms | 7.487 ms |
| Worst simulation tick | 13.710 ms | 10.941 ms |

The busy-shelter gameplay benchmark now enforces **p99 < 18 ms** and **worst frame < 20 ms** with the shipped budgets. The rendered rerun at 1,000 NPCs recorded **16.936 / 17.260 ms** for rest and **16.792 / 17.068 ms** for sleep. An earlier rest run failed on a **66.716 ms** frame that spent **59.721 ms** in the draw interval. The limits include draw and pacing time. [Benchmark commands](performance-benchmark.md#check-the-rendered-frame-limits)

## Multi-day memory verification

The rendered soak advanced **24 simulated days** in **253.6 seconds** with 1,000 NPCs, 48 rest cycles, 48 sleep cycles, and 2,880 drawn frames. Every simulation tick ran. The fixture used seed 4815 and the busy shelter with barricade strength 21 to sustain repeated recovery. Orphan nodes stayed at **0** through the run and scene teardown.

The eight-day trial still showed rising live memory, so the verification continued with a fresh 24-day trial. During days 18 through 24 the measurements plateaued within the following ranges.

| Monitor | Range during days 18–24 | First-to-last change |
| --- | ---: | ---: |
| Godot live static memory | 98.500–100.956 MiB | +38.2 KiB |
| Godot static high-water mark | 113.079 MiB | 0 |
| Windows process private memory | 540.035–540.102 MiB | +68 KiB |
| Scene-tree nodes | 199–208 | −6 |
| Resources | 57 | 0 |

After teardown Godot live static memory dropped to **41.300 MiB**, with two remaining scene-tree nodes and zero orphans. The final static sample before teardown was **100.925 MiB**, compared with **94.496 MiB** immediately after loading. A simulation-only diagnostic attributed part of the initial growth to NPC inventories and trust records. An isolated recovery diagnostic showed the log's text objects stopped accumulating when its 150-row limit was reached. These observations support bounded retention for this fixture.

Godot 4.7 provides static memory monitors. A separate Windows sampler recorded the engine process's private bytes every 500 ms using the PID printed by the soak. This process metric covers committed private memory across the engine, renderer, and other libraries. The existing dynamic-memory CSV field stays blank because the engine exposes no corresponding monitor. [Godot Performance monitors](https://docs.godotengine.org/en/4.7/classes/class_performance.html) · [Windows private memory definition](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.privatememorysize64)

The source captures remain in `.runtime/soak-long/`, including `process-memory.csv` and `benchmarks/soak-19352.csv` under its isolated Godot user-data directory. The soak command and frame gates are documented in the benchmark guide. [Reproduction commands](performance-benchmark.md#run-a-multi-day-soak)

The 93,180 query comparisons and all 234 simulation checks passed. The three Engineer supply-trip failures came from a fixture that repeatedly invoked the planner at a fixed clock time. The Engineer first equips its toolbox, then waits for the trip retry. Advancing the fixture through the real scheduler verifies departure, travel, search, return, and installation with normal AP recovery and action cooldowns. All 65 survival checks now pass.

## 1. Bound catch-up while preserving tick order

The headless harness can apply a soft main-thread time budget to the existing scheduler with `--frame-budget-ms=4`. It reports overdue ticks, frame-time percentiles, and achieved warp. Use the unbounded harness for throughput and worst-case bursts. The rendered captures above exercise the gameplay rest and sleep budgets. Profile death recovery separately if applying a budget to its 32× rate.

The harness calls [`advance_budgeted()`](../scripts/simulation.gd) with an **absolute** target tick based on elapsed time, bounded by the end of the trial. It continues toward that target the next frame.

```gdscript
func advance_budgeted(target_step: int, budget_usec: int, max_steps: int) -> int:
	var started: int = Time.get_ticks_usec()
	var first_step: int = clock_step
	var last_step: int = mini(target_step, first_step + max_steps)
	while clock_step < last_step:
		_clock_step()
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	_record_advance(started, first_step)
	return maxi(0, target_step - clock_step)
```

A single tick can exceed the budget. Record its due count and execution time to tell a crowded tick from a large batch of otherwise cheap ticks. If single ticks still dominate, profile planner calls before splitting a tick across frames. Any resumable tick needs to retain the due list and rotating cursor, complete each tick before incrementing the clock, and preserve the action and recovery order.

Keep the existing AP cadence for this pass. If staggered recovery becomes a gameplay choice, a stable per-actor phase can spread grants across the full 300-tick interval. Apply the phase consistently to AP initialization, affordability scheduling, and save/load.

```gdscript
func next_staggered_ap_step(actor_id: int, now_step: int) -> int:
	var interval: int = NpcGate.AP_INTERVAL_STEPS
	var phase: int = actor_id % interval
	return now_step + 1 + posmod(phase - now_step - 1, interval)
```

## 2. Measure planner allocations using the existing actor data

The simulation already keeps off-screen actor state in dictionaries owned by a `RefCounted` simulation. Start with planner functions that create temporary occupant lists, filter them, or scan nearby blocks repeatedly. Use the Godot profiler on an opening-window capture. Inspect `_human()`, `_zombie()`, `_join_group()`, `_shelter_target()`, and `choose_site()` for inclusive and self time. Sample a rendered gameplay capture before evaluating `MultiMeshInstance2D` for visible sprite batches. [Planner source](../scripts/npc_utility/planner.gd) · [Godot profiler](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/the_profiler.html)

For read-only counts such as the radio response's garrison size, iterate the existing block's actor IDs. This avoids allocating both an occupant list and a filtered list. Preserve snapshots for callers that execute actions and can mutate the underlying bucket during iteration.

```gdscript
const EMPTY_ACTOR_IDS: Array = []

func standing_indoor_survivors(block_id: int) -> int:
	var ids: Array = spatial.get(block_id, EMPTY_ACTOR_IDS)
	var count: int = 0
	for id: int in ids:
		var actor: Dictionary = actors[id]
		if actor.inside and actor.human and not actor.down:
			count += 1
	return count
```

Call `s.standing_indoor_survivors(site.id)` where the planner builds the garrison count. If profiling later shows that even the direct scans are costly, prototype packed per-block counts by actor category. Update counts on movement, entry and exit, faction changes, and downed-state changes, and rebuild them from actors on load.

## 3. Time route queries, then test a bounded cache

Block indexing already uses `y * width + x`. The directed `AStar2D` graph encodes one-way fort exits and gatehouse entrances. `AStarGrid2D` supports cell solidity and grid-wide diagonal rules, so a migration would need a way to preserve those directed edges. Keep the existing graph for the first comparison. Record query time by call site, especially supply ranking, normal movement, and avoidance reroutes. [Current navigation rules](../scripts/npc_ai.gd) · [AStar2D](https://docs.godotengine.org/en/4.7/classes/class_astar2d.html) · [AStarGrid2D](https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html)

Supply ranking and return reserves currently request complete paths to read their size. A bounded cache of **point counts** preserves those formulas and avoids allocating path arrays on hits. The ordered key distinguishes outward and return trips. Clear the cache after rebuilding navigation and after any persistent topology or weight change. Call the cache only against the base graph. Temporary threat-avoidance queries keep their existing uncached path. [Supply planner](../scripts/npc_utility/supplies.gd)

```gdscript
const ROUTE_CACHE_SLOTS: int = 4_096
var _route_keys: PackedInt32Array = PackedInt32Array()
var _route_point_counts: PackedInt32Array = PackedInt32Array()

func reset_route_point_cache() -> void:
	_route_keys.resize(ROUTE_CACHE_SLOTS)
	_route_keys.fill(-1)
	_route_point_counts.resize(ROUTE_CACHE_SLOTS)

func base_route_point_count(from_id: int, to_id: int) -> int:
	var key: int = from_id * blocks.size() + to_id
	var slot: int = hash(key) & (ROUTE_CACHE_SLOTS - 1)
	if _route_keys[slot] != key:
		var path: PackedInt64Array = query_route(from_id, to_id)
		_route_point_counts[slot] = path.size()
		_route_keys[slot] = key
	return _route_point_counts[slot]
```

With valid block IDs, the two 4,096-entry buffers use 32 KiB of payload. Use zero for the existing empty-path check and pass each count through the existing AP and score calculations. Compare hit rate, path CPU time, and deterministic action outcomes before adopting it.

## Acceptance checks

1. Capture 1× gameplay at the same seed, NPC count, and FPS cap as the corrected headless baseline. Include the opening and accelerated rest or sleep. Report worst-frame simulation time, frame-time percentiles, and peak overdue ticks.
2. Compare budgeted and unbounded advances at the same final tick. Check NPC actions and final state, including route legality, cooldowns, AP, and save/load. Report effective warp alongside the frame-time numbers.
3. Evaluate each planner or cache change separately. Keep the synchronized AP/path burst as a regression run and compare its one-frame workload using the same scenario settings.
