extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const BALL_RADIUS_FALLBACK := 14.3
const HIT_COOLDOWN_SECONDS := 0.42
const HIT_FLASH_SECONDS := 0.28
const BOUNCE_MAX_ANGLE := 60.0
const BOUNCE_MIN_SPEED := 6.0
const HIT_GAUGE_FLASH_SECONDS := 0.45
const RALLY_SPEED_CAP_INCREASE_PER_GUARD := 0.5
const RALLY_SPEED_CAP_BONUS_MAX := BallUpdateStaticConfig.RALLY_SPEED_CAP_BONUS_MAX

var ball_was_inside := false
var contact_count := 0
var last_contact_pos := Vector2.ZERO
var cooldown := 0.0
var hit_flash_timer := 0.0
var gauge_flash_timer := 0.0
var gauge_trigger_count := 0
var gauge_last_gain := 0.0


func advance(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	cooldown = maxf(0.0, cooldown - safe_delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - safe_delta)
	gauge_flash_timer = maxf(0.0, gauge_flash_timer - safe_delta)


func reset_all() -> void:
	ball_was_inside = false
	contact_count = 0
	last_contact_pos = Vector2.ZERO
	cooldown = 0.0
	hit_flash_timer = 0.0
	gauge_flash_timer = 0.0
	gauge_trigger_count = 0
	gauge_last_gain = 0.0


func reset_round_transients() -> void:
	hit_flash_timer = 0.0
	gauge_flash_timer = 0.0


func resolve_ball_hit(
	owner: Object,
	registry: Object,
	companion_pos: Vector2,
	catch_width: float,
	catch_height: float,
	hit_gauge_gain: float,
	companion_active: bool,
	strike_active: bool
) -> Dictionary:
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		ball_was_inside = false
		return {"hit": false}
	if companion_pos == Vector2.ZERO:
		return {"hit": false}

	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var half_width: float = maxf(1.0, catch_width * 0.5)
	var half_height: float = maxf(1.0, catch_height * 0.5)
	var dx: float = absf(ball_pos.x - companion_pos.x)
	var dy: float = absf(ball_pos.y - companion_pos.y)
	var inside: bool = dx <= half_width + ball_radius and dy <= half_height + ball_radius
	var hit_now: bool = inside and not ball_was_inside and cooldown <= 0.0
	ball_was_inside = inside
	if not hit_now:
		return {"hit": false}

	contact_count += 1
	last_contact_pos = ball_pos
	cooldown = HIT_COOLDOWN_SECONDS
	hit_flash_timer = HIT_FLASH_SECONDS
	_release_ball_control_skill_for_companion_guard(owner, registry)
	_apply_paddle_bounce(owner, registry, ball_pos, ball_radius, companion_pos, half_width, half_height)
	_register_ball_intensity_contact(registry)
	_play_paddle_hit(registry)
	_try_apply_hit_gauge_gain(owner, registry, hit_gauge_gain, companion_active)
	return {
		"hit": true,
		"should_begin_strike": not strike_active,
	}


func get_snapshot(companion_active: bool, hit_gauge_gain: float) -> Dictionary:
	return {
		"companion_contact_count": contact_count,
		"companion_last_contact_pos": last_contact_pos,
		"companion_hit_cooldown": cooldown,
		"companion_hit_flash_timer": hit_flash_timer,
		"companion_hit_gauge_gain": hit_gauge_gain if companion_active else 0.0,
		"companion_hit_gauge_last_gain": gauge_last_gain,
		"companion_hit_gauge_trigger_count": gauge_trigger_count,
		"companion_hit_gauge_flash_timer": gauge_flash_timer,
		"companion_hit_gauge_flash_ratio": get_gauge_flash_ratio(companion_active),
	}


func get_hit_flash_ratio(companion_active: bool) -> float:
	if not companion_active or HIT_FLASH_SECONDS <= 0.0:
		return 0.0
	return clampf(hit_flash_timer / HIT_FLASH_SECONDS, 0.0, 1.0)


func get_gauge_flash_ratio(companion_active: bool) -> float:
	if not companion_active or HIT_GAUGE_FLASH_SECONDS <= 0.0:
		return 0.0
	return clampf(gauge_flash_timer / HIT_GAUGE_FLASH_SECONDS, 0.0, 1.0)


func _apply_paddle_bounce(owner: Object, registry: Object, ball_pos: Vector2, ball_radius: float, companion_pos: Vector2, half_width: float, half_height: float) -> void:
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	var speed: float = maxf(ball_vel.length(), BOUNCE_MIN_SPEED)
	var max_angle: float = float(BattleSceneOwnerReader.get_value(owner, "max_bounce_angle", BOUNCE_MAX_ANGLE))
	var hit_pos: float = clampf((ball_pos.x - companion_pos.x) / maxf(1.0, half_width), -1.0, 1.0)
	var launch_dir: Vector2 = Vector2(0.0, -1.0).rotated(deg_to_rad(hit_pos * max_angle)).normalized()
	owner.set("ball_vel", _apply_companion_guard_bounce_speed(registry, owner, launch_dir * speed))
	owner.set("ball_pos", companion_pos + launch_dir * (half_height + ball_radius + 1.0))
	_apply_rally_speed_cap_progression(owner)


func _apply_companion_guard_bounce_speed(registry: Object, owner: Object, velocity: Vector2) -> Vector2:
	var ball_physics: Object = _get_registry_instance(registry, "ball_physics")
	if ball_physics == null or not ball_physics.has_method("apply_companion_guard_bounce_speed"):
		return velocity
	var cap_bonus: float = clampf(float(BattleSceneOwnerReader.get_value(owner, "rally_speed_cap_bonus", 0.0)), 0.0, RALLY_SPEED_CAP_BONUS_MAX)
	var adjusted: Variant = ball_physics.apply_companion_guard_bounce_speed(velocity, cap_bonus)
	return adjusted if adjusted is Vector2 else velocity


func _apply_rally_speed_cap_progression(owner: Object) -> void:
	var current_bonus: float = maxf(0.0, float(BattleSceneOwnerReader.get_value(owner, "rally_speed_cap_bonus", 0.0)))
	owner.set("rally_speed_cap_bonus", minf(current_bonus + RALLY_SPEED_CAP_INCREASE_PER_GUARD, RALLY_SPEED_CAP_BONUS_MAX))


func _try_apply_hit_gauge_gain(owner: Object, registry: Object, hit_gauge_gain: float, companion_active: bool) -> bool:
	if not companion_active:
		return false
	var gauge_max: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", 500.0)))
	var current_gauge: float = clampf(float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0)), 0.0, gauge_max)
	if current_gauge >= gauge_max:
		gauge_last_gain = 0.0
		return false
	var next_gauge: float = minf(gauge_max, current_gauge + maxf(0.0, hit_gauge_gain))
	var applied_gain: float = maxf(0.0, next_gauge - current_gauge)
	if applied_gain <= 0.0:
		gauge_last_gain = 0.0
		return false
	owner.set("special_gauge", next_gauge)
	gauge_last_gain = applied_gain
	gauge_trigger_count += 1
	gauge_flash_timer = HIT_GAUGE_FLASH_SECONDS
	_trigger_hit_gauge_feedback(registry)
	return true


func _release_ball_control_skill_for_companion_guard(owner: Object, registry: Object) -> void:
	var whip: Object = _get_registry_instance(registry, "stage1_dalji_whip_skill_state")
	if whip == null or not whip.has_method("register_player_hit"):
		return
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	var context := {"current_stage": int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1))}
	whip.register_player_hit(ball_vel, context)


func _play_paddle_hit(registry: Object) -> void:
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _register_ball_intensity_contact(registry: Object) -> void:
	var ball_intensity: Object = _get_registry_instance(registry, "ball_intensity")
	if ball_intensity != null and ball_intensity.has_method("register_contact"):
		ball_intensity.register_contact("lingpet", "player", {"source": "companion_guard"})


func _trigger_hit_gauge_feedback(registry: Object) -> void:
	var feedback: Object = _get_registry_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()
	var orb_hud_state: Object = _get_registry_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(Time.get_ticks_msec())


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
