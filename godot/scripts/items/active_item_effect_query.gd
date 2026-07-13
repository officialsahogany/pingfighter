extends RefCounted

const ActiveItemEffectContextBuilder := preload("res://scripts/items/active_item_effect_context_builder.gd")
const ActiveItemEffectStatus := preload("res://scripts/items/active_item_effect_status.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ActiveItemPaddleSync := preload("res://scripts/items/active_item_paddle_sync.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")
const ActiveItemStopwatchOwnerEffects := preload("res://scripts/items/active_item_stopwatch_owner_effects.gd")

var _context_builder: Object = ActiveItemEffectContextBuilder.new()
var _status: Object = ActiveItemEffectStatus.new()
var _paddle_sync: Object = ActiveItemPaddleSync.new()
var _pickup_effect_state: Object = ActiveItemPickupEffectState.new()
var _stopwatch_owner_effects: Object = ActiveItemStopwatchOwnerEffects.new()


func can_store_item(target: Object, item_name: String) -> bool:
	return _status.can_store_item(item_name, _build_active_status_flags(target))


func get_player_paddle_scale(target: Object) -> float:
	var persistent_scale: float = _get_float_property(target, "milk_bottle_scale", 1.0)
	return _paddle_sync.get_player_paddle_scale(
		_get_float_property(target, "long_boost_scale", 1.0) * persistent_scale,
		_get_float_property(target, "strange_vial_scale", 1.0)
	)


func get_player_paddle_width(target: Object, base_width: float) -> float:
	return _paddle_sync.get_player_paddle_width(get_player_paddle_scale(target), base_width)


func get_player_paddle_height(target: Object, base_height: float) -> float:
	return _paddle_sync.get_player_paddle_height(get_player_paddle_scale(target), base_height)


func get_pickup_effect(target: Object) -> Dictionary:
	return _get_dictionary_property(target, "pickup_effect")


func has_pickup_effect(target: Object) -> bool:
	return _pickup_effect_state.has_pickup_effect(get_pickup_effect(target))


func has_field_effects(target: Object) -> bool:
	return _status.has_field_effects(_build_field_effect_flags(target))


func get_pickup_particles(target: Object) -> Array[Dictionary]:
	return _get_array_property(target, "pickup_particles")


func get_regeneration_potion_particles(target: Object) -> Array[Dictionary]:
	return _get_array_property(target, "regeneration_potion_particles")


func get_regeneration_potion_rings(target: Object) -> Array[Dictionary]:
	return _get_array_property(target, "regeneration_potion_rings")


func get_magnet_field_particles(target: Object) -> Array[Dictionary]:
	return _get_array_property(target, "magnet_field_particles")


func get_holy_barrier_particles(target: Object) -> Array[Dictionary]:
	return _get_array_property(target, "holy_barrier_particles")


func get_dash_boost_particles(target: Object) -> Array[Dictionary]:
	return _get_array_property(target, "dash_boost_particles")


func get_field_effect_draw_context(target: Object) -> Dictionary:
	var pickup_particles: Array[Dictionary] = _get_array_property(target, "pickup_particles")
	var regeneration_potion_particles: Array[Dictionary] = _get_array_property(target, "regeneration_potion_particles")
	var regeneration_potion_rings: Array[Dictionary] = _get_array_property(target, "regeneration_potion_rings")
	var magnet_field_particles: Array[Dictionary] = _get_array_property(target, "magnet_field_particles")
	var holy_barrier_particles: Array[Dictionary] = _get_array_property(target, "holy_barrier_particles")
	var dash_boost_particles: Array[Dictionary] = _get_array_property(target, "dash_boost_particles")
	var brick_walls: Array[Dictionary] = _get_array_property(target, "brick_walls")
	var brick_particles: Array[Dictionary] = _get_array_property(target, "brick_particles")
	var trampolines: Array[Dictionary] = _get_array_property(target, "trampolines")
	var trampoline_particles: Array[Dictionary] = _get_array_property(target, "trampoline_particles")
	return {
		"pickup_particles": pickup_particles,
		"regeneration_potion_rings": regeneration_potion_rings,
		"regeneration_potion_particles": regeneration_potion_particles,
		"stopwatch_context": get_stopwatch_context(target) if bool(target.get("stopwatch_active")) else {},
		"magnet_field_context": get_magnet_field_context(target) if bool(target.get("magnet_field_active")) else {},
		"magnet_field_particles": magnet_field_particles,
		"holy_barrier_context": get_holy_barrier_context(target) if bool(target.get("holy_barrier_active")) else {},
		"holy_barrier_particles": holy_barrier_particles,
		"brick_wall_context": get_brick_wall_context(target) if bool(target.get("brick_wall_installing")) or not brick_walls.is_empty() or not brick_particles.is_empty() else {},
		"trampoline_context": {"trampolines": trampolines, "particles": trampoline_particles} if not trampolines.is_empty() or not trampoline_particles.is_empty() else {},
		"long_boost_timer_context": get_long_boost_timer_context(target) if bool(target.get("long_boost_active")) else {},
		"vitamin_pill_timer_context": get_vitamin_pill_timer_context(target) if bool(target.get("vitamin_pill_active")) else {},
		"strange_vial_timer_context": get_strange_vial_timer_context(target) if bool(target.get("strange_vial_active")) else {},
		"doping_potion_timer_context": get_doping_potion_context(target) if bool(target.get("doping_potion_active")) else {},
		"dash_boost_context": get_dash_boost_context(target) if bool(target.get("dash_boost_active")) else {},
		"dash_boost_particles": dash_boost_particles,
	}


func get_brick_wall_context(target: Object) -> Dictionary:
	return _context_builder.build_brick_wall_context(
		bool(target.get("brick_wall_installing")),
		float(target.get("brick_wall_install_timer_frames")),
		float(target.get("brick_wall_install_initial_frames")),
		_get_dictionary_property(target, "pending_brick_wall"),
		_get_array_property(target, "brick_walls"),
		_get_array_property(target, "brick_particles")
	)


func get_long_boost_timer_context(target: Object) -> Dictionary:
	return _context_builder.build_long_boost_timer_context(
		bool(target.get("long_boost_active")),
		float(target.get("long_boost_timer_frames")),
		float(target.get("long_boost_initial_timer_frames"))
	)


func get_vitamin_pill_timer_context(target: Object) -> Dictionary:
	return _context_builder.build_vitamin_pill_timer_context(
		bool(target.get("vitamin_pill_active")),
		float(target.get("vitamin_pill_timer_frames")),
		float(target.get("vitamin_pill_initial_timer_frames")),
		float(target.get("vitamin_pill_phase")),
		float(target.get("vitamin_pill_flash_timer_frames")),
		_get_vector2_property(target, "vitamin_pill_player_center")
	)


func get_strange_vial_timer_context(target: Object) -> Dictionary:
	return _context_builder.build_strange_vial_timer_context(
		bool(target.get("strange_vial_active")),
		float(target.get("strange_vial_timer_frames")),
		float(target.get("strange_vial_initial_timer_frames")),
		str(target.get("strange_vial_effect_type")),
		float(target.get("strange_vial_phase")),
		float(target.get("strange_vial_flash_timer_frames")),
		_get_vector2_property(target, "strange_vial_player_center"),
		float(target.get("strange_vial_scale")),
		float(target.get("strange_vial_speed_multiplier")),
		float(target.get("strange_vial_target_scale")),
		float(target.get("strange_vial_target_speed_multiplier"))
	)


func get_doping_potion_context(target: Object) -> Dictionary:
	return _context_builder.build_doping_potion_context(
		bool(target.get("doping_potion_active")),
		float(target.get("doping_potion_timer_frames")),
		float(target.get("doping_potion_initial_timer_frames")),
		float(target.get("doping_potion_phase")),
		float(target.get("doping_potion_flash_timer_frames")),
		_get_vector2_property(target, "doping_potion_player_center"),
		int(target.get("doping_potion_use_count"))
	)


func get_player_speed_multiplier(target: Object) -> float:
	return _status.get_player_speed_multiplier(
		bool(target.get("vitamin_pill_active")),
		float(target.get("vitamin_pill_timer_frames")),
		bool(target.get("strange_vial_active")),
		float(target.get("strange_vial_timer_frames")),
		float(target.get("strange_vial_speed_multiplier"))
	)


func get_aipill_context(target: Object) -> Dictionary:
	return _context_builder.build_aipill_context(
		bool(target.get("aipill_active")),
		float(target.get("aipill_phase")),
		float(target.get("aipill_flash_timer_frames"))
	)


# 능력치 툴팁용 아이템별 기여 내역. get_player_speed_multiplier /
# get_player_paddle_scale과 같은 상태 플래그·배율 소스를 읽으므로 두 값이
# 어긋나면 툴팁의 "기타 효과" 잔여 줄로 드러난다. 라벨은 아이템 표시명
# 로컬라이즈를 거친 최종 문자열이다.
func get_player_stat_breakdown(target: Object, stat_key: String) -> Array:
	var entries: Array = []
	match stat_key:
		"player_speed":
			if bool(target.get("vitamin_pill_active")) and float(target.get("vitamin_pill_timer_frames")) > 0.0:
				entries.append({
					"label": LanguageSettings.localize_item_display_name("vitamin_pill", "비타민드링크"),
					"ratio": ActiveItemEffectStatus.VITAMIN_PILL_SPEED_MULTIPLIER,
					"icon_id": "vitamin_pill",
				})
			if bool(target.get("strange_vial_active")) and float(target.get("strange_vial_timer_frames")) > 0.0:
				entries.append({
					"label": LanguageSettings.localize_item_display_name("strange_vial", "기묘한 약병"),
					"ratio": maxf(0.0, float(target.get("strange_vial_speed_multiplier"))),
					"icon_id": "strange_vial",
				})
		"paddle_scale":
			var long_boost_scale: float = _get_float_property(target, "long_boost_scale", 1.0)
			if absf(long_boost_scale - 1.0) > 0.001:
				entries.append({
					"label": LanguageSettings.localize_item_display_name("long_boost", "거대화포션"),
					"ratio": maxf(0.0, long_boost_scale),
					"icon_id": "long_boost",
				})
			var milk_bottle_scale: float = _get_float_property(target, "milk_bottle_scale", 1.0)
			if absf(milk_bottle_scale - 1.0) > 0.001:
				entries.append({
					"label": LanguageSettings.localize_item_display_name("milk_bottle", "우유병"),
					"ratio": maxf(0.0, milk_bottle_scale),
					"icon_id": "milk_bottle",
				})
			var strange_vial_scale: float = _get_float_property(target, "strange_vial_scale", 1.0)
			if absf(strange_vial_scale - 1.0) > 0.001:
				entries.append({
					"label": LanguageSettings.localize_item_display_name("strange_vial", "기묘한 약병"),
					"ratio": maxf(0.0, strange_vial_scale),
					"icon_id": "strange_vial",
				})
	return entries


func get_stopwatch_context(target: Object) -> Dictionary:
	return _context_builder.build_stopwatch_context(
		bool(target.get("stopwatch_active")),
		float(target.get("stopwatch_timer_frames")),
		float(target.get("stopwatch_initial_timer_frames")),
		float(target.get("stopwatch_recovery_timer_frames")),
		float(target.get("stopwatch_flash_timer_frames")),
		float(target.get("stopwatch_clock_angle"))
	)


func get_magnet_field_context(target: Object) -> Dictionary:
	return _context_builder.build_magnet_field_context(
		bool(target.get("magnet_field_active")),
		float(target.get("magnet_field_timer_frames")),
		float(target.get("magnet_field_initial_timer_frames")),
		float(target.get("magnet_field_phase")),
		_get_vector2_property(target, "magnet_field_player_center")
	)


func get_holy_barrier_context(target: Object) -> Dictionary:
	return _context_builder.build_holy_barrier_context(
		bool(target.get("holy_barrier_active")),
		float(target.get("holy_barrier_timer_frames")),
		float(target.get("holy_barrier_initial_timer_frames")),
		float(target.get("holy_barrier_glow_phase"))
	)


func get_holy_barrier_collision_context(target: Object) -> Dictionary:
	return _context_builder.build_holy_barrier_collision_context(bool(target.get("holy_barrier_active")))


func get_dash_boost_context(target: Object) -> Dictionary:
	return _context_builder.build_dash_boost_context(
		bool(target.get("dash_boost_active")),
		float(target.get("dash_boost_timer_frames")),
		float(target.get("dash_boost_initial_timer_frames")),
		float(target.get("dash_boost_glow_phase")),
		_get_vector2_property(target, "dash_boost_player_center")
	)


func get_dash_boost_timer_context(target: Object) -> Dictionary:
	return _context_builder.build_dash_boost_timer_context(
		bool(target.get("dash_boost_active")),
		float(target.get("dash_boost_timer_frames")),
		float(target.get("dash_boost_initial_timer_frames"))
	)


func get_dash_boost_remaining_ratio(target: Object) -> float:
	if not bool(target.get("dash_boost_active")):
		return 0.0
	var initial: float = float(target.get("dash_boost_initial_timer_frames"))
	if initial <= 0.0:
		return 0.0
	return clamp(float(target.get("dash_boost_timer_frames")) / initial, 0.0, 1.0)


func get_dash_boost_remaining_time(target: Object) -> float:
	if not bool(target.get("dash_boost_active")):
		return 0.0
	return max(0.0, float(target.get("dash_boost_timer_frames")) / 60.0)


func get_brick_wall_collision_context(target: Object) -> Dictionary:
	return {
		"brick_walls": _get_array_property(target, "brick_walls"),
	}


func get_stopwatch_ball_context(target: Object) -> Dictionary:
	return _context_builder.build_stopwatch_ball_context(
		bool(target.get("stopwatch_active")),
		float(target.get("stopwatch_timer_frames")),
		float(target.get("stopwatch_recovery_timer_frames")),
		float(target.get("stopwatch_post_recovery_grace_frames")),
		get_stopwatch_recovery_speed_ratio(target),
		_get_vector2_property(target, "stopwatch_original_ball_vel")
	)


func is_time_frozen(target: Object) -> bool:
	return _status.is_time_frozen(
		bool(target.get("stopwatch_active")),
		float(target.get("stopwatch_timer_frames"))
	)


func is_aipill_active(target: Object) -> bool:
	return _status.is_active(bool(target.get("aipill_active")))


func is_stopwatch_active(target: Object) -> bool:
	return _status.is_active(bool(target.get("stopwatch_active")))


func is_doping_potion_active(target: Object) -> bool:
	return _status.is_active(bool(target.get("doping_potion_active")) and float(target.get("doping_potion_timer_frames")) > 0.0)


func is_holy_barrier_active(target: Object) -> bool:
	return _status.is_active(bool(target.get("holy_barrier_active")))


func is_dash_boost_active(target: Object) -> bool:
	return _status.is_active(bool(target.get("dash_boost_active")))


func is_magnet_field_active(target: Object) -> bool:
	return _status.is_active(bool(target.get("magnet_field_active")))


func is_wall_installing(target: Object) -> bool:
	return _status.is_active(bool(target.get("brick_wall_installing")))


func get_stopwatch_recovery_speed_ratio(target: Object) -> float:
	return _stopwatch_owner_effects.get_recovery_speed_ratio(float(target.get("stopwatch_recovery_timer_frames")))


func _build_active_status_flags(target: Object) -> Dictionary:
	return {
		"aipill_active": bool(target.get("aipill_active")),
		"long_boost_active": bool(target.get("long_boost_active")),
		"milk_bottle_active": bool(target.get("milk_bottle_active")),
		"vitamin_pill_active": bool(target.get("vitamin_pill_active")),
		"strange_vial_active": bool(target.get("strange_vial_active")),
		"doping_potion_active": bool(target.get("doping_potion_active")),
		"stopwatch_active": bool(target.get("stopwatch_active")),
		"magnet_field_active": bool(target.get("magnet_field_active")),
		"holy_barrier_active": bool(target.get("holy_barrier_active")),
		"dash_boost_active": bool(target.get("dash_boost_active")),
		"brick_wall_installing": bool(target.get("brick_wall_installing")),
	}


func _build_field_effect_flags(target: Object) -> Dictionary:
	var flags: Dictionary = _build_active_status_flags(target)
	flags.merge({
		"has_pickup_particles": not get_pickup_particles(target).is_empty(),
		"has_regeneration_potion_rings": not get_regeneration_potion_rings(target).is_empty(),
		"has_regeneration_potion_particles": not get_regeneration_potion_particles(target).is_empty(),
		"has_magnet_field_particles": not get_magnet_field_particles(target).is_empty(),
		"has_holy_barrier_particles": not get_holy_barrier_particles(target).is_empty(),
		"has_dash_boost_particles": not get_dash_boost_particles(target).is_empty(),
		"has_brick_walls": not _get_array_property(target, "brick_walls").is_empty(),
		"has_brick_particles": not _get_array_property(target, "brick_particles").is_empty(),
		"has_trampolines": not _get_array_property(target, "trampolines").is_empty(),
		"has_trampoline_particles": not _get_array_property(target, "trampoline_particles").is_empty(),
	}, true)
	return flags


func _get_array_property(target: Object, key: String) -> Array[Dictionary]:
	var value: Variant = target.get(key)
	if value is Array:
		return value
	return []


func _get_dictionary_property(target: Object, key: String) -> Dictionary:
	var value: Variant = target.get(key)
	if value is Dictionary:
		return value
	return {}


func _get_vector2_property(target: Object, key: String) -> Vector2:
	var value: Variant = target.get(key)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_float_property(target: Object, key: String, fallback: float) -> float:
	var value: Variant = target.get(key)
	if value == null:
		return fallback
	return float(value)
