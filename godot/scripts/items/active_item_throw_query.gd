extends RefCounted

const VISIBLE_EFFECT_ARRAY_KEYS := [
	"pending_throws",
	"grenades",
	"flares",
	"tear_gas_projectiles",
	"tear_gas_zones",
	"dynamites",
	"placed_dynamites",
	"molotovs",
	"molotov_fire_zones",
	"boomerangs",
	"banana_projectiles",
	"landed_bananas",
	"soap_projectiles",
	"landed_soaps",
	"boomerang_particles",
	"banana_particles",
	"soap_particles",
	"soap_foam_trails",
	"spider_mines",
	"spider_mine_particles",
	"dynamite_explosions",
	"explosion_zones",
	"flare_zones",
]


func is_throw_windup_active(controller: Object) -> bool:
	return not _get_array(controller, "pending_throws").is_empty()


func has_visible_effects(controller: Object) -> bool:
	for key in VISIBLE_EFFECT_ARRAY_KEYS:
		if not _get_array(controller, key).is_empty():
			return true
	return false


func has_actor_draw_context(controller: Object) -> bool:
	return (
		has_visible_effects(controller)
		or _get_float(controller, "grenade_boss_stun_timer_frames") > 0.0
		or _get_float(controller, "flare_boss_confused_timer_frames") > 0.0
		or is_boss_skill_cooldown_paused(controller)
		or _get_float(controller, "tear_gas_boss_pause_text_timer_frames") > 0.0
		or _get_float(controller, "banana_boss_slip_timer_frames") > 0.0
		or _get_float(controller, "soap_boss_slip_timer_frames") > 0.0
		or _get_float(controller, "spider_mine_slow_timer_frames") > 0.0
	)


func build_actor_draw_context(controller: Object, throw_context: Dictionary) -> Dictionary:
	if not has_actor_draw_context(controller):
		return {}
	var banana_slip_duration: float = _get_float(controller, "BANANA_SLIP_DURATION_FRAMES", 1.0)
	var soap_debuff_duration: float = _get_float(controller, "SOAP_DEBUFF_DURATION_FRAMES", 1.0)
	var spider_mine_slow_duration: float = _get_float(controller, "SPIDER_MINE_SLOW_DURATION_FRAMES", 1.0)
	var boss_stun_frame_msec: float = _get_float(controller, "BOSS_STUN_FRAME_MSEC", 100.0)
	var banana_boss_slip_timer_frames: float = _get_float(controller, "banana_boss_slip_timer_frames")
	var soap_boss_slip_timer_frames: float = _get_float(controller, "soap_boss_slip_timer_frames")
	var spider_mine_slow_timer_frames: float = _get_float(controller, "spider_mine_slow_timer_frames")
	var tear_gas_cooldown_paused: bool = is_boss_skill_cooldown_paused(controller)
	var tear_gas_marker_active: bool = (
		tear_gas_cooldown_paused
		or _get_float(controller, "tear_gas_boss_pause_text_timer_frames") > 0.0
	)

	return {
		"active_item_throw_windup_active": bool(throw_context.get("active", false)),
		"active_item_throw_windup_progress": float(throw_context.get("progress", 0.0)),
		"active_item_throw_windup_angle_degrees": float(throw_context.get("angle_degrees", 0.0)),
		"active_item_throw_windup_name": str(throw_context.get("item_name", "")),
		"active_item_boss_stun_active": _get_float(controller, "grenade_boss_stun_timer_frames") > 0.0,
		"active_item_boss_stun_frame": int(Time.get_ticks_msec() / boss_stun_frame_msec) % 8,
		"active_item_boss_confusion_active": _get_float(controller, "flare_boss_confused_timer_frames") > 0.0,
		"active_item_boss_tear_gas_pause_active": tear_gas_marker_active,
		"active_item_tear_gas_cooldown_pause_active": tear_gas_cooldown_paused,
		"active_item_boss_skill_cooldown_paused": tear_gas_cooldown_paused,
		"active_item_boss_banana_slip_active": banana_boss_slip_timer_frames > 0.0,
		"active_item_boss_banana_slip_ratio": (
			banana_boss_slip_timer_frames / banana_slip_duration
			if banana_slip_duration > 0.0
			else 0.0
		),
		"active_item_boss_soap_active": soap_boss_slip_timer_frames > 0.0,
		"active_item_boss_soap_ratio": (
			soap_boss_slip_timer_frames / soap_debuff_duration
			if soap_debuff_duration > 0.0
			else 0.0
		),
		"active_item_boss_spider_slow_active": spider_mine_slow_timer_frames > 0.0,
		"active_item_boss_spider_slow_ratio": (
			spider_mine_slow_timer_frames / spider_mine_slow_duration
			if spider_mine_slow_duration > 0.0
			else 0.0
		),
	}


func build_boss_ai_context(controller: Object) -> Dictionary:
	return {
		"active_item_grenade_stun_active": _get_float(controller, "grenade_boss_stun_timer_frames") > 0.0,
		"active_item_grenade_knockback_active": (
			_get_float(controller, "grenade_boss_knockback_timer_frames") > 0.0
			and abs(_get_float(controller, "grenade_boss_knockback_vel")) > 0.0
		),
		"active_item_grenade_knockback_vel": _get_float(controller, "grenade_boss_knockback_vel"),
		"active_item_flare_confusion_active": _get_float(controller, "flare_boss_confused_timer_frames") > 0.0,
		"active_item_banana_slip_active": _get_float(controller, "banana_boss_slip_timer_frames") > 0.0,
		"active_item_banana_slip_direction": _get_float(controller, "banana_boss_slip_direction"),
		"active_item_banana_slip_speed": get_banana_slip_speed(controller),
		"active_item_soap_slip_active": _get_float(controller, "soap_boss_slip_timer_frames") > 0.0,
		"active_item_soap_slip_blend": _get_float(controller, "SOAP_BLEND_FACTOR"),
		"active_item_soap_slip_friction": _get_float(controller, "SOAP_FRICTION"),
		"active_item_molotov_slow_active": _get_float(controller, "molotov_fire_slow_timer_frames") > 0.0,
		"active_item_molotov_slow_factor": _get_float(controller, "MOLOTOV_FIRE_SLOW_FACTOR"),
		"active_item_molotov_fire_barriers": _get_molotov_fire_barriers(controller),
		"active_item_tear_gas_cooldown_pause_active": is_boss_skill_cooldown_paused(controller),
		"active_item_boss_skill_cooldown_paused": is_boss_skill_cooldown_paused(controller),
		"active_item_spider_mine_slow_active": _get_float(controller, "spider_mine_slow_timer_frames") > 0.0,
		"active_item_spider_mine_slow_factor": _get_float(controller, "SPIDER_MINE_SLOW_FACTOR"),
	}


func is_boss_skill_cooldown_paused(controller: Object) -> bool:
	return _get_float(controller, "tear_gas_boss_pause_timer_frames") > 0.0


func _get_molotov_fire_barriers(controller: Object) -> Array:
	if controller != null and controller.has_method("get_molotov_fire_barriers"):
		return controller.get_molotov_fire_barriers()
	return []


func get_banana_slip_speed(controller: Object) -> float:
	var banana_boss_slip_timer_frames: float = _get_float(controller, "banana_boss_slip_timer_frames")
	if banana_boss_slip_timer_frames <= 0.0:
		return 0.0
	var banana_slip_duration: float = _get_float(controller, "BANANA_SLIP_DURATION_FRAMES")
	if banana_slip_duration <= 0.0:
		return _get_float(controller, "BANANA_SLIP_BASE_SPEED")
	var slip_ratio: float = banana_boss_slip_timer_frames / banana_slip_duration
	return _get_float(controller, "BANANA_SLIP_BASE_SPEED") + _get_float(controller, "BANANA_SLIP_DECAY_SPEED") * clamp(slip_ratio, 0.0, 1.0)


func is_boss_in_molotov_fire(controller: Object) -> bool:
	for zone in _get_array(controller, "molotov_fire_zones"):
		if zone is Dictionary and bool(zone.get("boss_in_fire", false)):
			return true
	return false


func _get_array(source: Object, key: String) -> Array:
	if source == null:
		return []
	var value: Variant = source.get(key)
	if value is Array:
		return value
	return []


func _get_float(source: Object, key: String, fallback: float = 0.0) -> float:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value is float or value is int:
		return float(value)
	return fallback
