extends RefCounted

enum Kind { SHELTER, MEDICAL, AMMO, HARDWARE, REVIVAL, COUNT }

const SITES_PER_ACTOR: int = 12
const GROW_ROWS: int = 64
const HALF_LIFE_MINUTES: float = 720.0
const NO_SITE: int = -1

var _width: int
var _height: int
var _row_count: int = 0
var _rows: PackedInt32Array
var _sites: PackedInt32Array
var _seen: PackedInt32Array
var _values: PackedByteArray


func _init(width: int, height: int, actor_capacity: int) -> void:
	assert(width > 0 and height > 0 and actor_capacity >= 0)
	_width = width
	_height = height
	_rows.resize(actor_capacity)
	_rows.fill(-1)


func site_id(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= _width or cell.y < 0 or cell.y >= _height:
		return NO_SITE
	return cell.y * _width + cell.x


@warning_ignore("integer_division")
func coordinates(id: int) -> Vector2i:
	assert(id >= 0 and id < _width * _height)
	return Vector2i(id % _width, id / _width)


func _row_for(actor_id: int) -> int:
	if actor_id < 0 or actor_id >= _rows.size():
		return -1
	return _rows[actor_id]


func _allocate_row(actor_id: int) -> int:
	if actor_id >= _rows.size():
		var old_capacity: int = _rows.size()
		_rows.resize(actor_id + 1)
		for index in range(old_capacity, _rows.size()):
			_rows[index] = -1
	var first_slot: int = _row_count * SITES_PER_ACTOR
	if first_slot == _sites.size():
		var capacity: int = first_slot + GROW_ROWS * SITES_PER_ACTOR
		_sites.resize(capacity)
		_seen.resize(capacity)
		_values.resize(capacity * Kind.COUNT)
	_rows[actor_id] = _row_count
	_row_count += 1
	for slot in range(first_slot, first_slot + SITES_PER_ACTOR):
		_sites[slot] = NO_SITE
	return _rows[actor_id]


static func confidence(age_minutes: int) -> float:
	return HALF_LIFE_MINUTES / (HALF_LIFE_MINUTES + maxi(0, age_minutes))


static func distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return maxi(absi(from_cell.x - to_cell.x), absi(from_cell.y - to_cell.y))


# Upsert a complete observation. Each value is a byte quantized from [0, 1].
func remember(
	actor_id: int, cell: Vector2i, seen_minute: int, values: PackedByteArray,
	home_id: int = NO_SITE, entry_id: int = NO_SITE
) -> void:
	assert(actor_id >= 0 and values.size() == Kind.COUNT)
	var id: int = site_id(cell)
	if id == NO_SITE:
		return
	var row: int = _row_for(actor_id)
	if row < 0:
		row = _allocate_row(actor_id)
	var first: int = row * SITES_PER_ACTOR
	var selected: int = -1
	var lowest: float = INF
	for slot in range(first, first + SITES_PER_ACTOR):
		var stored: int = _sites[slot]
		if stored == id:
			if seen_minute < _seen[slot]:
				return
			selected = slot
			break
		if stored == NO_SITE:
			selected = slot
			break
		if stored == home_id or stored == entry_id:
			continue
		var peak: int = 0
		for kind in range(Kind.COUNT):
			peak = maxi(peak, _values[slot * Kind.COUNT + kind])
		var keep: float = peak * confidence(seen_minute - _seen[slot])
		keep /= 1.0 + distance(cell, coordinates(stored)) / 6.0
		if keep < lowest:
			lowest = keep
			selected = slot
	_sites[selected] = id
	_seen[selected] = seen_minute
	for kind in range(Kind.COUNT):
		_values[selected * Kind.COUNT + kind] = values[kind]


func lookup(actor_id: int, id: int, kind: int, now_minute: int) -> float:
	var slot: int = _find(actor_id, id)
	return 0.0 if slot < 0 else _quality(slot, kind, now_minute)


func knows(actor_id: int, id: int) -> bool:
	return _find(actor_id, id) >= 0


func _find(actor_id: int, id: int) -> int:
	var row: int = _row_for(actor_id)
	if row < 0 or id == NO_SITE:
		return -1
	var first: int = row * SITES_PER_ACTOR
	for slot in range(first, first + SITES_PER_ACTOR):
		if _sites[slot] == id:
			return slot
	return -1


func save_records() -> Array:
	var records: Array = []
	for actor_id in range(_rows.size()):
		var row: int = _rows[actor_id]
		if row < 0:
			continue
		for slot in range(row * SITES_PER_ACTOR, (row + 1) * SITES_PER_ACTOR):
			if _sites[slot] != NO_SITE:
				var record: Array = [actor_id, _sites[slot], _seen[slot]]
				for kind in range(Kind.COUNT):
					record.append(_values[slot * Kind.COUNT + kind])
				records.append(record)
	return records


func restore_records(records: Variant, now_minute: int) -> void:
	if not records is Array:
		return
	for record in records:
		if not record is Array or record.size() != 3 + Kind.COUNT:
			continue
		if not record.all(func(value): return value is float or value is int):
			continue
		var actor_id: int = int(record[0])
		var id: int = int(record[1])
		if actor_id <= 0 or actor_id >= _rows.size() or id < 0 or id >= _width * _height:
			continue
		var values := PackedByteArray()
		for kind in range(Kind.COUNT):
			values.append(clampi(int(record[3 + kind]), 0, 255))
		remember(actor_id, coordinates(id), clampi(int(record[2]), 0, now_minute), values)


func _quality(slot: int, kind: int, now_minute: int) -> float:
	return _values[slot * Kind.COUNT + kind] / 255.0 * confidence(now_minute - _seen[slot])


# Rank remembered IDs with a cheap distance estimate, then route the finalists.
# The caller reuses equal-sized output buffers and reads only the returned prefix.
func shortlist(
	actor_id: int, origin: Vector2i, kind: int, now_minute: int, max_distance: int,
	out_ids: PackedInt32Array, out_scores: PackedFloat64Array, excluded_id: int = NO_SITE
) -> int:
	assert(out_ids.size() == out_scores.size())
	var limit: int = out_ids.size()
	var row: int = _row_for(actor_id)
	if row < 0 or limit == 0:
		return 0
	var count: int = 0
	var first: int = row * SITES_PER_ACTOR
	for slot in range(first, first + SITES_PER_ACTOR):
		var id: int = _sites[slot]
		if id == NO_SITE or id == excluded_id:
			continue
		var d: int = distance(origin, coordinates(id))
		if d > max_distance:
			continue
		var score: float = _quality(slot, kind, now_minute) / (1.0 + d / 4.0)
		if score <= 0.0:
			continue
		var index: int = mini(count, limit - 1)
		if count == limit and not _outranks(score, id, out_scores[index], out_ids[index]):
			continue
		while index > 0 and _outranks(score, id, out_scores[index - 1], out_ids[index - 1]):
			out_ids[index] = out_ids[index - 1]
			out_scores[index] = out_scores[index - 1]
			index -= 1
		out_ids[index] = id
		out_scores[index] = score
		count = mini(count + 1, limit)
	return count


static func _outranks(score: float, id: int, other_score: float, other_id: int) -> bool:
	return score > other_score or (score == other_score and id < other_id)
