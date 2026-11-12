extends SceneTree
## Profile complete ticks in the seeded 1,000-NPC baseline, without a render loop.

const Sim = preload("res://scripts/simulation.gd")
const Counters = preload("res://scripts/performance_counters.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Fixture = preload("res://tests/performance_fixture.gd")
const Planner = preload("res://scripts/npc_utility/planner.gd")
const Scheduler = preload("res://scripts/npc_utility/scheduler.gd")
const STEPS: int = 1440 * Catalog.CLOCK_STEPS_PER_MINUTE
const NPCS: int = 1000
const SEED: int = 4815

enum Column {
	STEP, TICK, DUE, DECISIONS, PLANNER, HUMAN, ZOMBIE, GROUP, SUPPLY,
	AP_GRANTS, AP, PATHS, ASTAR, OCCUPANTS, VISIBLE_HUMAN, NEARBY_LIGHT, SCENT, EXECUTE, COUNT
}


class ProfiledScheduler extends Scheduler:
	var due_count: int

	func take(step: int) -> Array:
		var bucket: Array = super.take(step)
		due_count = bucket.size()
		return bucket


class ProfiledPlanner extends Planner:
	var human_usec: int
	var zombie_usec: int
	var group_usec: int
	var supply_usec: int

	func _human(s, a: Dictionary, here: Dictionary, present: Array, skill: String) -> int:
		var started: int = Time.get_ticks_usec()
		var result: int = super._human(s, a, here, present, skill)
		human_usec += Time.get_ticks_usec() - started
		return result

	func _zombie(s, a: Dictionary, here: Dictionary, present: Array, skill: String) -> int:
		var started: int = Time.get_ticks_usec()
		var result: int = super._zombie(s, a, here, present, skill)
		zombie_usec += Time.get_ticks_usec() - started
		return result

	func _join_group(s, a: Dictionary, here: Dictionary) -> bool:
		var started: int = Time.get_ticks_usec()
		var result: bool = super._join_group(s, a, here)
		group_usec += Time.get_ticks_usec() - started
		return result

	func _supply_turn(s, a: Dictionary, here: Dictionary, danger: float, competing: float) -> bool:
		var started: int = Time.get_ticks_usec()
		var result: bool = super._supply_turn(s, a, here, danger, competing)
		supply_usec += Time.get_ticks_usec() - started
		return result


class ProfiledSim extends Sim:
	var samples: PackedInt64Array = PackedInt64Array()
	var planner: ProfiledPlanner = ProfiledPlanner.new()
	var scheduler: ProfiledScheduler = ProfiledScheduler.new()
	var _row: int
	var _astar_usec: int
	var _occupants_usec: int
	var _visible_usec: int
	var _light_usec: int
	var _scent_usec: int
	var _execute_usec: int

	func _init() -> void:
		samples.resize(STEPS * Column.COUNT)
		performance_counters = Counters.new()
		npc_planner = planner
		npc_schedule = scheduler

	func _clock_step() -> void:
		performance_counters.reset()
		planner.human_usec = 0
		planner.zombie_usec = 0
		planner.group_usec = 0
		planner.supply_usec = 0
		_astar_usec = 0
		_occupants_usec = 0
		_visible_usec = 0
		_light_usec = 0
		_scent_usec = 0
		_execute_usec = 0
		var started: int = Time.get_ticks_usec()
		super._clock_step()
		samples[_row + Column.TICK] = Time.get_ticks_usec() - started
		samples[_row + Column.STEP] = clock_step
		samples[_row + Column.DUE] = scheduler.due_count
		samples[_row + Column.DECISIONS] = performance_counters.decisions
		samples[_row + Column.PLANNER] = performance_counters.decision_usec
		samples[_row + Column.HUMAN] = planner.human_usec
		samples[_row + Column.ZOMBIE] = planner.zombie_usec
		samples[_row + Column.GROUP] = planner.group_usec
		samples[_row + Column.SUPPLY] = planner.supply_usec
		samples[_row + Column.AP_GRANTS] = performance_counters.ap_grants
		samples[_row + Column.AP] = performance_counters.ap_usec
		samples[_row + Column.PATHS] = performance_counters.path_queries
		samples[_row + Column.ASTAR] = _astar_usec
		samples[_row + Column.OCCUPANTS] = _occupants_usec
		samples[_row + Column.VISIBLE_HUMAN] = _visible_usec
		samples[_row + Column.NEARBY_LIGHT] = _light_usec
		samples[_row + Column.SCENT] = _scent_usec
		samples[_row + Column.EXECUTE] = _execute_usec
		_row += Column.COUNT

	func query_route(from_id: int, to_id: int) -> PackedInt64Array:
		var started: int = Time.get_ticks_usec()
		var path: PackedInt64Array = super.query_route(from_id, to_id)
		_astar_usec += Time.get_ticks_usec() - started
		return path

	func occupants(b: Dictionary, inside = null) -> Array:
		var started: int = Time.get_ticks_usec()
		var result: Array = super.occupants(b, inside)
		_occupants_usec += Time.get_ticks_usec() - started
		return result

	func _visible_human(a: Dictionary) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super._visible_human(a)
		_visible_usec += Time.get_ticks_usec() - started
		return result

	func nearby_light(a: Dictionary) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.nearby_light(a)
		_light_usec += Time.get_ticks_usec() - started
		return result

	func scent_death_snapshot(a: Dictionary) -> Array[Dictionary]:
		var started: int = Time.get_ticks_usec()
		var result: Array[Dictionary] = super.scent_death_snapshot(a)
		_scent_usec += Time.get_ticks_usec() - started
		return result

	func execute(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> void:
		var started: int = Time.get_ticks_usec()
		super.execute(a, command, target_id, data)
		_execute_usec += Time.get_ticks_usec() - started


func _initialize() -> void:
	var sim: ProfiledSim = ProfiledSim.new()
	var error: String = Fixture.start_city(sim, SEED, NPCS)
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	sim.player().down = true
	Fixture.awaken_npcs(sim, true)
	sim._reset_npc_runtime()
	sim.advance_steps(STEPS)
	if not _write_profile(sim.samples):
		quit(1)
		return
	print("Profiled %d complete ticks, %d NPC actions." % [STEPS, int(sim.metrics.npc_actions)])
	quit()


func _write_profile(samples: PackedInt64Array) -> bool:
	var directory: String = ProjectSettings.globalize_path("user://benchmarks")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("Cannot create %s (%s)." % [directory, error_string(error)])
		return false
	var path: String = "%s/tick-profile-%d.csv" % [directory, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_line("clock_step,tick_us,due_entries,decisions,planner_us,human_us,zombie_us,join_group_us,supply_us,"
		+ "ap_grants,ap_us,path_queries,astar_us,occupants_us,visible_human_us,nearby_light_us,scent_us,execute_us")
	var values: PackedStringArray = PackedStringArray()
	values.resize(Column.COUNT)
	for offset in range(0, samples.size(), Column.COUNT):
		for column in range(Column.COUNT):
			values[column] = str(samples[offset + column])
		file.store_csv_line(values)
	file.close()
	print("Tick profile: ", path)
	return true
