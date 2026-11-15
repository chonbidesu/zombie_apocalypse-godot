extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Fixture = preload("res://tests/performance_fixture.gd")
var checks: int
var failures: int

class TraceSim extends Sim:
	var actions := PackedStringArray()
	func execute(a: Dictionary, command: String, target: int = -1, data: Dictionary = {}) -> void:
		actions.append("%d/%d/%s/%d/%s" % [clock_step, a.id, command, target, JSON.stringify(data)])
		super.execute(a, command, target, data)


func _initialize() -> void:
	_action_effects()
	var count: int = 300
	var ap: int = 2
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--npcs="): count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--ap="): ap = int(arg.get_slice("=", 1))
	var reference: TraceSim
	for skip: bool in [false, true]:
		var sim := TraceSim.new()
		sim.skip_unobserved_narration = skip
		_check(Fixture.start_city(sim, 4815, count, count / 2).is_empty(), "The narration fixture starts.")
		Fixture.awaken_npcs(sim, true)
		sim._reset_npc_runtime()
		_check(not Fixture.prepare_shelter(sim).is_empty(), "The narration fixture has a shelter.")
		sim.player().ap = 50 - ap
		sim.begin_sleep()
		while sim.resting: sim.elapse_budgeted(0.25, 8000)
		if reference == null:
			reference = sim
			continue
		_check(sim.actions == reference.actions, "Lazy narration preserves every committed action and its order.")
		_check(sim.actors == reference.actors and sim.blocks == reference.blocks and sim.metrics == reference.metrics,
			"Lazy narration preserves world state, inventory, damage and AP.")
		_check(sim.rng.state == reference.rng.state, "Unobserved narration preserves the random stream, including flavour draws.")
		_check(sim.messages == reference.messages, "Observed, audible and remote event text remains unchanged.")
		_check(sim.npc_planner.memory.save_records() == reference.npc_planner.memory.save_records(), "NPC memory is unaffected by narration.")
		_check(sim.unnarrated_actions > 0 and sim.narrated_actions < reference.narrated_actions,
			"Invisible NPC actions skip formatting work.")
		print("Narration verified %d actions; formatted %d, skipped %d." % [sim.actions.size(), sim.narrated_actions, sim.unnarrated_actions])
	print("NPC NARRATION CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _action_effects() -> void:
	# Exercise flavour RNG and remote events that a sleep trace may rarely hit.
	for command: String in ["read", "barricade", "search", "groan", "bellow", "broadcast", "phone", "enter"]:
		var reference: Sim
		for skip: bool in [false, true]:
			var sim := Sim.new()
			sim.start(991)
			sim.skip_unobserved_narration = skip
			var a: Dictionary = sim.actors[1]
			a.x = 1
			a.y = 1
			a.inside = command not in ["groan", "bellow", "enter"]
			a.ap = 50
			a.human = true
			a.down = false
			var p: Dictionary = sim.player()
			p.x = 9
			p.y = 9
			p.inside = true
			p.down = false
			var site: Dictionary = sim.blocks[11]
			site.type = "office"
			site.fort = ""
			site.ruin = 0
			site.radio = true
			site.frequency = 28.01
			sim.set_barricade_strength(site, 0)
			sim.give_item(p, "radio")
			var data: Dictionary = {"text": "Defend", "frequency": 28.01}
			if command == "read":
				sim.give_item(a, "book")
				data.uid = a.inventory.back().uid
			sim.reindex()
			sim.execute(a, command, 0 if command == "phone" else -1, data)
			if reference == null:
				reference = sim
				continue
			_check(sim.rng.state == reference.rng.state and sim.actors == reference.actors
				and sim.blocks == reference.blocks and sim.messages == reference.messages,
				"Unseen %s preserves effects, flavour randomness and received signals." % command)
			if command in ["read", "barricade", "search", "groan", "enter"]:
				_check(sim.unnarrated_actions == 1, "Unobservable %s skips narration." % command)
			else:
				_check(sim.narrated_actions == 1 and sim.messages == reference.messages,
					"Observable remote %s keeps its message." % command)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
