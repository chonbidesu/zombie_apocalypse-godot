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
```

With the gameplay budgets, each run exits with code `1` if the nearest-rank p99 reaches 18 ms or any wall frame reaches 20 ms. The CSV includes every measured frame and is written before the limits are checked. The explicit `--unbounded` and `--frame-budget-ms` comparison runs report frame times without applying the limits. Run the two modes sequentially on the same rendered setup when comparing results.

## Run a multi-day soak

```powershell
godot --path godot --disable-vsync --max-fps 60 --resolution 1536x864 --script res://tests/performance_soak.gd -- --days=24
```

Use a debug build. The soak advances every simulation tick in 12-minute batches with 1,000 NPCs. It alternates rest and sleep in a reinforced shelter and updates the gameplay scene after each batch. It checks for orphan nodes after deferred cleanup on every frame and writes hourly memory, node, object, and resource counts under `user://benchmarks/`, including a sample after scene teardown. The soak measures retention over simulated time. The rendered frame-limit checks above exercise the normal frame budgets.

## Read the CSV

- **Frame cost.** Rows normally summarize about one second. `mean_wall_frame_ms` and `peak_wall_frame_ms` measure elapsed time between frame callbacks, including waits. Godot updates `fps`, `engine_process_ms`, and `engine_physics_ms` on its own roughly one-second interval. Those engine readings can carry over between CSV rows, including the first row after setup. A `burst` row isolates one frame's wall time and simulation counters. Headless frame timings characterize the simulation and engine loop. Capture gameplay for timings with rendering and UI work. [Godot 4.7.2 engine timing](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp#L4741-L4762)
- **Script and decision cost.** `script_ms` and `peak_script_ms` time the gameplay scene's frame callback or the harness's simulation advance. The gameplay callback includes nested simulation time. `simulation_ms` and `peak_simulation_ms` isolate the measured simulation entry points and their nested work. `decision_mean_us` divides timed planner work by planner calls, and `npc_actions` counts successful NPC actions. The Godot editor profiler provides timings for other script functions. [Godot profiler documentation](https://docs.godotengine.org/en/latest/tutorials/scripting/debug/the_profiler.html)
- **Path and AP load.** `path_queries` counts actual synchronous AStar requests, including reroutes and supply lookups. `peak_path_queries` is the largest frame count in the window. `ap_updates` counts actors visited by the recovery loop, including the player, while `ap_grants` counts actual increments. In a burst row, `forced_path_ms` measures the synthetic route batch and `ap_ms` measures the recovery loop.
- **Memory and node counts.** `static_memory_bytes`, `static_peak_bytes`, `nodes`, and `orphan_nodes` come from Godot's Performance singleton. The dynamic-memory field is blank because Godot 4.7 exposes no separate dynamic-memory monitor. Use a debug build for memory and orphan counts. [Godot Performance monitors](https://docs.godotengine.org/en/latest/classes/class_performance.html)
- **Setup cost.** `setup_ms` includes city generation, navigation graph construction, NPC creation, and harness setup. The frame capture starts after setup. `sim_minute` uses the simulation's absolute clock, which starts at minute 480.
- **Fast-forward budget.** `frame_budget_ms` and `max_steps_per_frame` identify the stress harness limits. `peak_steps_per_frame` is the largest tick batch in the row. `backlog_steps` gives the ticks still due after the last frame in the row, and `peak_backlog_steps` gives the largest such backlog in the row. `achieved_warp` divides simulated minutes completed since capture started by wall seconds elapsed. The [rendered gameplay capture](performance-optimization.md#integrated-budgets-in-a-busy-shelter) records recovery-mode budgets and deferred time.
- **Frame percentiles.** `wall_frame_p95_ms` and `wall_frame_p99_ms` are cumulative since capture started. Values are upper bounds rounded into 0.25 ms histogram bins. Values beyond the histogram range appear as `>4096`. Use the last row for whole-run percentiles.
- **Periodic UI refresh.** In gameplay, `periodic_refreshes` counts scheduled dashboard refreshes in the window. `periodic_refresh_ms` totals their synchronous time and `peak_periodic_refresh_ms` records the largest frame total. Measure the wall interval to include deferred layout and node cleanup.
