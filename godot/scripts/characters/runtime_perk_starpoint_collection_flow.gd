extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

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
		CALLBACK_GET_INSTANCE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance"),
		CALLBACK_CAPTURE_RESUME_PRE_CHOICE_VELOCITY: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_capture_resume_pre_choice_velocity"),
		CALLBACK_OPEN_NEXT_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "open_next_choice"),
		CALLBACK_CLEAR_RESUME_PRE_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_clear_resume_pre_choice"),
		CALLBACK_SYNC_OWNER: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_owner"),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_starpoint_absorption"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_offer_modifiers"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
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
	if _should_collect_tower_muhon(catalog):
		return _collect_tower_muhon(amount, owner, registry, runtime_state)
	if runtime_state == null or starpoint_absorption == null:
		return {"accepted": false, "choice_active": false, "blocked_reason": "missing_starpoint_collection_deps"}
	var collection_update: Dictionary = starpoint_absorption.build_collection_update(
		amount,
		int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "starpoint_for_skills")),
		int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices")),
		starpoint_per_choice
	)
	var collection_apply_result: Dictionary = starpoint_absorption.apply_collection_state_update(
		runtime_state,
		collection_update
	)
	if not bool(collection_apply_result.get("accepted", false)):
		return {
			"accepted": false,
			"choice_active": bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")),
			"blocked_reason": "collection_apply_rejected",
		}
	if choice_offer_modifiers != null:
		choice_offer_modifiers.reset_megingjord_extra_pick_count_for_new_choices(
			owner,
			registry,
			RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE),
			int(collection_apply_result.get("new_pending_choice_count", 0))
		)
	if choice_feedback != null:
		choice_feedback.apply_feedback_state_update(runtime_state, collection_update, 1.0)
	var post_collection_plan: Dictionary = starpoint_absorption.build_post_collection_choice_plan(
		int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices")),
		bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")),
		defer_choice_open
	)
	if bool(post_collection_plan.get("open_next_choice", false)):
		if bool(post_collection_plan.get("capture_resume_pre_choice_velocity", false)):
			RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_CAPTURE_RESUME_PRE_CHOICE_VELOCITY, [owner])
		# allowlist source 스탬프: 시스템 카드 로테이션(융합·신비의 주사위)의
		# 오퍼 후처리는 이 출처 컨텍스트로만 열린다(아카데미 등은 fail-closed).
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_OPEN_NEXT_CHOICE, [character_type, catalog, false, owner, registry, null, {"source": "battle_starpoint"}])
		if starpoint_absorption.should_clear_pre_choice_after_open(
			post_collection_plan,
			bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active"))
		):
			RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_CLEAR_RESUME_PRE_CHOICE, [])
	RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
	return {
		"accepted": true,
		"choice_active": bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")),
		"collection_update": collection_update,
		"collection_apply_result": collection_apply_result,
		"post_collection_plan": post_collection_plan,
	}


func _should_collect_tower_muhon(catalog: Object) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	# A reserved boss-Vision offer is content acquisition, not currency. The
	# compatibility path still needs one pending choice to materialize the exact
	# reserved Chosik instead of turning that chest into Muhon.
	if (
		catalog != null
		and catalog.has_method("has_reserved_boss_vision_offer")
		and bool(catalog.call("has_reserved_boss_vision_offer"))
	):
		return false
	return true


func _collect_tower_muhon(
	amount: int,
	owner: Object,
	registry: Object,
	runtime_state: Object
) -> Dictionary:
	if amount <= 0:
		return {
			"accepted": false,
			"choice_active": _get_choice_active(runtime_state),
			"collection_mode": "tower_muhon",
			"blocked_reason": "invalid_muhon_amount",
		}
	# The tower owner is intentionally created during stage-entry prewarm. A
	# pickup is a physics hot path, so never let this lookup cold-instantiate the
	# whole eager tower flow chain (GRT-003/GRT-042).
	var flow_owner := _get_cached_registry_instance(registry, "tower_ascent_flow_owner")
	if flow_owner == null or not flow_owner.has_method("collect_muhon"):
		return {
			"accepted": false,
			"choice_active": _get_choice_active(runtime_state),
			"collection_mode": "tower_muhon",
			"blocked_reason": "missing_tower_ascent_flow_owner",
		}
	var apply_value: Variant = flow_owner.call("collect_muhon", amount, owner)
	var apply_result: Dictionary = (
		(apply_value as Dictionary)
		if apply_value is Dictionary
		else {}
	)
	var accepted := bool(apply_result.get("accepted", false))
	return {
		"accepted": accepted,
		"choice_active": _get_choice_active(runtime_state),
		"collection_mode": "tower_muhon",
		"muhon_amount": amount,
		"run_state_result": apply_result,
		"blocked_reason": "" if accepted else str(apply_result.get("reason", "tower_muhon_rejected")),
	}


func _get_cached_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.call("get_cached_instance", key)
	return value as Object if value is Object and value != null else null


func _get_choice_active(runtime_state: Object) -> bool:
	return bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")) if runtime_state != null else false
