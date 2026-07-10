extends RefCounted

const PATH_INVALID := "invalid"
const PATH_RING_CORE := "ring_core"
const PATH_INSTANT := "instant"
const PATH_UNLOCK := "unlock"
const PATH_LEVEL := "level"

const CALLBACK_BUILD_RING_CORE_UPDATE := "build_ring_core_update"
const CALLBACK_BUILD_INSTANT_UPDATE := "build_instant_update"
const CALLBACK_BUILD_UNLOCK_UPDATE := "build_unlock_update"
const CALLBACK_BUILD_LEVEL_UPDATE := "build_level_update"
const CALLBACK_APPLY_CHOICE := "apply_choice"
const CALLBACK_APPLY_UNLOCK_CHOICE := "apply_unlock_choice"
const CALLBACK_APPLY_LEVEL_SIDE_EFFECT := "apply_level_side_effect"
const CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT := "apply_choice_feedback_result"
const CALLBACK_SYNC_OWNER := "sync_owner"
const DEFAULT_RING_CORE_CHOICE_ID := "lingpet_ring_core_upgrade"
const DEFAULT_LEVEL_FEEDBACK_TIMER := 1.1


func build_grant_callbacks(
	runtime_state: Object,
	level_side_effects: Object,
	instant_rewards: Object,
	lingpet_rewards: Object
) -> Dictionary:
	var callbacks: Dictionary = {}
	if lingpet_rewards != null:
		callbacks[CALLBACK_BUILD_RING_CORE_UPDATE] = Callable(lingpet_rewards, "build_debug_ring_core_upgrade_update")
	if instant_rewards != null:
		callbacks[CALLBACK_BUILD_INSTANT_UPDATE] = Callable(instant_rewards, "build_debug_instant_choice_update")
	if level_side_effects != null:
		callbacks[CALLBACK_BUILD_UNLOCK_UPDATE] = Callable(level_side_effects, "build_debug_unlock_choice_update")
		callbacks[CALLBACK_BUILD_LEVEL_UPDATE] = Callable(level_side_effects, "build_debug_level_update")
	if runtime_state != null:
		callbacks[CALLBACK_APPLY_CHOICE] = Callable(runtime_state, "apply_choice")
		callbacks[CALLBACK_APPLY_UNLOCK_CHOICE] = Callable(runtime_state, "_apply_unlock_choice")
		callbacks[CALLBACK_APPLY_LEVEL_SIDE_EFFECT] = Callable(runtime_state, "_apply_level_side_effect")
		callbacks[CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT] = Callable(runtime_state, "_apply_choice_feedback_result")
		callbacks[CALLBACK_SYNC_OWNER] = Callable(runtime_state, "_sync_owner")
	return callbacks


func build_grant_callbacks_from_runtime_state(runtime_state: Object) -> Dictionary:
	return build_grant_callbacks(
		runtime_state,
		_get_runtime_state_object(runtime_state, "_level_side_effects"),
		_get_runtime_state_object(runtime_state, "_instant_rewards"),
		_get_runtime_state_object(runtime_state, "_lingpet_rewards")
	)


func build_path(perk_id: String, perk_data: Dictionary, ring_core_choice_id: String) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or perk_data.is_empty():
		return {
			"accepted": false,
			"path": PATH_INVALID,
			"choice_id": clean_id,
		}
	if clean_id == ring_core_choice_id:
		return _accepted_path(clean_id, PATH_RING_CORE)
	if bool(perk_data.get("is_instant", false)) or clean_id == "convert_to_gold" or int(perk_data.get("max_level", 1)) <= 0:
		return _accepted_path(clean_id, PATH_INSTANT)
	if str(perk_data.get("unlocks_skill", "")) != "":
		return _accepted_path(clean_id, PATH_UNLOCK)
	return _accepted_path(clean_id, PATH_LEVEL)


func build_choice_data_patch(path: String, update: Dictionary, fallback_level: int = 0) -> Dictionary:
	if not bool(update.get("accepted", false)):
		return {"accepted": false}
	var patch: Dictionary = {}
	match path:
		PATH_RING_CORE:
			patch["next_tier"] = int(update.get("next_tier", fallback_level))
		PATH_INSTANT:
			patch["current_level"] = int(update.get("current_level", 0))
			patch["next_level"] = int(update.get("next_level", 0))
		PATH_UNLOCK:
			patch["current_level"] = int(update.get("current_level", 0))
			patch["next_level"] = int(update.get("next_level", fallback_level))
		PATH_LEVEL:
			var level: int = int(update.get("next_level", fallback_level))
			patch["current_level"] = int(update.get("current_level", max(0, level - 1)))
			patch["next_level"] = level
		_:
			return {"accepted": false}
	return {
		"accepted": true,
		"patch": patch,
	}


func build_post_apply_update(perk_id: String) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "":
		return {"accepted": false}
	return {
		"accepted": true,
		"last_selected_id": clean_id,
		"sync_owner": true,
	}


func apply_choice_data_patch(data: Dictionary, patch_result: Dictionary) -> bool:
	if not bool(patch_result.get("accepted", false)):
		return false
	var patch: Dictionary = _get_dict(patch_result.get("patch", {}))
	for key in patch.keys():
		data[key] = patch[key]
	return true


func apply_choice_data_update(
	data: Dictionary,
	path: String,
	update: Dictionary,
	fallback_level: int = 0
) -> Dictionary:
	var patch_result: Dictionary = build_choice_data_patch(path, update, fallback_level)
	if not apply_choice_data_patch(data, patch_result):
		return {"accepted": false}
	return patch_result


func build_runtime_level_patch_update(
	perk_id: String,
	patch_result: Dictionary,
	fallback_level: int = 1
) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or not bool(patch_result.get("accepted", false)):
		return {"accepted": false}
	var patch: Dictionary = _get_dict(patch_result.get("patch", {}))
	return {
		"accepted": true,
		"perk_id": clean_id,
		"level": int(patch.get("next_level", fallback_level)),
	}


func apply_runtime_level_patch(runtime_skill_levels: Dictionary, update: Dictionary) -> Dictionary:
	if not bool(update.get("accepted", false)):
		return {"accepted": false}
	var clean_id: String = str(update.get("perk_id", "")).strip_edges()
	if clean_id == "":
		return {"accepted": false}
	var level: int = int(update.get("level", 1))
	runtime_skill_levels[clean_id] = level
	return {
		"accepted": true,
		"perk_id": clean_id,
		"level": level,
	}


func apply_post_apply_update(
	runtime_state: Object,
	owner: Object,
	update: Dictionary,
	sync_owner: Callable
) -> bool:
	if runtime_state == null or not bool(update.get("accepted", false)):
		return false
	runtime_state.set("last_selected_id", str(update.get("last_selected_id", runtime_state.get("last_selected_id"))))
	if bool(update.get("sync_owner", false)) and sync_owner.is_valid():
		sync_owner.call(owner)
	return true


func apply_post_apply_for_perk(
	runtime_state: Object,
	owner: Object,
	perk_id: String,
	sync_owner: Callable
) -> bool:
	return apply_post_apply_update(runtime_state, owner, build_post_apply_update(perk_id), sync_owner)


func apply_debug_grant_from_runtime_state(
	runtime_state: Object,
	perk_id: String,
	target_level: int,
	owner: Object,
	registry: Object,
	catalog: Object
) -> Dictionary:
	return apply_debug_grant(
		runtime_state,
		perk_id,
		target_level,
		owner,
		registry,
		catalog,
		_get_runtime_state_dict(runtime_state, "runtime_skill_levels"),
		DEFAULT_RING_CORE_CHOICE_ID,
		_get_level_feedback_timer(_get_runtime_state_object(runtime_state, "_level_side_effects")),
		build_grant_callbacks_from_runtime_state(runtime_state)
	)


func apply_debug_grant(
	runtime_state: Object,
	perk_id: String,
	target_level: int,
	owner: Object,
	registry: Object,
	catalog: Object,
	runtime_skill_levels: Dictionary,
	ring_core_choice_id: String,
	level_feedback_timer: float,
	callbacks: Dictionary
) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "":
		return {"accepted": false, "blocked_reason": "blank_perk_id"}
	var data: Dictionary = _get_catalog_perk_data(catalog, clean_id)
	if data.is_empty():
		return {"accepted": false, "blocked_reason": "missing_perk_data", "choice_id": clean_id}
	data["id"] = clean_id

	var path_payload: Dictionary = build_path(clean_id, data, ring_core_choice_id)
	if not bool(path_payload.get("accepted", false)):
		return path_payload
	var debug_path: String = str(path_payload.get("path", PATH_INVALID))
	if debug_path == PATH_LEVEL and str(data.get("rarity", "")).to_lower() == "mythic":
		var max_level: int = maxi(1, int(data.get("max_level", 1)))
		var clamped_target: int = clampi(target_level, 1, max_level)
		var current_level: int = int(runtime_skill_levels.get(clean_id, 0))
		# Mythic debug grants travel through the normal choice path so first
		# acquisition keeps its cinematic and item-specific lifecycle. Reapplying
		# the exact same level must stay a true no-op; otherwise it replays the
		# acquisition cinematic even though ownership did not change.
		if current_level == clamped_target:
			return {
				"accepted": true,
				"choice_id": clean_id,
				"path": debug_path,
				"level": current_level,
				"unchanged": true,
			}
	match debug_path:
		PATH_RING_CORE:
			return _apply_choice_debug_grant(
				runtime_state,
				clean_id,
				data,
				debug_path,
				_call_update(callbacks, CALLBACK_BUILD_RING_CORE_UPDATE, [clean_id, target_level, data]),
				target_level,
				owner,
				registry,
				callbacks
			)
		PATH_INSTANT:
			return _apply_choice_debug_grant(
				runtime_state,
				clean_id,
				data,
				debug_path,
				_call_update(callbacks, CALLBACK_BUILD_INSTANT_UPDATE, [clean_id, data]),
				0,
				owner,
				registry,
				callbacks
			)
		PATH_UNLOCK:
			return _apply_unlock_debug_grant(
				runtime_state,
				clean_id,
				data,
				debug_path,
				_call_update(callbacks, CALLBACK_BUILD_UNLOCK_UPDATE, [clean_id, target_level, data]),
				owner,
				registry,
				callbacks
			)
		PATH_LEVEL:
			if str(data.get("rarity", "")).to_lower() == "mythic":
				return _apply_choice_debug_grant(
					runtime_state,
					clean_id,
					data,
					debug_path,
					_call_update(callbacks, CALLBACK_BUILD_LEVEL_UPDATE, [clean_id, target_level, data]),
					target_level,
					owner,
					registry,
					callbacks
				)
			return _apply_level_debug_grant(
				runtime_state,
				clean_id,
				data,
				_call_update(callbacks, CALLBACK_BUILD_LEVEL_UPDATE, [clean_id, target_level, data]),
				runtime_skill_levels,
				owner,
				registry,
				level_feedback_timer,
				callbacks
			)
	return {"accepted": false, "blocked_reason": "invalid_debug_path", "choice_id": clean_id}


func _accepted_path(choice_id: String, path: String) -> Dictionary:
	return {
		"accepted": true,
		"path": path,
		"choice_id": choice_id,
	}


func _apply_choice_debug_grant(
	runtime_state: Object,
	clean_id: String,
	data: Dictionary,
	debug_path: String,
	update: Dictionary,
	fallback_level: int,
	owner: Object,
	registry: Object,
	callbacks: Dictionary
) -> Dictionary:
	if not bool(apply_choice_data_update(data, debug_path, update, fallback_level).get("accepted", false)):
		return {"accepted": false, "blocked_reason": "choice_data_update_failed", "choice_id": clean_id}
	var apply_result: Dictionary = _call_bool(callbacks, CALLBACK_APPLY_CHOICE, [data, owner, registry])
	if not bool(apply_result.get("accepted", false)):
		return apply_result
	if not apply_post_apply_for_perk(runtime_state, owner, clean_id, _get_callback(callbacks, CALLBACK_SYNC_OWNER)):
		return {"accepted": false, "blocked_reason": "post_apply_failed", "choice_id": clean_id}
	return {"accepted": true, "choice_id": clean_id, "path": debug_path}


func _apply_unlock_debug_grant(
	runtime_state: Object,
	clean_id: String,
	data: Dictionary,
	debug_path: String,
	update: Dictionary,
	owner: Object,
	registry: Object,
	callbacks: Dictionary
) -> Dictionary:
	if not bool(apply_choice_data_update(data, debug_path, update, 1).get("accepted", false)):
		return {"accepted": false, "blocked_reason": "choice_data_update_failed", "choice_id": clean_id}
	var apply_result: Dictionary = _call_bool(callbacks, CALLBACK_APPLY_UNLOCK_CHOICE, [data, owner, registry])
	if not bool(apply_result.get("accepted", false)):
		return apply_result
	if not apply_post_apply_for_perk(runtime_state, owner, clean_id, _get_callback(callbacks, CALLBACK_SYNC_OWNER)):
		return {"accepted": false, "blocked_reason": "post_apply_failed", "choice_id": clean_id}
	return {"accepted": true, "choice_id": clean_id, "path": debug_path}


func _apply_level_debug_grant(
	runtime_state: Object,
	clean_id: String,
	data: Dictionary,
	update: Dictionary,
	runtime_skill_levels: Dictionary,
	owner: Object,
	registry: Object,
	level_feedback_timer: float,
	callbacks: Dictionary
) -> Dictionary:
	var patch_result: Dictionary = apply_choice_data_update(data, PATH_LEVEL, update, 1)
	if not bool(patch_result.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "choice_data_update_failed", "choice_id": clean_id}
	var level_patch: Dictionary = build_runtime_level_patch_update(clean_id, patch_result, 1)
	var runtime_level_result: Dictionary = apply_runtime_level_patch(runtime_skill_levels, level_patch)
	if not bool(runtime_level_result.get("accepted", false)):
		return runtime_level_result
	var side_effect_result: Dictionary = _call_optional(callbacks, CALLBACK_APPLY_LEVEL_SIDE_EFFECT, [data, owner, registry])
	if not bool(side_effect_result.get("accepted", false)):
		return side_effect_result
	var feedback_result: Dictionary = _call_bool(
		callbacks,
		CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT,
		[update, data, level_feedback_timer]
	)
	if not bool(feedback_result.get("accepted", false)):
		return feedback_result
	if not apply_post_apply_for_perk(runtime_state, owner, clean_id, _get_callback(callbacks, CALLBACK_SYNC_OWNER)):
		return {"accepted": false, "blocked_reason": "post_apply_failed", "choice_id": clean_id}
	return {
		"accepted": true,
		"choice_id": clean_id,
		"path": PATH_LEVEL,
		"level": int(runtime_level_result.get("level", 1)),
	}


func _get_catalog_perk_data(catalog: Object, perk_id: String) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_data"):
		return {}
	var value: Variant = catalog.get_perk_data(perk_id)
	if value is Dictionary:
		return value as Dictionary
	return {}


func _call_update(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		return result
	return {"accepted": bool(result)}


func _call_bool(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		return result
	return {"accepted": bool(result)}


func _call_optional(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		if result.has("accepted"):
			return result
		result["accepted"] = true
		return result
	return {"accepted": true}


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


func _get_level_feedback_timer(level_side_effects: Object) -> float:
	if level_side_effects == null:
		return DEFAULT_LEVEL_FEEDBACK_TIMER
	var value: Variant = level_side_effects.get("LEVEL_FEEDBACK_TIMER")
	if value == null:
		return DEFAULT_LEVEL_FEEDBACK_TIMER
	return float(value)


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null


func _get_runtime_state_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get(key)
	if value is Dictionary:
		return value
	return {}


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
