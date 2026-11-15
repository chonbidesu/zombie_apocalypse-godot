extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Fixture = preload("res://tests/performance_fixture.gd")
const Memory = preload("res://scripts/npc_utility/location_memory.gd")

class TraceSim extends Sim:
	var actions := PackedStringArray()
	var paths := PackedStringArray()

	func execute(actor: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> void:
		actions.append("%d/%d/%s/%d/%s" % [clock_step, actor.id, command, target_id, JSON.stringify(data)])
		super.execute(actor, command, target_id, data)

	func query_route(from_id: int, to_id: int) -> PackedInt64Array:
		var path := super.query_route(from_id, to_id)
		paths.append("%d/%d/%s" % [from_id, to_id, str(path)])
		return path


var _checks: int
var _failures: int


func _initialize() -> void:
	var npcs: int = 1000
	var humans: int = -1
	var ap: int = 1
	var mode: String = "sleep"
	for arg in OS.get_cmdline_user_args():
		if arg in ["--mode=rest", "--mode=sleep"]:
			mode = arg.get_slice("=", 1)
			continue
		var value := arg.get_slice("=", 1)
		if not value.is_valid_int():
			quit(2)
			return
		match arg.get_slice("=", 0):
			"--npcs": npcs = int(value)
			"--humans": humans = int(value)
			"--ap": ap = int(value)
			_:
				quit(2)
				return
	if npcs < 12 or npcs > 10000 or humans > npcs or humans < -1 or ap < 1 or ap > 50:
		quit(2)
		return
	var reference: TraceSim
	for limit: int in [0, 1, 4, -1]:
		var sim := TraceSim.new()
		sim.planning_batch.thread_limit = limit
		sim.managed_queries.enabled = limit != 0
		sim.managed_queries.planner_mode = 1
		sim.route_cache.enabled = limit != 0
		if not Fixture.start_city(sim, 4815, npcs, humans).is_empty():
			quit(1)
			return
		Fixture.awaken_npcs(sim, true)
		sim._reset_npc_runtime()
		if Fixture.prepare_shelter(sim).is_empty():
			quit(1)
			return
		sim.player().ap = 50 - ap
		if mode == "sleep": sim.begin_sleep()
		else: sim.begin_rest(ap)
		while sim.resting: sim.elapse_budgeted(0.25, 8000)
		if limit != 0 and ClassDB.class_exists("CSharpScript"):
			_check(sim.managed_queries.is_ready(), "The managed query backend was exercised at planner limit %d." % limit)
			_check(sim.managed_queries.planner_on_demand > 0 and sim.managed_queries.planner_batches == 0
				and sim.managed_queries.planner_replanned == 0,
				"The managed planner evaluates current turns without speculative replanning at limit %d." % limit)
		if reference == null:
			_check(not sim.actions.is_empty(), "The recovery fixture advances NPC actions.")
			reference = sim
			continue
		_check(sim.actions == reference.actions, "Every action and its order matches at planner limit %d." % limit)
		_check(sim.paths == reference.paths, "Every directed A* path matches at planner limit %d." % limit)
		_check(sim.actors == reference.actors and sim.blocks == reference.blocks and sim.metrics == reference.metrics,
			"Final actors, map and metrics match at planner limit %d." % limit)
		_check(sim.messages == reference.messages and sim.rng.state == reference.rng.state,
			"Event history and RNG state match at planner limit %d." % limit)
		_check(sim.npc_planner.memory.save_records() == reference.npc_planner.memory.save_records(),
			"Bounded observation memory matches at planner limit %d." % limit)
		_check(sim.clock_step == reference.clock_step and sim.clock_fraction == 0.0 and sim.player().ap == reference.player().ap,
			"Recovery ends on the same tick at planner limit %d." % limit)
		if limit == 1: _check(sim.planning_batch.peak_workers == 0, "A one-thread budget uses the serial fallback.")
		if limit == 1 and ClassDB.class_exists("CSharpScript"):
			_check(sim.managed_queries.planner_peak_workers == 1, "The C# planner respects a one-thread budget.")
		print("Planner limit %d verified %d actions and %d routes; GDScript workers %d, C# worker budget %d." % [
			limit, sim.actions.size(), sim.paths.size(), sim.planning_batch.peak_workers, sim.managed_queries.planner_peak_workers])
	_check_observation_eviction()
	print("PARALLEL PLANNER CHECKS: %d FAILURES: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_observation_eviction() -> void:
	var sim := Sim.new()
	sim.start(991)
	var actor: Dictionary = sim.actors[1]
	actor.x = 4
	actor.y = 4
	actor.inside = false
	actor.home = 0
	actor.npc_observed = -1
	var supplies = sim.npc_planner.supplies
	var memory = supplies.memory
	var victim := Vector2i(5, 5)
	memory.remember(actor.id, victim, sim.minute, PackedByteArray([0, 0, 0, 0, 0]), 0)
	for index in range(1, Memory.SITES_PER_ACTOR):
		memory.remember(actor.id, Vector2i(index % 10, index / 10), sim.minute,
			PackedByteArray([255, 255, 255, 255, 255]), 0)
	for y in range(3, 6):
		for x in range(3, 6): sim.block_at(x, y).type = "office"
	var here: Dictionary = sim.current_block(actor)
	var observations: Array = supplies.observations(sim, actor, here, 0)
	supplies.observe(sim, actor, here, 0, observations)
	_check(memory.knows(actor.id, memory.site_id(victim)),
		"A known neighbour evicted by an earlier observation is observed again in map order.")
	actor.inside = true
	here.type = "office"
	here.ruin = 0
	here.generator = false
	sim.search_tables.office = {"first_aid_kit": 1.0}
	var stocked: PackedByteArray = supplies._observation_values(sim, actor, here, here, 0)
	sim.search_tables.office = {"newspaper": 1.0}
	var depleted: PackedByteArray = supplies._observation_values(sim, actor, here, here, 0)
	_check(stocked[Memory.Kind.MEDICAL] > 0 and depleted[Memory.Kind.MEDICAL] == 0,
		"Stock observation caching respects changed search tables.")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
