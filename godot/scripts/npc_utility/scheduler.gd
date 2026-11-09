extends RefCounted

var _buckets: Dictionary[int, Array] = {}
const EMPTY: Array = []


func clear() -> void:
	_buckets.clear()


func add(actor_id: int, due_step: int) -> void:
	if _buckets.has(due_step):
		_buckets[due_step].append(actor_id)
	else:
		_buckets[due_step] = [actor_id]


func take(step: int) -> Array:
	if not _buckets.has(step):
		return EMPTY
	var bucket: Array = _buckets[step]
	_buckets.erase(step)
	bucket.sort()
	return bucket
