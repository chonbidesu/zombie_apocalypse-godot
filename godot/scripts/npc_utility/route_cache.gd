extends RefCounted
## Directed static-graph paths. Temporary danger obstacles bypass the cache.

const CAPACITY: int = 4096
var enabled: bool = true
var constraints_active: bool = false
var requests: int
var searches: int
var hits: int
var bypasses: int
var _graph_id: int
var _paths: Dictionary[Vector2i, PackedInt64Array] = {}
var _keys: Array[Vector2i] = []
var _cursor: int


func clear() -> void:
	_paths.clear()
	_keys.clear()
	_cursor = 0
	_graph_id = 0


func get_path(graph: AStar2D, from: int, to: int) -> PackedInt64Array:
	requests += 1
	if not enabled or constraints_active:
		searches += 1
		bypasses += int(constraints_active)
		return graph.get_id_path(from, to)
	if _graph_id != graph.get_instance_id():
		clear()
		_graph_id = graph.get_instance_id()
	var key := Vector2i(from, to)
	if _paths.has(key):
		hits += 1
		return _paths[key].duplicate()
	searches += 1
	var path := graph.get_id_path(from, to)
	if _keys.size() < CAPACITY:
		_keys.append(key)
	else:
		_paths.erase(_keys[_cursor])
		_keys[_cursor] = key
		_cursor = (_cursor + 1) % CAPACITY
	_paths[key] = path
	return path.duplicate()
