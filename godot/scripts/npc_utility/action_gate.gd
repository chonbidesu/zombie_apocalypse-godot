extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const RECOVERY_STEPS: int = Catalog.CLOCK_STEPS_PER_MINUTE
const AP_INTERVAL_STEPS: int = Catalog.RECOVERY_MINUTES * Catalog.CLOCK_STEPS_PER_MINUTE


static func can_act(ap: int, action_cost: int, now_step: int, ready_step: int) -> bool:
	return action_cost >= 0 and ap >= action_cost and now_step >= ready_step


static func ready_after_action(now_step: int) -> int:
	return now_step + RECOVERY_STEPS


# Count the existing global AP boundaries since the actor's last AP sync.
@warning_ignore("integer_division")
static func ap_at(ap: int, synced_step: int, now_step: int) -> int:
	var gained: int = now_step / AP_INTERVAL_STEPS - synced_step / AP_INTERVAL_STEPS
	return mini(Catalog.AP_CAP, ap + gained)


# The scheduler supplies unique, due IDs and the current cheapest eligible
# command per ID. -1 means no eligible command. The caller owns the buffers.
static func collect_ready(
	now_step: int,
	due_ids: PackedInt32Array,
	ap_by_id: PackedByteArray,
	min_cost_by_id: PackedInt32Array,
	ready_by_id: PackedInt64Array,
	ready_ids: PackedInt32Array
) -> int:
	assert(ready_ids.size() >= due_ids.size())
	var count: int = 0
	for actor_id in due_ids:
		var cost: int = min_cost_by_id[actor_id]
		if cost >= 0 and ap_by_id[actor_id] >= cost and now_step >= ready_by_id[actor_id]:
			ready_ids[count] = actor_id
			count += 1
	return count
