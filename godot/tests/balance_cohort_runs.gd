extends SceneTree
## Full-city balance measurements. Instrumentation never chooses NPC actions.

const Sim = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_builder.gd")
const DAYS_STEPS: int = 14_400

class Trial extends Sim:
	var records: Array[Dictionary] = []
	var action_counts: Array[Dictionary] = [{}, {}]
	var xp_sources: Array[Dictionary] = [{}, {}]
	var learned_skills: Dictionary = {}
	var start_minute: int
	var executor: int = -1
	var executing_command: String = ""

	func start_tracking() -> void:
		start_minute = minute
		records.clear()
		for a: Dictionary in actors:
			records.append({"id": a.id, "cohort": "human" if a.human else "zombie",
				"initial_xp": a.xp, "initial_skills": a.human_skills.size() + a.zombie_skills.size(),
				"earned_xp": 0, "spent_xp": 0, "peak_unspent_xp": a.xp, "purchases": 0,
				"human_skill_purchases": 0, "zombie_skill_purchases": 0, "actions": 0,
				"deaths": 0, "combat_deaths": 0, "suicides": 0, "infection_deaths": 0,
				"revives_received": 0, "revives_performed": 0, "kills": 0, "first_death_minute": -1})

	func execute(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> void:
		if records.is_empty():
			super.execute(a, command, target_id, data)
			return
		var before_xp: int = a.xp
		var before_revives: int = metrics.revivals
		var side: int = 0 if a.human else 1
		executor = a.id
		executing_command = command
		super.execute(a, command, target_id, data)
		executor = -1
		executing_command = ""
		if a.id <= 0: return
		var record: Dictionary = records[a.id]
		record.actions += 1
		action_counts[side][command] = int(action_counts[side].get(command, 0)) + 1
		var earned: int = int(a.xp) - before_xp
		assert(earned >= 0, "XP spending must be measured through learn(), not execute().")
		record.earned_xp += earned
		record.peak_unspent_xp = maxi(record.peak_unspent_xp, a.xp)
		if earned > 0: xp_sources[side][command] = int(xp_sources[side].get(command, 0)) + earned
		if metrics.revivals > before_revives:
			record.revives_performed += 1
			if target_id > 0: records[target_id].revives_received += 1

	func learn(skill: String, actor_id: int = 0) -> String:
		var before: int = actors[actor_id].xp
		var result: String = super.learn(skill, actor_id)
		if result.is_empty() and actor_id > 0 and not records.is_empty():
			var record: Dictionary = records[actor_id]
			record.spent_xp += before - int(actors[actor_id].xp)
			record.purchases += 1
			var key: String = "human_skill_purchases" if C.SKILLS[skill].side == "human" else "zombie_skill_purchases"
			record[key] += 1
			learned_skills[skill] = int(learned_skills.get(skill, 0)) + 1
		return result

	func die(a: Dictionary, penalty: int = 0) -> void:
		if a.id > 0 and not records.is_empty():
			var record: Dictionary = records[a.id]
			record.deaths += 1
			if record.first_death_minute < 0: record.first_death_minute = minute - start_minute
			if executor == a.id and executing_command == "jump": record.suicides += 1
			elif executor == a.id and a.infected: record.infection_deaths += 1
			elif executor > 0 and executor != a.id and executing_command in ["attack", "bite"]:
				record.combat_deaths += 1
				records[executor].kills += 1
		super.die(a, penalty)

	func audit() -> PackedStringArray:
		var errors := PackedStringArray()
		var deaths: int = records[0].deaths
		var revives: int = 0
		var actions: int = 0
		for a: Dictionary in actors:
			if a.id == 0: continue
			var r: Dictionary = records[a.id]
			if r.initial_xp + r.earned_xp - r.spent_xp != a.xp: errors.append("XP ledger mismatch: %d" % a.id)
			if r.initial_skills + r.purchases != a.human_skills.size() + a.zombie_skills.size(): errors.append("Skill ledger mismatch: %d" % a.id)
			if r.purchases != a.npc_purchases: errors.append("Purchase counter mismatch: %d" % a.id)
			deaths += r.deaths
			revives += r.revives_performed
			actions += r.actions + r.purchases
		if deaths != metrics.deaths: errors.append("Death ledger mismatch")
		if revives != metrics.revivals: errors.append("Revival ledger mismatch")
		if actions != metrics.npc_actions: errors.append("Action ledger mismatch")
		return errors


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seed_value: int = 23
	var days: int = 10
	var humans: int = 2000
	var zombies: int = 2000
	var mode: String = "malton"
	var opening: String = "natural"
	var output: String = "res://reports/balance-2026-11-14"
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--seed": seed_value = int(value)
			"--days": days = int(value)
			"--humans": humans = int(value)
			"--zombies": zombies = int(value)
			"--mode": mode = value
			"--opening": opening = value
			"--output": output = value
			_:
				push_error("Unknown argument: " + arg)
				quit(2)
				return
	if days < 1 or humans < 1 or zombies < 1 or mode not in ["malton", "random"] or opening not in ["natural", "awake"]:
		push_error("Expected positive --days/--humans/--zombies, --mode=malton|random, --opening=natural|awake.")
		quit(2)
		return
	var sim := Trial.new()
	var config: Dictionary = World.defaults(100, 100)
	config.mode = mode
	config.survivors = humans
	config.zombies = zombies
	var error: String = sim.start(seed_value, "Private", config)
	if not error.is_empty():
		push_error(error)
		quit(2)
		return
	var p: Dictionary = sim.player()
	p.down = true
	p.dormant = true
	p.inside = false
	p.x = 0
	p.y = 0
	if opening == "awake":
		for a: Dictionary in sim.actors:
			if a.id > 0 and not a.human:
				a.down = false
				a.dormant = false
				a.hp = sim.max_hp(a)
				# Match the performance fixture's staggered opening turns.
				a.next_think = float(sim.clock_step + 10 + a.id % 70) / 10.0
	sim.reindex()
	# Exclude the inactive player from NPC targets as well as population totals.
	var player_cell: Array = sim.spatial.get(0, [])
	player_cell.erase(0)
	if player_cell.is_empty(): sim.spatial.erase(0)
	sim._reset_npc_runtime()
	sim.start_tracking()
	# Exercise the same optional spatial kernel as accelerated recovery. No UI,
	# AP grants, time skipping, shelters or special medical supplies are added.
	sim.resting = true
	sim.sleeping = true
	sim.rest_target = 51
	sim.rest_end_step = sim.clock_step + (days + 1) * DAYS_STEPS
	var report: Dictionary = {"schema": 1, "mode": mode, "seed": seed_value, "opening": opening,
		"requested_days": days, "population": humans + zombies, "width": sim.width, "height": sim.height,
		"engine": Engine.get_version_info().string, "managed_available": ClassDB.class_exists("CSharpScript"),
		"features": {"full_ap_recovery": sim.npc_full_recovery, "local_awareness": sim.npc_local_awareness,
			"plan_on_turn": sim.npc_plan_on_turn, "skip_unobservable_narration": sim.skip_unobserved_narration},
		"source_files": _source_hashes(), "initial": _snapshot(sim), "days": [], "complete": false}
	var directory: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(directory)
	var stem: String = directory.path_join("%s-%s-%d" % [mode, opening, seed_value])
	var started: int = Time.get_ticks_usec()
	for day: int in range(1, days + 1):
		for quarter: int in range(4):
			sim.advance_steps(DAYS_STEPS / 4)
			print("PROGRESS %s %s seed=%d day=%.2f elapsed=%.1fs actions=%d" % [mode, opening, seed_value,
				day - 1 + (quarter + 1) / 4.0, (Time.get_ticks_usec() - started) / 1_000_000.0, sim.metrics.npc_actions])
		var audit: PackedStringArray = sim.audit()
		if not audit.is_empty():
			push_error("; ".join(audit))
			report.audit_errors = audit
			_write_report(stem, report)
			quit(1)
			return
		var sample: Dictionary = _snapshot(sim)
		report.days.append(sample)
		report.elapsed_seconds = (Time.get_ticks_usec() - started) / 1_000_000.0
		_write_report(stem, report)
		print("BALANCE %s %s seed=%d day=%d humans=%d standing_zombies=%d hostile_zombies=%d dormant=%d deaths=%d revives=%d purchases=%d" % [
			mode, opening, seed_value, day, sample.human_form, sample.standing_zombies, sample.hostile_zombies,
			sample.dormant, sample.deaths, sample.revivals, sample.cohorts.human.purchases + sample.cohorts.zombie.purchases])
	_write_actors(stem, sim)
	report.complete = true
	report.audit_errors = []
	report.action_counts = {"human_form": sim.action_counts[0], "zombie_form": sim.action_counts[1]}
	report.xp_sources = {"human_form": sim.xp_sources[0], "zombie_form": sim.xp_sources[1]}
	report.learned_skills = sim.learned_skills
	report.final_rng_state = str(sim.rng.state)
	report.routes = {"requests": sim.route_cache.requests, "searches": sim.route_cache.searches, "hits": sim.route_cache.hits}
	_write_report(stem, report)
	print("BALANCE COMPLETE: ", stem, ".json elapsed=", report.elapsed_seconds)
	quit()


func _snapshot(sim: Trial) -> Dictionary:
	var result: Dictionary = {"day": float(sim.minute - sim.start_minute) / 1440.0,
		"human_form": 0, "standing_humans": 0, "zombie_form": 0, "standing_zombies": 0,
		"hostile_zombies": 0, "awaiting_revival": 0, "dormant": 0, "down": 0, "recovering": 0,
		"deaths": sim.metrics.deaths, "revivals": sim.metrics.revivals, "npc_actions": sim.metrics.npc_actions,
		"cohorts": {"human": {}, "zombie": {}}}
	for cohort: String in ["human", "zombie"]:
		var group: Dictionary = {"count": 0, "ever_active": 0, "human_form": 0, "standing_humans": 0,
			"standing_zombies": 0, "never_died": 0, "earned_xp": 0, "unspent_xp": 0, "spent_xp": 0,
			"purchases": 0, "owned_skills": 0, "initial_skills": 0, "deaths": 0, "combat_deaths": 0,
			"suicides": 0, "infection_deaths": 0, "revives_received": 0, "revives_performed": 0,
			"kills": 0, "zero_xp": 0, "purchasers": 0, "ever_revived": 0, "hp": 0,
			"max_earned_xp": 0, "max_unspent_xp": 0, "max_peak_unspent_xp": 0,
			"max_purchases": 0, "max_owned_skills": 0, "max_deaths": 0, "max_combat_deaths": 0,
			"max_revives_received": 0, "max_revives_performed": 0}
		for a: Dictionary in sim.actors:
			if a.id == 0: continue
			var r: Dictionary = sim.records[a.id]
			if r.cohort != cohort: continue
			group.count += 1
			group.ever_active += int(not a.dormant)
			group.human_form += int(a.human)
			group.standing_humans += int(a.human and not a.down)
			group.standing_zombies += int(not a.human and not a.down)
			group.never_died += int(r.deaths == 0)
			group.unspent_xp += int(a.xp)
			group.initial_skills += r.initial_skills
			group.owned_skills += a.human_skills.size() + a.zombie_skills.size()
			group.zero_xp += int(r.earned_xp == 0)
			group.purchasers += int(r.purchases > 0)
			group.ever_revived += int(r.revives_received > 0)
			group.hp += int(a.hp) if a.human and not a.down else 0
			for key: String in ["earned_xp", "spent_xp", "purchases", "deaths", "combat_deaths", "suicides", "infection_deaths", "revives_received", "revives_performed", "kills"]:
				group[key] += r[key]
			var values: Dictionary = {"earned_xp": r.earned_xp, "unspent_xp": a.xp,
				"peak_unspent_xp": r.peak_unspent_xp, "purchases": r.purchases,
				"owned_skills": a.human_skills.size() + a.zombie_skills.size(), "deaths": r.deaths,
				"combat_deaths": r.combat_deaths, "revives_received": r.revives_received, "revives_performed": r.revives_performed}
			for key: String in values:
				group["max_" + key] = maxi(group["max_" + key], values[key])
		result.cohorts[cohort] = group
	for a: Dictionary in sim.actors:
		if a.id == 0: continue
		result.human_form += int(a.human)
		result.zombie_form += int(not a.human)
		result.standing_humans += int(a.human and not a.down)
		result.standing_zombies += int(not a.human and not a.down)
		result.hostile_zombies += int(not a.human and not a.down and not a.wants_revive)
		result.awaiting_revival += int(a.wants_revive)
		result.dormant += int(a.dormant)
		result.down += int(a.down)
		result.recovering += int(not str(a.get("recovery_mode", "")).is_empty() and a.ap < 50)
	var world: Dictionary = sim.population()
	result.powered = world.powered
	result.ruined = world.ruined
	return result


func _write_report(stem: String, report: Dictionary) -> void:
	var file := FileAccess.open(stem + ".json", FileAccess.WRITE)
	assert(file != null, "Cannot write balance report")
	file.store_string(JSON.stringify(report, "\t"))


func _write_actors(stem: String, sim: Trial) -> void:
	var file := FileAccess.open(stem + "-npcs.csv", FileAccess.WRITE)
	assert(file != null, "Cannot write actor statistics")
	var columns := PackedStringArray(["id", "name", "job", "cohort", "current_form", "down", "dormant", "hp", "ap", "unspent_xp",
		"initial_xp", "earned_xp", "spent_xp", "peak_unspent_xp", "initial_skills", "owned_skills", "purchases",
		"human_skill_purchases", "zombie_skill_purchases", "deaths", "combat_deaths", "suicides", "infection_deaths",
		"revives_received", "revives_performed", "kills", "first_death_minute", "actions", "human_skills", "zombie_skills"])
	file.store_csv_line(columns)
	for a: Dictionary in sim.actors:
		if a.id == 0: continue
		var row: Dictionary = sim.records[a.id].duplicate()
		row.merge({"name": sim.display_name(a), "job": a.job, "current_form": "human" if a.human else "zombie",
			"down": int(a.down), "dormant": int(a.dormant), "hp": a.hp, "ap": a.ap, "unspent_xp": a.xp,
			"owned_skills": a.human_skills.size() + a.zombie_skills.size(),
			"human_skills": ";".join(a.human_skills), "zombie_skills": ";".join(a.zombie_skills)})
		var values := PackedStringArray()
		for key: String in columns: values.append(str(row[key]))
		file.store_csv_line(values)


func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["simulation.gd", "catalog.gd", "npc_ai.gd", "extended_rules.gd", "world_builder.gd",
		"npc_utility/planner.gd", "npc_utility/supplies.gd", "npc_utility/progression.gd", "npc_utility/location_memory.gd",
		"npc_utility/managed_queries.gd", "npc_utility/planning_batch.gd", "npc_utility/route_cache.gd", "NpcQueryKernel.cs", "NpcPlannerScoring.cs"]:
		result[path] = FileAccess.get_file_as_string("res://scripts/" + path).sha256_text()
	result["balance_cohort_runs.gd"] = FileAccess.get_file_as_string("res://tests/balance_cohort_runs.gd").sha256_text()
	return result
