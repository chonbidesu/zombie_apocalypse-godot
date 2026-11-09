extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const AI = preload("res://scripts/npc_ai.gd")
const Desire = preload("res://scripts/npc_utility/desire.gd")
const Memory = preload("res://scripts/npc_utility/location_memory.gd")
const OBSERVED_ITEMS = [[], ["first_aid_kit"], ["pistol_clip", "shotgun_shell", "pistol", "shotgun"],
	["toolbox", "fuel_can", "portable_generator", "fire_axe", "crowbar", "baseball_bat", "radio_transmitter", "spray_can"], ["syringe"]]
const TRIP_RESERVE = 9

var memory: Memory
var _values := PackedByteArray([0, 0, 0, 0, 0])
var _ids := PackedInt32Array([-1, -1, -1])
var _scores := PackedFloat64Array([0.0, 0.0, 0.0])


func reset(width: int, height: int, actors: int) -> void:
	memory = Memory.new(width, height, actors)


static func weapon_track(s, a: Dictionary) -> String:
	var best: String = ""
	var efficiency: float = 0.0
	for item in a.inventory:
		var def: Dictionary = Catalog.ITEMS[item.kind]
		if not def.has("damage") or def.get("fragile", false):
			continue
		if def.has("capacity") and item.ammo <= 0 and s.item_kind(a, def.ammo_kind).is_empty():
			continue
		var stats: Dictionary = s.attack_stats(a, {}, "attack", item)
		var value: float = stats.hit * stats.damage
		if item.kind in ["pistol", "shotgun"] and a.job in ["Private", "Police Officer", "Guard", "Medic"]:
			value *= 1.3
		if value > efficiency:
			efficiency = value
			best = item.kind
	return "axe" if best == "fire_axe" else best


static func store_for(s, a: Dictionary, site: Dictionary, kind: String) -> String:
	if site.type == "mall" and s.has_skill(a, "shopping"):
		for store in Catalog.MALL_STORES:
			if kind in Catalog.MALL_STORES[store]:
				return store
	return ""


func observe(s, a: Dictionary, here: Dictionary, hostile: int) -> void:
	var stamp: int = here.id * 2 + int(a.inside)
	if a.npc_observed == stamp and s.minute < a.npc_observed_at + 60:
		return
	a.npc_observed = stamp
	a.npc_observed_at = s.minute
	for y in range(maxi(0, a.y - 1), mini(s.height, a.y + 2)):
		for x in range(maxi(0, a.x - 1), mini(s.width, a.x + 2)):
			var site: Dictionary = s.block_at(x, y)
			if not s.is_building(site):
				continue
			var inside: bool = site.id == here.id and a.inside
			if not inside and memory.knows(a.id, site.id):
				continue
			_values[Memory.Kind.SHELTER] = (120 + 6 * s.barricade_strength(site)) if inside and hostile == 0 and site.ruin == 0 else 0
			var profile: Dictionary = a if inside else {}
			var known_type: String = site.type if inside else s.visible_type(site, a)
			var observed_site: Dictionary = site if known_type == site.type else {"type": known_type, "generator": false, "ruin": 0, "fuel_until": 0}
			for channel in range(1, Memory.Kind.COUNT):
				var wealth: float = 0.0
				for item in OBSERVED_ITEMS[channel]:
					var store: String = store_for(s, a, site, item) if inside else ""
					wealth = maxf(wealth, s.item_search_chance(observed_site, item, profile, store))
				_values[channel] = roundi(255.0 * Desire.unit(wealth / 0.20))
			memory.remember(a.id, Vector2i(x, y), s.minute, _values, a.home, int(s.blocks[a.home].npc_entry))


func choose_site(s, a: Dictionary, here: Dictionary, kind: String, threat: float) -> Vector2:
	var channel: int = Memory.Kind.HARDWARE
	if kind == "first_aid_kit": channel = Memory.Kind.MEDICAL
	elif kind == "syringe": channel = Memory.Kind.REVIVAL
	elif kind in OBSERVED_ITEMS[Memory.Kind.AMMO]: channel = Memory.Kind.AMMO
	var origin := Vector2i(a.x, a.y)
	var max_distance: int = mini(9, maxi(0, (a.ap - TRIP_RESERVE - 3) / 2))
	var avoid: int = a.avoid_site if a.avoid_until > s.minute else -1
	var count: int = memory.shortlist(a.id, origin, channel, s.minute, max_distance, _ids, _scores, avoid)
	var best_id: int = -1
	var best: float = 0.0
	# Known building types in the immediate neighbourhood may also have niche stock.
	for index in range(count + 9):
		var cell: Vector2i = memory.coordinates(_ids[index]) if index < count else origin + Vector2i((index - count) % 3 - 1, (index - count) / 3 - 1)
		var id: int = memory.site_id(cell)
		if id < 0 or id == avoid:
			continue
		var site: Dictionary = s.blocks[id]
		var distance: int = Memory.distance(origin, cell)
		if not s.is_building(site) or (distance <= 1 and site.barricade > 4 and not (a.inside and s.can_free_run_between(a, here, site))):
			continue
		var visible: bool = distance <= 1
		var chance: float = 0.0
		if visible:
			if _hostile_street(s, site): continue
			if s.visible_type(site, a) != site.type:
				continue
			chance = s.item_search_chance(site, kind, a if id == here.id and a.inside else {}, store_for(s, a, site, kind))
		else:
			# Static stock tables identify which remembered building types can supply the item.
			var table: Dictionary = s.search_tables.get(site.type, {})
			if not table.has(kind): continue
			chance = minf(0.20, 0.20 * _scores[index] * (1.0 + distance / 4.0))
		if chance <= 0.0:
			continue
		var home: Dictionary = s.blocks[a.home]
		var route: PackedInt64Array = s.navigation.get_id_path(here.id, id)
		var return_route: PackedInt64Array = s.navigation.get_id_path(id, home.id)
		if route.is_empty() or return_route.is_empty():
			continue
		var trip: int = route.size() + return_route.size() + TRIP_RESERVE + 1
		var urgency: float = 1.0 if kind in ["first_aid_kit", "syringe"] else 0.84
		var value: float = Desire.scavenge(a.ap, trip, urgency, Desire.unit(chance / 0.14), threat)
		value /= 1.0 + route.size() / 5.0
		if value > best:
			best = value
			best_id = id
	if best_id < 0 and max_distance >= 2:
		var known: Dictionary = _public_source(s, a, origin, kind, mini(max_distance, 6), avoid)
		if not known.is_empty():
			var outward: PackedInt64Array = s.navigation.get_id_path(here.id, known.id)
			var back: PackedInt64Array = s.navigation.get_id_path(known.id, a.home)
			var trip: int = outward.size() + back.size() + TRIP_RESERVE + 1
			if not outward.is_empty() and not back.is_empty() and a.ap >= trip:
				return Vector2(known.id, Desire.scavenge(a.ap, trip, 0.80, 0.40, threat))
	return Vector2(best_id, best)


static func _public_source(s, a: Dictionary, origin: Vector2i, kind: String, radius: int, avoid: int) -> Dictionary:
	var best: Dictionary = {}
	var distance: int = radius + 1
	# Public landmarks supply a lead about stock type. The NPC learns access and
	# current search conditions when it reaches the building.
	for y in range(maxi(0, origin.y - radius), mini(s.height, origin.y + radius + 1)):
		for x in range(maxi(0, origin.x - radius), mini(s.width, origin.x + radius + 1)):
			var site: Dictionary = s.block_at(x, y)
			var d: int = Memory.distance(origin, Vector2i(x, y))
			if d >= distance or site.id == avoid or not s.is_building(site) or s.visible_type(site, a) != site.type: continue
			if kind not in s.search_tables.get(site.type, {}) and store_for(s, a, site, kind).is_empty(): continue
			best = site
			distance = d
	return best


func run_trip(s, a: Dictionary, here: Dictionary) -> bool:
	if a.supply_goal < 0:
		return false
	var home: Dictionary = s.blocks[a.home]
	var site: Dictionary = s.blocks[a.supply_goal]
	if not a.supply_kind.is_empty():
		var found: bool = not s.item_kind(a, a.supply_kind).is_empty()
		var return_path: PackedInt64Array = s.navigation.get_id_path(here.id, home.id)
		var reserve: int = return_path.size() + TRIP_RESERVE + 2
		if found or return_path.is_empty() or a.ap <= reserve:
			a.supply_kind = ""
			a.supply_goal = a.home
			site = home
	if a.supply_kind.is_empty() and site.id == home.id and home.barricade > 4 and (not a.inside or here.id != home.id):
		var entry_id: int = int(home.npc_entry)
		var roof_access: bool = a.inside and s.scent_distance(a, home) == 1 and s.can_free_run_between(a, here, home)
		if not roof_access:
			if entry_id < 0 or not s.has_skill(a, "free_running") or s.blocks[entry_id].barricade > 4:
				return abandon(s, a, site.id)
			var entry: Dictionary = s.blocks[entry_id]
			if here.id != entry_id: return AI.go(s, a, entry) or abandon(s, a, entry_id)
			if not a.inside: return s._try(a, "enter") or abandon(s, a, entry_id)
	if here.id != site.id:
		if not a.supply_kind.is_empty() and s.scent_distance(a, site) == 1 and _hostile_street(s, site):
			a.supply_goal = a.home
			a.supply_kind = ""
			a.avoid_site = site.id
			a.avoid_until = s.minute + 150
			return false
		return AI.go(s, a, site) or abandon(s, a, site.id)
	if not a.inside:
		return s._try(a, "enter") or abandon(s, a, site.id)
	if a.supply_kind.is_empty():
		a.supply_goal = -1
		a.next_trip = s.minute + 30 + int(a.id) % 20
		return false
	if s.acquisition_reason(a).is_empty():
		return s._try(a, "search", -1, {"store": store_for(s, a, site, a.supply_kind)})
	for item in a.inventory:
		if item.uid != a.equipped and item.kind != a.supply_kind and not s.supply_needed_by(a, item.kind) and not Catalog.ITEMS[item.kind].has("damage"):
			return s._try(a, "drop", -1, {"uid": item.uid})
	return abandon(s, a, site.id)


static func abandon(s, a: Dictionary, id: int) -> bool:
	a.avoid_site = id
	a.avoid_until = s.minute + 150
	a.supply_goal = -1
	a.supply_kind = ""
	a.next_trip = s.minute + 30
	return false


static func _hostile_street(s, site: Dictionary) -> bool:
	for id in s.spatial.get(site.id, []):
		var other: Dictionary = s.actors[id]
		if not other.inside and not other.human and not other.down and not other.wants_revive: return true
	return false
