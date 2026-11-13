extends RefCounted

const AI = preload("res://scripts/npc_ai.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Desire = preload("res://scripts/npc_utility/desire.gd")
const Progression = preload("res://scripts/npc_utility/progression.gd")
const Supplies = preload("res://scripts/npc_utility/supplies.gd")
const Gate = preload("res://scripts/npc_utility/action_gate.gd")
const MARKERS = ["cemetery", "church", "cathedral"]
const SHARE = ["first_aid_kit", "toolbox", "pistol_clip", "shotgun_shell", "fuel_can"]

var supplies = Supplies.new()
var memory:
	get: return supplies.memory

var _score: float
var _command: String
var _target: int
var _data: Dictionary
var _focus: Dictionary[int, int] = {}


func reset(width: int, height: int, count: int) -> void:
	supplies.reset(width, height, count)


func _clear_choice() -> void:
	_score = 0.0
	_command = ""
	_target = -1
	_data = {}


func _offer(s, a: Dictionary, value: float, command: String, target: int = -1, data: Dictionary = {}) -> void:
	if value <= _score or a.ap < s.cost(a, command, target, data):
		return
	if not s.reason(a, command, target, data).is_empty():
		return
	_score = value
	_command = command
	_target = target
	_data = data


func turn(s, a: Dictionary) -> int:
	if a.dormant or a.busy_until > s.now():
		return 0
	if a.down:
		s._try(a, "stand")
		return 0
	s._maybe_speak(a)
	var skill: String = ""
	if a.xp >= 75:
		skill = Progression.target_skill(a, s.level(a), Supplies.weapon_track(s, a) if a.human else "", _clinician(s, a))
		if not skill.is_empty() and not s.skill_reason(a, skill).is_empty(): skill = ""
	var here: Dictionary = s.current_block(a)
	if a.ap == 0 and skill.is_empty():
		var discounted: bool = a.human and a.inside and a.scout_site == here.id and (a.scout_day != s.minute / 1440 or a.scout_used < 5)
		if not discounted:
			return 1
	var present: Array = s.occupants(here, a.inside)
	_clear_choice()
	if a.human:
		return _human(s, a, here, present, skill)
	if a.wants_revive:
		if _purchase(s, a, skill): return 0
		return _seek_revival(s, a, here)
	return _zombie(s, a, here, present, skill)


func _purchase(s, a: Dictionary, skill: String) -> bool:
	if skill.is_empty() or not Gate.can_act(a.ap, 0, s.clock_step, ceili(a.busy_until * Catalog.CLOCK_STEPS_PER_MINUTE - 0.00001)):
		return false
	if not s.learn(skill, a.id).is_empty():
		return false
	a.last_action = "learn"
	a.busy_until = float(Gate.ready_after_action(s.clock_step)) / Catalog.CLOCK_STEPS_PER_MINUTE
	a.npc_purchases += 1
	s.metrics.npc_actions += 1
	return true


func train_before_standing(s, a: Dictionary) -> bool:
	if a.human or not a.wants_revive or a.xp < 100:
		return false
	return _purchase(s, a, Progression.target_skill(a, s.level(a), "", false))


static func _clinician(s, a: Dictionary) -> bool:
	return a.job in ["Scientist", "NecroTech Lab Assistant"] or (a.human and (s.has_skill(a, "lab_experience") or s.blocks[a.home].type == "necrotech_lab"))


func _human(s, a: Dictionary, here: Dictionary, present: Array, skill: String) -> int:
	if a.prefers_undead and AI.return_to_undeath(s, a):
		return 0
	var enemies: int = 0
	var allies: int = 0
	var builders: int = 0
	var opponent: Dictionary = {}
	for other in present:
		if other.down: continue
		if other.human:
			allies += 1
			if other.ap > 0 and s.has_skill(other, "construction"): builders += 1
		elif not other.wants_revive:
			enemies += 1
			if opponent.is_empty() or _tagged_threat(s, other) > _tagged_threat(s, opponent) or (s.has_skill(a, "scent_blood") and other.hp < opponent.hp): opponent = other
	var outside: int = _outside_hostiles(s, here) if a.inside else enemies
	var wall: int = s.barricade_strength(here)
	var breach: float = 0.0
	if a.inside and outside > 0:
		breach = Desire.unit((outside * 1.8 - wall * 0.75 - 1.5 * builders) / 8.0)
	var danger: float = Desire.danger(0.0, enemies, allies, 1.0, breach)
	if not a.inside and enemies == 0:
		for y in range(maxi(0, a.y - 1), mini(s.height, a.y + 2)):
			for x in range(maxi(0, a.x - 1), mini(s.width, a.x + 2)):
				var nearby_enemies: int = _outside_hostiles(s, s.block_at(x, y))
				danger = maxf(danger, Desire.danger(1.0, nearby_enemies, allies, 1.0, 0.0))
	var hp: float = float(a.hp) / s.max_hp(a)
	var flee: float = Desire.flee(danger, hp, a.ap)
	var attack_efficiency: float = 0.0
	if not opponent.is_empty():
		var weapon: Dictionary = s.item_by_uid(a, a.equipped)
		if weapon.is_empty() or not Catalog.ITEMS[weapon.kind].has("capacity") or weapon.ammo > 0:
			attack_efficiency = AI.expected_damage(s, opponent, s.attack_stats(a, opponent, "attack", weapon))
	var exposed: bool = not a.inside and enemies > 0 and enemies >= allies and attack_efficiency < 1.0
	var short_on_ap: bool = a.ap <= 7 and (not a.inside or enemies >= allies or wall < 3)
	var emergency: bool = exposed or enemies >= 2.5 * allies or breach >= 0.85 or (enemies > 0 and (a.hp <= 22 or short_on_ap))
	if emergency and a.ap > 0:
		if a.infected and a.hp <= 5 and s._try(a, "heal", a.id): return 0
		if AI.retreat(s, a, true, breach >= 0.85):
			a.next_trip = s.minute + 60
			return 0
	if not opponent.is_empty():
		var defense: float = 0.49 + 0.5 * Desire.defend(attack_efficiency, 1.0, danger)
		_offer(s, a, defense, "attack", opponent.id)
		_offer(s, a, defense - 0.03, "reload")
		if a.ap >= 15 and a.hp > 30 and opponent.tagged_until <= s.minute:
			_offer(s, a, 0.54 if _clinician(s, a) else 0.43, "extract", opponent.id)
	if not s.item_kind(a, "first_aid_kit").is_empty():
		var diagnosis: bool = s.has_skill(a, "diagnosis")
		for other in present:
			if not other.human or other.down or (other.hp > s.max_hp(other) - 8 and not other.infected): continue
			if other.id != a.id and not diagnosis and other.hp > 40 and not other.infected: continue
			var role_bonus: float = 0.25 if a.job in ["Doctor", "Medic"] and other.id != a.id else 0.0
			var heal: float = Desire.heal(float(other.hp) / s.max_hp(other), 0.95 if other.infected else 0.0)
			_offer(s, a, 0.20 + 0.57 * heal + role_bonus, "heal", other.id)
	if s.has_skill(a, "lab_experience") and not s.item_kind(a, "syringe").is_empty():
		var extractor: bool = not s.item_kind(a, "dna_extractor").is_empty()
		for other in present:
			var triage_site: bool = here.revive_point or (here.type == "necrotech_lab" and a.inside)
			var profile: int = _tagged_threat(s, other)
			var low_risk: bool = not other.prefers_undead and enemies <= 1 and (other.down or (triage_site and (profile == 0 or (profile < 0 and extractor))))
			if not other.human and (other.wants_revive or other.id == 0 or low_risk):
				if extractor and not other.down and other.tagged_until <= s.minute:
					var screening: String = s.reason(a, "extract", other.id)
					if screening.is_empty():
						_offer(s, a, 0.94, "extract", other.id)
						continue
					if screening == s.BRAIN_ROT_EXTRACTION_BLOCKED and not (a.inside and here.type == "necrotech_lab" and s.powered(here) and s.has_skill(a, "necronet")):
						continue
				_offer(s, a, 0.92, "revive", other.id)
	if a.inside:
		_indoor_work(s, a, here, present, outside, allies, breach)
		if enemies == 0 and a.ap >= 10 and _score < 0.55:
			_ready_weapon(s, a)
		if s.has_skill(a, "lab_experience") and (here.type == "necrotech_lab" or here.id == a.home) and enemies == 0:
			if here.type == "necrotech_lab" and outside == 0 and a.ap >= 32:
				var needles: int = 0
				for item in a.inventory:
					if item.kind == "syringe": needles += 1
				if needles < 2: _offer(s, a, 0.57, "search")
			for other in s.occupants(here, false):
				if not other.wants_revive or other.down or s.has_skill(other, "brain_rot"): continue
				if s.item_kind(a, "syringe").is_empty():
					if outside == 0 and a.ap >= 25 and s.item_search_chance(here, "syringe", a) <= 0.075:
						_offer(s, a, 0.78, "manufacture")
					if a.ap >= 5 and here.type == "necrotech_lab": _offer(s, a, 0.76, "search")
				elif outside <= 1 and a.ap >= 4:
					_offer(s, a, 0.89, "leave")
				break
	else:
		if enemies == 0 and here.type == "necrotech_lab" and s.has_skill(a, "lab_experience") and s.item_kind(a, "syringe").is_empty():
			_offer(s, a, 0.68, "enter")
		if here.type in MARKERS and here.graffiti.is_empty() and not s.item_kind(a, "spray_can").is_empty() and s.has_skill(a, "lab_experience"):
			_offer(s, a, 0.56, "tag", -1, {"text": "Revive point"})
		elif here.graffiti.is_empty() and danger < 0.2 and Catalog.TAG_XP.has(here.type) and s.has_skill(a, "tagging"):
			_offer(s, a, 0.36, "tag", -1, {"text": "Keep an escape route clear."})
		if enemies == 0 and a.supply_goal < 0 and a.ap <= 9 and s.occupants(here, true).all(func(t): return t.human or t.down):
			_offer(s, a, 0.79, "enter")
	if not opponent.is_empty() and _score < 0.73 and a.ap >= 1 and AI.equip_best(s, a, opponent):
		return 0
	if flee > _score and a.ap > 0 and AI.retreat(s, a, true):
		a.next_trip = s.minute + 60
		return 0
	if _score < 0.72 and _purchase(s, a, skill):
		return 0
	if _score >= 0.66 and s._try(a, _command, _target, _data):
		return 0
	if a.ap < 1 and _command.is_empty():
		return 1
	supplies.observe(s, a, here, enemies)
	var rest: float = Desire.rest(a.ap, (0.56 + wall / 50.0) if a.inside and enemies == 0 and here.ruin == 0 else 0.0, danger)
	if danger < 0.55 and _score < 0.66:
		# Well-rested armed survivors seek isolated nearby zombies for experience.
		if a.ap >= 30 and a.hp >= 35 and a.supply_goal < 0 and not s.item_by_uid(a, a.equipped).is_empty():
			if a.inside and outside == 1 and wall <= 4 and s._try(a, "leave"): return 0
			if not a.inside and enemies == 0:
				for y in range(maxi(0, a.y - 1), mini(s.height, a.y + 2)):
					for x in range(maxi(0, a.x - 1), mini(s.width, a.x + 2)):
						var hunting_site: Dictionary = s.block_at(x, y)
						if _outside_hostiles(s, hunting_site) == 1 and AI.go(s, a, hunting_site): return 0
		if _respond_to_radio(s, a, here, enemies, outside): return 0
		if _respond_to_call(s, a, here, enemies, outside): return 0
		if a.inside and a.ap >= 20 and a.supply_goal < 0 and here.id == a.home and here.npc_entry >= 0 and s.has_skill(a, "construction"):
			var entry: Dictionary = s.blocks[here.npc_entry]
			if entry.ruin == 0 and s.barricade_strength(entry) < 10 and _outside_hostiles(s, entry) == 0 and s.can_free_run_between(a, here, entry):
				if AI.go(s, a, entry):
					a.supply_goal = a.home
					return 0
		if allies == 1 and a.supply_goal < 0 and a.ap >= 16 and not _clinician(s, a) and (not a.inside or wall < 8):
			if _join_group(s, a, here): return 0
		if _supply_turn(s, a, here, danger, maxf(_score, rest)):
			return 0
		if _service_revive_point(s, a, here):
			return 0
	elif not a.inside and a.supply_goal >= 0 and danger >= 0.55:
		Supplies.abandon(s, a, a.supply_goal)
	if rest >= _score and rest > 0.26:
		return mini(22, int(a.ap) + 3)
	if not _command.is_empty() and s._try(a, _command, _target, _data):
		return 0
	if a.inside:
		return 0 if a.ap >= 50 else mini(50, int(a.ap) + 2)
	if a.ap <= 10 and AI.retreat(s, a, true):
		return 0
	if s.occupants(here, true).all(func(t): return t.human or t.down) and s._try(a, "enter"):
		return 0
	if a.ap >= 2: s._wander(a)
	return 2


static func _tagged_threat(s, other: Dictionary) -> int:
	if other.tagged_until <= s.minute: return -1
	var score: int = 0
	for skill in ["infectious_bite", "tangling_grasp", "death_grip", "rend_flesh", "bellow", "feeding_groan"]:
		if skill in other.tagged_skills: score += 1
	return score


func _respond_to_call(s, a: Dictionary, here: Dictionary, enemies: int, outside: int) -> bool:
	if a.job not in ["Police Officer", "Firefighter"] and Catalog.occupation_category(a.job) != "military": return false
	if enemies > 0 or outside > 0 or a.supply_goal >= 0 or a.ap < 18 or a.hp < 30: return false
	var site_id: int = int(a.get("heard_call_site", -1))
	if int(a.get("heard_call_until", 0)) <= s.minute or site_id < 0 or site_id >= s.blocks.size() or site_id == here.id: return false
	return AI.go(s, a, s.blocks[site_id])


func _respond_to_radio(s, a: Dictionary, here: Dictionary, enemies: int, outside: int) -> bool:
	if enemies > 0 or outside > 0 or a.supply_goal >= 0 or a.ap < 18:
		return false
	var call: Dictionary = s.heard_defense_call(a)
	if call.is_empty() or int(call.site) == here.id:
		return false
	var site: Dictionary = s.blocks[int(call.site)]
	var distance: int = s.scent_distance(a, site)
	if distance > 3:
		return false
	var skilled: bool = s.has_skill(a, "construction") or not s.item_kind(a, "first_aid_kit").is_empty()
	var pressure: int = _outside_hostiles(s, site)
	var garrison: int = s.occupants(site, true).filter(func(t): return t.human and not t.down).size()
	if skilled and site.ruin == 0 and site.barricade > 0 and site.barricade <= 4 and pressure <= garrison + 2:
		if AI.go(s, a, site):
			a.home = site.id
			a.supply_goal = site.id
			return true
	a.avoid_site = site.id
	a.avoid_until = int(call.until)
	return false


func _join_group(s, a: Dictionary, here: Dictionary) -> bool:
	var best: Dictionary = {}
	var best_cost: int = 8
	for y in range(maxi(0, a.y - 5), mini(s.height, a.y + 6)):
		for x in range(maxi(0, a.x - 5), mini(s.width, a.x + 6)):
			var site: Dictionary = s.block_at(x, y)
			if site.id == here.id or site.fort != here.fort or site.ruin > 0 or site.barricade < 2 or site.barricade > 4: continue
			var distance: int = s.scent_distance(a, site)
			if distance >= best_cost or _outside_hostiles(s, site) > 0: continue
			var residents: int = 0
			for other in s.occupants(site, true):
				if other.down: continue
				if not other.human:
					residents = 0
					break
				residents += 1
			if residents < 2 or residents > 5: continue
			best = site
			best_cost = distance
	if best.is_empty() or not AI.go(s, a, best): return false
	a.home = best.id
	a.supply_goal = best.id
	a.supply_kind = ""
	return true


func _ready_weapon(s, a: Dictionary) -> void:
	var best_value: float = 0.0
	var best: Dictionary = {}
	for item in a.inventory:
		var def: Dictionary = Catalog.ITEMS[item.kind]
		if not def.has("damage") or def.get("fragile", false) or def.get("single_use", false): continue
		var stats: Dictionary = s.attack_stats(a, {}, "attack", item)
		var value: float = stats.hit * stats.damage
		if def.has("capacity") and item.ammo == 0:
			if s.item_kind(a, def.ammo_kind).is_empty(): continue
			value *= 0.7
		if value > best_value or (value == best_value and item.uid == a.equipped):
			best = item
			best_value = value
	if best.is_empty(): return
	if best.uid != a.equipped: _offer(s, a, 0.54, "equip", -1, {"uid": best.uid})
	elif Catalog.ITEMS[best.kind].has("capacity") and best.ammo == 0: _offer(s, a, 0.53, "reload")


func _indoor_work(s, a: Dictionary, here: Dictionary, present: Array, outside: int, allies: int, breach: float) -> void:
	var home: bool = a.home == here.id
	if home or here.ruin > 0:
		_offer(s, a, 0.77 if here.ruin > 0 and a.ap > 8 else 0.38, "repair")
	if not home:
		if here.npc_ingress and a.ap >= 6 and s.barricade_strength(here) < 10:
			_offer(s, a, 0.67, "barricade")
		return
	_offer(s, a, 0.68, "repair_generator")
	var can_defend_light: bool = outside < 2 or (breach < 0.35 and s.barricade_strength(here) >= 8 and allies > outside / 2)
	if can_defend_light and not s.powered(here) and (not s.item_kind(a, "portable_generator").is_empty() or not s.item_kind(a, "fuel_can").is_empty()):
		var local_pressure: int = 0
		for y in range(maxi(0, a.y - 2), mini(s.height, a.y + 3)):
			for x in range(maxi(0, a.x - 2), mini(s.width, a.x + 3)):
				local_pressure += _outside_hostiles(s, s.block_at(x, y))
		can_defend_light = local_pressure <= allies + 1 or (allies >= 3 and s.barricade_strength(here) >= 10)
	var dark_repair: bool = here.ruin >= 3 and s.is_dark_building(here) and s.has_skill(a, "construction") and not s.item_kind(a, "toolbox").is_empty()
	if can_defend_light: _offer(s, a, 0.79 if dark_repair else 0.73, "generator")
	if can_defend_light and (not s.powered(here) or here.fuel_until - s.minute < 250):
		_offer(s, a, 0.78 if dark_repair else 0.69, "fuel")
	if s.has_skill(a, "construction") or not s.item_kind(a, "length_of_pipe").is_empty():
		var target: int = _shelter_target(s, a, here, present)
		var strength: int = s.barricade_strength(here)
		var build: float = Desire.barricade(strength, target, s.barricade_build_chance(here), 1.0, breach)
		if strength < target:
			var priority: float = 0.35 * build + (0.53 if strength < 4 else (0.29 if strength < 10 else 0.08))
			if s.powered(here) and strength < 10: priority += 0.14
			if outside > 0 and breach < 0.85: priority += 0.25
			_offer(s, a, priority, "barricade")
	_offer(s, a, 0.36, "close")
	for other in present:
		if not other.human and other.down:
			_offer(s, a, 0.53, "dump", other.id)
			continue
		if other.id == a.id or not other.human or other.down: continue
		for kind in SHARE:
			if not s.supply_needed_by(other, kind) or s.supply_needed_by(a, kind) or not s.item_kind(other, kind).is_empty(): continue
			var item: Dictionary = s.item_kind(a, kind)
			if not item.is_empty(): _offer(s, a, 0.54, "give", other.id, {"uid": item.uid})
	if a.ap >= 45 and a.scout_site != here.id and s.barricade_strength(here) >= 8:
		_offer(s, a, 0.24, "scout")
	if a.ap >= 25 and s.minute >= a.npc_special_at:
		if here.type == "necrotech_lab" and here.last_pounding >= s.minute - 45:
			_offer(s, a, 0.23, "scan")
		if s.powered(here):
			_offer(s, a, 0.30, "repair_radio")
			_offer(s, a, 0.29, "install_radio")
			if outside >= 3 and breach < 0.5:
				_offer(s, a, 0.56, "broadcast", -1, {"text": "Defenders needed at " + here.name, "frequency": s.suggested_transmit_frequency(a), "defense_call": true})
	if a.ap >= 30 and outside == 0:
		var book: Dictionary = s.item_kind(a, "book")
		if not book.is_empty(): _offer(s, a, 0.17, "read", -1, {"uid": book.uid})
		var drink: Dictionary = s.item_kind(a, "beer")
		if not drink.is_empty() and a.hp < 30: _offer(s, a, 0.22, "drink", -1, {"uid": drink.uid})


func _shelter_target(s, a: Dictionary, here: Dictionary, present: Array) -> int:
	if here.npc_ingress or s.barricade_strength(here) < 10 or not s.has_skill(a, "free_running"):
		return 10
	for other in present:
		if other.human and not other.down and not s.has_skill(other, "free_running"): return 10
	if here.npc_entry < 0:
		for other in s.actors:
			if other.human and not other.down and other.home == here.id and not s.has_skill(other, "free_running"): return 10
	var best: int = -1
	var value: int = -999
	for y in range(maxi(0, a.y - 1), mini(s.height, a.y + 2)):
		for x in range(maxi(0, a.x - 1), mini(s.width, a.x + 2)):
			var site: Dictionary = s.block_at(x, y)
			if site.id == here.id or site.barricade > 4 or site.ruin > 0 or site.npc_entry >= 0 or site.fort != here.fort: continue
			if not s.is_building(site) or not s.can_free_run_between(a, site, here): continue
			if s.occupants(site, true).any(func(t): return not t.human and not t.down): continue
			var quality: int = s.barricade_strength(site) - 6 * _outside_hostiles(s, site) + (20 if site.npc_ingress else 0)
			if site.id == int(here.npc_entry): quality += 12
			if quality > value:
				value = quality
				best = site.id
	if best >= 0:
		here.npc_entry = best
		s.blocks[best].npc_ingress = true
	return Desire.barricade_target(false, best >= 0 and s.barricade_strength(s.blocks[best]) == 10)


func _supply_turn(s, a: Dictionary, here: Dictionary, danger: float, competing: float) -> bool:
	if a.supply_goal >= 0:
		return supplies.run_trip(s, a, here)
	if a.ap < 13 or s.minute < a.next_trip:
		return false
	var kind: String = s.wanted_supply(a)
	if not kind.is_empty():
		var candidate: Vector2 = supplies.choose_site(s, a, here, kind, danger)
		if candidate.x >= 0 and candidate.y + 0.19 > competing:
			a.supply_goal = int(candidate.x)
			a.supply_kind = kind
			return supplies.run_trip(s, a, here)
		if a.ap >= 28 and competing < 0.32 and not _clinician(s, a):
			s._wander(a, true)
			return a.busy_until > s.now()
	a.next_trip = s.minute + 30 + int(a.id) % 20
	return false


func _service_revive_point(s, a: Dictionary, here: Dictionary) -> bool:
	if a.ap < 12 or not s.has_skill(a, "lab_experience") or s.item_kind(a, "syringe").is_empty(): return false
	var best: Dictionary = {}
	var distance: int = 7
	for id in s.revive_site_ids():
		var site: Dictionary = s.blocks[id]
		var d: int = s.scent_distance(a, site)
		if d >= distance or not s.occupants(site, false).any(func(t): return t.wants_revive and not t.down): continue
		best = site
		distance = d
	if best.is_empty(): return false
	if here.id != best.id: return AI.go(s, a, best)
	return a.inside and s._try(a, "leave")


func _seek_revival(s, a: Dictionary, here: Dictionary) -> int:
	if a.ap < s.cost(a, "move"): return s.cost(a, "move")
	var best: Dictionary = {}
	var distance: int = 9999
	var rot: bool = s.has_skill(a, "brain_rot")
	if a.memory >= 0 and a.memory_until > s.minute:
		var site: Dictionary = s.blocks[a.memory]
		if site.revive_point or site.type == "necrotech_lab" or _staffed(s, site): best = site
	if best.is_empty():
		var avoid: int = a.avoid_site if a.avoid_until > s.minute else -1
		for clinic in s.sites_by_type.get("necrotech_lab", []):
			if clinic.id == avoid or (rot and not s.powered(clinic)): continue
			var d: int = s.scent_distance(a, clinic)
			if d >= distance: continue
			var staff: bool = _staffed(s, clinic)
			var cost: int = d + (0 if staff else 22)
			if cost < distance:
				distance = cost
				best = clinic
		if not rot:
			# Field technicians can receive patients at their current shelter too.
			for y in range(maxi(0, a.y - 8), mini(s.height, a.y + 9)):
				for x in range(maxi(0, a.x - 8), mini(s.width, a.x + 9)):
					var d: int = maxi(absi(x - a.x), absi(y - a.y)) + 2
					var site: Dictionary = s.block_at(x, y)
					if d >= distance or site.id == avoid or site.barricade > 4 or not _staffed(s, site): continue
					best = site
					distance = d
			for id in s.revive_site_ids():
				var site: Dictionary = s.blocks[id]
				var d: int = s.scent_distance(a, site)
				if id != avoid and d < distance:
					best = site
					distance = d
		if not best.is_empty():
			a.memory = best.id
			a.memory_until = s.minute + 90
	if best.is_empty():
		AI.seek_revival(s, a)
	elif here.id != best.id:
		if not AI.go(s, a, best):
			a.avoid_site = best.id
			a.avoid_until = s.minute + 90
			a.memory = -1
	elif a.inside and not rot:
		if not s._try(a, "leave"): _ground_exit(s, a)
	elif rot and not a.inside:
		if not s._try(a, "enter"): s._try(a, "break")
	return 0 if a.busy_until > s.now() else mini(50, int(a.ap) + 1)


static func _staffed(s, site: Dictionary) -> bool:
	for id in s.spatial.get(site.id, []):
		var medic: Dictionary = s.actors[id]
		if medic.human and not medic.down and s.has_skill(medic, "lab_experience") and (site.type == "necrotech_lab" or (medic.home == site.id and not s.item_kind(medic, "syringe").is_empty())):
			return true
	return false


func record_scan(s, a: Dictionary) -> void:
	var highest: int = 0
	for y in range(maxi(0, a.y - 4), mini(s.height, a.y + 5)):
		for x in range(maxi(0, a.x - 4), mini(s.width, a.x + 5)):
			var id: int = y * s.width + x
			var count: int = 0
			for actor_id in s.spatial.get(id, []):
				var other: Dictionary = s.actors[actor_id]
				if not other.human and not other.down and not other.wants_revive and other.tagged_until > s.minute: count += 1
			if count > highest:
				highest = count
				a.avoid_site = id
				a.avoid_until = s.minute + 120


func record_scent(s, a: Dictionary) -> void:
	var best: float = 0.0
	for cell in s.scent_death_snapshot(a):
		if not cell.valid or (cell.x == a.x and cell.y == a.y): continue
		var value: float = cell.zombies
		if a.hp < 30 and s.has_skill(a, "digestion"): value += 1.5 * (cell.bodies - cell.revivifying)
		value /= 1.0 + maxi(absi(cell.x - a.x), absi(cell.y - a.y))
		if value > best:
			best = value
			a.memory = cell.y * s.width + cell.x
			a.memory_until = s.minute + 45
			a.npc_signal = "scent"


static func _outside_hostiles(s, site: Dictionary) -> int:
	var count: int = 0
	for id in s.spatial.get(site.id, []):
		var other: Dictionary = s.actors[id]
		if not other.human and not other.down and not other.inside and not other.wants_revive: count += 1
	return count


func _zombie(s, a: Dictionary, here: Dictionary, present: Array, skill: String) -> int:
	var pack: int = 1
	var humans: int = 0
	_focus.clear()
	for other in present:
		if other.down or other.id == a.id: continue
		if other.human: humans += 1
		elif not other.wants_revive:
			pack += 1
			if other.grasp_target >= 0: _focus[other.grasp_target] = _focus.get(other.grasp_target, 0) + 1
	if humans > 0:
		if pack < 3 and a.ap <= 2 and not present.any(func(t): return t.human and not t.down and t.hp <= 12 and s.has_skill(a, "scent_fear")):
			return 8
		for other in present:
			if not other.human or other.down: continue
			var action: String = AI.zombie_attack(s, a, other)
			var stats: Dictionary = s.attack_stats(a, other, action)
			var wounds: float = 1.0 - float(other.hp) / s.max_hp(other) if s.has_skill(a, "scent_blood") else (0.7 if s.has_skill(a, "scent_fear") and other.hp < 25 else 0.0)
			var focus: float = _focus.get(other.id, 0)
			var value: float = Desire.attack(AI.expected_damage(s, other, stats), 0.7 * wounds + 0.3 * Desire.unit(focus / 3.0), pack)
			if other.id == a.grasp_target: value += 0.01
			_offer(s, a, value, action, other.id, {"unarmed": true})
			if a.inside and humans > pack and other.hp <= 12:
				_offer(s, a, 0.96, "drag", other.id)
		if pack < humans + 1 and AI.can_call(s, a, present):
			var bellow: bool = s.has_skill(a, "bellow") and ((humans >= 25 and a.ap >= 10) or not s.has_skill(a, "feeding_groan"))
			_offer(s, a, 0.97, "bellow" if bellow else "groan")
		if not _command.is_empty() and s._try(a, _command, _target, _data):
			if _command in ["groan", "bellow"]: a.next_groan = s.minute + 180
			return 0
	if _purchase(s, a, skill): return 0
	if s.has_skill(a, "digestion") and a.hp <= s.max_hp(a) - 4:
		for body in present:
			if body.down: _offer(s, a, 0.40, "feed", body.id)
	var prey: Dictionary = s.scent_trail_target(a)
	if not prey.is_empty():
		a.memory = s.current_block(prey).id
		a.memory_until = s.minute + 60
		a.npc_signal = "prey"
	else:
		prey = s._visible_human(a)
	var goal: Dictionary = {}
	var cue: float = 0.0
	var hunt: float = 0.0
	var exit_for_prey: bool = false
	if not prey.is_empty():
		goal = s.current_block(prey)
		cue = 1.0
		hunt = Desire.hunt(1.0, 0.0, false, s.scent_distance(a, prey), pack)
		exit_for_prey = not prey.inside
		if goal.id != here.id and pack >= 2 and a.ap >= 8 and s.minute >= a.npc_special_at:
			if present.any(func(t): return t.id != a.id and not t.human and not t.down and not t.wants_revive and t.memory_until < s.minute):
				_offer(s, a, 0.57, "gesture", prey.id)
	elif a.memory >= 0 and s.minute <= a.memory_until:
		goal = s.blocks[a.memory]
		if a.npc_signal == "scent" and here.id == goal.id:
			a.memory = -1
			goal = {}
		else:
			var strength: float = 0.85 if a.npc_signal == "groan" else (0.55 if a.npc_signal == "scent" else 0.72)
			cue = strength * Desire.unit((a.memory_until - s.minute) / (45.0 if a.npc_signal == "scent" else 60.0))
			hunt = Desire.hunt(cue, 0.0, false, s.scent_distance(a, goal), pack)
	var light: Dictionary = s.nearby_light(a)
	if not light.is_empty():
		var attraction: float = Desire.hunt(0.0, 0.0, true, s.scent_distance(a, light), pack)
		if attraction > hunt:
			goal = light
			cue = 0.50
			hunt = attraction
	if a.inside:
		_offer(s, a, Desire.vandalize(1.0 if here.generator else 0.6, here.ransack_hits > 0), "destroy_generator" if here.generator else ("ruin" if here.ransack_hits >= 5 else "ransack"))
		if goal.get("id", -1) == here.id and exit_for_prey: _offer(s, a, hunt, "leave")
	else:
		var wall: int = s.barricade_strength(here)
		if wall > 0 and goal.get("id", -1) == here.id:
			if pack < 3 and a.ap <= 2: return 10
			var stats: Dictionary = s.barricade_attack_stats(a, {"unarmed": true})
			var work: float = wall / maxf(0.01, stats.hit * stats.structural / 100.0)
			_offer(s, a, Desire.breach(cue, work, pack), "break", -1, {"unarmed": true})
		elif wall == 0 and (goal.get("id", -1) == here.id or (s.has_skill(a, "memories") and s.doors_closed(here) and s.rng.randf() < 0.95) or (here.ruin < 3 and s.can_be_ransacked(here) and s.has_skill(a, "ransack"))):
			var local_cue: float = cue if goal.get("id", -1) == here.id else (0.9 if s.doors_closed(here) and s.has_skill(a, "memories") else 0.0)
			_offer(s, a, maxf(0.16, Desire.breach(local_cue, 0.0, pack)), "enter")
	var wander: float = Desire.wander(cue, 0.65)
	if goal.is_empty() and a.ap >= 16 and s.minute >= a.npc_special_at:
		_offer(s, a, 0.15, "smell")
	if goal.is_empty() and _score <= wander and a.ap < 5:
		return 5
	if not goal.is_empty() and goal.id != here.id and hunt > maxf(_score, wander) and AI.go(s, a, goal):
		return 0
	if _score > wander and s._try(a, _command, _target, _data): return 0
	if a.ap < s.cost(a, "move") and not a.inside: return s.cost(a, "move")
	if a.inside and goal.get("id", -1) == here.id: a.memory = -1
	s._wander(a, true)
	return 0


static func _ground_exit(s, a: Dictionary) -> bool:
	for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if s._try(a, "move", -1, {"dx": delta.x, "dy": delta.y, "free_run": false}): return true
	return false
