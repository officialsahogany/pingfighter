extends RefCounted

const LingpetRuntimeVectorResolver := preload("res://scripts/lingpet/lingpet_runtime_vector_resolver.gd")

var _vector_resolver: Object = LingpetRuntimeVectorResolver.new()


func apply(
	snapshot: Dictionary,
	owner: Object,
	registry: Object,
	host: Object,
	collection_state: Object,
	loadout_state: Object,
	planner: Object,
	default_pet_id: String,
	state_none: String,
	state_egg: String,
	state_companion: String,
	callbacks: Dictionary = {}
) -> Dictionary:
	if host == null:
		return {
			"restored": false,
			"reason": "missing_host",
		}
	if host.has_method("reset_for_tests"):
		host.call("reset_for_tests")
	if snapshot.is_empty():
		_sync_owner(host, owner, registry)
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	# reset_for_tests() above wiped the run-scoped affinity progression. Re-import it
	# from the snapshot BEFORE restoring pet_id/state/loadout so the downstream profile
	# and owner sync surface the restored per-pet affinity + run-global ring core tier.
	# Absent on minimal/legacy snapshots (e.g. the volatile-reset egg snapshot) -> stays
	# a fresh run, which is the intended per-run reset.
	var affinity_run_state: Variant = snapshot.get("affinity_run_state", {})
	if affinity_run_state is Dictionary and not (affinity_run_state as Dictionary).is_empty() and host.has_method("import_affinity_run_state"):
		host.call("import_affinity_run_state", affinity_run_state)

	_set_current_pet_id(host, str(snapshot.get("pet_id", default_pet_id)))
	if loadout_state != null and loadout_state.has_method("set_loadouts"):
		loadout_state.set_loadouts(snapshot.get("lingpet_loadouts", snapshot.get("ringpet_loadouts", {})))
	var restored_state := _normalize_state(str(snapshot.get("state", state_none)), state_none, state_egg, state_companion)
	var current_pet_id := str(host.get("_pet_id"))
	var restore_plan: Dictionary = planner.build_plan(snapshot, owner, collection_state, current_pet_id, restored_state) if planner != null and planner.has_method("build_plan") else {}
	var restore_reason := str(restore_plan.get("restore_reason", "ok"))
	_set_current_pet_id(host, str(restore_plan.get("pet_id", current_pet_id)))
	var target_state := str(restore_plan.get("target_state", state_none))
	if target_state == state_companion:
		_apply_companion_restore(host, snapshot, owner, registry, state_companion, callbacks)
	elif target_state == state_egg and bool(restore_plan.get("spawn_fresh_egg", false)):
		if host.has_method("_spawn_egg"):
			host.call("_spawn_egg", owner)
	else:
		_call_void(callbacks.get("clear_field_state", null))
	if target_state == state_companion or target_state == state_egg:
		_restore_egg_color_index(host, snapshot)
		_restore_egg_required_hits(host, snapshot)
	if owner != null:
		if str(host.get("_state")) == state_companion and collection_state != null and collection_state.has_method("ensure_pet_active_slot"):
			collection_state.ensure_pet_active_slot(owner, str(host.get("_pet_id")))
		# Preserve the runtime's historical final-sync call shape: final restore
		# sync does not forward registry, while empty-snapshot sync still does.
		_sync_owner(host, owner, null)
	return {
		"restored": true,
		"reason": restore_reason,
		"state": str(host.get("_state")),
		"owned_pet_ids": collection_state.get_owned_pet_ids() if collection_state != null and collection_state.has_method("get_owned_pet_ids") else [],
	}


func _apply_companion_restore(host: Object, snapshot: Dictionary, owner: Object, registry: Object, state_companion: String, callbacks: Dictionary) -> void:
	host.set("_state", state_companion)
	if host.has_method("_apply_current_loadout"):
		host.call("_apply_current_loadout", owner, true, false, registry)
	var egg_state: Object = host.get("_egg_state")
	if egg_state != null and egg_state.has_method("set_hatched") and host.has_method("_get_current_required_hits"):
		egg_state.set_hatched(int(host.call("_get_current_required_hits")))
	var companion_fallback := Vector2.ZERO
	var companion_pos: Vector2 = _vector_resolver.vector2_or_fallback(snapshot.get("companion_pos", companion_fallback), companion_fallback)
	host.set("_companion_pos", companion_pos)
	var motion_state: Object = host.get("_companion_motion_state")
	if motion_state != null:
		motion_state.set("pos", companion_pos)
	_call_void(callbacks.get("restore_companion_patrol", null), [snapshot])
	if owner != null and host.has_method("_initialize_companion_patrol"):
		host.call("_initialize_companion_patrol", owner, companion_pos == Vector2.ZERO)


func _restore_egg_required_hits(host: Object, snapshot: Dictionary) -> void:
	if not snapshot.has("required_hits"):
		return
	var required_hits := int(snapshot.get("required_hits", 0))
	# 0 / negative is the "unrolled" sentinel (fresh-run reset snapshots) — keep
	# the fresh spawn's own roll instead of forcing a value.
	if required_hits < 1:
		return
	var egg_state: Object = host.get("_egg_state")
	if egg_state != null and egg_state.has_method("set_required_hits"):
		egg_state.set_required_hits(required_hits)


func _restore_egg_color_index(host: Object, snapshot: Dictionary) -> void:
	if not snapshot.has("egg_color_index"):
		return
	var color_index := int(snapshot.get("egg_color_index", -1))
	if color_index < 0:
		return
	var egg_state: Object = host.get("_egg_state")
	if egg_state != null and egg_state.has_method("set_color_index"):
		egg_state.set_color_index(color_index)


func _set_current_pet_id(host: Object, pet_id: String) -> void:
	if host.has_method("_set_current_pet_id"):
		host.call("_set_current_pet_id", pet_id)
	else:
		host.set("_pet_id", pet_id)


func _normalize_state(value: String, state_none: String, state_egg: String, state_companion: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == state_egg or normalized == "hatching" or normalized == "알":
		return state_egg
	if normalized == state_companion or normalized == "active" or normalized == "owned" or normalized == "hatched" or normalized == "동행":
		return state_companion
	return state_none


func _sync_owner(host: Object, owner: Object, registry: Object) -> void:
	if owner == null or not host.has_method("_sync_owner"):
		return
	if registry != null:
		host.call("_sync_owner", owner, registry)
	else:
		host.call("_sync_owner", owner)


func _call_void(callback: Variant, args: Array = []) -> void:
	if typeof(callback) != TYPE_CALLABLE:
		return
	var callable: Callable = callback
	if callable.is_valid():
		callable.callv(args)
