extends SceneTree
## Differential coverage for map boundaries, ties and changed mirror records.

const Sim = preload("res://scripts/simulation.gd")
const AI = preload("res://scripts/npc_ai.gd")
var _checks: int
var _failures: int


func _initialize() -> void:
	if not ClassDB.class_exists("CSharpScript"):
		print("MANAGED QUERIES: skipped on the standard Godot build.")
		quit()
		return
	var sim := Sim.new()
	sim.start(1818)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5076
	for round: int in range(4):
		# Change occupancy, clinic staffing, doors, power and marker membership.
		for site: Dictionary in sim.blocks:
			site.type = ["office", "necrotech_lab", "street"][rng.randi_range(0, 2)]
			site.barricade = rng.randi_range(0, 8)
			site.ruin = rng.randi_range(0, 1)
			site.fort = "test" if site.id % 7 == 0 else ""
			site.generator = rng.randf() < 0.5
			site.generator_hp = 0 if site.id % 4 == 0 else 10
			site.fuel_until = sim.minute + rng.randi_range(-1, 1)
			site.doors = rng.randf() < 0.5
			site.revive_point = site.id % 11 == round
		for actor: Dictionary in sim.actors:
			actor.human = rng.randf() < 0.6
			actor.down = rng.randf() < 0.1
			actor.inside = rng.randf() < 0.5
			actor.wants_revive = rng.randf() < 0.5
			actor.home = sim.current_block(actor).id
			actor.human_skills = ["lab_experience"]
			actor.inventory = [{"kind": "syringe", "uid": 1}]
		if round == 0:
			sim.reindex()
		else:
			for site: Dictionary in sim.blocks: sim.managed_queries.dirty(site)
		# Revival lookup uses this index in the GDScript reference.
		sim.sites_by_type.clear()
		sim.revive_sites.clear()
		for site: Dictionary in sim.blocks:
			if site.revive_point: sim.revive_sites[site.id] = true
			if not sim.sites_by_type.has(site.type): sim.sites_by_type[site.type] = []
			sim.sites_by_type[site.type].append(site)
		for id: int in range(12):
			sim.npc_planner.memory.remember(0, Vector2i(id % sim.width, id / sim.width),
				sim.minute - 100 * id, PackedByteArray([id * 20, 0, 0, 0, 0]), 0)
		sim.resting = true
		sim.managed_queries.begin(sim)
		_check(sim.managed_queries.is_ready(), "C# mirror initialized in round %d." % round)
		var probe: Dictionary = sim.player().duplicate(true)
		for site: Dictionary in sim.blocks:
			probe.x = site.x
			probe.y = site.y
			probe.inside = site.id % 2 == 0
			probe.ap = 1 + site.id % 50
			probe.avoid_site = site.id + 1
			probe.avoid_until = sim.minute + 1
			sim.managed_queries.active = false
			var expected: Array = _queries(sim, probe, site)
			sim.managed_queries.active = true
			var actual: Array = _queries(sim, probe, site)
			_check(actual == expected, "All query targets match at cell %d in round %d: %s / %s." % [site.id, round, actual, expected])
	print("MANAGED QUERY CHECKS: %d FAILURES: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _queries(sim, actor: Dictionary, site: Dictionary) -> Array:
	return [_id(sim._visible_human(actor)), _id(sim.nearby_light(actor)),
		_id(sim.npc_planner._group_target(sim, actor, site)),
		_id(AI.retreat_target(sim, actor, site)), sim.npc_planner._staffed(sim, site),
		_id(sim.npc_planner._revival_target(sim, actor, false)),
		_id(sim.npc_planner._revival_target(sim, actor, true))]


func _id(value: Dictionary) -> int:
	return value.get("id", -1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
