extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const DEFAULT_EFFECT_WIDTH := 80.0
const DEFAULT_EFFECT_HEIGHT := 40.0
const DEFAULT_BOSS_WIDTH := 100.0
const DEFAULT_BOSS_HEIGHT := 40.0


static func apply_effect_status_fields(
	effect: Dictionary,
	profile: Dictionary,
	dissolve: bool,
	default_duration_frames: float,
	default_interval_frames: float,
	initial_cooldown_frames: float,
	default_slow_multiplier: float
) -> void:
	var status_id: String = get_profile_id(profile)
	if not should_apply_effect_status_fields(status_id, dissolve):
		return
	apply_profile_base_fields(
		effect,
		profile,
		status_id,
		default_duration_frames,
		default_interval_frames,
		initial_cooldown_frames
	)
	apply_profile_slow_multiplier(effect, profile, default_slow_multiplier)


static func apply_profile_base_fields(
	effect: Dictionary,
	profile: Dictionary,
	status_id: String,
	default_duration_frames: float,
	default_interval_frames: float,
	initial_cooldown_frames: float
) -> void:
	effect["status_id"] = status_id
	effect["status_duration_frames"] = get_profile_duration(profile, default_duration_frames)
	effect["status_interval_frames"] = get_profile_interval(profile, default_interval_frames)
	effect["status_cooldown_frames"] = get_initial_cooldown(initial_cooldown_frames)


static func apply_profile_slow_multiplier(effect: Dictionary, profile: Dictionary, default_slow_multiplier: float) -> void:
	if has_profile_slow_multiplier(profile):
		effect["slow_multiplier"] = get_profile_slow_multiplier(profile, default_slow_multiplier)


static func get_profile_id(profile: Dictionary) -> String:
	return str(profile.get("status_id", ""))


static func get_profile_duration(profile: Dictionary, default_duration_frames: float) -> float:
	return float(profile.get("status_duration_frames", default_duration_frames))


static func get_profile_interval(profile: Dictionary, default_interval_frames: float) -> float:
	return float(profile.get("status_interval_frames", default_interval_frames))


static func get_initial_cooldown(initial_cooldown_frames: float) -> float:
	return initial_cooldown_frames


static func has_profile_slow_multiplier(profile: Dictionary) -> bool:
	return profile.has("slow_multiplier")


static func get_profile_slow_multiplier(profile: Dictionary, default_slow_multiplier: float) -> float:
	return float(profile.get("slow_multiplier", default_slow_multiplier))


static func should_apply_effect_status_fields(status_id: String, dissolve: bool) -> bool:
	return status_id != "" and not dissolve


static func get_status_id(effect: Dictionary) -> String:
	return str(effect.get("status_id", ""))


static func get_status_effect_state(deps: Dictionary) -> Object:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if is_status_effect_state(status_effect_state):
		return status_effect_state
	return null


static func get_status_application(effect: Dictionary, deps: Dictionary) -> Dictionary:
	var status_id: String = get_status_id(effect)
	if status_id == "":
		return {}
	var status_effect_state: Object = get_status_effect_state(deps)
	if status_effect_state == null:
		return {}
	return {
		"status_id": status_id,
		"status_effect_state": status_effect_state,
	}


static func has_status_application(status_application: Dictionary) -> bool:
	return (
		get_status_application_id(status_application) != ""
		and get_status_application_state(status_application) != null
	)


static func get_status_application_id(status_application: Dictionary) -> String:
	return str(status_application.get("status_id", ""))


static func get_status_application_state(status_application: Dictionary) -> Object:
	var status_effect_state: Object = status_application.get("status_effect_state", null)
	if is_status_effect_state(status_effect_state):
		return status_effect_state
	return null


static func apply_status_if_ready(
	effect: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	timer_step: float,
	default_target: String,
	slow_status_id: String,
	default_duration_frames: float,
	default_interval_frames: float,
	default_slow_multiplier: float,
	min_slow_multiplier: float,
	max_slow_multiplier: float,
	default_source: String
) -> bool:
	var status_application: Dictionary = get_status_application(effect, deps)
	if not has_status_application(status_application):
		return false
	if not can_apply_status(effect, context, timer_step):
		return false
	return apply_ready_status(
		effect,
		status_application,
		default_target,
		slow_status_id,
		default_duration_frames,
		default_interval_frames,
		default_slow_multiplier,
		min_slow_multiplier,
		max_slow_multiplier,
		default_source
	)


static func apply_ready_status(
	effect: Dictionary,
	status_application: Dictionary,
	default_target: String,
	slow_status_id: String,
	default_duration_frames: float,
	default_interval_frames: float,
	default_slow_multiplier: float,
	min_slow_multiplier: float,
	max_slow_multiplier: float,
	default_source: String
) -> bool:
	var status_effect_state: Object = get_status_application_state(status_application)
	var status_id: String = get_status_application_id(status_application)
	if status_effect_state == null or status_id == "":
		return false
	status_effect_state.apply_status(
		get_status_target(default_target),
		status_id,
		get_status_duration(effect, default_duration_frames),
		build_status_data(
			effect,
			status_id,
			slow_status_id,
			default_slow_multiplier,
			min_slow_multiplier,
			max_slow_multiplier
		),
		get_status_source(effect, default_source)
	)
	reset_status_cooldown(effect, default_interval_frames)
	return true


static func is_status_effect_state(status_effect_state: Object) -> bool:
	return status_effect_state != null and status_effect_state.has_method("apply_status")


static func can_apply_status(effect: Dictionary, context: Dictionary, timer_step: float) -> bool:
	var cooldown: float = advance_status_cooldown(effect, timer_step)
	return is_status_ready_to_apply(cooldown, effect, context)


static func is_status_ready_to_apply(cooldown: float, effect: Dictionary, context: Dictionary) -> bool:
	return is_status_cooldown_ready(cooldown) and lingering_effect_hits_boss(effect, context)


static func get_status_target(default_target: String) -> String:
	return default_target


static func get_status_duration(effect: Dictionary, default_duration_frames: float) -> float:
	return float(effect.get("status_duration_frames", default_duration_frames))


static func get_status_source(effect: Dictionary, default_source: String) -> String:
	return str(effect.get("source", default_source))


static func build_status_data(
	effect: Dictionary,
	status_id: String,
	slow_status_id: String,
	default_slow_multiplier: float,
	min_slow_multiplier: float,
	max_slow_multiplier: float
) -> Dictionary:
	var data := {
		"source": get_status_data_source(effect),
	}
	if should_include_status_slow_multiplier(status_id, slow_status_id):
		data["multiplier"] = get_status_slow_multiplier(
			effect,
			default_slow_multiplier,
			min_slow_multiplier,
			max_slow_multiplier
		)
	return data


static func should_include_status_slow_multiplier(status_id: String, slow_status_id: String) -> bool:
	return status_id == slow_status_id


static func get_status_data_source(effect: Dictionary) -> String:
	return str(effect.get("source", ""))


static func get_status_slow_multiplier(
	effect: Dictionary,
	default_slow_multiplier: float,
	min_slow_multiplier: float,
	max_slow_multiplier: float
) -> float:
	return clamp(
		float(effect.get("slow_multiplier", default_slow_multiplier)),
		min_slow_multiplier,
		max_slow_multiplier
	)


static func reset_status_cooldown(effect: Dictionary, default_interval_frames: float) -> float:
	var cooldown: float = get_status_interval(effect, default_interval_frames)
	return set_status_cooldown(effect, cooldown)


static func get_status_interval(effect: Dictionary, default_interval_frames: float) -> float:
	return max(1.0, float(effect.get("status_interval_frames", default_interval_frames)))


static func advance_status_cooldown(effect: Dictionary, timer_step: float) -> float:
	var cooldown: float = get_next_status_cooldown(effect, timer_step)
	return set_status_cooldown(effect, cooldown)


static func set_status_cooldown(effect: Dictionary, cooldown: float) -> float:
	effect["status_cooldown_frames"] = cooldown
	return cooldown


static func get_status_cooldown(effect: Dictionary) -> float:
	return max(0.0, float(effect.get("status_cooldown_frames", 0.0)))


static func get_next_status_cooldown(effect: Dictionary, timer_step: float) -> float:
	return max(0.0, get_status_cooldown(effect) - timer_step)


static func is_status_cooldown_ready(cooldown: float) -> bool:
	return cooldown <= 0.0


static func lingering_effect_hits_boss(effect: Dictionary, context: Dictionary) -> bool:
	var effect_rect: Rect2 = get_lingering_effect_rect(effect)
	var boss_rect: Rect2 = get_lingering_boss_rect(context)
	return do_lingering_rects_intersect(effect_rect, boss_rect)


static func do_lingering_rects_intersect(effect_rect: Rect2, boss_rect: Rect2) -> bool:
	return effect_rect.intersects(boss_rect)


static func get_lingering_effect_rect(effect: Dictionary) -> Rect2:
	var pos: Vector2 = get_lingering_effect_rect_pos(effect)
	var size: Vector2 = get_lingering_effect_rect_size(effect)
	return Rect2(pos - size * 0.5, size)


static func get_lingering_effect_rect_pos(effect: Dictionary) -> Vector2:
	return CommandoFirearmValueUtils.get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO)


static func get_lingering_effect_rect_width(effect: Dictionary) -> float:
	return max(1.0, float(effect.get("width", DEFAULT_EFFECT_WIDTH)))


static func get_lingering_effect_rect_height(effect: Dictionary) -> float:
	return max(1.0, float(effect.get("height", DEFAULT_EFFECT_HEIGHT)))


static func get_lingering_effect_rect_size(effect: Dictionary) -> Vector2:
	return Vector2(get_lingering_effect_rect_width(effect), get_lingering_effect_rect_height(effect))


static func get_lingering_boss_rect(context: Dictionary) -> Rect2:
	return Rect2(get_lingering_boss_rect_pos(context), get_lingering_boss_rect_size(context))


static func get_lingering_boss_rect_pos(context: Dictionary) -> Vector2:
	return CommandoFirearmValueUtils.get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)


static func get_lingering_boss_rect_width(context: Dictionary) -> float:
	return max(1.0, float(context.get("boss_paddle_width", context.get("boss_width", DEFAULT_BOSS_WIDTH))))


static func get_lingering_boss_rect_height(context: Dictionary) -> float:
	return max(1.0, float(context.get("boss_hitbox_height", DEFAULT_BOSS_HEIGHT)))


static func get_lingering_boss_rect_size(context: Dictionary) -> Vector2:
	return Vector2(get_lingering_boss_rect_width(context), get_lingering_boss_rect_height(context))
