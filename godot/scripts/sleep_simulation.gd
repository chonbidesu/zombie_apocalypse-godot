extends RefCounted
## Owns recovery work between UI updates. Sleep reads published progress only.

const Sim = preload("res://scripts/simulation.gd")
const Counters = preload("res://scripts/performance_counters.gd")
const SLICE_USEC = 8_000

var _thread := Thread.new()
var _mutex := Mutex.new()
var _stop := false
var _update: Dictionary = {}
var _messages: Array = []
var _effects: Array = []
var _published_effects: Array = []
var _pending_counters := Counters.new()
var paused_at_usec: int
var rest_snapshots_enabled: bool = true
var _last_view_usec: int
var _view_actor_ids: Dictionary[int, bool] = {}


func is_started() -> bool:
	return _thread.is_started()


func is_alive() -> bool:
	return _thread.is_alive()


func start(sim: Sim, elapsed: float) -> Error:
	_stop = false
	_last_view_usec = 0
	_view_actor_ids.clear()
	return _thread.start(_run.bind(sim, elapsed, Time.get_ticks_usec()))


func join() -> float:
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	var result: Dictionary = _thread.wait_to_finish()
	paused_at_usec = result.paused_at
	return result.remaining


func record_damage(amount: int, human: bool) -> void:
	_effects.append([amount, human])


func record_sound(effect: String) -> void:
	_effects.append(effect)


func take_update(counters: Counters) -> Dictionary:
	_mutex.lock()
	var update: Dictionary = _update
	if not update.is_empty():
		update.messages = _messages
		update.effects = _published_effects
		_messages = []
		_published_effects = []
		_update = {}
	if counters != null:
		counters.add_simulation(_pending_counters)
		_pending_counters.reset()
	_mutex.unlock()
	return update


func _rest_view(sim: Sim, now: int) -> Dictionary:
	if sim.sleeping or not rest_snapshots_enabled or now - _last_view_usec < 250_000: return {}
	_last_view_usec = now
	var p: Dictionary = sim.player()
	var blocks: Dictionary[int, Dictionary] = {}
	var actors: Dictionary[int, Dictionary] = {}
	var ids: Dictionary[int, bool] = {0: true}
	# The minimap needs its halo and connected building footprints. Copy three
	# squares in each direction; distant geometry stays in the UI copy.
	for y in range(maxi(0, p.y - 3), mini(sim.height, p.y + 4)):
		for x in range(maxi(0, p.x - 3), mini(sim.width, p.x + 4)):
			var site: Dictionary = sim.block_at(x, y)
			blocks[site.id] = site.duplicate(true)
			for id: int in sim.spatial.get(site.id, []): ids[id] = true
	if p.trail_from >= 0: ids[p.trail_from] = true
	for id: int in _view_actor_ids: actors[id] = sim.actors[id].duplicate(true)
	for id: int in ids: actors[id] = sim.actors[id].duplicate(true)
	_view_actor_ids = ids
	return {"blocks": blocks, "actors": actors, "minute": sim.minute, "clock_step": sim.clock_step,
		"clock_fraction": sim.clock_fraction, "resting": sim.resting, "rest_target": sim.rest_target,
		"notice": sim.last_rest_notice}


static func progress(sim: Sim) -> Dictionary:
	var p := sim.player()
	return {"clock_step": sim.clock_step, "time_text": sim.time_text(),
		"sleeping": sim.sleeping, "target": sim.rest_target,
		"seed": sim.world_seed, "blocks": sim.blocks.size(), "npcs": sim.actors.size() - 1,
		"npc_actions": int(sim.metrics.npc_actions), "ap": int(p.ap), "hp": int(p.hp),
		"max_hp": sim.max_hp(p), "xp": int(p.xp), "human": p.human, "down": p.down,
		"job": p.job, "sex": p.get("sex", "")}


func _stop_requested() -> bool:
	_mutex.lock()
	var requested: bool = _stop
	_mutex.unlock()
	return requested


func _run(sim: Sim, elapsed: float, last_usec: int) -> Dictionary:
	var last_event: int = sim.event_sequence
	var counters := sim.performance_counters
	while sim.resting and not _stop_requested():
		var now: int = Time.get_ticks_usec()
		elapsed += (now - last_usec) / 1_000_000.0
		last_usec = now
		elapsed = sim.elapse_sleep(elapsed, SLICE_USEC, _stop_requested)
		var update := progress(sim)
		var view := _rest_view(sim, Time.get_ticks_usec())
		# Events are copied before returning to the live world. Keep the same
		# bounded history if the renderer misses several publications.
		var event_count: int = mini(sim.event_sequence - last_event, sim.messages.size())
		var events := sim.messages.slice(sim.messages.size() - event_count).duplicate(true)
		last_event = sim.event_sequence
		_mutex.lock()
		# Preserve a snapshot until the UI consumes it, even if another progress
		# publication arrives before the next presentation refresh.
		if view.is_empty() and _update.has("view"): view = _update.view
		if not view.is_empty(): update.view = view
		_update = update
		_messages.append_array(events)
		_published_effects.append_array(_effects)
		_effects.clear()
		if _messages.size() > 1000:
			_messages = _messages.slice(-1000)
		if counters != null:
			_pending_counters.add_simulation(counters)
			counters.reset()
		_mutex.unlock()
		if elapsed <= 0.0 and sim.resting:
			OS.delay_usec(1_000)
	var stopped: int = Time.get_ticks_usec()
	var remaining: float = elapsed + (stopped - last_usec) / 1_000_000.0 if sim.resting else 0.0
	return {"remaining": remaining, "paused_at": stopped}
