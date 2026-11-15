extends RefCounted
## The owner updates changed cells before any managed query reads the mirror.

const STRIDE: int = 13
var enabled: bool = true
var planner_enabled: bool = true
# -1 measures both backends, 0 uses GDScript, 1 forces C# scoring.
var planner_mode: int = -1
var planner_tuning: Dictionary[int, Dictionary] = {}
var active: bool = false
var planning_active: bool = false
var planner_batches: int
var planner_prepared: int
var planner_reused: int
var planner_replanned: int
var planner_peak_workers: int
var planner_on_demand: int
var actor_mirror_enabled: bool = false
var _kernel: RefCounted
var _load_attempted: bool = false
var _initialized: bool = false
var _dirty: Dictionary[int, bool] = {}
var _fort_ids: Dictionary[String, int] = {"": 0}
var _actor_meta: Dictionary[int, Dictionary] = {}
var _actor_rows := PackedInt32Array()
var _planner_dirty: Dictionary[int, bool] = {}
var _planner_sites: Dictionary[int, bool] = {}
var _planner_coarse: Dictionary[int, bool] = {}
var _plans := PackedFloat64Array()
var _plan_offsets: Dictionary[int, int] = {}
var _changed: Dictionary[int, bool] = {}
var _revision: int
var _kernel_width: int
var _current_id: int = -1
var _current_revision: int = -1
var _current_values := PackedFloat64Array()
var _current_offset: int
var _on_turn: bool
var _tick_started: int
var _backend_sample: Dictionary = {}
var _backend_choice: int
const WEAPON_KINDS = {"pistol": 1, "shotgun": 2, "knife": 3, "fire_axe": 4, "flare_gun": 5, "newspaper": 6}
const WEAPON_SKILLS = {"firearms": 1, "pistol_training": 2, "advanced_pistol": 4, "shotgun_training": 8,
	"advanced_shotgun": 16, "hand_to_hand": 32, "knife_combat": 64, "axe_proficiency": 128}
const THREAT_SKILLS = ["infectious_bite", "tangling_grasp", "death_grip", "rend_flesh", "bellow", "feeding_groan"]


func is_ready() -> bool:
	return _initialized


func reset() -> void:
	active = false
	planning_active = false
	_initialized = false
	_dirty.clear()
	_fort_ids = {"": 0}
	_actor_meta.clear()
	_planner_dirty.clear()
	_planner_sites.clear()
	_planner_coarse.clear()
	_plan_offsets.clear()
	_changed.clear()
	_current_id = -1
	planner_batches = 0
	planner_prepared = 0
	planner_reused = 0
	planner_replanned = 0
	planner_peak_workers = 0
	planner_on_demand = 0
	planner_tuning.clear()
	_backend_sample = {}


func begin(sim, due: Array = []) -> void:
	active = false
	planning_active = false
	_backend_sample = {}
	if not enabled or not sim.resting or not ClassDB.class_exists("CSharpScript"): return
	_on_turn = sim.npc_plan_on_turn
	actor_mirror_enabled = planner_enabled and (not _on_turn or planner_mode == 1)
	_tick_started = Time.get_ticks_usec()
	if _kernel == null:
		if _load_attempted: return
		_load_attempted = true
		var script: Script = load("res://scripts/NpcQueryKernel.cs")
		if script == null or not script.can_instantiate(): return
		_kernel = script.new()
	if not _initialized:
		var rows := PackedInt32Array()
		rows.resize(sim.blocks.size() * STRIDE)
		for site: Dictionary in sim.blocks: _write_cell(sim, site, rows, int(site.id) * STRIDE)
		_kernel.call("Initialize", sim.width, sim.height, rows)
		_kernel_width = sim.width
		if actor_mirror_enabled:
			_kernel.call("InitializePlanner", sim.actors.size())
			for a: Dictionary in sim.actors: _planner_dirty[a.id] = true
			for site: Dictionary in sim.blocks: _planner_sites[site.id] = true
		_dirty.clear()
		_initialized = true
	else:
		flush(sim)
	active = true
	planning_active = actor_mirror_enabled and (_choose_backend(due.size()) if not _on_turn else true)
	_changed.clear()
	_current_id = -1
	_plan_offsets.clear()
	if _on_turn: return
	if not planning_active: return
	var ids := PackedInt32Array()
	var unique: Dictionary[int, bool] = {}
	for id: int in due:
		var actor: Dictionary = sim.actors[id]
		if not actor.human or actor.down or actor.dormant or actor.prefers_undead or actor.busy_until > sim.now() or sim._npc_due(actor) != sim.clock_step: continue
		if unique.has(id): continue
		unique[id] = true
		ids.append(id)
	if ids.is_empty(): return
	var sites: Dictionary[int, bool] = {}
	for id: int in ids: sites[sim.actors[id].y * sim.width + sim.actors[id].x] = true
	_flush_planner(sim, sites)
	_plans = _kernel.call("PlanHumans", ids, sim.minute, sim.planning_batch.thread_limit)
	planner_peak_workers = maxi(planner_peak_workers, int(_plans[0]))
	planner_batches += 1
	planner_prepared += ids.size()
	var offset: int = 1
	while offset < _plans.size():
		_plan_offsets[int(_plans[offset + 1])] = offset
		offset += int(_plans[offset])


func _choose_backend(count: int) -> bool:
	if planner_mode >= 0: return planner_mode == 1
	if count < 12: return false
	var bucket: int = 16
	while bucket < count: bucket *= 2
	if not planner_tuning.has(bucket):
		planner_tuning[bucket] = {"samples": [[], []], "round": 0, "best": -1}
	var state: Dictionary = planner_tuning[bucket]
	if state.best >= 0: return state.best == 1
	_backend_sample = state
	_backend_choice = state.round % 2
	return _backend_choice == 1


func finish_tick(decisions: int) -> void:
	if _backend_sample.is_empty(): return
	var samples: Array = _backend_sample.samples[_backend_choice]
	samples.append(float(Time.get_ticks_usec() - _tick_started) / maxi(1, decisions))
	_backend_sample.round += 1
	if _backend_sample.round >= 10:
		var gdscript: Array = _backend_sample.samples[0]
		var managed: Array = _backend_sample.samples[1]
		gdscript.sort()
		managed.sort()
		_backend_sample.best = int(managed[2] < gdscript[2] * 0.97)
	_backend_sample = {}


func dirty(site: Dictionary, actor_id: int = -1) -> void:
	if _initialized:
		_dirty[site.id] = true
		if actor_mirror_enabled:
			_planner_sites[site.id] = true
			if actor_id >= 0: _planner_dirty[actor_id] = true
			else: _planner_coarse[site.id] = true
		_changed[site.id] = true
		_revision += 1


func flush(sim) -> void:
	if _dirty.is_empty(): return
	var rows := PackedInt32Array()
	rows.resize(_dirty.size() * STRIDE)
	var offset: int = 0
	for id: int in _dirty:
		_write_cell(sim, sim.blocks[id], rows, offset)
		offset += STRIDE
	_kernel.call("UpdateCells", rows)
	_dirty.clear()


func dirty_actor(a: Dictionary) -> void:
	if not _initialized or not actor_mirror_enabled: return
	_planner_dirty[a.id] = true
	_changed[a.y * _kernel_width + a.x] = true
	_revision += 1


func _flush_planner(sim, sites: Dictionary[int, bool]) -> void:
	# Only the origin's occupants participate in the typed human planner.
	# Leave distant changed actors pending until a plan actually needs them.
	_actor_rows.clear()
	var rows := PackedInt32Array()
	for id: int in sites:
		var ids: Array = sim.spatial.get(id, [])
		var coarse: bool = _planner_coarse.has(id)
		for actor_id: int in ids:
			if coarse or _planner_dirty.has(actor_id):
				_write_actor(sim, sim.actors[actor_id])
				_planner_dirty.erase(actor_id)
		_planner_coarse.erase(id)
		if _planner_sites.has(id):
			rows.append_array(PackedInt32Array([id, sim.barricade_strength(sim.blocks[id]), ids.size()]))
			for actor_id: int in ids: rows.append(actor_id)
			_planner_sites.erase(id)
	if not _actor_rows.is_empty(): _kernel.call("UpdatePlannerActors", _actor_rows)
	if not rows.is_empty(): _kernel.call("UpdatePlannerSites", rows)


func query(sim, method: StringName, args: Array) -> Variant:
	flush(sim)
	if sim.npc_local_awareness and method == &"RetreatTarget": method = &"LocalRetreatTarget"
	return _kernel.callv(method, args)


func _write_cell(sim, site: Dictionary, rows: PackedInt32Array, offset: int) -> void:
	var flags: int = int(sim.is_building(site))
	if site.type == "necrotech_lab": flags |= 2
	if sim.can_host_generator(site) and site.generator and site.generator_hp > 0: flags |= 4
	if sim.doors_closed(site): flags |= 8
	if site.revive_point: flags |= 16
	if planner_enabled and sim.is_dark_building(site): flags |= 32
	if not _fort_ids.has(site.fort): _fort_ids[site.fort] = _fort_ids.size()
	var humans_inside: int = 0
	var zombies_inside: int = 0
	var hostiles_outside: int = 0
	var first_human: int = -1
	var first_inside: int = -1
	var first_outside: int = -1
	var staffed: bool = false
	var ids: Array = sim.spatial.get(site.id, [])
	for id: int in ids:
		var actor: Dictionary = sim.actors[id]
		if actor.down: continue
		if actor.human:
			if first_human < 0: first_human = id
			if actor.inside:
				humans_inside += 1
				if first_inside < 0: first_inside = id
			elif first_outside < 0:
				first_outside = id
			if not staffed and sim.has_skill(actor, "lab_experience"):
				staffed = site.type == "necrotech_lab" or (actor.home == site.id and not sim.item_kind(actor, "syringe").is_empty())
		elif actor.inside:
			zombies_inside += 1
		elif not actor.wants_revive:
			hostiles_outside += 1
	rows[offset] = site.id
	rows[offset + 1] = flags
	rows[offset + 2] = site.barricade
	rows[offset + 3] = site.ruin
	rows[offset + 4] = _fort_ids[site.fort]
	rows[offset + 5] = ceili(float(site.fuel_until))
	rows[offset + 6] = humans_inside
	rows[offset + 7] = zombies_inside
	rows[offset + 8] = hostiles_outside
	rows[offset + 9] = first_human
	rows[offset + 10] = first_inside
	rows[offset + 11] = first_outside
	rows[offset + 12] = int(staffed)


func invalidate_actor(id: int) -> void:
	_actor_meta.erase(id)


func _write_actor(sim, a: Dictionary) -> void:
	var meta: Dictionary = _actor_meta.get(a.id, {})
	if meta.is_empty() or meta.human != a.human or meta.equipped != a.equipped or meta.items != a.inventory.size():
		meta = _actor_metadata(sim, a)
		_actor_meta[a.id] = meta
	var flags: int = meta.flags | (int(a.inside) << 1) | (int(a.down) << 2) | (int(a.wants_revive) << 3)
	if a.infected: flags |= 64
	if a.prefers_undead: flags |= 128
	if a.get("fuel_soaked", false): flags |= 32768
	if a.job in ["Scientist", "NecroTech Lab Assistant"] or (a.human and ((flags & 512) != 0 or sim.blocks[a.home].type == "necrotech_lab")): flags |= 65536
	var weapon_flags: int = meta.weapon_flags
	if meta.firearm and meta.weapon.get("ammo", 0) == 0: weapon_flags |= 8
	var tagged: int = 0
	if a.tagged_until > sim.minute:
		for skill: String in a.tagged_skills:
			if skill in THREAT_SKILLS: tagged += 1
	var offset: int = _actor_rows.size()
	_actor_rows.resize(offset + 14)
	_actor_rows[offset] = a.id
	_actor_rows[offset + 1] = a.y * sim.width + a.x
	_actor_rows[offset + 2] = flags
	_actor_rows[offset + 3] = a.hp
	_actor_rows[offset + 4] = meta.max_hp
	_actor_rows[offset + 5] = a.ap
	_actor_rows[offset + 6] = tagged
	_actor_rows[offset + 7] = a.tagged_until
	_actor_rows[offset + 8] = meta.hit
	_actor_rows[offset + 9] = meta.damage
	_actor_rows[offset + 10] = weapon_flags
	_actor_rows[offset + 11] = meta.skills
	_actor_rows[offset + 12] = meta.kind
	_actor_rows[offset + 13] = a.grasped_by


func _actor_metadata(sim, a: Dictionary) -> Dictionary:
	var skills: Array = a.human_skills if a.human else a.zombie_skills
	var flags: int = int(a.human)
	if "construction" in skills: flags |= 16
	if "scent_blood" in skills: flags |= 32
	if "diagnosis" in skills: flags |= 256
	if "lab_experience" in skills: flags |= 512
	if a.job in ["Doctor", "Medic"]: flags |= 8192
	if sim.has_skill(a, "flesh_rot"): flags |= 16384
	var weapon: Dictionary = {}
	for item: Dictionary in a.inventory:
		match item.kind:
			"first_aid_kit": flags |= 1024
			"syringe": flags |= 2048
			"dna_extractor": flags |= 4096
			"flak_jacket": flags |= 16384
		if item.uid == a.equipped: weapon = item
	var hit: float = 10.0
	var damage: int = 1
	var weapon_flags: int = 0
	var kind: int = 0
	var firearm: bool = false
	if not weapon.is_empty():
		var def: Dictionary = sim.C.ITEMS[weapon.kind]
		hit = def.get("hit", 10.0)
		damage = def.get("damage", 1)
		kind = WEAPON_KINDS.get(weapon.kind, 7)
		firearm = def.has("capacity")
		if firearm or def.get("ranged", false): weapon_flags |= 1
	var skill_mask: int = 0
	for skill: String in skills: skill_mask |= WEAPON_SKILLS.get(skill, 0)
	return {"human": a.human, "equipped": a.equipped, "items": a.inventory.size(), "flags": flags,
		"max_hp": sim.max_hp(a), "hit": roundi(hit * 2.0), "damage": damage, "weapon_flags": weapon_flags,
		"skills": skill_mask, "kind": kind, "firearm": firearm, "weapon": weapon}


func _ensure_plan(sim, id: int) -> void:
	if _current_id == id and _current_revision == _revision: return
	var a: Dictionary = sim.actors[id]
	var valid: bool = _plan_offsets.has(id)
	if valid:
		for y in range(maxi(0, a.y - 1), mini(sim.height, a.y + 2)):
			for x in range(maxi(0, a.x - 1), mini(sim.width, a.x + 2)):
				if _changed.has(y * sim.width + x): valid = false
	if valid:
		_current_values = _plans
		_current_offset = _plan_offsets[id]
		planner_reused += 1
	else:
		flush(sim)
		var site: int = a.y * sim.width + a.x
		var sites: Dictionary[int, bool] = {site: true}
		_flush_planner(sim, sites)
		_current_values = _kernel.call("PlanHuman", id, sim.minute)
		planner_peak_workers = maxi(planner_peak_workers, 1)
		_current_offset = 1
		if _on_turn: planner_on_demand += 1
		else: planner_replanned += 1
	_current_id = id
	_current_revision = _revision


func human_context(sim, a: Dictionary) -> Dictionary:
	_ensure_plan(sim, a.id)
	var row: int = _current_offset
	var opponent: int = int(_current_values[row + 2])
	return {"enemies": int(_current_values[row + 3]), "allies": int(_current_values[row + 4]),
		"opponent": sim.actors[opponent] if opponent >= 0 else {}, "outside": int(_current_values[row + 5]),
		"wall": int(_current_values[row + 6]), "breach": _current_values[row + 7],
		"danger": _current_values[row + 8], "flee": _current_values[row + 9],
		"attack_efficiency": _current_values[row + 10], "emergency": _current_values[row + 11] != 0}


func primary_candidates(sim, a: Dictionary) -> Array:
	_ensure_plan(sim, a.id)
	return [_current_values, _current_offset]
