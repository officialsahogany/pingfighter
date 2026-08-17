extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_HEIGHT := 750.0
const DURATION := 0.70
const PARTICLE_COUNT := 7
const SOURCE_PLAYFIELD_OFFSET_Y := -120.0
# 표시 명칭은 무혼으로 통일한다. 합성 문자열은 카탈로그 키가 될 수 없으므로
# 접두사만 번역하고 수치를 붙인다. 이 상수는 반드시 평문 한글로 둘 것.
# 이전의 유니코드 이스케이프 표기가 리브랜드 검색을 통째로 빗나가게 했다.
const COLLECTION_FEEDBACK_PREFIX := "무혼"
const COLLECTION_FEEDBACK_TEMPLATE := "%s +%d"
const COLLECTION_FEEDBACK_TIMER := 1.0

var effect: Dictionary = {}


func build_collection_update(
	amount: int,
	current_starpoints: int,
	current_pending_choices: int,
	starpoint_per_choice: int
) -> Dictionary:
	var collected_amount: int = max(0, int(amount))
	var next_starpoints: int = max(0, int(current_starpoints)) + collected_amount
	var next_pending: int = max(0, int(current_pending_choices))
	var choice_cost: int = max(1, int(starpoint_per_choice))
	var granted_choices := 0
	while next_starpoints >= choice_cost:
		next_starpoints -= choice_cost
		next_pending += 1
		granted_choices += 1
	return {
		"accepted": true,
		"amount": collected_amount,
		"next_starpoint_for_skills": next_starpoints,
		"next_pending_skill_choices": next_pending,
		"granted_choices": granted_choices,
		"feedback_text": COLLECTION_FEEDBACK_TEMPLATE % [LanguageSettings.translate_text(COLLECTION_FEEDBACK_PREFIX), collected_amount],
		"feedback_timer": COLLECTION_FEEDBACK_TIMER,
	}


func apply_collection_state_update(runtime_state: Object, collection_update: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(collection_update.get("accepted", false)):
		return {"accepted": false}
	var previous_pending_choices: int = int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"))
	var next_starpoints: int = int(collection_update.get(
		"next_starpoint_for_skills",
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "starpoint_for_skills")
	))
	var next_pending_choices: int = int(collection_update.get(
		"next_pending_skill_choices",
		previous_pending_choices
	))
	runtime_state.set("starpoint_for_skills", next_starpoints)
	runtime_state.set("pending_skill_choices", next_pending_choices)
	return {
		"accepted": true,
		"starpoint_for_skills": next_starpoints,
		"pending_skill_choices": next_pending_choices,
		"previous_pending_skill_choices": previous_pending_choices,
		"new_pending_choice_count": max(0, next_pending_choices - previous_pending_choices),
	}


func build_post_collection_choice_plan(
	current_pending_choices: int,
	current_choice_active: bool,
	defer_choice_open: bool
) -> Dictionary:
	var should_open_choice: bool = max(0, current_pending_choices) > 0 and not current_choice_active and not defer_choice_open
	return {
		"open_next_choice": should_open_choice,
		"capture_resume_pre_choice_velocity": should_open_choice,
		"clear_pre_choice_if_open_fails": should_open_choice,
	}


func should_clear_pre_choice_after_open(post_collection_plan: Dictionary, choice_active_after_open: bool) -> bool:
	return bool(post_collection_plan.get("clear_pre_choice_if_open_fails", false)) and not choice_active_after_open


func reset() -> void:
	effect.clear()


func is_active() -> bool:
	return bool(effect.get("active", false))


func is_active_from_runtime_state(runtime_state: Object) -> bool:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_starpoint_absorption")
	return RuntimePerkRuntimeStateAccess.call_bool(helper, "is_active")


func start(owner: Object) -> void:
	if owner == null:
		effect.clear()
		return
	effect = {
		"active": true,
		"age": 0.0,
		"duration": DURATION,
		"source_pos": Vector2.ZERO,
		"target_pos": Vector2.ZERO,
		"screen_scale": 1.0,
		"particles": _build_particles(),
	}


func start_from_runtime_state(runtime_state: Object, owner: Object) -> Dictionary:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_starpoint_absorption")
	if helper == null or not helper.has_method("start"):
		return {"accepted": false}
	helper.call("start", owner)
	return {
		"accepted": true,
		"active": RuntimePerkRuntimeStateAccess.call_bool(helper, "is_active"),
	}


func update(delta: float, view_size: Vector2, owner: Object, layout_state: Dictionary) -> void:
	if effect.is_empty():
		return
	var age: float = float(effect.get("age", 0.0)) + max(0.0, delta)
	effect["age"] = age
	if age >= float(effect.get("duration", DURATION)):
		effect.clear()
		return
	if owner == null or view_size == Vector2.ZERO or layout_state.is_empty():
		return

	var player_pos: Vector2 = RuntimePerkPayloadAccess.get_value(owner, "player_pos", Vector2.ZERO)
	var paddle_width: float = float(RuntimePerkPayloadAccess.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH))
	var player_center_pf := player_pos + Vector2(paddle_width * 0.5, PLAYER_BASE_PADDLE_HEIGHT * 0.5)
	var game_offset: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout_state.get("game_offset", Vector2.ZERO))
	var game_size: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout_state.get("game_size", Vector2.ZERO))
	var pf_height: float = float(layout_state.get("height", FIELD_HEIGHT))
	var screen_scale: float = max(0.001, game_size.y / max(1.0, pf_height))
	var target_screen: Vector2 = game_offset + player_center_pf * screen_scale
	var source_screen: Vector2 = target_screen + Vector2(0.0, SOURCE_PLAYFIELD_OFFSET_Y * screen_scale)
	effect["source_pos"] = source_screen
	effect["target_pos"] = target_screen
	effect["screen_scale"] = screen_scale


func update_from_runtime_state(
	runtime_state: Object,
	delta: float,
	view_size: Vector2,
	owner: Object,
	registry: Object
) -> Dictionary:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_starpoint_absorption")
	if helper == null or not helper.has_method("update"):
		return {"accepted": false}
	var layout_state: Dictionary = {}
	if registry != null and view_size != Vector2.ZERO:
		layout_state = _build_layout_state_from_runtime_state(runtime_state, registry, view_size)
	helper.call("update", delta, view_size, owner, layout_state)
	return {
		"accepted": true,
		"active": RuntimePerkRuntimeStateAccess.call_bool(helper, "is_active"),
	}


func get_snapshot() -> Dictionary:
	return effect.duplicate(true)


func _build_particles() -> Array:
	var out: Array = []
	for index in range(PARTICLE_COUNT):
		out.append({
			"phase": _pseudo_unit(index, 1.3) * TAU,
			"radius_seed": _pseudo_unit(index, 3.7),
			"twinkle_seed": _pseudo_unit(index, 8.3),
			"orbit_dir": 1.0 if _pseudo_unit(index, 5.1) >= 0.5 else -1.0,
		})
	return out


func _pseudo_unit(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)


func _build_layout_state_from_runtime_state(runtime_state: Object, registry: Object, view_size: Vector2) -> Dictionary:
	var flight_helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_active_unlock_flight")
	return RuntimePerkRuntimeStateAccess.call_dict(
		flight_helper,
		"build_layout_state_from_runtime_state",
		[runtime_state, registry, view_size]
	)
