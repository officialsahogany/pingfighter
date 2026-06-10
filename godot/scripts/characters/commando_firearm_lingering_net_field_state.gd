extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const NET_SHAPE_SEED_PHASE_FACTOR := 0.61803398875
const NET_SHAPE_POINT_COUNT := 36
const INITIAL_CONSTRICT_FACTOR := 1.0


static func apply_lifecycle_fields(effect: Dictionary, dissolve: bool) -> void:
	effect["dissolve"] = dissolve
	effect["boss_trapped"] = not dissolve
	effect["hooked_player"] = not dissolve
	effect["rope_broken"] = dissolve
	effect["rope_snap_timer"] = 0.0


static func mark_hooked_field_broken(effect: Dictionary, dash_break_frames: float) -> void:
	effect["hooked_player"] = false
	effect["dissolve"] = true
	effect["rope_broken"] = true
	effect["timer_frames"] = dash_break_frames
	effect["max_timer_frames"] = dash_break_frames
	effect["rope_snap_timer"] = dash_break_frames
	effect["status_id"] = ""


static func break_active_hooked_net_fields(effects: Array, dash_break_frames: float) -> void:
	for index in range(effects.size()):
		var effect: Dictionary = CommandoFirearmValueUtils.get_dict(effects[index])
		if not is_active_hooked_net_field(effect):
			continue
		mark_hooked_field_broken(effect, dash_break_frames)
		effects[index] = effect


static func get_dash_trigger_result(context: Dictionary, deps: Dictionary, last_dash_active: bool) -> Dictionary:
	var dash_active: bool = is_player_dash_active(context, deps)
	return {
		"dash_active": dash_active,
		"dash_triggered": dash_active and not last_dash_active,
	}


static func apply_dash_break_if_triggered(
	effects: Array,
	context: Dictionary,
	deps: Dictionary,
	last_dash_active: bool,
	dash_break_frames: float
) -> Dictionary:
	var dash_trigger_result: Dictionary = get_dash_trigger_result(context, deps, last_dash_active)
	if bool(dash_trigger_result.get("dash_triggered", false)):
		break_active_hooked_net_fields(effects, dash_break_frames)
	return dash_trigger_result


static func is_player_dash_active(context: Dictionary, deps: Dictionary = {}) -> bool:
	var dash_snapshot: Variant = context.get("dash_snapshot", {})
	if dash_snapshot is Dictionary:
		return bool((dash_snapshot as Dictionary).get("active", false))
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return bool((snapshot as Dictionary).get("active", false))
	return false


static func get_rope_snap_duration(profile: Dictionary, default_dash_break_frames: float) -> float:
	return float(profile.get("dash_break_frames", default_dash_break_frames))


static func get_origin(projectile: Dictionary, fallback_origin: Variant) -> Variant:
	return projectile.get("origin", fallback_origin)


static func get_player_slow_multiplier(profile: Dictionary, default_player_slow_multiplier: float) -> float:
	return float(profile.get("player_slow_multiplier", default_player_slow_multiplier))


static func apply_profile_fields(
	effect: Dictionary,
	profile: Dictionary,
	projectile: Dictionary,
	fallback_origin: Variant,
	default_dash_break_frames: float,
	default_player_slow_multiplier: float
) -> void:
	effect["rope_snap_duration"] = get_rope_snap_duration(profile, default_dash_break_frames)
	effect["origin"] = get_origin(projectile, fallback_origin)
	effect["player_slow_multiplier"] = get_player_slow_multiplier(profile, default_player_slow_multiplier)


static func apply_geometry_fields(effect: Dictionary, pos: Vector2, effect_size: Vector2, effect_id: int) -> void:
	effect["deploy_x"] = get_deploy_x(pos)
	effect["net_rect"] = get_net_rect(pos, effect_size)
	effect["constrict_factor"] = get_initial_constrict_factor()
	effect["shape"] = build_net_shape(effect_size, effect_id)


static func apply_net_fields(
	effect: Dictionary,
	profile: Dictionary,
	projectile: Dictionary,
	fallback_origin: Variant,
	pos: Vector2,
	effect_size: Vector2,
	effect_id: int,
	dissolve: bool,
	default_dash_break_frames: float,
	default_player_slow_multiplier: float
) -> void:
	apply_lifecycle_fields(effect, dissolve)
	apply_profile_fields(
		effect,
		profile,
		projectile,
		fallback_origin,
		default_dash_break_frames,
		default_player_slow_multiplier
	)
	apply_geometry_fields(effect, pos, effect_size, effect_id)


static func get_deploy_x(pos: Vector2) -> float:
	return pos.x


static func get_net_rect(pos: Vector2, effect_size: Vector2) -> Rect2:
	return Rect2(pos - effect_size * 0.5, effect_size)


static func get_initial_constrict_factor() -> float:
	return INITIAL_CONSTRICT_FACTOR


static func build_net_shape(effect_size: Vector2, effect_id: int) -> Array:
	return generate_net_shape(effect_size.x, effect_size.y, effect_id)


static func generate_net_shape(width: float, height: float, seed_value: int) -> Array:
	var points: Array = []
	var seed_phase: float = get_net_shape_seed_phase(seed_value)
	for i in range(NET_SHAPE_POINT_COUNT):
		points.append(get_net_shape_point(width, height, i, NET_SHAPE_POINT_COUNT, seed_phase))
	return points


static func get_net_shape_seed_phase(seed_value: int) -> float:
	return fposmod(float(seed_value) * NET_SHAPE_SEED_PHASE_FACTOR, 1.0)


static func get_net_shape_scale(angle: float, seed_phase: float) -> float:
	var noise: float = sin(angle * 3.0 + seed_phase * TAU) * 0.18
	noise += sin(angle * 7.0 + seed_phase * 5.0) * 0.08
	return 0.82 + noise


static func get_net_shape_point(width: float, height: float, point_index: int, point_count: int, seed_phase: float) -> Vector2:
	var angle: float = TAU * float(point_index) / float(point_count)
	var scale: float = get_net_shape_scale(angle, seed_phase)
	return Vector2(
		cos(angle) * width * 0.5 * scale,
		sin(angle) * height * 0.5 * scale
	)


static func get_lingering_effect_pos(
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	pos: Vector2,
	boss_target: Vector2,
	field_width: float,
	field_height: float,
	default_net_width: float,
	default_net_min_height: float,
	default_net_height: float
) -> Vector2:
	var kind: String = str(profile.get("kind", ""))
	if kind == "net_field":
		return get_net_lingering_effect_pos(
			profile,
			projectile,
			context,
			pos,
			boss_target,
			field_width,
			field_height,
			default_net_width,
			default_net_min_height,
			default_net_height
		)
	return get_default_lingering_effect_pos(profile, pos, field_width, field_height)


static func get_net_lingering_effect_pos(
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	pos: Vector2,
	boss_target: Vector2,
	field_width: float,
	field_height: float,
	default_width: float,
	default_min_height: float,
	default_height: float
) -> Vector2:
	var target: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("target", boss_target), boss_target)
	var width: float = float(profile.get("width", default_width))
	var height: float = get_net_effect_height(profile, context, default_min_height, default_height)
	return Vector2(
		clamp(pos.x, width * 0.5, field_width - width * 0.5),
		clamp(target.y, 20.0 + height * 0.5, field_height - height * 0.5 - 20.0)
	)


static func get_default_lingering_effect_pos(profile: Dictionary, pos: Vector2, field_width: float, field_height: float) -> Vector2:
	var width: float = float(profile.get("width", 80.0))
	return Vector2(
		clamp(pos.x, width * 0.5, field_width - width * 0.5),
		clamp(pos.y, 18.0, field_height - 18.0)
	)


static func get_net_effect_height(profile: Dictionary, context: Dictionary, default_min_height: float, default_height: float) -> float:
	var height_limits: Vector2 = get_net_effect_height_limits(profile, default_min_height, default_height)
	return clamp(get_net_effect_desired_height(context), height_limits.x, height_limits.y)


static func get_net_effect_desired_height(context: Dictionary) -> float:
	var boss_height: float = max(1.0, float(context.get("boss_hitbox_height", 40.0)))
	return boss_height * 1.1


static func get_net_effect_height_limits(profile: Dictionary, default_min_height: float, default_height: float) -> Vector2:
	return Vector2(
		max(1.0, float(profile.get("min_height", default_min_height))),
		max(1.0, float(profile.get("height", default_height)))
	)


static func apply_net_field_boss_clamp(effect: Dictionary, context: Dictionary, default_width: float, default_height: float) -> Dictionary:
	if not is_boss_clamping_net_field(effect):
		return {}
	var pos: Vector2 = get_net_field_pos(effect)
	var width: float = get_net_field_effect_width(effect, default_width)
	var height: float = get_net_field_effect_height(effect, default_height)
	var boss_pos: Vector2 = get_net_field_boss_pos(context)
	var boss_width: float = get_net_field_boss_width(context)
	var clamp_rect: Rect2 = get_net_field_clamp_rect(effect, pos, width, height, boss_width)
	return build_net_field_boss_clamp_result(boss_pos, boss_width, clamp_rect)


static func is_net_gun_effect(effect: Dictionary) -> bool:
	return str(effect.get("weapon_id", "")) == "net_gun"


static func is_active_hooked_net_field(effect: Dictionary) -> bool:
	return is_net_gun_effect(effect) and bool(effect.get("hooked_player", false)) and not bool(effect.get("dissolve", false))


static func should_sync_rope_origin(effect: Dictionary) -> bool:
	if is_active_hooked_net_field(effect):
		return true
	return (
		is_net_gun_effect(effect)
		and bool(effect.get("rope_broken", false))
		and bool(effect.get("dissolve", false))
		and float(effect.get("rope_snap_timer", 0.0)) > 0.0
	)


static func has_active_hooked_net_field(effects: Array) -> bool:
	for value in effects:
		if is_active_hooked_net_field(CommandoFirearmValueUtils.get_dict(value)):
			return true
	return false


static func is_boss_clamping_net_field(effect: Dictionary) -> bool:
	return is_net_gun_effect(effect) and bool(effect.get("boss_trapped", false)) and not bool(effect.get("dissolve", false))


static func is_net_constrict_candidate(effect: Dictionary, min_constrict_factor: float) -> bool:
	return is_active_hooked_net_field(effect) and get_net_constrict_factor(effect, get_initial_constrict_factor()) > min_constrict_factor


static func get_net_constrict_input_direction(input_snapshot: Dictionary) -> int:
	var left_input: bool = bool(input_snapshot.get("left_pressed", false))
	var right_input: bool = bool(input_snapshot.get("right_pressed", false))
	return (-1 if left_input else 0) + (1 if right_input else 0)


static func should_record_net_constrict_input(dir_input: int, last_dir: int) -> bool:
	return dir_input != 0 and dir_input != last_dir


static func should_apply_net_constrict_input(dir_input: int, now_msec: int, last_dir: int, last_tick_msec: int, window_msec: int) -> bool:
	return should_record_net_constrict_input(dir_input, last_dir) and now_msec - last_tick_msec <= window_msec


static func apply_net_constrict_input(
	effects: Array,
	input_snapshot: Dictionary,
	now_msec: int,
	last_dir: int,
	last_tick_msec: int,
	min_constrict_factor: float,
	constrict_step: float,
	window_msec: int,
	audio: Object
) -> Dictionary:
	var active_indices: Array[int] = []
	for index in range(effects.size()):
		var effect: Dictionary = CommandoFirearmValueUtils.get_dict(effects[index])
		if is_net_constrict_candidate(effect, min_constrict_factor):
			active_indices.append(index)
	if active_indices.is_empty():
		return {}
	var dir_input: int = get_net_constrict_input_direction(input_snapshot)
	if not should_record_net_constrict_input(dir_input, last_dir):
		return {}
	var applied := false
	if should_apply_net_constrict_input(dir_input, now_msec, last_dir, last_tick_msec, window_msec):
		for index in active_indices:
			var effect: Dictionary = CommandoFirearmValueUtils.get_dict(effects[index])
			effect["constrict_factor"] = get_next_net_constrict_factor(effect, min_constrict_factor, constrict_step)
			effects[index] = effect
		applied = true
		if audio != null and audio.has_method("play_commando_net_gun_constrict"):
			audio.play_commando_net_gun_constrict()
		elif audio != null and audio.has_method("play_commando_net_gun_capture"):
			audio.play_commando_net_gun_capture()
	return {
		"effects": effects,
		"last_dir": dir_input,
		"last_tick_msec": now_msec,
		"applied": applied,
	}


static func get_next_net_constrict_factor(effect: Dictionary, min_constrict_factor: float, constrict_step: float) -> float:
	var current: float = get_net_constrict_factor(effect, get_initial_constrict_factor())
	return max(min_constrict_factor, current - constrict_step)


static func get_net_constrict_factor(effect: Dictionary, initial_constrict_factor: float) -> float:
	return float(effect.get("constrict_factor", initial_constrict_factor))


static func get_net_field_pos(effect: Dictionary) -> Vector2:
	return CommandoFirearmValueUtils.get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO)


static func get_net_field_effect_width(effect: Dictionary, default_width: float) -> float:
	return max(1.0, float(effect.get("width", default_width)))


static func get_net_field_effect_height(effect: Dictionary, default_height: float) -> float:
	return max(1.0, float(effect.get("height", default_height)))


static func get_net_field_boss_pos(context: Dictionary) -> Vector2:
	return CommandoFirearmValueUtils.get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)


static func get_net_field_boss_width(context: Dictionary) -> float:
	return max(1.0, float(context.get("boss_paddle_width", context.get("boss_width", 100.0))))


static func get_net_field_clamp_width(effect: Dictionary, width: float, boss_width: float) -> float:
	var safe_width: float = max(1.0, width)
	if not is_active_hooked_net_field(effect):
		return safe_width
	var constrict_factor: float = get_net_constrict_factor(effect, get_initial_constrict_factor())
	if constrict_factor >= 1.0:
		return safe_width
	return max(
		get_net_field_min_boss_clamp_width(boss_width),
		get_net_field_constricted_width(safe_width, constrict_factor)
	)


static func get_net_field_min_boss_clamp_width(boss_width: float) -> float:
	return max(1.0, boss_width) + 10.0


static func get_net_field_constricted_width(width: float, constrict_factor: float) -> float:
	return max(1.0, width) * constrict_factor


static func get_net_field_clamp_rect(effect: Dictionary, pos: Vector2, width: float, height: float, boss_width: float) -> Rect2:
	var clamp_size: Vector2 = get_net_field_clamp_size(effect, width, height, boss_width)
	return Rect2(get_net_field_clamp_origin(pos, clamp_size), clamp_size)


static func get_net_field_clamp_size(effect: Dictionary, width: float, height: float, boss_width: float) -> Vector2:
	return Vector2(get_net_field_clamp_width(effect, width, boss_width), max(1.0, height))


static func get_net_field_clamp_origin(pos: Vector2, clamp_size: Vector2) -> Vector2:
	return pos - clamp_size * 0.5


static func get_net_field_clamped_boss_x(boss_x: float, boss_width: float, clamp_rect: Rect2) -> float:
	return clamp(
		boss_x,
		get_net_field_boss_clamp_min_x(clamp_rect),
		get_net_field_boss_clamp_max_x(boss_width, clamp_rect)
	)


static func get_net_field_safe_boss_width(boss_width: float) -> float:
	return max(1.0, boss_width)


static func get_net_field_boss_clamp_min_x(clamp_rect: Rect2) -> float:
	return clamp_rect.position.x


static func get_net_field_boss_clamp_max_x(boss_width: float, clamp_rect: Rect2) -> float:
	return clamp_rect.end.x - get_net_field_safe_boss_width(boss_width)


static func get_net_field_clamped_boss_pos(boss_pos: Vector2, boss_width: float, clamp_rect: Rect2) -> Vector2:
	var clamped_pos: Vector2 = boss_pos
	clamped_pos.x = get_net_field_clamped_boss_x(boss_pos.x, boss_width, clamp_rect)
	return clamped_pos


static func should_emit_net_field_boss_clamp_result(boss_pos: Vector2, clamped_pos: Vector2) -> bool:
	return not is_equal_approx(clamped_pos.x, boss_pos.x)


static func build_net_field_boss_clamp_result(boss_pos: Vector2, boss_width: float, clamp_rect: Rect2) -> Dictionary:
	var clamped_pos: Vector2 = get_net_field_clamped_boss_pos(boss_pos, boss_width, clamp_rect)
	if not should_emit_net_field_boss_clamp_result(boss_pos, clamped_pos):
		return {}
	return {
		"boss_pos": clamped_pos,
		"commando_net_gun_boss_clamped": true,
		"commando_net_gun_clamp_rect": clamp_rect,
	}
