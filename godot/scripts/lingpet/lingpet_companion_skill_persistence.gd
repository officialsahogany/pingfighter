extends RefCounted

var state_by_pet_id: Dictionary = {}
var trigger_count := 0
var shared_cooldown := 0.0
# Tracks the last battle stage observed for persistent skill deployments
# (skeleton archers, bone barriers). -1 = not observed yet, so the first
# observation only adopts the stage number; later stage changes wipe deployed
# skill entities through the full runtime-host reset path.
var _last_seen_stage := -1


func reset_store() -> void:
	state_by_pet_id.clear()
	trigger_count = 0
	shared_cooldown = 0.0
	reset_stage_observer()


func get_trigger_count() -> int:
	return trigger_count


func get_shared_cooldown() -> float:
	return shared_cooldown


func get_last_seen_stage() -> int:
	return _last_seen_stage


func reset_stage_observer() -> void:
	_last_seen_stage = -1


func maybe_reset_runtime_transients_for_stage(
	stage: int,
	skill_states: Array,
	skill_runtime_host: Object,
	owner: Object = null,
	registry: Object = null
) -> bool:
	# Persistent lingpet skill deployments survive round boundaries through
	# reset_round(), but a stage transition must wipe them so they do not carry
	# into the next stage. Cooldowns, affinity, feed state, and companion state
	# are untouched; only deployed skill runtime entities are cleared.
	if stage == _last_seen_stage:
		return false
	var had_previous_stage := _last_seen_stage >= 0
	_last_seen_stage = stage
	if not had_previous_stage:
		return false
	reset_runtime_transients(skill_states, skill_runtime_host, owner, registry, false)
	return true


func save_current(pet_id: String, skill_states: Array) -> void:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id == "":
		return
	state_by_pet_id[normalized_pet_id] = build_persistent_snapshot(skill_states)


func restore_current(pet_id: String, skill_states: Array) -> bool:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id == "" or not state_by_pet_id.has(normalized_pet_id):
		reset_states(skill_states)
		_apply_shared_cooldown_to_current(skill_states)
		return false
	var snapshot: Variant = state_by_pet_id.get(normalized_pet_id, {})
	if not (snapshot is Dictionary):
		reset_states(skill_states)
		_apply_shared_cooldown_to_current(skill_states)
		return false
	var normalized := normalize_persistent_snapshot(snapshot as Dictionary, skill_states.size())
	for slot in range(skill_states.size()):
		var state: Object = skill_states[slot]
		if state != null and state.has_method("apply_persistent_snapshot"):
			state.apply_persistent_snapshot(normalized.get(slot_key(slot), {}) as Dictionary)
	_apply_shared_cooldown_to_current(skill_states)
	trigger_count = maxi(0, int(normalized.get("trigger_count", 0)))
	sync_shared_trigger_count(skill_states)
	return true


func advance_stored_cooldowns(delta: float, active_pet_id: String, companion_active: bool, slot_count: int) -> void:
	var safe_delta := maxf(0.0, delta)
	if safe_delta <= 0.0 or state_by_pet_id.is_empty():
		return
	var normalized_active_pet_id := active_pet_id.strip_edges().to_lower()
	for raw_pet_id in state_by_pet_id.keys():
		var pet_id := str(raw_pet_id)
		if companion_active and pet_id == normalized_active_pet_id:
			continue
		var snapshot: Variant = state_by_pet_id.get(raw_pet_id, {})
		if not (snapshot is Dictionary):
			continue
		var updated := normalize_persistent_snapshot(snapshot as Dictionary, slot_count)
		for slot in range(slot_count):
			var key := slot_key(slot)
			var slot_snapshot: Dictionary = updated.get(key, {}) as Dictionary
			var cooldown: float = maxf(0.0, float(slot_snapshot.get("cooldown", 0.0)) - safe_delta)
			slot_snapshot["cooldown"] = maxf(cooldown, shared_cooldown)
			updated[key] = slot_snapshot
		state_by_pet_id[raw_pet_id] = updated


func advance_states(delta: float, skill_states: Array) -> void:
	shared_cooldown = maxf(0.0, shared_cooldown - maxf(0.0, delta))
	for state in skill_states:
		if state != null and state.has_method("advance"):
			state.advance(delta)
	_apply_shared_cooldown_to_current(skill_states)


func cancel_windups(skill_states: Array) -> void:
	for state in skill_states:
		if state != null and state.has_method("cancel_windup"):
			state.cancel_windup()


func reset_round_transients(skill_states: Array) -> void:
	for state in skill_states:
		if state != null and state.has_method("reset_round_transients"):
			state.reset_round_transients()
	_apply_shared_cooldown_to_current(skill_states)
	sync_shared_trigger_count(skill_states)


func reset_runtime_transients(
	skill_states: Array,
	skill_runtime_host: Object,
	owner: Object = null,
	registry: Object = null,
	round_scope: bool = false
) -> void:
	# round_scope (per-round) lets skills that implement reset_round() persist
	# across the round boundary (Bone Barrier keeps installed barriers). The
	# full path (companion change / hatch / new battle / tests) still wipes all.
	cancel_windups(skill_states)
	if skill_runtime_host == null:
		return
	if round_scope:
		skill_runtime_host.reset_round(owner, registry)
	else:
		skill_runtime_host.reset(owner, registry)


func reset_states(skill_states: Array) -> void:
	for state in skill_states:
		if state != null and state.has_method("reset_all"):
			state.reset_all()
	trigger_count = 0
	sync_shared_trigger_count(skill_states)


func build_persistent_snapshot(skill_states: Array) -> Dictionary:
	var snapshot := {
		"trigger_count": trigger_count,
	}
	for slot in range(skill_states.size()):
		var state: Object = skill_states[slot]
		snapshot[slot_key(slot)] = state.get_persistent_snapshot() if state != null and state.has_method("get_persistent_snapshot") else empty_state_snapshot()
	return snapshot


func normalize_persistent_snapshot(snapshot: Dictionary, slot_count: int) -> Dictionary:
	var normalized := {
		"trigger_count": maxi(0, int(snapshot.get("trigger_count", 0))),
	}
	var has_nested := false
	for slot in range(slot_count):
		if snapshot.has(slot_key(slot)):
			has_nested = true
			break
	if has_nested:
		for slot in range(slot_count):
			var key := slot_key(slot)
			var slot_snapshot: Variant = snapshot.get(key, {})
			normalized[key] = (slot_snapshot as Dictionary).duplicate(true) if slot_snapshot is Dictionary else empty_state_snapshot()
		return normalized
	if slot_count > 0:
		normalized["slot_0"] = snapshot.duplicate(true)
	for slot in range(1, slot_count):
		normalized[slot_key(slot)] = empty_state_snapshot()
	normalized["trigger_count"] = maxi(0, int(snapshot.get("trigger_count", snapshot.get("trigger_count_0", 0))))
	return normalized


func empty_state_snapshot() -> Dictionary:
	return {
		"cooldown": 0.0,
		"trigger_count": 0,
		"last_gain": 0.0,
		"origin": Vector2.ZERO,
	}


func slot_key(slot_index: int) -> String:
	return "slot_%d" % maxi(0, slot_index)


func get_state_for_slot(skill_states: Array, slot_index: int) -> Object:
	if skill_states.is_empty():
		return null
	return skill_states[clampi(slot_index, 0, skill_states.size() - 1)]


func sync_shared_trigger_count(skill_states: Array) -> void:
	for state in skill_states:
		if state != null:
			state.trigger_count = trigger_count


func record_launch(slot_index: int, skill_states: Array) -> void:
	var state: Object = get_state_for_slot(skill_states, slot_index)
	trigger_count = maxi(trigger_count + 1, int(state.trigger_count) if state != null else 0)
	sync_shared_trigger_count(skill_states)


func start_shared_cooldown(cooldown_seconds: float, skill_states: Array) -> void:
	shared_cooldown = maxf(shared_cooldown, maxf(0.0, cooldown_seconds))
	if shared_cooldown <= 0.0:
		return
	_apply_shared_cooldown_to_current(skill_states)
	_apply_shared_cooldown_to_store(skill_states.size())


func is_any_winding_up(skill_states: Array) -> bool:
	for state in skill_states:
		if state != null and bool(state.windup_active):
			return true
	return false


func _apply_shared_cooldown_to_current(skill_states: Array) -> void:
	if shared_cooldown <= 0.0:
		return
	for state in skill_states:
		if state != null:
			state.cooldown = maxf(float(state.cooldown), shared_cooldown)


func _apply_shared_cooldown_to_store(slot_count: int) -> void:
	if shared_cooldown <= 0.0 or state_by_pet_id.is_empty():
		return
	for raw_pet_id in state_by_pet_id.keys():
		var snapshot: Variant = state_by_pet_id.get(raw_pet_id, {})
		if not (snapshot is Dictionary):
			continue
		var updated := normalize_persistent_snapshot(snapshot as Dictionary, slot_count)
		for slot in range(slot_count):
			var key := slot_key(slot)
			var slot_snapshot: Dictionary = updated.get(key, {}) as Dictionary
			slot_snapshot["cooldown"] = maxf(float(slot_snapshot.get("cooldown", 0.0)), shared_cooldown)
			updated[key] = slot_snapshot
		state_by_pet_id[raw_pet_id] = updated
