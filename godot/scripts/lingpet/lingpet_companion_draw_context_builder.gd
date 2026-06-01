extends RefCounted


func build_config(params: Dictionary) -> Dictionary:
	var companion_active := bool(params.get("companion_active", false))
	var body_hit_state: Object = params.get("body_hit_state", null) as Object
	var skill_state: Object = params.get("skill_state", null) as Object
	var switch_state: Object = params.get("switch_state", null) as Object
	var skill_runtime_host: Object = params.get("skill_runtime_host", null) as Object
	var current_profile: Object = params.get("current_profile", null) as Object
	var skill_id := str(params.get("skill_id", ""))
	var skill_flash_seconds := maxf(0.0, float(params.get("skill_flash_seconds", 0.0)))
	var switch_transition_seconds := maxf(0.0, float(params.get("switch_transition_seconds", 0.0)))
	var windup_seconds := maxf(0.0, float(params.get("windup_seconds", 0.0)))
	var windup_active := skill_state != null and bool(skill_state.windup_active)
	var casting_windup := windup_active and skill_runtime_host != null and bool(skill_runtime_host.should_show_cast_windup(skill_id))
	var animator: Object = params.get("animator", null) as Object
	var attacking := animator != null and bool(animator.strike_active)
	return {
		"radius": float(params.get("radius", 16.0)),
		"burst_particles": int(params.get("burst_particles", 8)),
		"hit_flash": _get_hit_flash_ratio(body_hit_state, companion_active),
		"gauge_flash": _get_gauge_flash_ratio(body_hit_state, companion_active),
		"skill_flash": _get_skill_flash_ratio(skill_state, companion_active, skill_flash_seconds),
		"switch_transition": _get_switch_ratio(switch_state, switch_transition_seconds),
		"switch_particles": int(params.get("switch_particles", 12)),
		"switch_trigger_count": _get_trigger_count(switch_state),
		"gauge_trigger_count": _get_trigger_count(body_hit_state, "gauge_trigger_count"),
		"skill_trigger_count": _get_trigger_count(skill_state),
		"animator": animator,
		"patrol_pause": _get_float(params.get("patrol_pause", 0.0)),
		"windup_elapsed": _get_float(skill_state.windup_elapsed if skill_state != null else 0.0),
		"windup_seconds": windup_seconds,
		"casting_windup": casting_windup,
		"attacking": attacking,
		"companion_visible": bool(params.get("companion_visible", true)),
		"walk_texture": _get_visual_texture(current_profile, "companion_walk", params.get("walk_fallback", null) as Texture2D),
		"strike_texture": _get_visual_texture(current_profile, "companion_strike", params.get("strike_fallback", null) as Texture2D),
		"cast_texture": _get_visual_texture(current_profile, "companion_cast", params.get("cast_fallback", null) as Texture2D),
		"motion_speed_ratio": clampf(_get_float(params.get("motion_speed_ratio", 0.0)), 0.0, 1.0),
	}


func _get_hit_flash_ratio(body_hit_state: Object, companion_active: bool) -> float:
	if body_hit_state == null:
		return 0.0
	return float(body_hit_state.get_hit_flash_ratio(companion_active))


func _get_gauge_flash_ratio(body_hit_state: Object, companion_active: bool) -> float:
	if body_hit_state == null:
		return 0.0
	return float(body_hit_state.get_gauge_flash_ratio(companion_active))


func _get_skill_flash_ratio(skill_state: Object, companion_active: bool, flash_seconds: float) -> float:
	if not companion_active or skill_state == null or flash_seconds <= 0.0:
		return 0.0
	return float(skill_state.get_flash_ratio(flash_seconds))


func _get_switch_ratio(switch_state: Object, transition_seconds: float) -> float:
	if switch_state == null:
		return 0.0
	return float(switch_state.get_ratio(transition_seconds))


func _get_trigger_count(state: Object, property_name: String = "trigger_count") -> int:
	if state == null:
		return 0
	return int(state.get(property_name))


func _get_visual_texture(current_profile: Object, visual_key: String, fallback: Texture2D) -> Texture2D:
	if current_profile == null:
		return fallback
	return current_profile.get_visual_texture(visual_key, fallback)


func _get_float(value: Variant) -> float:
	return float(value)
