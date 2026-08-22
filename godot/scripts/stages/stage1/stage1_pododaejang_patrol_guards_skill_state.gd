extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")

const STAGE_ID := 1
const BOSS_VARIANT := "podo"
const GAUGE_COST := 150.0
const DURATION_FRAMES := 300.0
const FADE_FRAMES := 30.0
const GUARD_RADIUS := 18.0
const GUARD_COUNT := 2
const GUARD_X_POSITIONS := [300.0, 460.0]
const GUARD_SPAWN_Y_OFFSET := 30.0
const PATROL_LEFT := 140.0
const PATROL_RIGHT := 620.0
const TARGET_LEFT := 160.0
const TARGET_RIGHT := 600.0
const PATROL_SPEED_MIN_PX_PER_SECOND := 110.0
const PATROL_SPEED_MAX_PX_PER_SECOND := 180.0
const INITIAL_WAIT_MIN_FRAMES := 10.0
const INITIAL_WAIT_MAX_FRAMES := 30.0
const WAIT_MIN_FRAMES := 24.0
const WAIT_MAX_FRAMES := 90.0
const TARGET_REACHED_DISTANCE := 3.0
const PUSH_SPEED_PX_PER_FRAME := 8.0
const PUSH_FRAMES := 10.0
const PUSH_DECAY_PER_FRAME := 0.85
const COLLISION_COOLDOWN_FRAMES := 10.0
const POJOL_FRAME_COUNT := 8
const POJOL_FRAME_DURATION := 6.0

var active := false
var timer_frames := 0.0
var used_this_round := false
var guards: Array = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	reset_round()


func reset_round() -> void:
	active = false
	timer_frames = 0.0
	used_this_round = false
	guards.clear()


func can_activate(context: Dictionary = {}) -> bool:
	return (
		int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and _is_pododaejang_context(context)
		and not active
		and not used_this_round
	)


func should_roll_activation(gauge: float, context: Dictionary = {}) -> bool:
	return gauge >= GAUGE_COST and can_activate(context)


func activate(context: Dictionary, deps: Dictionary = {}) -> bool:
	if not can_activate(context):
		return false
	active = true
	used_this_round = true
	timer_frames = DURATION_FRAMES
	guards.clear()
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0))
	var boss_height: float = maxf(1.0, float(context.get("boss_hitbox_height", boss_size.y)))
	var spawn_y: float = boss_pos.y + boss_height + GUARD_SPAWN_Y_OFFSET
	for index in range(GUARD_COUNT):
		var direction: float = 1.0 if index == 0 else -1.0
		guards.append({
			"x": GUARD_X_POSITIONS[index],
			"y": spawn_y,
			"direction": direction,
			"target_x": rng.randf_range(TARGET_LEFT, TARGET_RIGHT),
			"wait_timer": rng.randf_range(INITIAL_WAIT_MIN_FRAMES, INITIAL_WAIT_MAX_FRAMES),
			"patrol_speed": rng.randf_range(PATROL_SPEED_MIN_PX_PER_SECOND, PATROL_SPEED_MAX_PX_PER_SECOND),
			"push_vx": 0.0,
			"push_timer": 0.0,
			"collision_cooldown": 0.0,
			"age_frames": 0.0,
			"alpha": 1.0,
		})
	_play_summon_audio(deps)
	return true


func update_and_collide(
	fps_scale: float,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or not _is_pododaejang_context(context):
		reset_round()
		return {}
	if not active or guards.is_empty():
		return {}
	timer_frames = maxf(0.0, timer_frames - fps_scale)
	if timer_frames <= 0.0:
		active = false
		guards.clear()
		return {}
	_update_guards(fps_scale)
	return _check_ball_collision(scene, context, deps)


func get_draw_context() -> Dictionary:
	return {
		"stage1_pododaejang_patrol_guards_active": active,
		"stage1_pododaejang_patrol_guards": guards.duplicate(true),
		"stage1_pododaejang_patrol_guards_timer": timer_frames,
		"stage1_pododaejang_patrol_guards_duration": DURATION_FRAMES,
	}


func is_active() -> bool:
	return active


func was_used_this_round() -> bool:
	return used_this_round


func set_rng_seed_for_test(seed_value: int) -> void:
	rng.seed = seed_value


func _update_guards(fps_scale: float) -> void:
	var delta_seconds: float = fps_scale / 60.0
	var fade_alpha: float = clampf(timer_frames / FADE_FRAMES, 0.0, 1.0) if timer_frames <= FADE_FRAMES else 1.0
	for index in range(guards.size()):
		var guard_value: Variant = guards[index]
		if not (guard_value is Dictionary):
			continue
		var guard: Dictionary = guard_value
		guard["age_frames"] = float(guard.get("age_frames", 0.0)) + fps_scale
		guard["alpha"] = fade_alpha
		guard["collision_cooldown"] = maxf(
			0.0,
			float(guard.get("collision_cooldown", 0.0)) - fps_scale
		)

		var push_timer: float = maxf(0.0, float(guard.get("push_timer", 0.0)))
		if push_timer > 0.0:
			guard["x"] = float(guard.get("x", 0.0)) + float(guard.get("push_vx", 0.0)) * fps_scale
			guard["push_vx"] = float(guard.get("push_vx", 0.0)) * pow(PUSH_DECAY_PER_FRAME, fps_scale)
			guard["push_timer"] = maxf(0.0, push_timer - fps_scale)
		else:
			_update_patrol_guard(guard, fps_scale, delta_seconds)
		guard["x"] = clampf(float(guard.get("x", 0.0)), PATROL_LEFT, PATROL_RIGHT)
		guards[index] = guard


func _update_patrol_guard(guard: Dictionary, fps_scale: float, delta_seconds: float) -> void:
	var wait_timer: float = maxf(0.0, float(guard.get("wait_timer", 0.0)))
	if wait_timer > 0.0:
		guard["wait_timer"] = maxf(0.0, wait_timer - fps_scale)
		return
	var x: float = float(guard.get("x", 0.0))
	var target_x: float = float(guard.get("target_x", x))
	var delta_x: float = target_x - x
	if absf(delta_x) <= TARGET_REACHED_DISTANCE:
		guard["x"] = target_x
		guard["target_x"] = rng.randf_range(TARGET_LEFT, TARGET_RIGHT)
		guard["wait_timer"] = rng.randf_range(WAIT_MIN_FRAMES, WAIT_MAX_FRAMES)
		return
	var direction: float = signf(delta_x)
	guard["direction"] = direction
	guard["x"] = x + direction * float(guard.get("patrol_speed", PATROL_SPEED_MIN_PX_PER_SECOND)) * delta_seconds


func _check_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not bool(context.get("ball_active", false)):
		return {}
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO))
	var ball_radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	for index in range(guards.size()):
		var guard_value: Variant = guards[index]
		if not (guard_value is Dictionary):
			continue
		var guard: Dictionary = guard_value
		if float(guard.get("alpha", 1.0)) < 0.5:
			continue
		if float(guard.get("collision_cooldown", 0.0)) > 0.0:
			continue
		var guard_pos := Vector2(float(guard.get("x", 0.0)), float(guard.get("y", 0.0)))
		if ball_pos.distance_to(guard_pos) >= GUARD_RADIUS + ball_radius:
			continue
		var speed: float = ball_vel.length()
		if speed <= 0.001:
			speed = 6.0
		var random_angle: float = rng.randf_range(0.0, TAU)
		var next_ball_vel := Vector2(cos(random_angle), sin(random_angle)) * speed
		guard["push_vx"] = cos(random_angle) * PUSH_SPEED_PX_PER_FRAME
		guard["push_timer"] = PUSH_FRAMES
		guard["collision_cooldown"] = COLLISION_COOLDOWN_FRAMES
		guards[index] = guard
		_spawn_impact(guard_pos, deps)
		_play_collision_audio(deps)
		return {
			"ball_vel": next_ball_vel,
			"stage1_pododaejang_patrol_guard_hit": true,
		}
	return {}


func _spawn_impact(pos: Vector2, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null:
		return
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 0.45, 0.8)
	if impact_effects.has_method("spawn_paddle_hit_particles"):
		impact_effects.spawn_paddle_hit_particles(pos, false, Vector2.UP, 0.85)


func _play_summon_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_whip"):
		audio.play_whip()


func _play_collision_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _is_pododaejang_context(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in [BOSS_VARIANT, "pododaejang", "podo_daejang"]


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
