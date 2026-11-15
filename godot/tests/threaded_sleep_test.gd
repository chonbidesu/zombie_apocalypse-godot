extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/interface.gd")
const GameScene = preload("res://main.tscn")
const Fixture = preload("res://tests/performance_fixture.gd")
const Counters = preload("res://scripts/performance_counters.gd")
const PerformanceMonitor = preload("res://scripts/PerformanceMonitor.gd")


class RecordingSim extends Sim:
	var actions := PackedStringArray()
	var interrupt_at: int = -1
	var worker_ticks: int

	func _clock_step() -> void:
		super._clock_step()
		if not Thread.is_main_thread(): worker_ticks += 1
		if clock_step == interrupt_at:
			player_damaged.emit(4, player().human)
			stop_rest("Sleep interrupted.")

	func execute(actor: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> void:
		if actor.id > 0:
			actions.append("%d/%d/%s/%d/%s" % [clock_step, actor.id, command, target_id, JSON.stringify(data)])
		super.execute(actor, command, target_id, data)


var _checks: int
var _failures: int


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var baseline := RecordingSim.new()
	baseline.planning_batch.thread_limit = 0
	baseline.managed_queries.enabled = false
	var threaded := RecordingSim.new()
	threaded.planning_batch.thread_limit = 4
	for sim in [baseline, threaded]:
		if not Fixture.start_city(sim, 4815, 1000).is_empty():
			push_error("Could not build the threaded sleep fixture.")
			quit(1)
			return
		Fixture.awaken_npcs(sim, true)
		sim._reset_npc_runtime()
		if Fixture.prepare_shelter(sim).is_empty():
			push_error("Could not place the threaded sleep fixture.")
			quit(1)
			return
		sim.player().ap = 38
		sim.performance_counters = Counters.new()

	baseline.begin_sleep()
	while baseline.sleeping: baseline.elapse_budgeted(0.25, 8_000)
	var game: Game = GameScene.instantiate() as Game
	game.get_node("GameMusic").free()
	game.sim = threaded
	game.threaded_sleep_enabled = true
	root.add_child(game)
	game.set_process(false)
	var local_map := game.local_map
	var wake_button := game.rest_button
	game.begin_sleep()
	game._advance_session(0.016)
	_check(game._sleep_sim.is_started() and not local_map.is_visible_in_tree(), "Sleep starts the worker and hides the map.")
	if not await _wait_for_wake(game): return
	_check(threaded.worker_ticks == 3600 and threaded.clock_step == baseline.clock_step and threaded.clock_fraction == 0.0,
		"The worker executes all 3,600 ticks and stops on the same AP boundary.")
	_check(not threaded.actions.is_empty() and threaded.actions == baseline.actions,
		"Every ordered NPC action matches, including its tick, actor, command, target and arguments.")
	_check(threaded.actors == baseline.actors and threaded.blocks == baseline.blocks and threaded.messages == baseline.messages
		and threaded.metrics == baseline.metrics and threaded.rng.state == baseline.rng.state,
		"Final actors, blocks, events, metrics and RNG state match.")
	_check(threaded.performance_counters.clock_steps == 3600
		and threaded.performance_counters.decisions == baseline.performance_counters.decisions,
		"Main-thread telemetry receives matching worker tick and planner counters.")
	_check(threaded.player().ap == 50 and game.simulation_backlog == 0.0 and game.local_map == local_map
		and wake_button == game.rest_button and local_map.is_visible_in_tree(),
		"Natural wake restores the dashboard and discards fast-forward.")
	print("Verified ordered NPC actions: ", threaded.actions.size())
	if OS.get_processor_count() >= 4:
		_check((threaded.npc_plan_on_turn and threaded.planning_batch.batches == 0 and threaded.managed_queries.planner_replanned == 0)
			or (threaded.managed_queries.planner_reused > 0 and threaded.managed_queries.planner_batches > 0)
			or (threaded.planning_batch.reused_count > 0 and threaded.planning_batch.peak_workers >= 2),
			"Recovery avoids speculative work when turn-time planning is selected.")
	else:
		_check(threaded.planning_batch.peak_workers == 0, "Small CPUs retain the serial planner fallback.")

	for input in ["Wake", "Escape"]:
		threaded.player().ap = 40
		var before: int = threaded.clock_step
		game.begin_sleep()
		game._advance_session(0.016)
		if not await _wait_for_progress(game, before): return
		if input == "Wake":
			wake_button.pressed.emit()
		else:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			game._unhandled_key_input(escape)
		var end: int = threaded.clock_step
		await process_frame
		_check(not threaded.sleeping and not game._sleep_sim.is_started() and game.simulation_backlog == 0.0
			and threaded.last_rest_notice == "You wake up." and local_map.is_visible_in_tree()
			and threaded.player().ap < 50 and end == threaded.clock_step and end > before,
			"%s joins the worker, clears pending time and restores the dashboard." % input)
		game._advance_session(0.1)
		_check(threaded.clock_step == end + 1, "The frame after %s runs at normal speed." % input)

	threaded.interrupt_at = threaded.clock_step + 2
	game.begin_sleep()
	game._advance_session(0.016)
	if not await _wait_for_wake(game): return
	_check(threaded.clock_step == threaded.interrupt_at and game.simulation_backlog == 0.0
		and game.notice == "Sleep interrupted." and game.damage_overlay.splashes.size() == 1,
		"An in-tick interruption stops at that tick and delivers its damage effect on the main thread.")

	game.begin_sleep()
	game._advance_session(0.016)
	game.paused = true
	game.refresh()
	var paused_step: int = threaded.clock_step
	await process_frame
	_check(threaded.sleeping and not game._sleep_sim.is_started() and threaded.clock_step == paused_step,
		"Pause suspends the worker while keeping sleep active.")
	game.paused = false
	game.refresh()
	game._advance_session(0.016)
	_check(game._sleep_sim.is_started(), "Resuming sleep starts the worker again.")
	game.last_save_slot = "user://threaded-sleep-test-save.json"
	game._quicksave()
	var save_file := FileAccess.open(game.last_save_slot, FileAccess.READ)
	var saved: Variant = JSON.parse_string(save_file.get_as_text()) if save_file != null else null
	_check(saved is Dictionary and saved.clock_step == threaded.clock_step and threaded.sleeping
		and not game._sleep_sim.is_started(), "Quicksave captures a complete tick and keeps sleep active.")
	var monitor: PerformanceMonitor
	for child in game.get_children():
		if child is PerformanceMonitor: monitor = child
	if monitor != null:
		threaded.performance_counters = null
		var monitor_key := InputEventKey.new()
		monitor_key.keycode = KEY_F9
		monitor_key.pressed = true
		game._advance_session(0.016)
		monitor._input(monitor_key)
		var capture_step: int = threaded.clock_step
		game._advance_session(0.016)
		if not await _wait_for_progress(game, capture_step): return
		monitor._input(monitor_key)
		await process_frame
		await process_frame
		_check(threaded.performance_counters == null and threaded.sleeping and monitor.total_steps > 0,
			"F9 can start and stop telemetry during sleep and collects worker ticks.")
		threaded.performance_counters = Counters.new()
	game._advance_session(0.016)
	_check(game._sleep_sim.is_started(), "The teardown fixture has a running worker.")
	game.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(game) and threaded.performance_counters != null,
		"Scene teardown joins the worker and restores the simulation counters.")
	await _check_threaded_rest()
	print("THREADED SLEEP CHECKS: %d FAILURES: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_threaded_rest() -> void:
	var sim := Sim.new()
	sim.start(991)
	for actor: Dictionary in sim.actors:
		if actor.id > 0:
			actor.down = true
			actor.dormant = true
	sim._reset_npc_runtime()
	var game: Game = GameScene.instantiate() as Game
	game.get_node("GameMusic").free()
	game.sim = sim
	game.threaded_rest_enabled = true
	root.add_child(game)
	game.set_process(false)
	sim.player().ap = 20
	game.begin_rest(3)
	game._advance_session(0.016)
	_check(game._sleep_sim.is_started() and game.rest_target == 23 and not game.dashboard_sleeping,
		"Rest uses a background worker and preserves its requested AP target and visible dashboard.")
	_check(game._recovery_view != null and game.local_map.sim == game._recovery_view
		and not is_same(game._recovery_view.player(), sim.player())
		and not is_same(game._recovery_view.blocks[0], sim.blocks[0]),
		"Rest renders isolated actor and block copies while the simulation owns the live world.")
	game._cancel_recovery()
	_check(not sim.resting and not game._sleep_sim.is_started() and game.simulation_backlog == 0.0,
		"Cancel rest joins background work and discards accelerated time.")
	sim.clock_step = 5099
	sim.minute = 509
	sim.clock_fraction = 0.0
	sim.player().ap = 49
	game.begin_rest(1)
	game._advance_session(0.1)
	while game.resting:
		await process_frame
		game._advance_session(0.016)
	_check(sim.clock_step == 5100 and sim.player().ap == 50 and game.simulation_backlog == 0.0,
		"Threaded rest stops at the exact target AP tick.")
	sim.player().ap = 20
	game.begin_rest(1)
	game._advance_session(0.0)
	var first: int = sim.clock_step
	var first_clock: String = game.clock_label.text
	var started: int = Time.get_ticks_usec()
	game.set_process(true)
	for frame in range(60): await process_frame
	game.set_process(false)
	game._join_sleep_thread()
	var elapsed: float = (Time.get_ticks_usec() - started) / 1_000_000.0
	var expected: float = 8.0 * 10.0 * elapsed
	_check(absf(float(sim.clock_step - first) - expected) < maxf(3.0, expected * 0.05),
		"Rest handoffs account for elapsed time once and sustain the requested 8x rate.")
	_check(game.clock_label.text != first_clock and game.local_map.is_visible_in_tree(),
		"Rest refreshes the visible dashboard while background recovery advances.")
	game._cancel_recovery()
	game.queue_free()
	await process_frame


func _wait_for_wake(game: Game) -> bool:
	var deadline: int = Time.get_ticks_msec() + 30_000
	while game.resting and Time.get_ticks_msec() < deadline:
		await process_frame
		game._advance_session(0.016)
	if not game.resting: return true
	game.queue_free()
	push_error("The threaded sleep fixture did not wake.")
	quit(1)
	return false


func _wait_for_progress(game: Game, step: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + 3_000
	while game.resting and game.recovery_progress().clock_step <= step and Time.get_ticks_msec() < deadline:
		await process_frame
		game._advance_session(0.016)
	if game.resting and game.recovery_progress().clock_step > step: return true
	game.queue_free()
	push_error("The threaded sleep fixture did not advance before manual wake.")
	quit(1)
	return false


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
