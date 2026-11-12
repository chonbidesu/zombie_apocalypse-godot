extends SceneTree
## Compare the optimized neighbourhood queries with their original scans.

const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Fixture = preload("res://tests/performance_fixture.gd")


class ComparedSim extends Sim:
	var human_checks: int
	var light_checks: int
	var failures: int

	func _visible_human(a: Dictionary) -> Dictionary:
		var actual: Dictionary = super._visible_human(a)
		human_checks += 1
		_compare(actual, _reference_human(a), "visible human", a)
		return actual

	func nearby_light(a: Dictionary) -> Dictionary:
		var actual: Dictionary = super.nearby_light(a)
		light_checks += 1
		_compare(actual, _reference_light(a), "nearby light", a)
		return actual

	func _compare(actual: Dictionary, expected: Dictionary, query: String, observer: Dictionary) -> void:
		if (actual.is_empty() and expected.is_empty()) or is_same(actual, expected):
			return
		failures += 1
		if failures == 1:
			push_error("%s differed at tick %d for actor %s." % [query, clock_step, str(observer.get("id", -1))])

	func _reference_human(a: Dictionary) -> Dictionary:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if a.x + dx not in range(width) or a.y + dy not in range(height):
					continue
				var b: Dictionary = block_at(a.x + dx, a.y + dy)
				for other: Dictionary in occupants(b):
					if other.human and not other.down:
						if nearby(a, other) or (not other.inside and not a.inside) or (dx == 0 and dy == 0 and not doors_closed(b) and b.barricade == 0):
							return other
		return {}

	func _reference_light(a: Dictionary) -> Dictionary:
		var best: Dictionary = {}
		var distance: int = 4
		for y in range(maxi(0, a.y - 3), mini(height, a.y + 4)):
			for x in range(maxi(0, a.x - 3), mini(width, a.x + 4)):
				var b: Dictionary = block_at(x, y)
				var d: int = maxi(absi(x - a.x), absi(y - a.y))
				if powered(b) and d < distance:
					best = b
					distance = d
		return best


func _initialize() -> void:
	var sim: ComparedSim = ComparedSim.new()
	sim.start()
	_check_corner_cases(sim)
	var error: String = Fixture.start_city(sim, 4815, 1000)
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	sim.player().down = true
	Fixture.awaken_npcs(sim, true)
	sim._reset_npc_runtime()
	sim.advance(1440)
	print("NEIGHBOURHOOD CHECKS: %d visibility, %d light, %d differences, %d NPC actions." % [
		sim.human_checks, sim.light_checks, sim.failures, int(sim.metrics.npc_actions),
	])
	quit(0 if sim.failures == 0 else 1)


func _check_corner_cases(sim: ComparedSim) -> void:
	var observer: Dictionary = {"x":0, "y":0, "inside":false}
	var here: Dictionary = sim.block_at(0, 0)
	here.type = "office"
	here.doors = false
	here.barricade = 0
	for id in range(1, 3):
		var actor: Dictionary = sim.actors[id]
		actor.x = 0
		actor.y = 0
		actor.inside = true
	sim.reindex()
	sim._visible_human(observer)
	here.doors = true
	sim._visible_human(observer)
	observer.inside = true
	sim._visible_human(observer)
	for at: Vector2i in [Vector2i(2, 0), Vector2i(0, 2)]:
		var site: Dictionary = sim.block_at(at.x, at.y)
		site.type = "office"
		site.generator = true
		site.generator_hp = Catalog.GENERATOR_HP
		site.fuel_until = sim.minute + 1
	sim.nearby_light(observer)
	sim.block_at(2, 0).fuel_until = sim.minute
	sim.nearby_light(observer)
	sim.block_at(0, 2).generator_hp = 0
	sim.nearby_light(observer)
