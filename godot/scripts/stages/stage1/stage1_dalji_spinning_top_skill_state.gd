extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const Stage1DaljiSpinningTopPayloadFactory := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_payload_factory.gd")

const STAGE_ID := 1
const GAUGE_COST := 150.0
const DURATION_FRAMES := 216.0
const WHIP_ANIMATION_FRAMES := 36.0
const WHIP_SPIN_START_FRAME := 18.0
const PAENGI_SPRITE_FRAME_COUNT := 32
const TOP_COLLISION_COOLDOWN_FRAMES := 60.0
const GOLDEN_STAR_COOLDOWN_FRAMES := 30.0
const TOP_COLLISION_DISTANCE := 40.0
const TOP_RADIUS := 20.0
const NORMAL_OFFSETS := [-30.0, 30.0]
const ENRAGED_OFFSETS := [-60.0, -20.0, 20.0, 60.0]
const GOLDEN_TOP_CHANCE := 0.15
const BASE_DOWN_SPEED := 0.6
const INITIAL_DOWN_SPEED := 0.4
const TOP_BOTTOM_MARGIN := 100.0
const TOP_SIDE_MARGIN := 40.0
const BALL_HIT_PUSH_SPEED := 12.0
const TOP_HIT_BOOST_FRAMES := 12.0
const TOP_HIT_SPEED_BOOST := 3.0
const TOP_TO_TOP_BOOST_SPEED := 8.0
const TOP_TO_TOP_BOOST_FRAMES := 18.0
const TOP_TO_TOP_SPEED_BOOST := 4.0
const FALL_FRAMES := 30.0
const HIT_IMPACT_BOOST := 1.0
const HIT_BOOST_DECAY_RATE := 0.975
const HIT_MIN_BOOST := 0.70

var active := false
var timer_frames := 0.0
var tops: Array = []
var whip_animation_timer := 0.0
var top_collision_cooldown := 0.0
var golden_top_star_cooldown := 0.0
var top_audio: Object = null


func reset() -> void:
	reset_round()


func reset_round() -> void:
	active = false
	timer_frames = 0.0
	tops.clear()
	whip_animation_timer = 0.0
	top_collision_cooldown = 0.0
	golden_top_star_cooldown = 0.0
	top_audio = null


func can_activate(context: Dictionary = {}) -> bool:
	return (
		int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and not active
	)


func should_roll_activation(gauge: float, context: Dictionary = {}) -> bool:
	if gauge < GAUGE_COST or not can_activate(context):
		return false
	return true


func activate(context: Dictionary, deps: Dictionary = {}) -> bool:
	if not can_activate(context):
		return false

	active = true
	timer_frames = DURATION_FRAMES
	whip_animation_timer = WHIP_ANIMATION_FRAMES
	top_collision_cooldown = 0.0
	golden_top_star_cooldown = 0.0
	top_audio = deps.get("audio", null)
	tops.clear()

	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_paddle_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0))
	var boss_center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5,
		boss_pos.y + float(context.get("boss_hitbox_height", boss_paddle_size.y)) * 0.5
	)
	var offsets: Array = ENRAGED_OFFSETS if bool(context.get("enraged_boss_active", false)) else NORMAL_OFFSETS
	for i in range(offsets.size()):
		tops.append(Stage1DaljiSpinningTopPayloadFactory.build_top(
			boss_center,
			float(offsets[i]),
			i,
			INITIAL_DOWN_SPEED,
			GOLDEN_TOP_CHANCE
		))

	_play_whip_sound()
	return true


func update_and_collide(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		reset_round()
		return {}
	if not active or tops.is_empty():
		return {}

	top_collision_cooldown = max(0.0, top_collision_cooldown - fps_scale)
	golden_top_star_cooldown = max(0.0, golden_top_star_cooldown - fps_scale)

	if timer_frames > 0.0:
		timer_frames = max(0.0, timer_frames - fps_scale)
		if whip_animation_timer > 0.0:
			_update_whip_animation(fps_scale)
			return _check_ball_collision(scene, context, deps)

		_check_top_to_top_collision(deps)
		_update_tops(fps_scale, context)
	else:
		active = false
		tops.clear()
		return {}

	return _check_ball_collision(scene, context, deps)


func get_draw_context() -> Dictionary:
	return {
		"stage1_spinning_top_active": active,
		"stage1_spinning_top_tops": tops.duplicate(true),
		"stage1_spinning_top_whip_timer": whip_animation_timer,
		"stage1_spinning_top_timer": timer_frames,
		"boss_paengi_top_whip_active": whip_animation_timer > 0.0,
		"boss_paengi_top_whip_frame": get_paengi_sprite_frame_index(),
	}


func is_active() -> bool:
	return active


func get_paengi_sprite_frame_index() -> int:
	if whip_animation_timer <= 0.0:
		return PAENGI_SPRITE_FRAME_COUNT - 1
	var progress: float = clamp(1.0 - (whip_animation_timer / WHIP_ANIMATION_FRAMES), 0.0, 0.999)
	return int(progress * float(PAENGI_SPRITE_FRAME_COUNT))


func _update_whip_animation(fps_scale: float) -> void:
	var old_timer: float = whip_animation_timer
	whip_animation_timer = max(0.0, whip_animation_timer - fps_scale)
	if old_timer >= WHIP_SPIN_START_FRAME and whip_animation_timer < WHIP_SPIN_START_FRAME:
		for i in range(tops.size()):
			var top: Dictionary = tops[i]
			top["whip_phase"] = "spinning"
			tops[i] = top


func _check_top_to_top_collision(deps: Dictionary) -> void:
	if tops.size() != 2 or top_collision_cooldown > 0.0:
		return

	var top1: Dictionary = tops[0]
	var top2: Dictionary = tops[1]
	var top1_pos := Vector2(float(top1.get("x", 0.0)), float(top1.get("y", 0.0)))
	var top2_pos := Vector2(float(top2.get("x", 0.0)), float(top2.get("y", 0.0)))
	var delta: Vector2 = top1_pos - top2_pos
	if delta.length() >= TOP_COLLISION_DISTANCE:
		return

	var angle: float = atan2(delta.y, delta.x)
	top1["vx"] = cos(angle) * TOP_TO_TOP_BOOST_SPEED
	top1["vy"] = sin(angle) * TOP_TO_TOP_BOOST_SPEED * 0.3
	top1["speed_boost"] = TOP_TO_TOP_SPEED_BOOST
	top1["boost_timer"] = TOP_TO_TOP_BOOST_FRAMES

	top2["vx"] = -cos(angle) * TOP_TO_TOP_BOOST_SPEED
	top2["vy"] = -sin(angle) * TOP_TO_TOP_BOOST_SPEED * 0.3
	top2["speed_boost"] = TOP_TO_TOP_SPEED_BOOST
	top2["boost_timer"] = TOP_TO_TOP_BOOST_FRAMES

	if golden_top_star_cooldown <= 0.0:
		if bool(top1.get("is_golden", false)) and not bool(top1.get("star_spawned", false)):
			if _spawn_starpoint_drop((top1_pos + top2_pos) * 0.5, deps):
				top1["star_spawned"] = true
				golden_top_star_cooldown = GOLDEN_STAR_COOLDOWN_FRAMES
		if bool(top2.get("is_golden", false)) and not bool(top2.get("star_spawned", false)):
			if _spawn_starpoint_drop((top1_pos + top2_pos) * 0.5, deps):
				top2["star_spawned"] = true
				golden_top_star_cooldown = GOLDEN_STAR_COOLDOWN_FRAMES

	tops[0] = top1
	tops[1] = top2
	top_collision_cooldown = TOP_COLLISION_COOLDOWN_FRAMES
	_spawn_impact((top1_pos + top2_pos) * 0.5, deps)
	_play_collision_sound(deps)


func _update_tops(fps_scale: float, context: Dictionary) -> void:
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	for i in range(tops.size()):
		var top: Dictionary = tops[i]
		if timer_frames > FALL_FRAMES:
			_update_running_top(top, fps_scale, width, height)
		elif timer_frames > 0.0:
			top["rotation_speed"] = float(top.get("rotation_speed", 20.0)) * pow(0.92, fps_scale)
			top["tilt"] = 90.0 * (1.0 - timer_frames / FALL_FRAMES)
			top["alpha"] = 255.0 * (timer_frames / FALL_FRAMES)
		tops[i] = top


func _update_running_top(top: Dictionary, fps_scale: float, width: float, height: float) -> void:
	var boost_timer: float = float(top.get("boost_timer", 0.0))
	if boost_timer > 0.0:
		boost_timer = max(0.0, boost_timer - fps_scale)
		top["boost_timer"] = boost_timer
		if boost_timer <= 0.0:
			top["speed_boost"] = 0.0
			top["vx"] = float(top.get("vx", 0.0)) * 0.25
			top["vy"] = BASE_DOWN_SPEED

	top["rotation"] = float(top.get("rotation", 0.0)) + float(top.get("rotation_speed", 20.0)) * fps_scale
	top["zigzag_timer"] = float(top.get("zigzag_timer", 0.0)) + fps_scale

	if float(top.get("boost_timer", 0.0)) <= 0.0:
		var zigzag_timer: int = int(top.get("zigzag_timer", 0.0))
		var period: int = randi_range(20, 40)
		if period > 0 and zigzag_timer % period == 0:
			top["vx"] = randf_range(-2.0, 2.0)
		var wave_x: float = sin(float(top.get("zigzag_timer", 0.0)) * 0.1) * 0.5
		top["x"] = float(top.get("x", 0.0)) + (float(top.get("vx", 0.0)) + wave_x) * fps_scale
		top["y"] = float(top.get("y", 0.0)) + float(top.get("vy", INITIAL_DOWN_SPEED)) * fps_scale
	else:
		top["x"] = float(top.get("x", 0.0)) + float(top.get("vx", 0.0)) * fps_scale
		top["y"] = float(top.get("y", 0.0)) + float(top.get("vy", 0.0)) * fps_scale

	if float(top.get("x", 0.0)) < TOP_SIDE_MARGIN or float(top.get("x", 0.0)) > width - TOP_SIDE_MARGIN:
		top["vx"] = -float(top.get("vx", 0.0))
		top["x"] = clamp(float(top.get("x", 0.0)), TOP_SIDE_MARGIN, width - TOP_SIDE_MARGIN)

	if float(top.get("y", 0.0)) < height - TOP_BOTTOM_MARGIN and float(top.get("boost_timer", 0.0)) <= 0.0:
		top["vy"] = BASE_DOWN_SPEED


func _check_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not active or tops.is_empty() or not bool(context.get("ball_active", false)):
		return {}

	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO))
	var ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	for i in range(tops.size()):
		var top: Dictionary = tops[i]
		if float(top.get("tilt", 0.0)) > 45.0:
			continue

		var top_pos := Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0)))
		var delta: Vector2 = ball_pos - top_pos
		var distance: float = delta.length()
		if distance >= TOP_RADIUS + ball_radius:
			continue

		if bool(top.get("is_golden", false)) and not bool(top.get("star_spawned", false)) and golden_top_star_cooldown <= 0.0:
			if _spawn_starpoint_drop(top_pos, deps):
				top["star_spawned"] = true
				golden_top_star_cooldown = GOLDEN_STAR_COOLDOWN_FRAMES

		var speed: float = ball_vel.length()
		if speed <= 0.01:
			speed = 8.0
		var random_angle: float = randf_range(0.0, TAU)
		var next_ball_vel := Vector2(cos(random_angle), sin(random_angle)) * speed

		var push_angle: float = randf_range(0.0, TAU)
		if distance > 0.01:
			push_angle = atan2(-delta.y, -delta.x)
		top["vx"] = cos(push_angle) * BALL_HIT_PUSH_SPEED
		top["vy"] = sin(push_angle) * BALL_HIT_PUSH_SPEED * 0.5
		top["speed_boost"] = TOP_HIT_SPEED_BOOST
		top["boost_timer"] = TOP_HIT_BOOST_FRAMES
		tops[i] = top

		_spawn_impact(top_pos, deps)
		_play_collision_sound(deps)
		return {
			"ball_vel": next_ball_vel,
			"ball_impact_boost": HIT_IMPACT_BOOST,
			"ball_boost_decay_rate": HIT_BOOST_DECAY_RATE,
			"ball_min_boost": HIT_MIN_BOOST,
			"stage1_dalji_spinning_top_hit": true,
		}

	return {}


func _spawn_impact(pos: Vector2, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null:
		return
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 0.55, 1.0)
	if impact_effects.has_method("spawn_paddle_hit_particles"):
		impact_effects.spawn_paddle_hit_particles(pos, false, Vector2(0.0, 1.0), 1.0)


func _spawn_starpoint_drop(pos: Vector2, deps: Dictionary) -> bool:
	var balloon_event: Object = deps.get("stage1_balloon_event", null)
	if balloon_event == null or not balloon_event.has_method("spawn_starpoint_drop"):
		return false
	balloon_event.spawn_starpoint_drop(pos, "golden_top", deps)
	return true


func _play_whip_sound() -> void:
	if top_audio != null and top_audio.has_method("play_whip"):
		top_audio.play_whip()


func _play_collision_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", top_audio)
	if audio != null and audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
