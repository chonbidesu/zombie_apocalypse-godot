extends RefCounted
## Read-only scoring is joined before the ordered action resolver resumes.

const Planner = preload("res://scripts/npc_utility/planner.gd")
const MIN_JOBS_PER_WORKER: int = 6
const TUNING_SAMPLES: int = 5

class Worker extends RefCounted:
	var planner := Planner.new()
	var results: Dictionary[int, Dictionary] = {}

	func score(sim, jobs: Array, first: int, stride: int) -> void:
		results.clear()
		for index in range(first, jobs.size(), stride):
			var actor: Dictionary = jobs[index]
			var result := planner.prepare(sim, actor)
			if not result.is_empty(): results[actor.id] = result


# -1 detects the available CPU budget, 0 and 1 use serial planning.
var thread_limit: int = -1
var active: bool = false
var batches: int
var prepared_count: int
var reused_count: int
var invalidated_count: int
var peak_workers: int
var peak_concurrent_workers: int
var configurations: Dictionary[int, Dictionary] = {}
var _workers: Array[Worker] = []
var _jobs: Array = []
var _results: Dictionary[int, Dictionary] = {}
var _dirty: Dictionary[Vector2i, bool] = {}
var _dirty_buckets: Dictionary[Vector2i, Array] = {}
var _sim
var _worker_count: int
var _sample_started: int
var _sample_state: Dictionary = {}
var _sample_mode: int
var _cpu_budget: int = maxi(0, OS.get_processor_count() - 2)
var _worker_mutex := Mutex.new()
var _running_workers: int


func begin(sim, due: Array) -> void:
	_results.clear()
	_dirty.clear()
	_dirty_buckets.clear()
	active = false
	_sample_started = 0
	if sim.npc_plan_on_turn: return
	if sim.managed_queries.planning_active: return
	var limit: int = _cpu_budget if thread_limit < 0 else mini(_cpu_budget, thread_limit)
	if not sim.resting or limit < 2 or due.size() < MIN_JOBS_PER_WORKER * 2: return
	var started: int = Time.get_ticks_usec()
	var ready_humans: int = 0
	var now: float = sim.now()
	for id: int in due:
		var actor: Dictionary = sim.actors[id]
		if not actor.human or actor.down or actor.dormant or actor.ap <= 0 or actor.prefers_undead:
			continue
		if actor.busy_until > now or sim._npc_due(actor) != sim.clock_step: continue
		ready_humans += 1
	limit = mini(limit, ready_humans / MIN_JOBS_PER_WORKER)
	if limit < 2: return
	_worker_count = _automatic_workers(limit, started) if thread_limit < 0 else limit
	# The serial control skips candidate collection and conflict filtering.
	if _worker_count < 2: return
	_jobs.clear()
	var prior_buckets: Dictionary[Vector2i, Array] = {}
	var first: int = due.bsearch(sim.npc_cursor)
	for offset in range(due.size()):
		var id: int = due[(first + offset) % due.size()]
		var actor: Dictionary = sim.actors[id]
		if actor.dormant or actor.down or actor.busy_until > sim.now() or sim._npc_due(actor) != sim.clock_step:
			continue
		var cell := Vector2i(actor.x, actor.y)
		var bucket := Vector2i(cell.x / 4, cell.y / 4)
		if actor.human and actor.ap > 0 and not actor.prefers_undead:
			if not _contains_near(prior_buckets, cell, 3): _jobs.append(actor)
		if not prior_buckets.has(bucket): prior_buckets[bucket] = []
		prior_buckets[bucket].append(cell)
	_worker_count = mini(_worker_count, _jobs.size() / MIN_JOBS_PER_WORKER)
	if _worker_count < 2: return
	while _workers.size() < _worker_count: _workers.append(Worker.new())
	_sim = sim
	var task: int = WorkerThreadPool.add_group_task(_score_worker, _worker_count, _worker_count, true, "NPC scoring")
	WorkerThreadPool.wait_for_group_task_completion(task)
	_sim = null
	for index in range(_worker_count):
		_results.merge(_workers[index].results)
		_workers[index].results.clear()
		_workers[index].planner.supplies.memory = null
	batches += 1
	peak_workers = maxi(peak_workers, _worker_count)
	prepared_count += _results.size()
	active = not _results.is_empty()


func _automatic_workers(limit: int, started: int) -> int:
	# Compare complete ticks, including rejected preparations and scheduling.
	# Ready-actor buckets let busy and quiet ticks choose separately before
	# paying for candidate collection. Actual workers are capped by usable jobs.
	var bucket: int = 2
	while bucket * 2 <= limit: bucket *= 2
	if limit == _cpu_budget: bucket = limit
	if not configurations.has(bucket):
		var choices: Array[int] = [0]
		var count: int = 2
		while count <= bucket:
			choices.append(count)
			count *= 2
		if choices.back() != bucket: choices.append(bucket)
		var samples: Dictionary[int, Array] = {}
		for choice: int in choices: samples[choice] = []
		configurations[bucket] = {"choices": choices, "samples": samples, "round": 0, "best": -1}
	var state: Dictionary = configurations[bucket]
	if state.best >= 0: return state.best
	_sample_state = state
	_sample_mode = state.choices[state.round % state.choices.size()]
	_sample_started = started
	return _sample_mode


func _score_worker(index: int) -> void:
	_worker_mutex.lock()
	_running_workers += 1
	peak_concurrent_workers = maxi(peak_concurrent_workers, _running_workers)
	_worker_mutex.unlock()
	_workers[index].score(_sim, _jobs, index, _worker_count)
	_worker_mutex.lock()
	_running_workers -= 1
	_worker_mutex.unlock()


func take(actor: Dictionary) -> Dictionary:
	var result: Dictionary = _results.get(actor.id, {})
	if result.is_empty(): return result
	var cell := Vector2i(actor.x, actor.y)
	if (result.global_home and not _dirty.is_empty()) or _contains_near(_dirty_buckets, cell, 2):
		invalidated_count += 1
		return {}
	if result.has("group") and _contains_near(_dirty_buckets, cell, 5): result.erase("group")
	if result.has("retreat") and _contains_near(_dirty_buckets, cell, 8): result.erase("retreat")
	reused_count += 1
	return result


static func _contains_near(buckets: Dictionary[Vector2i, Array], origin: Vector2i, radius: int) -> bool:
	var start := Vector2i(maxi(0, origin.x - radius) / 4, maxi(0, origin.y - radius) / 4)
	var end := Vector2i((origin.x + radius) / 4, (origin.y + radius) / 4)
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var bucket := Vector2i(x, y)
			if not buckets.has(bucket): continue
			for cell: Vector2i in buckets[bucket]:
				if maxi(absi(cell.x - origin.x), absi(cell.y - origin.y)) <= radius: return true
	return false


func dirty(actor_or_site: Dictionary) -> void:
	var cell := Vector2i(actor_or_site.x, actor_or_site.y)
	if _dirty.has(cell): return
	_dirty[cell] = true
	var bucket := Vector2i(cell.x / 4, cell.y / 4)
	if not _dirty_buckets.has(bucket): _dirty_buckets[bucket] = []
	_dirty_buckets[bucket].append(cell)


func reset() -> void:
	_sample_started = 0
	configurations.clear()
	batches = 0
	prepared_count = 0
	reused_count = 0
	invalidated_count = 0
	peak_workers = 0
	peak_concurrent_workers = 0
	finish(0)


func finish(decisions: int) -> void:
	if _sample_started > 0:
		var samples: Array = _sample_state.samples[_sample_mode]
		samples.append(float(Time.get_ticks_usec() - _sample_started) / maxi(1, decisions))
		_sample_state.round += 1
		if _sample_state.round >= TUNING_SAMPLES * _sample_state.choices.size():
			var serial: Array = _sample_state.samples[0]
			serial.sort()
			var best_time: float = serial[TUNING_SAMPLES / 2] * 0.97
			_sample_state.best = 0
			for choice: int in _sample_state.choices:
				var timings: Array = _sample_state.samples[choice]
				timings.sort()
				if timings[TUNING_SAMPLES / 2] < best_time:
					best_time = timings[TUNING_SAMPLES / 2]
					_sample_state.best = choice
	_sample_state = {}
	_sample_started = 0
	active = false
	_results.clear()
	_jobs.clear()
	_dirty.clear()
	_dirty_buckets.clear()
