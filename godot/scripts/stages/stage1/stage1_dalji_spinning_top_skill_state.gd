extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const Stage1DaljiSpinningTopPayloadFactory := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_payload_factory.gd")

const STAGE_ID := 1
const GAUGE_COST := 150.0
const DURATION_FRAMES := 216.0
# One whip "hit" cycle per top: wind-up -> strike -> recovery. Dalji plays this
# once for every top, striking a single top forward each time instead of a
# single whip that releases all tops at once. 36 matches the paengi sheet's
# authored playback (pipeline-meta `progress = 1.0 - timer / 36.0`), so the whip
# reads at its designed pace; this is the timing lever for the whole sequence
# (normal 2x36, enraged 4x36 frames).
const PER_HIT_WHIP_FRAMES := 36.0
# Fraction through a whip cycle where the paengi sprite reaches its down-strike
# frame; the struck top launches here. The v2 paengi sheet cracks early, at
# sprite frame ~8 of 32 (0.25 * 32), so the launch aligns with the visible crack.
const STRIKE_FRAME_RATIO := 0.25
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
# Launch impulse applied to the single top struck on each hit. Tops fling out on
# a wide, mostly-sideways skid that eases off (LAUNCH_DECAY per frame), and
# consecutive tops fire to opposite sides so the hits read as an alternating
# left / right scatter across the field rather than a narrow drop under the
# boss. Total skid length ~= LAUNCH_SPEED * DECAY * (1 - DECAY^FRAMES) / (1 - DECAY)
# (decay applies before each move; ~179px with the current values; the old
# 9.0 / 0.90 / 20 tune capped at ~71px and felt like the tops just fell downward).
const LAUNCH_SPEED := 13.0
const LAUNCH_DECAY := 0.94
const LAUNCH_SPEED_BOOST := 3.0
const LAUNCH_BOOST_FRAMES := 34.0

var active := false
var timer_frames := 0.0
var tops: Array = []
# Index of the top Dalji is currently whipping. Equals tops.size() once every
# top has been struck (whole hit sequence finished).
var hit_index := 0
# Countdown within the current whip cycle.
var hit_whip_timer := 0.0
var top_collision_cooldown := 0.0
var golden_top_star_cooldown := 0.0
var top_audio: Object = null


func reset() -> void:
	reset_round()


func reset_round() -> void:
	active = false
	timer_frames = 0.0
	tops.clear()
	hit_index = 0
	hit_whip_timer = 0.0
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
	hit_index = 0
	hit_whip_timer = 0.0
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

	# Begin the first whip cycle; every top waits (parked) until it is struck.
	hit_whip_timer = PER_HIT_WHIP_FRAMES if not tops.is_empty() else 0.0
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
		_advance_hit_sequence(fps_scale, deps)
		if timer_frames > FALL_FRAMES:
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
		"stage1_spinning_top_whip_timer": hit_whip_timer,
		"stage1_spinning_top_timer": timer_frames,
		"stage1_spinning_top_whip_target_index": _current_whip_target_index(),
		"boss_paengi_top_whip_active": _hitting_active(),
		"boss_paengi_top_whip_frame": get_paengi_sprite_frame_index(),
	}


func get_ai_context() -> Dictionary:
	return {
		# Dalji stays planted only while he is still working through the hit
		# sequence (whipping tops forward one at a time); he frees up once done.
		"stage1_dalji_spinning_top_freeze_active": _hitting_active(),
	}


func is_active() -> bool:
	return active


func get_paengi_sprite_frame_index() -> int:
	if not _hitting_active() or hit_whip_timer <= 0.0:
		return PAENGI_SPRITE_FRAME_COUNT - 1
	var progress: float = clamp(1.0 - (hit_whip_timer / PER_HIT_WHIP_FRAMES), 0.0, 0.999)
	return int(progress * float(PAENGI_SPRITE_FRAME_COUNT))


func _hitting_active() -> bool:
	return active and not tops.is_empty() and hit_index < tops.size()


func _current_whip_target_index() -> int:
	# The whip cord connects to the top currently being wound up. Once that top
	# has been struck (launched) the cord detaches, so no cord shows during the
	# recovery half of its cycle.
	if not _hitting_active():
		return -1
	var top: Dictionary = tops[hit_index]
	if bool(top.get("launched", false)):
		return -1
	return hit_index


func _advance_hit_sequence(fps_scale: float, deps: Dictionary) -> void:
	if hit_index >= tops.size():
		return
	if hit_whip_timer <= 0.0:
		hit_whip_timer = PER_HIT_WHIP_FRAMES

	var strike_threshold: float = PER_HIT_WHIP_FRAMES * (1.0 - STRIKE_FRAME_RATIO)
	var old_timer: float = hit_whip_timer
	hit_whip_timer = max(0.0, hit_whip_timer - fps_scale)
	if old_timer > strike_threshold and hit_whip_timer <= strike_threshold:
		_launch_top(hit_index, deps)

	if hit_whip_timer <= 0.0:
		# Guarantee the top launched even if a large fps_scale skipped the strike
		# crossing, then advance to the next top.
		_launch_top(hit_index, deps)
		hit_index += 1
		if hit_index < tops.size():
			hit_whip_timer = PER_HIT_WHIP_FRAMES
			_play_whip_sound()
		else:
			hit_whip_timer = 0.0


func _launch_top(index: int, deps: Dictionary) -> void:
	if index < 0 or index >= tops.size():
		return
	var top: Dictionary = tops[index]
	if bool(top.get("launched", false)):
		return
	top["launched"] = true
	top["whip_phase"] = "spinning"
	top["rotation_speed"] = 20.0
	var dir: Vector2 = _launch_direction(index)
	top["vx"] = dir.x * LAUNCH_SPEED
	top["vy"] = dir.y * LAUNCH_SPEED
	top["speed_boost"] = LAUNCH_SPEED_BOOST
	top["boost_timer"] = LAUNCH_BOOST_FRAMES
	top["launch_boost"] = true
	top["zigzag_timer"] = 0.0
	tops[index] = top

	var pos := Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0)))
	_spawn_impact(pos, deps)
	_play_collision_sound(deps)


func _launch_direction(index: int) -> Vector2:
	# Whipped tops fling wide to alternating sides. The launch is sideways-
	# dominant (shallow angles from horizontal, no steep-downward branch) so
	# consecutive hits visibly knock tops left / right across the field instead
	# of dropping them in a narrow band under the boss. Even hit indices fire
	# left so the first struck (leftmost) top flies outward. The returned unit
	# vector points down (+y) and to one side; down = toward player.
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var angle_deg: float
	if index == 0:
		# First hit reads as a clean shallow sideways skid.
		angle_deg = randf_range(18.0, 30.0)
	elif randf() < 0.6:
		angle_deg = randf_range(16.0, 32.0)  # shallow, mostly sideways
	else:
		angle_deg = randf_range(34.0, 48.0)  # diagonal
	var angle: float = deg_to_rad(angle_deg)
	return Vector2(side * cos(angle), sin(angle))


func _check_top_to_top_collision(deps: Dictionary) -> void:
	if tops.size() != 2 or top_collision_cooldown > 0.0:
		return

	var top1: Dictionary = tops[0]
	var top2: Dictionary = tops[1]
	if not bool(top1.get("launched", false)) or not bool(top2.get("launched", false)):
		return
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
	top1["launch_boost"] = false

	top2["vx"] = -cos(angle) * TOP_TO_TOP_BOOST_SPEED
	top2["vy"] = -sin(angle) * TOP_TO_TOP_BOOST_SPEED * 0.3
	top2["speed_boost"] = TOP_TO_TOP_SPEED_BOOST
	top2["boost_timer"] = TOP_TO_TOP_BOOST_FRAMES
	top2["launch_boost"] = false

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
			# Only tops Dalji has already struck run; the rest wait, parked at the
			# boss, until their own hit.
			if bool(top.get("launched", false)):
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
		# Whip-launched tops ease their diagonal skid out over the boost window
		# (fast -> slow) rather than holding constant speed; ball / top-to-top
		# pushes keep their original constant-speed behavior.
		if bool(top.get("launch_boost", false)):
			var decay: float = pow(LAUNCH_DECAY, fps_scale)
			top["vx"] = float(top.get("vx", 0.0)) * decay
			top["vy"] = float(top.get("vy", 0.0)) * decay
		if boost_timer <= 0.0:
			top["speed_boost"] = 0.0
			top["launch_boost"] = false
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
		# Parked tops waiting for their whip are not yet in play.
		if not bool(top.get("launched", false)):
			continue
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
		top["launch_boost"] = false
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
