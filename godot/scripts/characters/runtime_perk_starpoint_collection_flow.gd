extends RefCounted

const CALLBACK_GET_INSTANCE := "get_instance"
const CALLBACK_CAPTURE_RESUME_PRE_CHOICE_VELOCITY := "capture_resume_pre_choice_velocity"
const CALLBACK_OPEN_NEXT_CHOICE := "open_next_choice"
const CALLBACK_CLEAR_RESUME_PRE_CHOICE := "clear_resume_pre_choice"
const CALLBACK_SYNC_OWNER := "sync_owner"
const DEFAULT_STARPOINT_PER_SKILL_CHOICE := 1


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_GET_INSTANCE: Callable(runtime_state, "_get_instance"),
		CALLBACK_CAPTURE_RESUME_PRE_CHOICE_VELOCITY: Callable(runtime_state, "_capture_resume_pre_choice_velocity"),
		CALLBACK_OPEN_NEXT_CHOICE: Callable(runtime_state, "open_next_choice"),
		CALLBACK_CLEAR_RESUME_PRE_CHOICE: Callable(runtime_state, "_clear_resume_pre_choice"),
		CALLBACK_SYNC_OWNER: Callable(runtime_state, "_sync_owner"),
	}


func collect_star_points_from_runtime_state(
	runtime_state: Object,
	amount: int,
	character_type: String,
	catalog: Object,
	owner: Object = null,
	registry: Object = null,
	defer_choice_open: bool = false
) -> Dictionary:
	return collect_star_points(
		amount,
		character_type,
		catalog,
		owner,
		registry,
		defer_choice_open,
		runtime_state,
		_get_runtime_state_object(runtime_state, "_starpoint_absorption"),
		_get_runtime_state_object(runtime_state, "_choice_offer_modifiers"),
		_get_runtime_state_object(runtime_state, "_choice_feedback"),
		build_state_callbacks(runtime_state),
		DEFAULT_STARPOINT_PER_SKILL_CHOICE
	)


func collect_star_points(
	amount: int,
	character_type: String,
	catalog: Object,
	owner: Object,
	registry: Object,
	defer_choice_open: bool,
	runtime_state: Object,
	starpoint_absorption: Object,
	choice_offer_modifiers: Object,
	choice_feedback: Object,
	callbacks: Dictionary,
	starpoint_per_choice: int
) -> Dictionary:
	if runtime_state == null or starpoint_absorption == null:
		return {"accepted": false, "choice_active": false, "blocked_reason": "missing_starpoint_collection_deps"}
	var collection_update: Dictionary = starpoint_absorption.build_collection_update(
		amount,
		int(runtime_state.get("starpoint_for_skills")),
		int(runtime_state.get("pending_skill_choices")),
		starpoint_per_choice
	)
	var collection_apply_result: Dictionary = starpoint_absorption.apply_collection_state_update(
		runtime_state,
		collection_update
	)
	if not bool(collection_apply_result.get("accepted", false)):
		return {
			"accepted": false,
			"choice_active": bool(runtime_state.get("choice_active")),
			"blocked_reason": "collection_apply_rejected",
		}
	if choice_offer_modifiers != null:
		choice_offer_modifiers.reset_megingjord_extra_pick_count_for_new_choices(
			owner,
			registry,
			_get_callback(callbacks, CALLBACK_GET_INSTANCE),
			int(collection_apply_result.get("new_pending_choice_count", 0))
		)
	if choice_feedback != null:
		choice_feedback.apply_feedback_state_update(runtime_state, collection_update, 1.0)
	var post_collection_plan: Dictionary = starpoint_absorption.build_post_collection_choice_plan(
		int(runtime_state.get("pending_skill_choices")),
		bool(runtime_state.get("choice_active")),
		defer_choice_open
	)
	if bool(post_collection_plan.get("open_next_choice", false)):
		if bool(post_collection_plan.get("capture_resume_pre_choice_velocity", false)):
			_call_optional(callbacks, CALLBACK_CAPTURE_RESUME_PRE_CHOICE_VELOCITY, [owner])
		_call_optional(callbacks, CALLBACK_OPEN_NEXT_CHOICE, [character_type, catalog, false, owner, registry])
		if starpoint_absorption.should_clear_pre_choice_after_open(
			post_collection_plan,
			bool(runtime_state.get("choice_active"))
		):
			_call_optional(callbacks, CALLBACK_CLEAR_RESUME_PRE_CHOICE, [])
	_call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
	return {
		"accepted": true,
		"choice_active": bool(runtime_state.get("choice_active")),
		"collection_update": collection_update,
		"collection_apply_result": collection_apply_result,
		"post_collection_plan": post_collection_plan,
	}


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


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null
