extends SceneTree

const Harness = preload("res://tests/balance_cohort_runs.gd")
var checks: int
var failures: int

func _initialize() -> void:
	var sim := Harness.Trial.new()
	sim.start(991)
	for a: Dictionary in sim.actors:
		a.dormant = true
		a.down = true
	var medic: Dictionary = sim.actors[1]
	var zombie: Dictionary = sim.actors[2]
	var victim: Dictionary = sim.actors[3]
	for a: Dictionary in [medic, zombie, victim]:
		a.x = 4
		a.y = 4
		a.inside = true
		a.dormant = false
		a.down = false
		a.ap = 50
		a.busy_until = sim.now()
		# Pin setup before starting the ledger, including starting skills and XP.
		a.inventory.clear()
		a.equipped = -1
	medic.human = true
	medic.hp = 40
	medic.xp = 200
	medic.human_skills = ["first_aid", "lab_experience", "necro_employment"]
	medic.zombie_skills = []
	zombie.human = false
	zombie.wants_revive = true
	zombie.hp = 50
	zombie.human_skills = []
	zombie.zombie_skills = ["vigour_mortis", "death_grip"]
	victim.human = true
	victim.hp = 40
	victim.infected = false
	sim.blocks[44].type = "hospital"
	sim.blocks[44].fort = ""
	sim.blocks[44].ruin = 0
	sim.give_item(medic, "first_aid_kit")
	sim.give_item(medic, "syringe")
	sim.reindex()
	sim.start_tracking()
	_check(sim._try(medic, "heal", victim.id), "Instrumented healing executes.")
	_check(sim.records[medic.id].earned_xp == 5 and medic.xp == 205, "Earned XP excludes starting XP.")
	medic.busy_until = sim.now()
	var paid: int = sim.skill_cost(medic, "free_running")
	_check(sim.npc_planner._purchase(sim, medic, "free_running"), "Instrumented skill purchase executes.")
	_check(sim.records[medic.id].purchases == 1 and sim.records[medic.id].spent_xp == paid
		and sim.records[medic.id].earned_xp == 5 and sim.records[medic.id].peak_unspent_xp == 205,
		"Purchases preserve earned XP and track exact spend and peak balance.")
	victim.hp = 1
	for attempt: int in range(40):
		if victim.down: break
		zombie.busy_until = sim.now()
		sim._try(zombie, "attack", victim.id)
	_check(victim.down and sim.records[victim.id].combat_deaths == 1 and sim.records[zombie.id].kills == 1,
		"Combat deaths and kills are attributed to individual NPCs.")
	medic.busy_until = sim.now()
	_check(sim._try(medic, "revive", zombie.id), "Instrumented revival executes.")
	_check(sim.records[medic.id].revives_performed == 1 and sim.records[zombie.id].revives_received == 1,
		"Revivals distinguish performer from recipient.")
	_check(sim.records[zombie.id].cohort == "zombie" and zombie.human,
		"Original cohorts remain stable after conversion.")
	# A voluntary jump must not be counted as a combat kill.
	zombie.down = false
	zombie.hp = 50
	zombie.busy_until = sim.now()
	sim.blocks[44].type = "office"
	_check(sim._try(zombie, "jump"), "Instrumented voluntary death executes.")
	_check(sim.records[zombie.id].suicides == 1 and sim.records[zombie.id].combat_deaths == 0,
		"Voluntary return to undeath is separate from combat losses.")
	_check(sim.audit().is_empty(), "XP, skills, actions, deaths and revivals reconcile with the simulation.")
	print("BALANCE METRIC CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
