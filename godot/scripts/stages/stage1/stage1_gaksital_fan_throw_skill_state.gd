extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const Stage1GaksitalFanProjectileContract := preload(
	"res://scripts/stages/stage1/stage1_gaksital_fan_projectile_contract.gd"
)

const STAGE_ID := 1
const BOSS_VARIANT := "gaksi"
const GAUGE_COST := 150.0
const WINDUP_FRAMES := 30.0
const ENRAGED_EXTRA_ANGLE_DEGREES := 35.0
const DEBUG_FORCE_ENRAGE_ENV := "DISKHEARTS_FORCE_GAKSI_ENRAGE"
const HIT_EFFECT_FRAMES := 24.0
const SMOKE_OPACITY_THRESHOLD := 0.05

var active := false
var windup_timer := 0.0
var timer_frames := 0.0
var fans: Array = []
var hit_effect_timer := 0.0
var hit_effect_pos := Vector2.ZERO
var enraged_launch := false
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	reset_round()


func reset_round() -> void:
	active = false
	windup_timer = 0.0
	timer_frames = 0.0
	fans.clear()
	hit_effect_timer = 0.0
	hit_effect_pos = Vector2.ZERO
	enraged_launch = false


func can_activate(context: Dictionary = {}) -> bool:
	return (
		int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and _is_gaksital_context(context)
		and not active
		and windup_timer <= 0.0
		and fans.is_empty()
	)


func should_roll_activation(gauge: float, context: Dictionary = {}) -> bool:
	return gauge >= GAUGE_COST and can_activate(context)


func activate(context: Dictionary, _deps: Dictionary = {}) -> bool:
	if not can_activate(context):
		return false
	active = true
	windup_timer = WINDUP_FRAMES
	timer_frames = Stage1GaksitalFanProjectileContract.DURATION_FRAMES
	enraged_launch = bool(context.get("enraged_boss_active", false)) or _is_debug_force_enrage_enabled()
	fans.clear()
	return true


func update_and_collide(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or not _is_gaksital_context(context):
		reset_round()
		return {}

	hit_effect_timer = max(0.0, hit_effect_timer - fps_scale)
	if not active and windup_timer <= 0.0 and fans.is_empty():
		return {}

	if windup_timer > 0.0:
		windup_timer = max(0.0, windup_timer - fps_scale)
		if windup_timer <= 0.0:
			_launch_fans(context, deps)
		return {}

	if fans.is_empty():
		active = false
		timer_frames = 0.0
		return {}

	timer_frames = max(0.0, timer_frames - fps_scale)
	if timer_frames <= 0.0:
		active = false
		fans.clear()
		return {}

	_update_fans(fps_scale, context, deps)
	var hit_result: Dictionary = _check_player_collision(scene, context, deps)
	if not hit_result.is_empty():
		return hit_result
	if fans.is_empty():
		active = false
	return {}


func get_draw_context() -> Dictionary:
	return {
		"stage1_fan_throw_active": active or windup_timer > 0.0 or not fans.is_empty() or hit_effect_timer > 0.0,
		"stage1_fan_throw_fans": fans.duplicate(true),
		"stage1_fan_throw_windup_timer": windup_timer,
		"stage1_fan_throw_windup_progress": clamp(1.0 - windup_timer / WINDUP_FRAMES, 0.0, 1.0),
		"stage1_fan_throw_hit_effect_timer": hit_effect_timer,
		"stage1_fan_throw_hit_effect_pos": hit_effect_pos,
		"boss_fan_throw_active": windup_timer > 0.0,
		"boss_fan_throw_frame": get_fan_throw_frame_index(),
	}


func is_active() -> bool:
	return active or windup_timer > 0.0 or not fans.is_empty()


func get_fan_throw_frame_index() -> int:
	if windup_timer <= 0.0:
		return 15
	var progress: float = clamp(1.0 - windup_timer / WINDUP_FRAMES, 0.0, 0.999)
	return int(progress * 16.0)


func _launch_fans(context: Dictionary, deps: Dictionary) -> void:
	fans.clear()
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0))
	var boss_height: float = max(1.0, float(context.get("boss_hitbox_height", boss_size.y)))
	var launch_pos := Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + boss_height
	)
	var player_center: Vector2 = _get_player_center(context)
	var base_direction := (player_center - launch_pos)
	if base_direction.length() <= 0.001:
		base_direction = Vector2.DOWN
	base_direction = base_direction.normalized()
	_append_fan(
		launch_pos,
		base_direction,
		Stage1GaksitalFanProjectileContract.DRAW_SIZE,
		Color.WHITE,
		Stage1GaksitalFanProjectileContract.MAIN_FAN_SOUND_VOLUME,
		Stage1GaksitalFanProjectileContract.MAIN_HIT_SOUND_VOLUME
	)
	if enraged_launch:
		_append_fan(launch_pos, base_direction.rotated(deg_to_rad(-ENRAGED_EXTRA_ANGLE_DEGREES)), Stage1GaksitalFanProjectileContract.EXTRA_DRAW_SIZE, Color(1.0, 0.84, 0.66, 1.0), Stage1GaksitalFanProjectileContract.EXTRA_FAN_SOUND_VOLUME, Stage1GaksitalFanProjectileContract.EXTRA_HIT_SOUND_VOLUME)
		_append_fan(launch_pos, base_direction.rotated(deg_to_rad(ENRAGED_EXTRA_ANGLE_DEGREES)), Stage1GaksitalFanProjectileContract.EXTRA_DRAW_SIZE, Color(1.0, 0.84, 0.66, 1.0), Stage1GaksitalFanProjectileContract.EXTRA_FAN_SOUND_VOLUME, Stage1GaksitalFanProjectileContract.EXTRA_HIT_SOUND_VOLUME)


func _append_fan(origin: Vector2, direction: Vector2, draw_size: float, tint: Color, fan_sound_volume: float, hit_sound_volume: float) -> void:
	fans.append(Stage1GaksitalFanProjectileContract.build_projectile(
		origin,
		direction,
		draw_size,
		tint,
		fan_sound_volume,
		hit_sound_volume,
		rng.randf_range(
			-Stage1GaksitalFanProjectileContract.VX_JITTER,
			Stage1GaksitalFanProjectileContract.VX_JITTER
		)
	))


func _update_fans(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var next_fans: Array = []
	for fan_value in fans:
		if not (fan_value is Dictionary):
			continue
		var motion := Stage1GaksitalFanProjectileContract.advance_projectile(
			fan_value as Dictionary,
			fps_scale
		)
		var fan: Dictionary = motion.get("projectile", {})
		if bool(motion.get("spin_boundary_crossed", false)):
			Stage1GaksitalFanProjectileContract.play_fan_audio(
				deps,
				float(fan.get("fan_sound_volume", Stage1GaksitalFanProjectileContract.MAIN_FAN_SOUND_VOLUME))
			)
		if Stage1GaksitalFanProjectileContract.is_expired_or_out_of_bounds(fan, width, height):
			continue
		next_fans.append(fan)
	fans = next_fans


func _check_player_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var player_center: Vector2 = _get_player_center(context)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	var hit_distance: float = Stage1GaksitalFanProjectileContract.HIT_RADIUS + max(1.0, player_size.x * 0.5)
	for fan_value in fans:
		if not (fan_value is Dictionary):
			continue
		var fan: Dictionary = fan_value
		var fan_pos := Vector2(float(fan.get("x", 0.0)), float(fan.get("y", 0.0)))
		if fan_pos.distance_to(player_center) > hit_distance:
			continue
		fans.clear()
		active = false
		timer_frames = 0.0
		if _is_player_in_smoke(player_center, context, deps):
			_trigger_boss_skill_parry(fan_pos, deps)
			return {
				"stage1_gaksital_fan_throw_hit": true,
				"stage1_gaksital_fan_throw_smoke_blocked": true,
			}
		hit_effect_timer = HIT_EFFECT_FRAMES
		hit_effect_pos = player_center
		_spawn_impact(player_center, deps)
		var knockback_vel: float = _apply_player_hit(player_center, fan_pos, deps, float(fan.get("hit_sound_volume", Stage1GaksitalFanProjectileContract.MAIN_HIT_SOUND_VOLUME)))
		scene["stage1_gaksital_fan_throw_hit"] = true
		return {
			"stage1_gaksital_fan_throw_hit": true,
			"stage1_gaksital_fan_throw_player_stunned": true,
			"stage1_gaksital_fan_throw_player_knockback_vel": knockback_vel,
		}
	return {}


func _apply_player_hit(_player_center: Vector2, _fan_pos: Vector2, deps: Dictionary, hit_sound_volume: float) -> float:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status(
			"player",
			"stun",
			Stage1GaksitalFanProjectileContract.STUN_FRAMES,
			{
				"source": "stage1_fan_throw",
				"cleansable": true,
			},
			"stage1_fan_throw"
		)
	var knockback_vel := Stage1GaksitalFanProjectileContract.roll_knockback_velocity(rng)
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(
			knockback_vel,
			Stage1GaksitalFanProjectileContract.KNOCKBACK_FRAMES,
			Stage1GaksitalFanProjectileContract.KNOCKBACK_DECAY,
			true,
			true
		)
	Stage1GaksitalFanProjectileContract.play_hit_audio(deps, hit_sound_volume)
	return knockback_vel


func _spawn_impact(pos: Vector2, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null:
		return
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 0.55, 1.0)
	if impact_effects.has_method("spawn_paddle_hit_particles"):
		impact_effects.spawn_paddle_hit_particles(pos, true, Vector2(0.0, -1.0), 1.0)


func _is_player_in_smoke(player_center: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("player_in_smoke", false)):
		return true
	for value in _get_smoke_zones(context, deps):
		var zone: Dictionary = _as_dict(value)
		if zone.is_empty():
			continue
		var opacity: float = float(zone.get("opacity", 0.0))
		var threshold := 50.0 if opacity > 1.0 else SMOKE_OPACITY_THRESHOLD
		if opacity <= threshold:
			continue
		var center: Vector2 = _get_smoke_zone_center(zone)
		var radius_y: float = float(zone.get("radius", 0.0))
		var radius_x: float = float(zone.get("radius_x", radius_y))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var dx: float = (player_center.x - center.x) / radius_x
		var dy: float = (player_center.y - center.y) / radius_y
		if dx * dx + dy * dy <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var context_zones := _as_array(context.get(key, []))
		if not context_zones.is_empty():
			return context_zones
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_tear_gas_zones"):
			var runtime_zones := _as_array(active_item_runtime.get_tear_gas_zones())
			if not runtime_zones.is_empty():
				return runtime_zones
		var throw_controller: Object = active_item_runtime.get("throw_controller")
		if throw_controller != null and throw_controller.has_method("get_tear_gas_zones"):
			var controller_zones := _as_array(throw_controller.get_tear_gas_zones())
			if not controller_zones.is_empty():
				return controller_zones
	return []


func _get_smoke_zone_center(zone: Dictionary) -> Vector2:
	if zone.get("position", null) is Vector2:
		return zone.get("position")
	return Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))


func _get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	return player_pos + player_size * 0.5


func _trigger_boss_skill_parry(pos: Vector2, deps: Dictionary) -> void:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("trigger_magic_anti_potion_parry"):
		active_item_runtime.trigger_magic_anti_potion_parry("부채", pos, "fan_throw")


func _is_gaksital_context(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in [BOSS_VARIANT, "gaksital", "talkwangdae", "talchum"]


func _is_debug_force_enrage_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	var value := OS.get_environment(DEBUG_FORCE_ENRAGE_ENV).strip_edges().to_lower()
	return value in ["1", "true", "yes", "on"]


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
