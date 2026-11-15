extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const AI = preload("res://scripts/npc_ai.gd")
var checks: int
var failures: int

class RecordingSim extends Sim:
	var decision_aps: Array[int] = []
	func reanimate_bodies() -> void:
		pass # Keep the isolated recovery case free of midnight reinforcements.
	func _npc_turn(a: Dictionary) -> int:
		decision_aps.append(a.ap)
		return super._npc_turn(a)


func _initialize() -> void:
	_recovery(false, true)
	_recovery(true, true)
	_recovery(false, false)
	_seek_safety()
	_awareness()
	print("NPC RECOVERY CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _city() -> RecordingSim:
	var sim := RecordingSim.new()
	sim.start(991)
	for actor: Dictionary in sim.actors:
		if actor.id > 0:
			actor.dormant = true
			actor.down = true
	var a: Dictionary = sim.actors[1]
	a.dormant = false
	a.down = false
	a.human = true
	a.prefers_undead = false
	a.x = 4
	a.y = 4
	a.inside = false
	a.ap = 50
	a.busy_until = sim.now()
	a.next_think = sim.now() + 0.1
	sim.blocks[44].type = "office"
	sim.blocks[44].fort = ""
	sim.blocks[44].ruin = 0
	sim.set_barricade_strength(sim.blocks[44], 0)
	sim.reindex()
	sim._reset_npc_runtime()
	return sim


func _recovery(inside: bool, human: bool) -> void:
	var sim := _city()
	var a: Dictionary = sim.actors[1]
	a.inside = inside
	a.human = human
	a.ap = 0
	sim.reindex()
	sim._reset_npc_runtime()
	var due: int = sim._npc_due(a)
	var intervals: int = 25 if inside and human else 50
	_check(due == (sim.clock_step / 300 + intervals) * 300, "An exhausted NPC is scheduled directly at full recovery.")
	sim.advance_steps(20 * 300)
	_check(sim.decision_aps.is_empty() and a.ap == (40 if inside and human else 20),
		"Resting NPCs make no decisions at partially recovered AP.")
	for attempt in range(20): sim.wake_npc(a)
	_check(sim._npc_due(a) == due and not str(a.recovery_mode).is_empty(), "Routine activity cannot wake a recovering NPC.")
	# Also reject a stale or externally queued early scheduler ticket.
	sim._schedule_npc(a, sim.clock_step + 1)
	sim.advance_steps(1)
	_check(sim.decision_aps.is_empty() and sim._npc_due(a) == due, "An early ticket cannot bypass full recovery.")
	var path: String = "user://npc-recovery-test.json"
	_check(sim.save_to(path) == OK, "Recovering NPCs can be saved.")
	var loaded := RecordingSim.new()
	_check(loaded.load_from(path).is_empty() and loaded._npc_due(loaded.actors[1]) == due,
		"Save/load preserves the recovery deadline.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sim.advance_steps(due - sim.clock_step)
	_check(sim.decision_aps.size() == 1 and sim.decision_aps[0] == 50, "The next decision evaluates the world at exactly fifty AP.")
	_check(sim.planning_batch.batches == 0 and sim.managed_queries.planner_batches == 0
		and sim.managed_queries.planner_replanned == 0, "Recovery performs no speculative scoring or invalidation replans.")


func _seek_safety() -> void:
	var sim := _city()
	var a: Dictionary = sim.actors[1]
	a.ap = 4
	sim._schedule_npc(a, sim.clock_step + 1)
	sim.advance_steps(1)
	_check(a.inside and a.ap == 3, "A low-AP survivor enters an unbarricaded building before exhausting AP.")
	a.busy_until = sim.now()
	sim._schedule_npc(a, sim.clock_step + 1)
	sim.advance_steps(1)
	_check(a.recovery_mode == "sleep" and sim._npc_due(a) > sim.clock_step + 300,
		"A sheltered survivor rests until full AP instead of polling after a few points.")
	sim = _city()
	a = sim.actors[1]
	for site: Dictionary in sim.npc_local_sites(a): site.type = "street"
	a.ap = 1
	sim._schedule_npc(a, sim.clock_step + 1)
	sim.advance_steps(1)
	_check(not a.inside and a.recovery_mode == "rest", "An NPC with no nearby refuge can remain outside to recover.")


func _awareness() -> void:
	var sim := _city()
	var a: Dictionary = sim.actors[1]
	a.human_skills = ["necro_employment"]
	for site: Dictionary in sim.blocks:
		site.type = "office"
		site.generator = false
		site.revive_point = false
		sim.set_barricade_strength(site, 0)
	sim.revive_sites.clear()
	var far: Dictionary = sim.block_at(7, 4)
	far.type = "necrotech_lab"
	far.generator = true
	far.generator_hp = 6
	far.fuel_until = sim.minute + 100
	sim.set_graffiti(far, "Revive point", true)
	sim.observe_npc_landmarks(a)
	_check(sim.nearby_light(a).is_empty() and sim.npc_planner._revival_target(sim, a, false).is_empty(),
		"Distant lights, clinics and markers do not leak into ordinary awareness.")
	var near: Dictionary = sim.block_at(5, 4)
	near.type = "necrotech_lab"
	near.generator = true
	near.generator_hp = 6
	near.fuel_until = sim.minute + 100
	sim.set_graffiti(near, "Revive point", true)
	sim.observe_npc_landmarks(a)
	_check(sim.nearby_light(a).get("id", -1) == near.id, "The neighbouring light is visible.")
	_check(sim.npc_planner._revival_target(sim, a, false).get("id", -1) == near.id, "A seen revival marker can become a destination.")
	a.x = 1
	a.y = 4
	sim.reindex()
	sim.observe_npc_landmarks(a)
	var remembered: int = sim.npc_planner._revival_target(sim, a, false).get("id", -1)
	near.generator = false
	sim.set_graffiti(near, "No longer a marker", true)
	_check(remembered == near.id and sim.npc_planner._revival_target(sim, a, false).get("id", -1) == near.id,
		"Remembered landmarks remain stale until the NPC can observe changes.")
	a.x = 4
	sim.reindex()
	var hidden: Dictionary = sim.actors[2]
	hidden.x = 5
	hidden.y = 4
	hidden.human = true
	hidden.down = false
	hidden.inside = true
	sim.reindex()
	_check(not sim.npc_seen_occupants(a, near).has(hidden), "An NPC cannot inspect occupants through a neighbouring roof.")
	# A used skill can supply information outside ordinary vision.
	a.human = false
	a.zombie_skills = ["scent_death"]
	a.ap = 50
	a.memory = -1
	far.type = "office"
	hidden.human = false
	hidden.x = 7
	hidden.inside = false
	hidden.wants_revive = false
	sim.reindex()
	_check(sim._try(a, "smell") and a.memory == far.id, "Scent Death retains its explicit extended sensing range.")
	# Exercise the managed local light query too.
	if ClassDB.class_exists("CSharpScript"):
		sim.resting = true
		sim.managed_queries.begin(sim)
		_check(sim.nearby_light(a).is_empty(), "C# light queries use the same one-block radius.")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
