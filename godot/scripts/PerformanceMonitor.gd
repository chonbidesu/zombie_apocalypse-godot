extends CanvasLayer
## F9 toggles an in-game capture. Headless callers use start() and stop().

const Sim = preload("res://scripts/simulation.gd")
const Counters = preload("res://scripts/performance_counters.gd")
const Catalog = preload("res://scripts/catalog.gd")
const SAMPLE_USEC: int = 1_000_000
const FRAME_BUCKET_USEC: int = 250
const FRAME_OVERFLOW_BUCKET: int = 16_385
const OUTPUT_DIR: String = "user://benchmarks"
const CSV_HEADER: String = (
	"sample,scenario,seed,blocks,npcs,warp,setup_ms,wall_s,sim_minute,frames,"
	+ "fps,engine_process_ms,mean_wall_frame_ms,peak_wall_frame_ms,peak_frame,"
	+ "engine_physics_ms,script_ms,peak_script_ms,simulation_ms,peak_simulation_ms,clock_steps,decisions,"
	+ "decision_mean_us,npc_actions,path_queries,path_queries_per_frame,peak_path_queries,"
	+ "ap_updates,ap_grants,ap_ms,forced_path_queries,forced_path_ms,"
	+ "static_memory_bytes,static_peak_bytes,dynamic_memory_bytes,nodes,orphan_nodes,"
	+ "frame_budget_ms,max_steps_per_frame,peak_steps_per_frame,backlog_steps,peak_backlog_steps,"
	+ "achieved_warp,wall_frame_p95_ms,wall_frame_p99_ms,"
	+ "periodic_refreshes,periodic_refresh_ms,peak_periodic_refresh_ms"
)

var interactive_sim: Sim
var frame_budget_usec: int = 0
var max_steps_per_frame: int = 0
var total_decisions: int = 0
var total_steps: int = 0
var total_forced_queries: int = 0

var _sim: Sim
var _file: FileAccess
var _panel: PanelContainer
var _label: Label
var _frame: Counters = Counters.new()
var _window: Counters = Counters.new()
var _scenario: String
var _warp: float
var _setup_ms: float
var _start_usec: int
var _last_frame_usec: int
var _frame_count: int
var _wall_usec: int
var _peak_wall_usec: int
var _peak_frame: int
var _script_usec: int
var _peak_script_usec: int
var _peak_simulation_usec: int
var _peak_periodic_refresh_usec: int
var _peak_queries: int
var _peak_steps: int
var _backlog_steps: int
var _peak_backlog_steps: int
var _total_frames: int
var _frame_histogram: PackedInt32Array = PackedInt32Array()
var _last_actions: int
var _window_actions: int
var _end_minute: float
var _stop_requested: bool


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(interactive_sim != null)
	if interactive_sim == null:
		return
	layer = 100
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.hide()
	add_child(_panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or key.keycode != KEY_F9 or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if _file != null:
		_stop_requested = true
	else:
		start(interactive_sim)


func start(simulation: Sim, scenario: String = "gameplay", warp: float = 1.0, setup_ms: float = 0.0) -> bool:
	if _file != null or simulation.performance_counters != null:
		return false
	var directory: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("Cannot create benchmark directory %s (%s)." % [directory, error_string(error)])
		return false
	var path: String = "%s/performance-%d-%d.csv" % [directory, OS.get_process_id(), Time.get_ticks_usec()]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("Cannot open %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return false
	_file.store_line(CSV_HEADER)
	_sim = simulation
	_scenario = scenario
	_warp = warp
	_setup_ms = setup_ms
	_stop_requested = false
	_start_usec = 0
	_last_frame_usec = 0
	total_decisions = 0
	total_steps = 0
	total_forced_queries = 0
	_total_frames = 0
	_frame_histogram.resize(FRAME_OVERFLOW_BUCKET + 1)
	_frame_histogram.fill(0)
	_last_actions = int(_sim.metrics.npc_actions)
	_reset_window()
	_frame.reset()
	_sim.performance_counters = _frame
	if _panel != null:
		_label.text = "Collecting performance data…  [F9]"
		_panel.show()
	set_process(true)
	print("Performance CSV: ", path)
	return true


func stop() -> void:
	if _file == null:
		return
	_write_window("sample", _last_frame_usec)
	_file.close()
	_file = null
	_sim.performance_counters = null
	_sim = null
	set_process(false)
	if _panel != null:
		_panel.hide()


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_frame_usec == 0:
		_start_usec = now
	else:
		# This callback runs before the simulation. Counters belong to the frame
		# that just ended, as does the wall interval from the last callback.
		var is_burst: bool = _frame.forced_path_queries > 0
		if is_burst:
			_write_window("sample", _last_frame_usec)
		_accumulate(now - _last_frame_usec)
		if is_burst or _wall_usec >= SAMPLE_USEC:
			_write_window("burst" if is_burst else "sample", now)
	_last_frame_usec = now
	if _stop_requested:
		stop()


func _accumulate(wall_usec: int) -> void:
	_frame_count += 1
	_total_frames += 1
	_wall_usec += wall_usec
	@warning_ignore("integer_division")
	var bucket: int = mini((wall_usec + FRAME_BUCKET_USEC - 1) / FRAME_BUCKET_USEC, FRAME_OVERFLOW_BUCKET)
	_frame_histogram[bucket] += 1
	if wall_usec > _peak_wall_usec:
		_peak_wall_usec = wall_usec
		_peak_frame = Engine.get_process_frames() - 1
	var script_usec: int = _frame.gameplay_usec if interactive_sim != null else _frame.simulation_usec
	_script_usec += script_usec
	_peak_script_usec = maxi(_peak_script_usec, script_usec)
	_peak_simulation_usec = maxi(_peak_simulation_usec, _frame.simulation_usec)
	_peak_periodic_refresh_usec = maxi(_peak_periodic_refresh_usec, _frame.periodic_refresh_usec)
	_peak_queries = maxi(_peak_queries, _frame.path_queries)
	_peak_steps = maxi(_peak_steps, _frame.clock_steps)
	_backlog_steps = _frame.backlog_steps
	_peak_backlog_steps = maxi(_peak_backlog_steps, _backlog_steps)
	_window.simulation_usec += _frame.simulation_usec
	_window.periodic_refreshes += _frame.periodic_refreshes
	_window.periodic_refresh_usec += _frame.periodic_refresh_usec
	_window.clock_steps += _frame.clock_steps
	_window.decision_usec += _frame.decision_usec
	_window.decisions += _frame.decisions
	_window.path_queries += _frame.path_queries
	_window.ap_updates += _frame.ap_updates
	_window.ap_grants += _frame.ap_grants
	_window.ap_usec += _frame.ap_usec
	_window.forced_path_queries += _frame.forced_path_queries
	_window.forced_path_usec += _frame.forced_path_usec
	total_decisions += _frame.decisions
	total_steps += _frame.clock_steps
	total_forced_queries += _frame.forced_path_queries
	_end_minute = _sim.now()
	var actions: int = int(_sim.metrics.npc_actions)
	_window_actions += maxi(0, actions - _last_actions)
	_last_actions = actions
	_frame.reset()


func _write_window(sample: String, now: int) -> void:
	if _frame_count == 0:
		return
	var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
	var engine_process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var engine_physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var static_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var peak_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var frame_ms: float = _wall_usec / (1000.0 * _frame_count)
	var peak_ms: float = _peak_wall_usec / 1000.0
	var decision_us: float = float(_window.decision_usec) / maxi(1, _window.decisions)
	var queries_per_frame: float = float(_window.path_queries) / _frame_count
	var wall_s: float = (now - _start_usec) / 1_000_000.0
	var achieved_warp: float = float(total_steps) / (Catalog.CLOCK_STEPS_PER_MINUTE * maxf(wall_s, 0.000001))
	_file.store_csv_line(PackedStringArray([
		sample, _scenario, str(_sim.world_seed), str(_sim.blocks.size()), str(_sim.actors.size() - 1),
		str(_warp), "%.3f" % _setup_ms, "%.6f" % wall_s,
		"%.1f" % _end_minute, str(_frame_count), str(fps), "%.3f" % engine_process_ms, "%.3f" % frame_ms,
		"%.3f" % peak_ms, str(_peak_frame), "%.3f" % engine_physics_ms,
		"%.3f" % (_script_usec / 1000.0), "%.3f" % (_peak_script_usec / 1000.0),
		"%.3f" % (_window.simulation_usec / 1000.0), "%.3f" % (_peak_simulation_usec / 1000.0),
		str(_window.clock_steps), str(_window.decisions), "%.3f" % decision_us,
		str(_window_actions), str(_window.path_queries), "%.3f" % queries_per_frame,
		str(_peak_queries), str(_window.ap_updates), str(_window.ap_grants),
		"%.3f" % (_window.ap_usec / 1000.0), str(_window.forced_path_queries),
		"%.3f" % (_window.forced_path_usec / 1000.0),
		str(static_bytes), str(peak_bytes), "", str(nodes), str(orphans),
		"%.3f" % (frame_budget_usec / 1000.0), str(max_steps_per_frame), str(_peak_steps),
		str(_backlog_steps), str(_peak_backlog_steps), "%.3f" % achieved_warp,
		_wall_frame_percentile(0.95), _wall_frame_percentile(0.99),
		str(_window.periodic_refreshes), "%.3f" % (_window.periodic_refresh_usec / 1000.0),
		"%.3f" % (_peak_periodic_refresh_usec / 1000.0),
	]))
	if _label != null:
		_label.text = (
			"%d FPS | Frame %.2f ms (peak %.2f) | Engine physics %.2f ms  [F9]\n"
			+ "Script peak %.2f ms | Simulation peak %.2f ms | NPC planner %.1f µs/call (%d calls)\n"
			+ "Paths/frame %.2f (peak %d) | Nodes %d | Orphans %d\n"
			+ "Static %.1f MiB (peak %.1f) | Dynamic N/A"
		) % [
			fps, frame_ms, peak_ms, engine_physics_ms, _peak_script_usec / 1000.0,
			_peak_simulation_usec / 1000.0, decision_us,
			_window.decisions, queries_per_frame, _peak_queries, nodes, orphans,
			static_bytes / 1048576.0, peak_bytes / 1048576.0,
		]
	_reset_window()


func _wall_frame_percentile(fraction: float) -> String:
	var rank: int = ceili(_total_frames * fraction)
	var seen: int = 0
	for bucket in range(FRAME_OVERFLOW_BUCKET):
		seen += _frame_histogram[bucket]
		if seen >= rank:
			return "%.2f" % (bucket * FRAME_BUCKET_USEC / 1000.0)
	return ">4096"


func _reset_window() -> void:
	_window.reset()
	_frame_count = 0
	_wall_usec = 0
	_peak_wall_usec = 0
	_peak_frame = 0
	_script_usec = 0
	_peak_script_usec = 0
	_peak_simulation_usec = 0
	_peak_periodic_refresh_usec = 0
	_peak_queries = 0
	_peak_steps = 0
	_backlog_steps = 0
	_peak_backlog_steps = 0
	_window_actions = 0
