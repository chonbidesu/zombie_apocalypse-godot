extends RefCounted
## Shared 100 × 100 city and NPC setup for performance captures.

const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const World = preload("res://scripts/world_builder.gd")
const INITIAL_THINK_WINDOW_STEPS: int = 7 * Catalog.CLOCK_STEPS_PER_MINUTE
const SHELTER_RESIDENTS: int = 12


static func start_city(sim: Sim, seed_value: int, count: int) -> String:
	var config: Dictionary = World.defaults(100, 100)
	@warning_ignore("integer_division")
	var survivors: int = count / 3
	config.survivors = survivors
	config.zombies = count - survivors
	var error: String = sim.start(seed_value, "Private", config)
	if not error.is_empty():
		return error
	if sim.blocks.size() != 10_000 or sim.actors.size() != count + 1:
		return "Unexpected city or NPC count."
	return ""


static func awaken_npcs(sim: Sim, stagger: bool) -> void:
	for id in range(1, sim.actors.size()):
		var actor: Dictionary = sim.actors[id]
		if not actor.dormant:
			continue
		actor.dormant = false
		actor.down = false
		actor.hp = sim.max_hp(actor)
		if stagger:
			# Dormant actors start without a due time. Spread their first turns
			# across the same opening window as naturally active actors.
			var offset: int = Catalog.CLOCK_STEPS_PER_MINUTE + id % INITIAL_THINK_WINDOW_STEPS
			actor.next_think = float(sim.clock_step + offset) / Catalog.CLOCK_STEPS_PER_MINUTE


static func prepare_shelter(sim: Sim, quiet: bool = false) -> Dictionary:
	var radius: int = 5 if quiet else 3
	var interior: Rect2i = Rect2i(5, 5, sim.width - 10, sim.height - 10)
	for site: Dictionary in sim.blocks:
		if site.type != "office" or not site.fort.is_empty() or site.ruin > 0:
			continue
		if not quiet and not interior.has_point(Vector2i(site.x, site.y)):
			continue
		if not _clear_area(sim, site, radius):
			continue
		var player: Dictionary = sim.player()
		player.x = site.x
		player.y = site.y
		player.inside = true
		player.home = site.id
		if not quiet:
			sim.set_barricade_strength(site, 8)
			site.doors = sim.has_doors(site)
			for id in range(1, SHELTER_RESIDENTS + 1):
				var actor: Dictionary = sim.actors[id]
				actor.x = site.x
				actor.y = site.y
				actor.inside = true
				actor.home = site.id
		sim.reindex()
		sim.discover()
		return site
	return {}


static func _clear_area(sim: Sim, site: Dictionary, radius: int) -> bool:
	for y in range(maxi(0, site.y - radius), mini(sim.height, site.y + radius + 1)):
		for x in range(maxi(0, site.x - radius), mini(sim.width, site.x + radius + 1)):
			if sim.spatial.has(y * sim.width + x):
				return false
	return true
