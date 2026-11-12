extends SceneTree
## Advance a loaded gameplay scene over several simulated days and sample after
## each frame's deferred frees. Run with rendering enabled to include the UI.

const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Fixture = preload("res://tests/performance_fixture.gd")
const Game = preload("res://scripts/interface.gd")
const GameScene = preload("res://main.tscn")
const MINUTES_PER_DAY: int = 1440
const BATCH_MINUTES: int = 12
const SAMPLE_MINUTES: int = 60
const RECOVER_AP: int = 12
const RECOVERY_MINUTES: int = RECOVER_AP * Catalog.RECOVERY_MINUTES

var _days: int = 8
var _start_usec: int
var _peak_orphans: int
var _rest_starts: int
var _sleep_starts: int
var _recovery_ends: int


func _initialize() -> void:
	if not OS.is_debug_build():
		push_error("Run the soak in a debug build for static memory and orphan monitors.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		var value: String = arg.trim_prefix("--days=")
		if not arg.begins_with("--days=") or not value.is_valid_int() or int(value) < 1:
			push_error("Expected an optional positive --days=8.")
			quit(2)
			return
		_days = int(value)
	_run.call_deferred()


func _run() -> void:
	print("SOAK_PID=", OS.get_process_id())
	var sim: Sim = Sim.new()
	var error: String = Fixture.start_city(sim, 4815, 1000)
	if not error.is_empty():
		_fail(error)
		return
	Fixture.awaken_npcs(sim, true)
	sim._reset_npc_runtime()
	var site: Dictionary = Fixture.prepare_shelter(sim)
	if site.is_empty():
		_fail("No shelter found for the soak.")
		return
	sim.set_barricade_strength(site, 21)
	var game: Game = GameScene.instantiate() as Game
	game.sim = sim
	root.add_child(game)
	game.set_process(false)
	for _frame in range(5):
		await process_frame

	var directory: String = ProjectSettings.globalize_path("user://benchmarks")
	var error_code: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error_code != OK:
		_fail("Could not create %s (%s)." % [directory, error_string(error_code)])
		return
	var path: String = "%s/soak-%d.csv" % [directory, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not open %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_line("phase,epoch_ms,elapsed_s,game_minutes,static_bytes,static_peak_bytes,orphan_nodes,"
		+ "nodes,objects,resources,rest_starts,sleep_starts,recovery_ends")
	_start_usec = Time.get_ticks_usec()
	var drawn_at_start: int = Engine.get_frames_drawn()
	_observe_orphans()
	_sample(file, "loaded", 0)
	var minutes: int = _days * MINUTES_PER_DAY
	for elapsed in range(BATCH_MINUTES, minutes + 1, BATCH_MINUTES):
		if (elapsed - BATCH_MINUTES) % RECOVERY_MINUTES == 0 and not sim.resting:
			_begin_recovery(game, (elapsed - BATCH_MINUTES) % (2 * RECOVERY_MINUTES) != 0)
		var recovering: bool = sim.resting
		sim.advance(BATCH_MINUTES)
		sim.discover()
		if recovering and not sim.resting:
			_recovery_ends += 1
			game.notice = sim.last_rest_notice
		game.feed.ingest(sim.messages)
		game.feed.update(1.0 / 60.0)
		game._refresh_dashboard()
		game._update_action_controls()
		game._update_log()
		game._animate_scene(1.0 / 60.0)
		await process_frame
		_observe_orphans()
		if elapsed % SAMPLE_MINUTES == 0:
			_sample(file, "running", elapsed)
		if elapsed % MINUTES_PER_DAY == 0:
			print("SOAK_DAY %d/%d, static %d bytes, peak orphan nodes %d." % [
				elapsed / MINUTES_PER_DAY, _days, int(Performance.get_monitor(Performance.MEMORY_STATIC)), _peak_orphans,
			])

	var drawn: int = Engine.get_frames_drawn() - drawn_at_start
	game.queue_free()
	sim = null
	await process_frame
	_observe_orphans()
	_sample(file, "teardown", minutes)
	file.close()
	print("Soak CSV: ", path)
	print("SOAK_RESULT days=%d peak_orphans=%d rendered_frames=%d rest_starts=%d sleep_starts=%d recovery_ends=%d" % [
		_days, _peak_orphans, drawn, _rest_starts, _sleep_starts, _recovery_ends,
	])
	if _peak_orphans != 0:
		_fail("Orphan nodes remained after frame cleanup.")
		return
	if DisplayServer.get_name() != "headless" and drawn <= 0:
		_fail("The gameplay soak did not draw any frames.")
		return
	quit()


func _begin_recovery(game: Game, sleep: bool) -> void:
	var sim: Sim = game.sim
	var player: Dictionary = sim.player()
	player.ap = mini(player.ap, Catalog.AP_CAP - RECOVER_AP)
	if sleep:
		game.begin_sleep()
		_sleep_starts += int(sim.sleeping)
	else:
		game.begin_rest(RECOVER_AP)
		_rest_starts += int(sim.resting)


func _observe_orphans() -> void:
	_peak_orphans = maxi(_peak_orphans, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))


func _sample(file: FileAccess, phase: String, game_minutes: int) -> void:
	file.store_csv_line(PackedStringArray([
		phase, str(roundi(Time.get_unix_time_from_system() * 1000.0)),
		"%.3f" % ((Time.get_ticks_usec() - _start_usec) / 1_000_000.0), str(game_minutes),
		str(int(Performance.get_monitor(Performance.MEMORY_STATIC))),
		str(int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))),
		str(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))),
		str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))),
		str(int(Performance.get_monitor(Performance.OBJECT_COUNT))),
		str(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))),
		str(_rest_starts), str(_sleep_starts), str(_recovery_ends),
	]))
	file.flush()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
