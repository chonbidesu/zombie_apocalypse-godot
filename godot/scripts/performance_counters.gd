extends RefCounted
## Per-thread counters merged when a simulation batch is published.

var gameplay_usec: int = 0
var periodic_refresh_usec: int = 0
var periodic_refreshes: int = 0
var simulation_usec: int = 0
var clock_steps: int = 0
var backlog_steps: int = 0
var decision_usec: int = 0
var decisions: int = 0
var path_queries: int = 0
var ap_updates: int = 0
var ap_grants: int = 0
var ap_usec: int = 0
var forced_path_queries: int = 0
var forced_path_usec: int = 0


func add_simulation(other: RefCounted) -> void:
	simulation_usec += other.simulation_usec
	clock_steps += other.clock_steps
	decision_usec += other.decision_usec
	decisions += other.decisions
	path_queries += other.path_queries
	ap_updates += other.ap_updates
	ap_grants += other.ap_grants
	ap_usec += other.ap_usec
	forced_path_queries += other.forced_path_queries
	forced_path_usec += other.forced_path_usec


func reset() -> void:
	gameplay_usec = 0
	periodic_refresh_usec = 0
	periodic_refreshes = 0
	simulation_usec = 0
	clock_steps = 0
	backlog_steps = 0
	decision_usec = 0
	decisions = 0
	path_queries = 0
	ap_updates = 0
	ap_grants = 0
	ap_usec = 0
	forced_path_queries = 0
	forced_path_usec = 0
