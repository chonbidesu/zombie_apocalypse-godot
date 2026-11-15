extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var checks: int
var failures: int


func _initialize() -> void:
	var sim := Sim.new()
	sim.start(991)
	var graph: AStar2D = sim.navigation
	for from: int in range(0, sim.blocks.size(), 3):
		for to: int in range(0, sim.blocks.size(), 7):
			var expected := graph.get_id_path(from, to)
			_check(sim.query_route(from, to) == expected, "First lookup preserves the directed A* route.")
			var cached := sim.query_route(from, to)
			_check(cached == expected, "Cached lookup preserves A* tie order.")
			if not cached.is_empty(): cached[0] = -1
			_check(sim.query_route(from, to) == expected, "Caller mutation cannot change the cached route.")
	_check(sim.route_cache.hits > 0 and sim.route_cache.searches < sim.route_cache.requests, "Repeated queries avoid real A* searches.")
	for index: int in range(5000): sim.query_route(index / 100, index % 100)
	_check(sim.route_cache._paths.size() == sim.route_cache.CAPACITY, "The route cache remains bounded after eviction.")
	_check(sim.query_route(0, 99) == graph.get_id_path(0, 99), "An evicted route is recomputed without changing its path.")
	graph.set_point_disabled(11, true)
	sim.route_cache.constraints_active = true
	_check(sim.query_route(0, 22) == graph.get_id_path(0, 22), "Temporary danger obstacles use the live graph.")
	sim.route_cache.constraints_active = false
	graph.set_point_disabled(11, false)
	_check(sim.query_route(0, 22) == graph.get_id_path(0, 22), "Temporary detours cannot poison the normal route cache.")
	var replacement := AStar2D.new()
	replacement.add_point(0, Vector2.ZERO)
	replacement.add_point(22, Vector2.ONE)
	sim.navigation = replacement
	_check(sim.query_route(0, 22).is_empty(), "Replacing the graph invalidates old routes.")
	print("ROUTE CACHE CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
