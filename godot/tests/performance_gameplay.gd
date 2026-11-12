extends SceneTree
## Capture the real gameplay scene through AP recovery with rendering enabled.

const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Counters = preload("res://scripts/performance_counters.gd")
const Fixture = preload("res://tests/performance_fixture.gd")
const Game = preload("res://scripts/interface.gd")
const GameScene = preload("res://main.tscn")
const SEED: int = 4815
const NPCS: int = 1000
const RECOVER_AP: int = 12
const MAX_FRAMES: int = 12_000
const TIMEOUT_USEC: int = 120_000_000
const P99_LIMIT_USEC: int = 18_000
const WORST_FRAME_LIMIT_USEC: int = 20_000

enum Column {
	STEP, AP, WALL, ACTIVE, SIM, GAMEPLAY, DRAW, STEPS, DECISIONS, PATHS, DEFERRED, DRAW_CALLS,
	REFRESHES, REFRESH, VISIBLE_NPCS, COUNT
}


class BudgetOverrideGame extends Game:
	var budget_override_usec: int

	func _recovery_budget_usec() -> int:
		return budget_override_usec


var _mode: String = "rest"
var _quiet: bool
var _budget_override_usec: int = -1
var _budget_usec: int
var _sim: Sim
var _game: Game
var _counters: Counters = Counters.new()
var _samples: PackedInt64Array = PackedInt64Array()
var _row: int
var _started_usec: int
var _frame_started_usec: int
var _draw_started_usec: int
var _first_step: int
var _end_step: int
var _output_stem: String
var _ending: bool


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run the gameplay capture with a real display driver.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg in ["--mode=rest", "--mode=sleep"]:
			_mode = arg.trim_prefix("--mode=")
		elif arg == "--quiet":
			_quiet = true
		elif arg == "--unbounded":
			_budget_override_usec = 0
		elif arg.begins_with("--frame-budget-ms="):
			var value: String = arg.trim_prefix("--frame-budget-ms=")
			if not value.is_valid_float() or not is_finite(float(value)) or float(value) < 0.001 or float(value) > 1000.0:
				_usage_error()
				return
			_budget_override_usec = roundi(float(value) * 1000.0)
		else:
			_usage_error()
			return
	_start.call_deferred()


func _usage_error() -> void:
	push_error("Expected --mode=rest or --mode=sleep, optional --quiet and either --unbounded or --frame-budget-ms=8.")
	quit(2)


func _start() -> void:
	_sim = Sim.new()
	var error: String = Fixture.start_city(_sim, SEED, NPCS)
	if not error.is_empty():
		_fail(error)
		return
	Fixture.awaken_npcs(_sim, true)
	_sim._reset_npc_runtime()
	var site: Dictionary = Fixture.prepare_shelter(_sim, _quiet)
	if site.is_empty():
		_fail("No unoccupied shelter found.")
		return
	_sim.player().ap = Catalog.AP_CAP - RECOVER_AP
	_first_step = _sim.clock_step
	_end_step = _first_step + RECOVER_AP * Catalog.RECOVERY_MINUTES * Catalog.CLOCK_STEPS_PER_MINUTE
	var directory: String = ProjectSettings.globalize_path("user://benchmarks")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK:
		_fail("Cannot create %s (%s)." % [directory, error_string(dir_error)])
		return
	_game = GameScene.instantiate() as Game
	if _budget_override_usec >= 0:
		_game.set_script(BudgetOverrideGame)
		(_game as BudgetOverrideGame).budget_override_usec = _budget_override_usec
	_game.sim = _sim
	root.add_child(_game)
	_game.set_process(false)
	for _frame in range(30):
		await process_frame
	if _mode == "sleep":
		_game.begin_sleep()
	else:
		_game.begin_rest(RECOVER_AP)
	if not _sim.resting or _sim.sleeping != (_mode == "sleep"):
		_fail("Could not start %s: %s" % [_mode, _game.notice])
		return
	_budget_usec = _game._recovery_budget_usec()
	_output_stem = "%s/gameplay-%s-%s-%dus-%d" % [
		directory, "quiet" if _quiet else "busy", _mode, _budget_usec, OS.get_process_id(),
	]
	await process_frame
	if Engine.get_frames_drawn() < 2:
		_fail("The gameplay scene did not render during warmup.")
		return
	if _budget_override_usec < 0:
		var screenshot: Image = root.get_texture().get_image()
		if screenshot != null and screenshot.save_png(_output_stem + ".png") == OK:
			print("Gameplay screenshot: ", _output_stem + ".png")
	print("Capturing %s at %sx, %.3f ms budget, block %d with %d residents, %s, %s, viewport %s." % [
		_mode, str(_sim.time_speed()), _budget_usec / 1000.0, site.id, _sim.occupants(site, true).size() - 1, DisplayServer.get_name(),
		RenderingServer.get_video_adapter_name(), str(root.get_texture().get_size()),
	])
	_samples.resize(MAX_FRAMES * Column.COUNT)
	_sim.performance_counters = _counters
	RenderingServer.frame_pre_draw.connect(_begin_draw)
	RenderingServer.frame_post_draw.connect(_capture_draw)
	# Wait for the next process_frame so the first sample begins before gameplay.
	await process_frame
	process_frame.connect(_begin_frame)
	_game.set_process(true)
	_begin_frame()


func _begin_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _row > 0:
		_samples[_row - Column.COUNT + Column.WALL] = now - _frame_started_usec
	if _ending:
		process_frame.disconnect(_begin_frame)
		RenderingServer.frame_pre_draw.disconnect(_begin_draw)
		RenderingServer.frame_post_draw.disconnect(_capture_draw)
		_finish.call_deferred()
		return
	if _started_usec == 0:
		_started_usec = now
	_frame_started_usec = now
	_counters.reset()


func _begin_draw() -> void:
	_draw_started_usec = Time.get_ticks_usec()


func _capture_draw() -> void:
	if _frame_started_usec == 0 or _ending:
		return
	var now: int = Time.get_ticks_usec()
	_samples[_row + Column.STEP] = _sim.clock_step
	_samples[_row + Column.AP] = int(_sim.player().ap)
	_samples[_row + Column.ACTIVE] = now - _frame_started_usec
	_samples[_row + Column.SIM] = _counters.simulation_usec
	_samples[_row + Column.GAMEPLAY] = _counters.gameplay_usec
	_samples[_row + Column.DRAW] = now - _draw_started_usec
	_samples[_row + Column.STEPS] = _counters.clock_steps
	_samples[_row + Column.DECISIONS] = _counters.decisions
	_samples[_row + Column.PATHS] = _counters.path_queries
	_samples[_row + Column.DEFERRED] = roundi(_game.simulation_backlog * 1_000_000.0)
	_samples[_row + Column.DRAW_CALLS] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_samples[_row + Column.REFRESHES] = _counters.periodic_refreshes
	_samples[_row + Column.REFRESH] = _counters.periodic_refresh_usec
	_samples[_row + Column.VISIBLE_NPCS] = 0 if _sim.sleeping else _game.actor_buttons.size()
	_row += Column.COUNT
	if not _sim.resting or _row == _samples.size() or now - _started_usec > TIMEOUT_USEC:
		_game.set_process(false)
		_ending = true


func _finish() -> void:
	var file: FileAccess = FileAccess.open(_output_stem + ".csv", FileAccess.WRITE)
	if file == null:
		_fail("Could not write gameplay capture (%s)." % error_string(FileAccess.get_open_error()))
		return
	file.store_line("clock_step,player_ap,wall_us,active_us,simulation_us,gameplay_us,draw_us,"
		+ "clock_steps,decisions,path_queries,deferred_wall_us,draw_calls,periodic_refreshes,periodic_refresh_us,visible_npcs")
	var values: PackedStringArray = PackedStringArray()
	values.resize(Column.COUNT)
	var frame_times: PackedInt64Array = PackedInt64Array()
	@warning_ignore("integer_division")
	frame_times.resize(_row / Column.COUNT)
	var frame_index: int = 0
	var rendered_frames: int = 0
	var wall_usec: int = 0
	for offset in range(0, _row, Column.COUNT):
		for column in range(Column.COUNT):
			values[column] = str(_samples[offset + column])
		file.store_csv_line(values)
		var frame_usec: int = _samples[offset + Column.WALL]
		frame_times[frame_index] = frame_usec
		frame_index += 1
		wall_usec += frame_usec
		rendered_frames += int(_samples[offset + Column.DRAW_CALLS] > 0)
	file.close()
	print("Gameplay CSV: ", _output_stem + ".csv")
	if rendered_frames == 0 or _sim.resting or _sim.clock_step < _end_step or int(_sim.player().ap) != Catalog.AP_CAP:
		_fail("The %s capture did not finish with full AP on rendered frames: %s" % [_mode, _sim.last_rest_notice])
		return
	if _budget_usec > 0 and (_sim.clock_step != _end_step or _game.simulation_backlog != 0.0):
		_fail("Budgeted recovery did not stop at the exact AP tick with an empty backlog.")
		return
	print("Completed %s in %.3f s, %d rendered frames, %d clock steps, %d NPC actions." % [
		_mode, wall_usec / 1_000_000.0, rendered_frames, _sim.clock_step - _first_step,
		int(_sim.metrics.npc_actions),
	])
	frame_times.sort()
	var p99: int = frame_times[ceili(frame_times.size() * 0.99) - 1]
	var worst: int = frame_times[frame_times.size() - 1]
	print("Frame p99 %.3f ms, worst %.3f ms." % [p99 / 1000.0, worst / 1000.0])
	var exit_code: int = 0
	if _budget_override_usec < 0:
		if p99 >= P99_LIMIT_USEC or worst >= WORST_FRAME_LIMIT_USEC:
			push_error("Frame regression: expected p99 < 18 ms and worst < 20 ms.")
			exit_code = 1
		else:
			print("Frame limits passed (p99 < 18 ms, worst < 20 ms).")
	_game.queue_free()
	await process_frame
	quit(exit_code)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
