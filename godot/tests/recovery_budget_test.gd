extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/interface.gd")
const GameScene = preload("res://main.tscn")


class RecordingSim extends Sim:
	var last_budget_usec: int
	var interrupt_next_tick: bool

	func elapse_budgeted(real_seconds: float, budget_usec: int) -> float:
		last_budget_usec = budget_usec
		return super.elapse_budgeted(real_seconds, budget_usec)

	func _clock_step() -> void:
		super._clock_step()
		if interrupt_next_tick:
			interrupt_next_tick = false
			stop_rest("Sleep interrupted.")


var _checks: int
var _failures: int


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sim: RecordingSim = RecordingSim.new()
	if not sim.start(991).is_empty():
		quit(1)
		return
	for id in range(1, sim.actors.size()):
		var actor: Dictionary = sim.actors[id]
		actor.dormant = true
		actor.down = true
	sim._reset_npc_runtime()
	var player: Dictionary = sim.player()
	var game: Game = GameScene.instantiate() as Game
	game.get_node("GameMusic").free()
	game.sim = sim
	root.add_child(game)
	game.set_process(false)
	var rest_control: Button = game.rest_button
	var map: Control = game.local_map
	var action: Button = game.action_controls[0].node

	player.ap = 20
	game.simulation_backlog = 5.0
	game.begin_rest(10)
	_check(sim.resting and game.simulation_backlog == 0.0, "Rest starts with a fresh time queue.")
	game._advance_session(0.016)
	_check(sim.last_budget_usec == 4_000, "Rest uses its gameplay budget.")
	_check(game.rest_button == rest_control and game.local_map == map and action.disabled,
		"Rest reuses the controls and disables gameplay actions.")
	game.simulation_backlog = 5.0
	(game.page.get_node("RestButton") as Button).pressed.emit()
	_check(not sim.resting and game.simulation_backlog == 0.0, "Cancel rest clears deferred time immediately.")
	_check(game.rest_button == rest_control and game.local_map == map and action.is_inside_tree() and not action.disabled,
		"Cancel rest re-enables the original action control.")
	var step: int = sim.clock_step
	game._advance_session(0.1)
	_check(sim.clock_step == step + 1, "The next frame advances at normal speed after cancel.")

	player.ap = 49
	sim.clock_step = 5099
	sim.minute = 509
	sim.clock_fraction = 0.0
	game.begin_sleep()
	_check(game.rest_button == rest_control and not map.is_visible_in_tree() and not action.is_visible_in_tree(),
		"Sleep keeps perception and action controls hidden.")
	game.simulation_backlog = 20.0
	game._advance_session(0.1)
	_check(sim.last_budget_usec == 8_000, "Sleep uses its gameplay budget.")
	_check(not sim.sleeping and player.ap == 50 and sim.clock_step == 5100 and sim.clock_fraction == 0.0,
		"Natural wake stops on the AP tick without consuming queued time at normal speed.")
	_check(game.simulation_backlog == 0.0 and not (game.page.get_node("SleepButton") as Button).disabled,
		"Natural wake clears the queue and refreshes the controls on that frame.")
	_check(game.rest_button == rest_control and game.local_map == map and map.is_visible_in_tree()
		and action.is_visible_in_tree(), "Natural wake restores the original dashboard controls.")

	player.ap = 40
	game.begin_sleep()
	game.simulation_backlog = 10.0
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	_check(not sim.sleeping and game.simulation_backlog == 0.0, "Escape wakes and clears deferred time.")

	game.begin_sleep()
	game.simulation_backlog = 10.0
	sim.interrupt_next_tick = true
	step = sim.clock_step
	game._advance_session(0.1)
	_check(not sim.resting and sim.clock_step == step + 1 and game.simulation_backlog == 0.0,
		"An interrupted recovery yields after the interrupting tick and drops queued time.")
	game.queue_free()
	await process_frame
	print("RECOVERY BUDGET CHECKS: %d FAILURES: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
