extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Progression = preload("res://scripts/npc_utility/progression.gd")
const Feed = preload("res://scripts/event_feed.gd")
var checks: int
var failures: int

func _initialize() -> void:
	_daily_scans()
	_medical_progression()
	_healing()
	print("DNA MEDICAL CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _city():
	var sim := Sim.new()
	sim.start(991)
	for a: Dictionary in sim.actors:
		a.dormant = true
		a.down = true
		a.tagged_until = 0
		a.tagged_skills.clear()
		a.recovery_mode = ""
	for id: int in [0, 1, 2, 3]:
		var a: Dictionary = sim.actors[id]
		a.x = 4
		a.y = 4
		a.inside = false
		a.human = id < 2
		a.down = false
		a.hp = 50
		a.ap = 50
		a.busy_until = sim.now()
		a.human_skills = ["necro_employment"] if id < 2 else []
		a.zombie_skills = [] if id < 2 else ["vigour_mortis"]
		a.inventory.clear()
		a.equipped = -1
		a.wants_revive = false
	for id: int in [0, 1]: sim.give_item(sim.actors[id], "dna_extractor")
	sim.blocks[44].type = "office"
	sim.blocks[44].fort = ""
	sim.blocks[44].ruin = 0
	sim.set_barricade_strength(sim.blocks[44], 0)
	sim.reindex()
	sim._reset_npc_runtime()
	return sim

func _daily_scans() -> void:
	var sim = _city()
	var p: Dictionary = sim.player()
	var human: Dictionary = sim.actors[1]
	var patient: Dictionary = sim.actors[2]
	patient.human_skills = ["first_aid"]
	_check(sim.action_feedback(p, "extract").is_empty(), "The scanner is usable with no selected target.")
	_check(sim.act("extract").ok and p.xp == 4, "An automatic extraction grants exactly four XP.")
	_check(patient.tagged_until == 1440 and sim.dna_human_training(patient), "The shared sample lasts until midnight and reveals human training.")
	_check(patient.tagged_skills == ["first_aid", "vigour_mortis"], "A DNA sample records both skill trees.")
	var event: Dictionary = sim.messages.back().duplicate(true)
	_check(event.dna_report.skills == patient.tagged_skills and event.actor == 0, "Player extraction stores its own immutable skill report.")
	_check(not sim._try(human, "extract", patient.id) and human.xp == 0,
		"A second human cannot collect XP from the same zombie that day.")
	p.busy_until = sim.now()
	_check(sim.act("extract", patient.id).ok and sim.actors[3].tagged_until == 1440 and p.xp == 8,
		"Using the scanner switches a scanned selection to another unscanned zombie.")
	p.busy_until = sim.now()
	var failed: Dictionary = sim.act("extract")
	_check(not failed.ok and failed.message == sim.DNA_SCAN_DAILY_BLOCKED and p.xp == 8,
		"When all local zombies are scanned, extraction fails without rewarding XP.")
	patient.zombie_skills.append("death_grip")
	_check(not sim.dna_profile(patient).contains("Death Grip") and not event.dna_report.skills.has("death_grip"),
		"DNA results remain a snapshot when the target learns another skill.")
	sim.die(patient)
	_check(patient.tagged_until == 1440 and not sim.reason(human, "extract", patient.id).is_empty(),
		"A dead body keeps its sampled identity but cannot be scanned before standing.")
	patient.ready_at = sim.minute
	patient.busy_until = sim.now()
	_check(sim._try(patient, "stand") and patient.tagged_until == 0 and patient.tagged_skills.is_empty(),
		"Standing as a zombie clears the previous life's shared scan tag.")
	_check(sim._try(human, "extract", patient.id) and human.xp == 4,
		"A zombie that died and stood up can earn a new four-XP sample that same day.")
	human.busy_until = sim.now()
	_check(not sim._try(human, "extract", patient.id) and human.xp == 4,
		"The new standing life is still limited to one sample until its next reset.")
	human.human_skills.append("lab_experience")
	sim.give_item(human, "syringe")
	human.busy_until = sim.now()
	_check(sim._try(human, "revive", patient.id), "A sampled former human can be revived.")
	patient.ready_at = sim.minute
	patient.busy_until = sim.now()
	_check(sim._try(patient, "stand") and patient.human and patient.tagged_until == 1440,
		"Standing as a revived human does not reset zombie scan eligibility.")
	sim.die(patient)
	patient.ready_at = sim.minute
	patient.busy_until = sim.now()
	_check(sim._try(patient, "stand") and not patient.human and patient.tagged_until == 0,
		"A revived human who dies and stands as a zombie gets a new scan allowance.")
	human.busy_until = sim.now()
	var before_xp: int = human.xp
	_check(sim._try(human, "extract", patient.id) and human.xp == before_xp + 4,
		"The revival-death-standing cycle permits a new rewarded scan before midnight.")
	_check(event.dna_report.skills == ["first_aid", "vigour_mortis"],
		"Old player reports remain unchanged across death, revival and resampling.")
	var path: String = "user://dna-medical-test.json"
	_check(sim.save_to(path) == OK, "DNA state saves.")
	var loaded := Sim.new()
	_check(loaded.load_from(path).is_empty() and loaded.actors[2].tagged_until == 1440
		and loaded.messages.any(func(row): return row.get("dna_report", {}).get("skills", []).has("first_aid")),
		"Save/load retains the lockout and historical player skill report.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Cross the real midnight hook without advancing inactive fixture actors.
	sim.clock_step = 14_399
	sim.minute = 1439
	sim.advance_steps(1)
	_check(patient.tagged_until == 0 and patient.tagged_skills.is_empty(), "Midnight clears all shared tags.")
	p.busy_until = sim.now()
	_check(sim.act("extract", patient.id).ok and p.xp == 12 and patient.tagged_until == 2880,
		"The next calendar day permits exactly one new rewarded sample.")
	var feed := Feed.new()
	_check(feed.format_rows([event]).contains("[url=dna:%d]" % event.id), "Player extraction formats a report link.")
	var npc_event: Dictionary = event.duplicate(true)
	npc_event.actor = 1
	npc_event.category = "ALLY"
	_check(not feed.format_rows([npc_event]).contains("[url="), "NPC extraction never creates a player report link.")

func _medical_progression() -> void:
	var sim = _city()
	var scientist: Dictionary = sim.actors[1]
	var patient: Dictionary = sim.actors[2]
	scientist.npc_necro_start = true
	scientist.dormant = false
	scientist.job = "NecroTech Lab Assistant"
	scientist.xp = 74
	# Other fixtures must not turn this into an overwhelming attack.
	sim.actors[3].x = 9
	sim.actors[3].y = 9
	sim.player().x = 0
	sim.player().y = 0
	sim.reindex()
	_check(Progression.target_skill(scientist, sim.level(scientist), "", true) == "lab_experience",
		"A starting technician saves for Lab Experience before Free Running.")
	sim._npc_turn(scientist)
	_check(scientist.last_action == "extract" and scientist.xp == 78,
		"A healthy technician samples a lone zombie for XP before retreating.")
	scientist.busy_until = sim.now()
	sim._npc_turn(scientist)
	_check(sim.has_skill(scientist, "lab_experience") and not sim.has_skill(scientist, "free_running") and scientist.xp == 3,
		"The technician buys the 75-XP revival skill as soon as it becomes affordable.")
	scientist.inside = true
	patient.x = 9
	patient.y = 9
	sim.blocks[44].type = "necrotech_lab"
	sim.reindex()
	scientist.busy_until = sim.now()
	sim._npc_turn(scientist)
	_check(scientist.last_action == "search", "A trained technician without syringes prioritizes searching the lab.")
	patient.x = 4
	patient.y = 4
	patient.inside = true
	patient.human_skills = ["first_aid"]
	patient.tagged_until = 0
	patient.tagged_skills.clear()
	patient.wants_revive = false # Its actual hidden preference is not evidence.
	sim.give_item(scientist, "syringe")
	scientist.busy_until = sim.now()
	sim.reindex()
	sim._npc_turn(scientist)
	_check(scientist.last_action == "extract" and sim.dna_human_training(patient),
		"Revival candidates are identified by sampled human skills first.")
	scientist.busy_until = sim.now()
	sim._npc_turn(scientist)
	_check(scientist.last_action == "revive" and patient.human and sim.metrics.revivals == 1,
		"A scanned human-trained zombie is revived even without a hidden revival flag.")
	var undead: Dictionary = sim.actors[3]
	undead.wants_revive = true
	undead.tagged_until = 1440
	undead.tagged_skills = ["vigour_mortis"]
	sim.give_item(scientist, "syringe")
	sim.npc_planner._clear_choice()
	sim.npc_planner._medical_choices(sim, scientist, sim.blocks[44], [undead], {"enemies":0})
	_check(sim.npc_planner._command != "revive", "A hidden revival flag cannot replace evidence of human training.")

func _healing() -> void:
	var sim = _city()
	var helper: Dictionary = sim.actors[1]
	helper.job = "Consumer"
	helper.human_skills.clear()
	sim.give_item(helper, "first_aid_kit")
	var other: Dictionary = sim.player()
	other.hp = 40
	sim.npc_planner._clear_choice()
	sim.npc_planner._medical_choices(sim, helper, sim.blocks[44], [helper, other], {"enemies":0})
	_check(sim.npc_planner._command == "heal" and sim.npc_planner._target == other.id and sim.npc_planner._score >= 0.81,
		"Non-combat NPCs value useful first aid for another person.")
	_check(sim._try(helper, "heal", other.id) and helper.xp == 5, "Healing another person grants five XP.")
	helper.hp = 40
	helper.busy_until = sim.now()
	sim.give_item(helper, "first_aid_kit")
	_check(sim._try(helper, "heal", helper.id) and helper.xp == 5, "Self-healing does not farm XP.")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
