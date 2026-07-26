extends RefCounted

var counters_enabled := false
var idle_skip_count := 0
var runtime_update_count := 0


func reset_counters_for_tests() -> void:
	counters_enabled = true
	idle_skip_count = 0
	runtime_update_count = 0


func get_idle_skip_count() -> int:
	return idle_skip_count


func get_runtime_update_count() -> int:
	return runtime_update_count


func record_idle_skip() -> void:
	if counters_enabled:
		idle_skip_count += 1


func record_runtime_update() -> void:
	if counters_enabled:
		runtime_update_count += 1


func can_skip_idle(skill_id: String, skill_state: Object, ball_active: bool, skill_runtime_host: Object) -> bool:
	if skill_state == null or bool(skill_state.windup_active):
		return false
	if _has_visible_effects_for_skill(skill_runtime_host, skill_id):
		return false
	# VISIBLE state is not the same question as LIVE state. A skill can keep
	# owner-facing state (boss slip / boss freeze), a pending self-schedule
	# (solar bolt refire, bubble trap queued shots) or a deferred release long
	# after its last particle dies. Skipping update() then freezes that timer
	# for the whole remaining cooldown while every consumer outside this gate
	# keeps polling the stale state -- the Banana Slice "boss slides into a wall
	# and never recovers" class. `is_launch_blocked` is already the host's
	# per-skill liveness map (it answers "is this skill still running?"), so
	# reuse it instead of asking every skill to remember to fold live state
	# into a predicate named "visible".
	if _has_live_runtime_state(skill_runtime_host, skill_id):
		return false
	if float(skill_state.cooldown) > 0.0:
		return true
	return not ball_active


func _has_visible_effects_for_skill(skill_runtime_host: Object, skill_id: String) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("has_visible_effects_for_skill"):
		return false
	return bool(skill_runtime_host.has_visible_effects_for_skill(skill_id))


func _has_live_runtime_state(skill_runtime_host: Object, skill_id: String) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("is_launch_blocked"):
		return false
	return bool(skill_runtime_host.is_launch_blocked(skill_id))
