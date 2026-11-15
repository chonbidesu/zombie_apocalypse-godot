extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Planner = preload("res://scripts/npc_utility/planner.gd")
var checks: int
var failures: int


func _initialize() -> void:
	if not ClassDB.class_exists("CSharpScript"):
		print("MANAGED PLANNER: skipped on the standard Godot build.")
		quit()
		return
	var sim := Sim.new()
	sim.managed_queries.planner_mode = 1
	sim.start(991)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5017
	for round: int in range(12):
		var due: Array = []
		for site: Dictionary in sim.blocks:
			site.barricade = rng.randi_range(0, 7)
			site.barricade_damage = 0
			site.generator = rng.randf() < 0.5
			site.fuel_until = sim.minute + rng.randi_range(-1, 1)
		for a: Dictionary in sim.actors:
			a.human = a.id % 3 != 0
			a.down = a.id % 11 == 0
			a.wants_revive = a.id % 5 == 0
			a.prefers_undead = false
			a.x = 3 + a.id % 3
			a.y = 3 + a.id / 12
			a.inside = a.id % 2 == 0
			a.hp = rng.randi_range(1, 50)
			a.ap = rng.randi_range(0, 50)
			a.infected = a.id % 7 == 0
			a.fuel_soaked = a.id % 13 == 0
			a.busy_until = sim.now()
			a.next_think = sim.now()
			a.tagged_until = sim.minute + rng.randi_range(-1, 1)
			a.tagged_skills = ["first_aid", "death_grip", "infectious_bite"] if a.id % 2 == 0 else []
			a.human_skills = ["firearms", "pistol_training", "advanced_pistol", "shotgun_training", "advanced_shotgun",
				"hand_to_hand", "knife_combat", "axe_proficiency", "necro_employment", "lab_experience", "necronet", "construction", "diagnosis"]
			a.zombie_skills = ["scent_blood", "flesh_rot"]
			a.inventory.clear()
			a.equipped = -1
			var weapon: String = ["pistol", "shotgun", "knife", "fire_axe", "flare_gun", "newspaper", "crowbar", ""][round % 8]
			if not weapon.is_empty():
				sim.give_item(a, weapon)
				a.equipped = a.inventory.back().uid
				if a.inventory.back().has("ammo"): a.inventory.back().ammo = round % 2
			for kind: String in ["first_aid_kit", "syringe", "dna_extractor", "flak_jacket"]: sim.give_item(a, kind)
			due.append(a.id)
		sim.reindex()
		sim.resting = true
		sim.managed_queries.begin(sim, due)
		_check(sim.managed_queries.planning_active, "The C# planner is active.")
		for a: Dictionary in sim.actors:
			if not a.human or a.down: continue
			_compare(sim, a)
		# An earlier actor changes an opponent and inventory before its turn.
		sim.actors[3].hp = 1
		sim.managed_queries.dirty(sim.current_block(sim.actors[3]), 3)
		for a: Dictionary in sim.actors:
			if a.human and not a.down: _compare(sim, a)
	print("MANAGED PLANNER CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _compare(sim, a: Dictionary) -> void:
	var here: Dictionary = sim.current_block(a)
	var present: Array = sim.occupants(here, a.inside)
	var planner = Planner.new()
	sim.managed_queries.planning_active = false
	var expected: Dictionary = planner._human_context(sim, a, here, present)
	planner._clear_choice()
	planner._primary_choices(sim, a, here, present, expected)
	var choice: Array = [planner._score, planner._command, planner._target, planner._data]
	sim.managed_queries.planning_active = true
	var actual: Dictionary = planner._human_context(sim, a, here, present)
	_check(actual == expected, "Managed context matches the reference for actor %d." % a.id)
	planner._clear_choice()
	planner._primary_choices(sim, a, here, present, actual)
	_check([planner._score, planner._command, planner._target, planner._data] == choice,
		"Managed candidates select the reference action for actor %d." % a.id)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
