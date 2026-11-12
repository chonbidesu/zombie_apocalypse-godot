extends SceneTree
## Run with --headless --script res://tests/performance_stress.gd -- --help

const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Fixture = preload("res://tests/performance_fixture.gd")
const Monitor = preload("res://scripts/PerformanceMonitor.gd")
const DAY_MINUTES: int = 1440
const DECISIONS_PER_DAY: int = 50
@warning_ignore("integer_division")
const PACED_INTERVAL: int = DAY_MINUTES * Catalog.CLOCK_STEPS_PER_MINUTE / DECISIONS_PER_DAY
const AP_INTERVAL: int = Catalog.RECOVERY_MINUTES * Catalog.CLOCK_STEPS_PER_MINUTE


class Trial extends Sim:
	var paced: bool = false
	var first_step: int = 0
	var burst_step: int = -1

	func _schedule_npc(actor: Dictionary, step: int) -> void:
		if not paced:
			super._schedule_npc(actor, step)

	func _clock_step() -> void:
		super._clock_step()
		if paced:
			# Each ID owns a slot in a repeating 28.8-minute interval.
			var first_id: int = (clock_step - first_step - 1) % PACED_INTERVAL + 1
			for id in range(first_id, actors.size(), PACED_INTERVAL):
				_npc_turn(actors[id])
		if clock_step == burst_step:
			_run_path_burst()

	func _run_path_burst() -> void:
		var started: int = Time.get_ticks_usec()
		for id in range(1, actors.size()):
			var actor: Dictionary = actors[id]
			var from_id: int = int(actor.y) * width + int(actor.x)
			var to_id: int = blocks.size() - 1 - from_id
			query_route(from_id, to_id)
		performance_counters.forced_path_queries += actors.size() - 1
		performance_counters.forced_path_usec += Time.get_ticks_usec() - started


class Runner extends Node:
	var waves: PackedInt32Array = PackedInt32Array([250, 500, 1000])
	var warp: float = 60.0
	var seed_value: int = 4815
	var minutes: int = DAY_MINUTES
	var scenario: String = "baseline"
	var frame_budget_usec: int = 0
	var max_steps_per_frame: int = 16
	var _wave_index: int = 0
	var _sim: Sim
	var _monitor: Monitor
	var _started_usec: int
	var _target_steps: int
	var _advanced_steps: int

	func configure(args: PackedStringArray) -> bool:
		for arg in args:
			var key: String = arg.get_slice("=", 0)
			var value: String = arg.trim_prefix(key + "=") if "=" in arg else ""
			match key:
				"--waves":
					waves.clear()
					for wave in value.split(","):
						if not wave.is_valid_int() or int(wave) < 1 or int(wave) > 6000:
							return false
						waves.append(int(wave))
				"--warp":
					if not value.is_valid_float() or not is_finite(float(value)) or float(value) <= 0.0:
						return false
					warp = float(value)
				"--seed":
					if not value.is_valid_int():
						return false
					seed_value = int(value)
				"--minutes":
					if not value.is_valid_int() or int(value) < 1 or int(value) > DAY_MINUTES:
						return false
					minutes = int(value)
				"--scenario":
					if value not in ["baseline", "paced", "burst"]:
						return false
					scenario = value
				"--frame-budget-ms":
					if not value.is_valid_float():
						return false
					var budget_ms: float = float(value)
					if not is_finite(budget_ms) or budget_ms < 0.001 or budget_ms > 1000.0:
						return false
					frame_budget_usec = roundi(budget_ms * 1000.0)
				"--max-steps-per-frame":
					if not value.is_valid_int() or int(value) < 1 or int(value) > DAY_MINUTES * Catalog.CLOCK_STEPS_PER_MINUTE:
						return false
					max_steps_per_frame = int(value)
				_:
					return false
		return true

	func _ready() -> void:
		_target_steps = minutes * Catalog.CLOCK_STEPS_PER_MINUTE
		_monitor = Monitor.new()
		add_child(_monitor)
		_start_wave()

	func _start_wave() -> void:
		var count: int = waves[_wave_index]
		var setup_started: int = Time.get_ticks_usec()
		var trial: Trial
		if scenario == "baseline":
			_sim = Sim.new()
		else:
			trial = Trial.new()
			trial.paced = scenario == "paced"
			_sim = trial
		var error: String = Fixture.start_city(_sim, seed_value, count)
		if not error.is_empty():
			_fail(error)
			return
		if trial != null:
			trial.first_step = _sim.clock_step
			if scenario == "burst":
				trial.burst_step = _sim.clock_step + AP_INTERVAL - _sim.clock_step % AP_INTERVAL
		_sim.player().down = true
		Fixture.awaken_npcs(_sim, scenario == "baseline")
		if scenario == "burst":
			for id in range(1, _sim.actors.size()):
				var actor: Dictionary = _sim.actors[id]
				actor.ap = Catalog.AP_CAP - 1
				actor.next_think = float(trial.burst_step) / Catalog.CLOCK_STEPS_PER_MINUTE
		_sim._reset_npc_runtime()
		var setup_ms: float = (Time.get_ticks_usec() - setup_started) / 1000.0
		_monitor.frame_budget_usec = frame_budget_usec
		_monitor.max_steps_per_frame = max_steps_per_frame if frame_budget_usec > 0 else 0
		if not _monitor.start(_sim, scenario, warp, setup_ms):
			_fail("Could not start CSV capture.")
			return
		_advanced_steps = 0
		_started_usec = 0
		print("Starting %s, %d NPCs, %d minutes at %sx (setup %.1f ms)." % [
			scenario, count, minutes, str(warp), setup_ms,
		])

	func _process(_delta: float) -> void:
		var now: int = Time.get_ticks_usec()
		if _started_usec == 0:
			_started_usec = now
		if _advanced_steps == _target_steps:
			# The monitor runs first and has now sampled the last workload frame.
			_finish_wave(now)
			return
		var requested_steps: float = (now - _started_usec) * (warp / 1_000_000.0) * Catalog.CLOCK_STEPS_PER_MINUTE
		var due: int = int(minf(requested_steps, _target_steps))
		var pending: int = due - _advanced_steps
		if pending <= 0:
			return
		if frame_budget_usec == 0:
			_sim.advance_steps(pending)
			_advanced_steps = due
			return
		var backlog: int = _sim.advance_budgeted(_sim.clock_step + pending, frame_budget_usec, max_steps_per_frame)
		_sim.performance_counters.backlog_steps = backlog
		_advanced_steps = due - backlog

	func _finish_wave(now: int) -> void:
		_monitor.stop()
		var count: int = waves[_wave_index]
		if _monitor.total_steps != _target_steps:
			_fail("CSV did not capture every simulated clock step.")
			return
		if scenario == "burst" and _monitor.total_forced_queries != count:
			_fail("CSV did not capture all synchronized route queries.")
			return
		if scenario == "paced" and minutes == DAY_MINUTES and _monitor.total_decisions != DECISIONS_PER_DAY * count:
			_fail("The paced run did not call the planner 50 times per NPC.")
			return
		var wall_seconds: float = (now - _started_usec) / 1_000_000.0
		print("Completed %s, %d NPCs in %.3f s (%.2fx achieved), %d clock steps, %d planner calls, %d actions." % [
			scenario, count, wall_seconds, minutes / wall_seconds,
			_monitor.total_steps, _monitor.total_decisions, int(_sim.metrics.npc_actions),
		])
		_sim = null
		_wave_index += 1
		if _wave_index == waves.size():
			set_process(false)
			get_tree().quit()
		else:
			_start_wave()

	func _fail(message: String) -> void:
		set_process(false)
		push_error(message)
		get_tree().quit(1)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--help" in args:
		_print_usage()
		quit()
		return
	var runner: Runner = Runner.new()
	if not runner.configure(args):
		runner.free()
		_print_usage()
		quit(2)
		return
	if DisplayServer.get_name() == "headless" and Engine.max_fps == 0:
		Engine.max_fps = 60
	root.add_child.call_deferred(runner)


func _print_usage() -> void:
	print("User arguments after --")
	print("  --waves=250,500,1000  NPC counts, 1 to 6000 each")
	print("  --warp=60             Positive multiplier, e.g. 1, 10 or 60")
	print("  --seed=4815           City and simulation seed")
	print("  --minutes=1440        Game minutes per wave, 1 to 1440")
	print("  --scenario=baseline   baseline, paced or burst")
	print("  --frame-budget-ms=4   Optional soft simulation budget, 0.001 to 1000 ms")
	print("  --max-steps-per-frame=16   Step cap when a frame budget is enabled")
