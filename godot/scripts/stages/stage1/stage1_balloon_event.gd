extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const Stage1BalloonEventAssets := preload("res://scripts/stages/stage1/stage1_balloon_event_assets.gd")
const Stage1BalloonPayloadFactory := preload("res://scripts/stages/stage1/stage1_balloon_payload_factory.gd")

const STAGE_ID := 1
const WIDTH := 760.0
const HEIGHT := 750.0
const NORMAL_BALLOON_SHEET_PATH := Stage1BalloonEventAssets.NORMAL_BALLOON_SHEET_PATH
const SPECIAL_BALLOON_SHEET_PATH := Stage1BalloonEventAssets.SPECIAL_BALLOON_SHEET_PATH
const NORMAL_BALLOON_BODY_YAW_SHEET_PATH := Stage1BalloonEventAssets.NORMAL_BALLOON_BODY_YAW_SHEET_PATH
const SPECIAL_BALLOON_BODY_YAW_SHEET_PATH := Stage1BalloonEventAssets.SPECIAL_BALLOON_BODY_YAW_SHEET_PATH
const BALLOON_POP_SHEET_PATH := Stage1BalloonEventAssets.BALLOON_POP_SHEET_PATH
const BALLOON_TEXTURE_PREWARM_STEPS := Stage1BalloonEventAssets.BALLOON_TEXTURE_PREWARM_STEPS
const NORMAL_BALLOON_FRAME_COUNT := Stage1BalloonEventAssets.NORMAL_BALLOON_FRAME_COUNT
const SPECIAL_BALLOON_FRAME_COUNT := Stage1BalloonEventAssets.SPECIAL_BALLOON_FRAME_COUNT
const BALLOON_YAW_FRAME_COUNT := Stage1BalloonEventAssets.BALLOON_YAW_FRAME_COUNT
const BALLOON_POP_FRAME_COUNT := Stage1BalloonEventAssets.BALLOON_POP_FRAME_COUNT
const BALLOON_POP_FRAME_DURATION := 4.0
const BALLOON_SPRITE_VISUAL_SCALE := 0.8
const BALLOON_MIN_RADIUS := 25
const BALLOON_MAX_RADIUS := 42
const BALLOON_PADDLE_BOUNCE_MIN_SPEED := 5.0
const BALLOON_PADDLE_BOUNCE_MAX_SPEED := 7.4
const BALLOON_PADDLE_BOUNCE_DRAG := 0.965
const BALLOON_PADDLE_BOUNCE_SLOW_FRAMES := 42.0
const BALLOON_PADDLE_BOUNCE_COOLDOWN_FRAMES := 14.0
const BALLOON_PADDLE_KNOCKBACK_SPEED := 7.0
const MIN_COOLDOWN_FRAMES := 1200.0
const MAX_COOLDOWN_FRAMES := 2100.0
const DOOR_OPEN_TIME := 60.0
const DOOR_OPEN_DELAY := 30.0
const MACHINE_RISE_TIME := 90.0
const MACHINE_RISE_DELAY := 90.0
const SHOOTING_DELAY := 90.0
const MACHINE_LOWER_TIME := 90.0
const MACHINE_LOWER_DELAY := 30.0
const DOOR_CLOSE_TIME := 60.0
const BALLOON_SHOOT_INTERVAL := 10.0
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_DROP_LIFETIME := 600.0
const STARPOINT_DROP_ACCELERATION := 0.25
const STARPOINT_DROP_MAX_FALL_SPEED := 12.0
const STARPOINT_DROP_BOUNCE_DAMPING := 0.7
const STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const STARPOINT_PARTICLE_COUNT := 10
const STARPOINT_PARTICLE_LIFE := 60.0
const POP_EFFECT_RENDER_LIMIT := 12
const POP_EFFECT_FALLBACK_NORMAL_PARTICLES := 10
const POP_EFFECT_FALLBACK_SPECIAL_PARTICLES := 12
const STARPOINT_PARTICLE_RENDER_LIMIT := 12
const SPECIAL_BALLOON_GLOW_LAYERS := 1
const STARPOINT_DROP_GLOW_LAYERS := 1
const STARPOINT_DROP_STAR_POINTS := 8
const DOOR_RING_LAYERS := 2
const DOOR_RING_SEGMENTS := 18
const MACHINE_CORE_ARC_SEGMENTS := 14
const MACHINE_JOINT_ARC_SEGMENTS := 6
const MACHINE_BARREL_COUNT := 4
const MACHINE_BARREL_ARC_SEGMENTS := 6
const NORMAL_BALLOON_COLORS := Stage1BalloonEventAssets.NORMAL_BALLOON_COLORS
const STARPOINT_BALLOON_COLOR := Stage1BalloonEventAssets.STARPOINT_BALLOON_COLOR

var active := false
var phase := "idle"
var timer_frames := 0.0
var cooldown_timer := 0.0
var door_open_percent := 0.0
var machine_scale := 0.0
var machine_pos := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
var play_left := 0.0
var play_right := WIDTH
var play_height := HEIGHT
var balloons: Array[Dictionary] = []
var pop_effects: Array[Dictionary] = []
var balloon_shoot_timer := 0.0
var balloon_shoot_count := 0
var total_balloon_count := 0
var balloon_shoot_order: Array[int] = []
var balloon_shoot_angles: Array[float] = []
var special_balloon_indices: Array[int] = []
var starpoint_drops: Array[Dictionary] = []
var starpoint_particles: Array[Dictionary] = []
var normal_balloon_sheet: Texture2D
var special_balloon_sheet: Texture2D
var normal_balloon_body_yaw_sheet: Texture2D
var special_balloon_body_yaw_sheet: Texture2D
var balloon_pop_sheet: Texture2D
var _prewarm_texture_step_index := 0


func _init() -> void:
	_set_next_cooldown()


func reset() -> void:
	active = false
	phase = "idle"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	balloons.clear()
	pop_effects.clear()
	var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
	starpoint_drops.clear()
	starpoint_particles.clear()
	if had_starpoints:
		CommonStarpointVisualHost.hide_all_existing_hosts()
	_set_next_cooldown()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> void:
	var fps_scale: float = delta * 60.0
	_update_pop_effects(fps_scale)
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		# Drop any mid-flight starpoints when the player leaves Stage 1 so they
		# don't reappear frozen at their last position when the player returns.
		# Without this clear the drops stay alive in this instance's arrays for
		# the full STARPOINT_DROP_LIFETIME (~10s) and resume falling on re-entry
		# from wherever they were frozen.
		var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
		if not starpoint_drops.is_empty():
			starpoint_drops.clear()
		if not starpoint_particles.is_empty():
			starpoint_particles.clear()
		if had_starpoints:
			CommonStarpointVisualHost.hide_all_existing_hosts()
		return

	_sync_geometry(context)
	_update_starpoint_drops(fps_scale, context, deps)
	_update_starpoint_particles(fps_scale)
	if active:
		_update_machine(fps_scale, deps)
	elif cooldown_timer <= 0.0:
		_activate()
	else:
		cooldown_timer = max(0.0, cooldown_timer - fps_scale)
		if cooldown_timer <= 0.0:
			_activate()

	if balloons.size() > 0:
		_update_balloons(fps_scale)
		_resolve_paddle_interactions(context, deps)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or balloons.is_empty():
		return false

	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var previous_ball_pos: Vector2 = _get_vector2(context, "ball_pos", ball_pos)
	var ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	for i in range(balloons.size()):
		var balloon: Dictionary = balloons[i]
		var balloon_pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
		var balloon_radius: float = float(balloon.get("radius", 30.0))
		if not _ball_path_hits_balloon(previous_ball_pos, ball_pos, balloon_pos, ball_radius + balloon_radius):
			continue

		balloons.remove_at(i)
		_handle_balloon_pop(balloon, deps, context)
		if not _is_whip_active(deps):
			scene["ball_vel"] = _deflect_ball_velocity(_get_vector2(scene, "ball_vel", Vector2.ZERO))
		return true
	return false


func resolve_commando_bullet_collision(projectile: Dictionary, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or balloons.is_empty():
		return {}
	if not _is_commando_balloon_pop_projectile(projectile):
		return {}

	var projectile_pos: Vector2 = _get_vector2(projectile, "pos", Vector2.ZERO)
	var previous_projectile_pos: Vector2 = _get_vector2(projectile, "prev_pos", projectile_pos)
	var projectile_radius: float = max(1.0, float(projectile.get("radius", 3.0)))
	for i in range(balloons.size()):
		var balloon: Dictionary = balloons[i]
		var balloon_pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
		var balloon_radius: float = float(balloon.get("radius", 30.0))
		if not _ball_path_hits_balloon(previous_projectile_pos, projectile_pos, balloon_pos, balloon_radius + projectile_radius):
			continue

		balloons.remove_at(i)
		_handle_balloon_pop(balloon, deps, context)
		return {
			"commando_firearm_balloon_popped": true,
			"commando_firearm_balloon_special": bool(balloon.get("is_special", false)),
			"commando_firearm_balloon_pos": balloon_pos,
			"commando_firearm_balloon_weapon_id": str(projectile.get("weapon_id", "")),
		}
	return {}


func _is_commando_balloon_pop_projectile(projectile: Dictionary) -> bool:
	if str(projectile.get("kind", "bullet")) != "bullet":
		return false
	var weapon_id := str(projectile.get("weapon_id", ""))
	return weapon_id in ["pistol", "commando_pistol", "ak47"]


func absorb_chaos_spear_objects(center: Vector2, radius: float, deps: Dictionary = {}) -> Array:
	if balloons.is_empty():
		return []
	var absorbed: Array = []
	for i in range(balloons.size() - 1, -1, -1):
		var balloon: Dictionary = balloons[i]
		var balloon_pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
		var balloon_radius: float = float(balloon.get("radius", 30.0))
		if balloon_pos.distance_to(center) > radius + balloon_radius:
			continue
		balloons.remove_at(i)
		_handle_balloon_pop(balloon, deps)
		var balloon_color: Color = _get_color(balloon.get("color", Color(0.78, 0.48, 1.0, 1.0)), Color(0.78, 0.48, 1.0, 1.0))
		absorbed.append(Stage1BalloonPayloadFactory.build_absorbed_balloon_payload(
			balloon_pos,
			balloon_radius,
			balloon_color
		))
	return absorbed


func _ball_path_hits_balloon(from_pos: Vector2, to_pos: Vector2, balloon_pos: Vector2, collision_distance: float) -> bool:
	if collision_distance <= 0.0:
		return false
	var movement: Vector2 = to_pos - from_pos
	var movement_len_sq: float = movement.length_squared()
	if movement_len_sq <= 0.001:
		return to_pos.distance_to(balloon_pos) <= collision_distance
	var t: float = clamp((balloon_pos - from_pos).dot(movement) / movement_len_sq, 0.0, 1.0)
	var closest: Vector2 = from_pos + movement * t
	return closest.distance_to(balloon_pos) <= collision_distance


func spawn_starpoint_drop(pos: Vector2, _source_type: String = "", deps: Dictionary = {}, context: Dictionary = {}) -> void:
	_spawn_starpoint_drop_at(pos, deps, context)


func draw_background(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, perf_logger: Object = null) -> void:
	if canvas == null or not active:
		return
	var sample_start: int = _perf_begin(perf_logger)
	if door_open_percent > 0.0:
		_draw_door(canvas, shake_offset)
	_perf_end(perf_logger, "stage1.balloon_bg.door", sample_start)
	sample_start = _perf_begin(perf_logger)
	if phase in ["machine_rising", "machine_rise_wait", "shooting", "shooting_wait", "machine_lowering"]:
		_draw_machine(canvas, shake_offset)
	_perf_end(perf_logger, "stage1.balloon_bg.machine", sample_start)


func draw_foreground(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null,
	game_offset: Vector2 = Vector2.ZERO,
	render_scale: float = 1.0
) -> void:
	if canvas == null:
		return
	if balloons.is_empty() and pop_effects.is_empty() and starpoint_particles.is_empty() and starpoint_drops.is_empty():
		CommonStarpointVisualHost.hide_on_canvas(canvas)
		return
	var sample_start: int = _perf_begin(perf_logger)
	for balloon in balloons:
		_draw_balloon(canvas, balloon, shake_offset)
	_perf_end(perf_logger, "stage1.balloon_fg.balloons", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_pop_effects(canvas, shake_offset)
	_perf_end(perf_logger, "stage1.balloon_fg.pop_effects", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_starpoint_particles(canvas, shake_offset)
	_perf_end(perf_logger, "stage1.balloon_fg.star_particles", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_starpoint_drops(canvas, shake_offset, game_offset, render_scale)
	_perf_end(perf_logger, "stage1.balloon_fg.star_drops", sample_start)


func get_active_balloons() -> Array[Dictionary]:
	return balloons.duplicate(true)


func _activate() -> void:
	if active:
		return
	active = true
	phase = "door_opening"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	balloon_shoot_timer = 0.0
	balloon_shoot_count = 0
	total_balloon_count = randi_range(2, 4)
	balloon_shoot_order = _build_shuffled_indices(total_balloon_count)
	special_balloon_indices = _build_special_indices(total_balloon_count)
	balloon_shoot_angles = _build_shoot_angles(total_balloon_count)


func _update_machine(fps_scale: float, deps: Dictionary) -> void:
	_prewarm_active_event_assets()
	var phase_started := timer_frames <= 0.0
	timer_frames += fps_scale

	match phase:
		"door_opening":
			if phase_started:
				_play_door_sound(deps)
			door_open_percent = _ease_out_cubic(min(1.0, timer_frames / DOOR_OPEN_TIME))
			if timer_frames >= DOOR_OPEN_TIME:
				_set_phase("door_open_wait")
		"door_open_wait":
			if timer_frames >= DOOR_OPEN_DELAY:
				_set_phase("machine_rising")
		"machine_rising":
			if phase_started:
				_play_machine_sound(deps)
			machine_scale = _ease_out_cubic(min(1.0, timer_frames / MACHINE_RISE_TIME))
			if timer_frames >= MACHINE_RISE_TIME:
				_set_phase("machine_rise_wait")
		"machine_rise_wait":
			if timer_frames >= MACHINE_RISE_DELAY:
				_set_phase("shooting")
				balloon_shoot_timer = 0.0
				balloon_shoot_count = 0
		"shooting":
			balloon_shoot_timer += fps_scale
			while balloon_shoot_timer >= BALLOON_SHOOT_INTERVAL and balloon_shoot_count < total_balloon_count:
				_shoot_single_balloon(balloon_shoot_count, deps)
				balloon_shoot_count += 1
				balloon_shoot_timer -= BALLOON_SHOOT_INTERVAL
			if balloon_shoot_count >= total_balloon_count:
				_set_phase("shooting_wait")
		"shooting_wait":
			if timer_frames >= SHOOTING_DELAY:
				_set_phase("machine_lowering")
		"machine_lowering":
			if phase_started:
				_play_machine_sound(deps)
			machine_scale = 1.0 - _ease_in_cubic(min(1.0, timer_frames / MACHINE_LOWER_TIME))
			if timer_frames >= MACHINE_LOWER_TIME:
				_set_phase("machine_lower_wait")
		"machine_lower_wait":
			if timer_frames >= MACHINE_LOWER_DELAY:
				_set_phase("door_closing")
		"door_closing":
			if phase_started:
				_play_door_sound(deps)
			door_open_percent = 1.0 - _ease_in_cubic(min(1.0, timer_frames / DOOR_CLOSE_TIME))
			if timer_frames >= DOOR_CLOSE_TIME:
				_deactivate()


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	timer_frames = 0.0


func _deactivate() -> void:
	active = false
	phase = "idle"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	_set_next_cooldown()


func _set_next_cooldown() -> void:
	cooldown_timer = randf_range(MIN_COOLDOWN_FRAMES, MAX_COOLDOWN_FRAMES)


func _sync_geometry(context: Dictionary) -> void:
	var width: float = float(context.get("width", WIDTH))
	play_left = float(context.get("play_left", 0.0))
	play_right = float(context.get("play_right", width))
	play_height = float(context.get("height", HEIGHT))
	machine_pos = Vector2((play_left + play_right) * 0.5, play_height * 0.5)


func _shoot_single_balloon(index: int, deps: Dictionary) -> void:
	var angle: float = balloon_shoot_angles[index % max(1, balloon_shoot_angles.size())]
	var speed: float = randf_range(3.0, 4.0)
	var is_special: bool = special_balloon_indices.has(index)
	var color: Color = STARPOINT_BALLOON_COLOR if is_special else NORMAL_BALLOON_COLORS[balloon_shoot_order[index] % NORMAL_BALLOON_COLORS.size()]
	var radius: float = float(randi_range(BALLOON_MIN_RADIUS, BALLOON_MAX_RADIUS))
	var bounce: float = randf_range(0.0, TAU)
	var sprite_index: int = balloon_shoot_order[index] % NORMAL_BALLOON_FRAME_COUNT
	var rotation: float = randf_range(0.0, 360.0)
	var rotation_speed: float = (-1.0 if randf() < 0.5 else 1.0) * randf_range(1.4, 2.8)
	balloons.append(Stage1BalloonPayloadFactory.build_balloon(
		machine_pos,
		angle,
		speed,
		radius,
		color,
		bounce,
		is_special,
		sprite_index,
		rotation,
		rotation_speed
	))
	_play_pop_sound(deps)


func _update_balloons(fps_scale: float) -> void:
	for i in range(balloons.size()):
		var balloon: Dictionary = balloons[i]
		var pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(balloon, "vel", Vector2.ZERO)
		var radius: float = float(balloon.get("radius", 30.0))

		pos += vel * fps_scale
		var cooldown: float = max(0.0, float(balloon.get("paddle_bounce_cooldown", 0.0)) - fps_scale)
		var slow_timer: float = max(0.0, float(balloon.get("paddle_bounce_slow_timer", 0.0)) - fps_scale)
		if slow_timer > 0.0:
			vel *= pow(BALLOON_PADDLE_BOUNCE_DRAG, fps_scale)

		var bounce: float = float(balloon.get("bounce", 0.0)) + 0.2 * fps_scale
		pos.y += sin(bounce) * fps_scale
		var move_speed: float = vel.length()
		var spin_scale: float = clamp(move_speed / 3.2, 0.45, 1.45)
		var rotation: float = fposmod(
			float(balloon.get("rotation", 0.0)) + float(balloon.get("rotation_speed", 1.8)) * spin_scale * fps_scale,
			360.0
		)

		if pos.x - radius <= play_left:
			pos.x = play_left + radius
			vel.x = abs(vel.x)
		elif pos.x + radius >= play_right:
			pos.x = play_right - radius
			vel.x = -abs(vel.x)
		if pos.y - radius <= 0.0:
			pos.y = radius
			vel.y = abs(vel.y)
		elif pos.y + radius >= play_height:
			pos.y = play_height - radius
			vel.y = -abs(vel.y)

		balloon["pos"] = pos
		balloon["vel"] = vel
		balloon["bounce"] = bounce
		balloon["rotation"] = rotation
		balloon["paddle_bounce_cooldown"] = cooldown
		balloon["paddle_bounce_slow_timer"] = slow_timer
		balloon["lifetime"] = float(balloon.get("lifetime", 0.0)) + fps_scale
		balloons[i] = balloon


func _resolve_paddle_interactions(context: Dictionary, deps: Dictionary) -> void:
	var player_rect: Rect2 = Rect2(
		_get_vector2(context, "player_pos", Vector2.ZERO),
		_get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var boss_rect: Rect2 = Rect2(
		_get_vector2(context, "boss_pos", Vector2.ZERO),
		Vector2(float(context.get("boss_paddle_width", 100.0)), float(context.get("boss_hitbox_height", 40.0)))
	)
	var dash_snapshot: Dictionary = _get_dictionary(context.get("dash_snapshot", {}))
	var player_dashing: bool = bool(dash_snapshot.get("active", false))
	for i in range(balloons.size() - 1, -1, -1):
		var balloon: Dictionary = balloons[i]
		var hit_player_rect: Rect2 = _get_first_overlapping_player_rect(balloon, player_rects)
		if player_dashing and hit_player_rect.size.x > 0.0:
			balloons.remove_at(i)
			_handle_balloon_pop(balloon, deps, context)
			continue
		if float(balloon.get("paddle_bounce_cooldown", 0.0)) > 0.0:
			continue
		if hit_player_rect.size.x > 0.0:
			var direction: float = _bounce_balloon_from_paddle(balloon, hit_player_rect)
			balloons[i] = balloon
			var movement_state: Object = deps.get("movement_state", null)
			if not _is_player_status_immune(deps, context) and movement_state != null and movement_state.has_method("start_knockback"):
				movement_state.start_knockback(direction * BALLOON_PADDLE_KNOCKBACK_SPEED, 18.0)
		elif _circle_rect_overlap(balloon, boss_rect):
			_bounce_balloon_from_paddle(balloon, boss_rect)
			balloons[i] = balloon


func _circle_rect_overlap(balloon: Dictionary, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
	var radius: float = float(balloon.get("radius", 30.0))
	var nearest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return pos.distance_to(nearest) <= radius


func _get_first_overlapping_player_rect(balloon: Dictionary, player_rects: Array[Rect2]) -> Rect2:
	for rect in player_rects:
		if _circle_rect_overlap(balloon, rect):
			return rect
	return Rect2()


func _bounce_balloon_from_paddle(balloon: Dictionary, rect: Rect2) -> float:
	var pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
	var vel: Vector2 = _get_vector2(balloon, "vel", Vector2.ZERO)
	var rect_center: Vector2 = rect.position + rect.size * 0.5
	var normal: Vector2 = pos - rect_center
	if normal.length() <= 0.001:
		normal = vel if vel.length() > 0.001 else Vector2((-1.0 if randf() < 0.5 else 1.0), -1.0)
	normal = normal.normalized()
	var bounce_speed: float = clamp(max(BALLOON_PADDLE_BOUNCE_MIN_SPEED, vel.length() * 1.18 + 0.8), BALLOON_PADDLE_BOUNCE_MIN_SPEED, BALLOON_PADDLE_BOUNCE_MAX_SPEED)
	balloon["vel"] = normal * bounce_speed
	balloon["pos"] = pos + normal * 3.0
	balloon["paddle_bounce_slow_timer"] = BALLOON_PADDLE_BOUNCE_SLOW_FRAMES
	balloon["paddle_bounce_cooldown"] = BALLOON_PADDLE_BOUNCE_COOLDOWN_FRAMES
	if abs(rect_center.x - pos.x) <= 1.0:
		return 1.0 if normal.x <= 0.0 else -1.0
	return 1.0 if rect_center.x >= pos.x else -1.0


func _deflect_ball_velocity(ball_vel: Vector2) -> Vector2:
	var speed: float = ball_vel.length()
	if speed <= 0.001:
		return ball_vel
	var current_angle: float = atan2(ball_vel.y, ball_vel.x)
	var horizontal_angle: float = abs(cos(current_angle))
	var angle_change: float
	if horizontal_angle > 0.7:
		angle_change = randf_range(-0.611, -0.436) if ball_vel.y >= 0.0 else randf_range(0.436, 0.611)
	else:
		angle_change = randf_range(-0.349, 0.349)
		if abs(ball_vel.y) < abs(ball_vel.x) * 0.5:
			angle_change = -0.524 if randf() < 0.5 else 0.524
	var next_vel := Vector2(cos(current_angle + angle_change), sin(current_angle + angle_change)) * speed
	var min_vertical: float = speed * 0.3
	if abs(next_vel.y) < min_vertical:
		next_vel.y = min_vertical if next_vel.y >= 0.0 else -min_vertical
		next_vel.x = sqrt(max(0.0, speed * speed - next_vel.y * next_vel.y)) * (1.0 if next_vel.x >= 0.0 else -1.0)
	return next_vel


func _handle_balloon_pop(balloon: Dictionary, deps: Dictionary, context: Dictionary = {}) -> void:
	_create_pop_effect(balloon)
	if bool(balloon.get("is_special", false)):
		_spawn_starpoint_drop(balloon, deps, context)
	_play_pop_sound(deps)


func _create_pop_effect(balloon: Dictionary) -> void:
	var pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
	var color: Color = _get_color(balloon.get("color", Color.WHITE), Color.WHITE)
	var radius: float = float(balloon.get("radius", 30.0))
	_ensure_textures()
	if balloon_pop_sheet != null:
		pop_effects.append(Stage1BalloonPayloadFactory.build_sprite_pop_effect(
			pos,
			radius,
			bool(balloon.get("is_special", false)),
			BALLOON_POP_FRAME_COUNT,
			BALLOON_POP_FRAME_DURATION
		))
		return

	pop_effects.append_array(Stage1BalloonPayloadFactory.build_fallback_pop_effects(
		pos,
		color,
		radius,
		bool(balloon.get("is_special", false)),
		POP_EFFECT_FALLBACK_NORMAL_PARTICLES,
		POP_EFFECT_FALLBACK_SPECIAL_PARTICLES
	))


func _update_pop_effects(fps_scale: float) -> void:
	var write_index := 0
	var effect_count := pop_effects.size()
	for index in range(effect_count):
		var e: Dictionary = pop_effects[index]
		match str(e.get("type", "")):
			"sprite":
				e["timer"] = float(e.get("timer", 0.0)) + fps_scale
				e["life"] = float(e.get("life", 0.0)) - fps_scale
				if float(e.get("life", 0.0)) > 0.0:
					pop_effects[write_index] = e
					write_index += 1
			"burst":
				e["life"] = float(e.get("life", 0.0)) - fps_scale
				if float(e.get("life", 0.0)) > 0.0:
					var radius: float = float(e.get("radius", 4.0))
					e["radius"] = radius + (float(e.get("max_radius", radius)) - radius) * min(1.0, 0.35 * fps_scale)
					e["alpha"] = max(0.0, float(e.get("alpha", 0.0)) - 0.055 * fps_scale)
					pop_effects[write_index] = e
					write_index += 1
			_:
				var pos: Vector2 = _get_vector2(e, "pos", Vector2.ZERO)
				var vel: Vector2 = _get_vector2(e, "vel", Vector2.ZERO)
				pos += vel * fps_scale
				vel *= pow(0.93, fps_scale)
				vel.y += 0.2 * fps_scale
				e["pos"] = pos
				e["vel"] = vel
				e["alpha"] = max(0.0, float(e.get("alpha", 1.0)) - 0.031 * fps_scale)
				e["life"] = float(e.get("life", 0.0)) - fps_scale
				if float(e.get("alpha", 0.0)) > 0.0 and float(e.get("life", 0.0)) > 0.0:
					pop_effects[write_index] = e
					write_index += 1
	if write_index < effect_count:
		pop_effects.resize(write_index)


func _spawn_starpoint_drop(balloon: Dictionary, deps: Dictionary, context: Dictionary = {}) -> void:
	var pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO)
	_spawn_starpoint_drop_at(pos, deps, context)


func _spawn_starpoint_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false
) -> void:
	# Stage 1 keeps the iridescent pink star on a slower "drifting jewel" tumble.
	starpoint_drops.append(StarpointPayloadFactory.build_drop(
		pos,
		null,
		star_detector_bonus,
		STARPOINT_DROP_SIZE,
		STARPOINT_DROP_LIFETIME,
		0.02,
		0.045
	))
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		_spawn_star_detector_bonus_drops(pos, deps, context)


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _i in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[randi() % STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size()]),
				play_left + STARPOINT_DROP_SIZE,
				play_right - STARPOINT_DROP_SIZE
			),
			clamp(
				pos.y + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[randi() % STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size()]),
				STARPOINT_DROP_SIZE,
				play_height - STARPOINT_DROP_SIZE
			)
		)
		_spawn_starpoint_drop_at(bonus_pos, deps, context, false, true)


func _update_starpoint_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if starpoint_drops.is_empty():
		return

	var player_rect := Rect2(
		_get_vector2(context, "player_pos", Vector2.ZERO),
		_get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var write_index := 0
	var drop_count := starpoint_drops.size()
	for index in range(drop_count):
		var d: Dictionary = starpoint_drops[index]
		StarpointDowsingAttraction.apply_to_drop(d, dowsing_context, dowsing_player_center, fps_scale)
		if not StarpointDropMotionState.update_drop(
			d,
			fps_scale,
			play_left,
			play_right,
			play_height,
			STARPOINT_DROP_SIZE,
			STARPOINT_DROP_MAX_FALL_SPEED,
			STARPOINT_DROP_ACCELERATION,
			STARPOINT_DROP_BOUNCE_DAMPING
		):
			continue

		var starlight_tracking_result := LingpetStarlightTrackingBridge.update_drop(d, fps_scale, context, deps)
		if bool(starlight_tracking_result.get("delivered", false)):
			if _collect_starpoint_drop(d, context, deps):
				StarpointCollectionCompaction.finish_in_place(starpoint_drops, index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			starpoint_drops[write_index] = d
			write_index += 1
			continue

		if StarpointDropOverlapQuery.overlaps_any_rect_player(d, player_rects, STARPOINT_DROP_SIZE):
			if _collect_starpoint_drop(d, context, deps):
				StarpointCollectionCompaction.finish_in_place(starpoint_drops, index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		starpoint_drops[write_index] = d
		write_index += 1
	if write_index < drop_count:
		starpoint_drops.resize(write_index)


func _collect_starpoint_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps, false)
	var pos: Vector2 = _get_vector2(drop, "pos", Vector2.ZERO)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + 10, 1.4)
	_play_starpoint_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func _spawn_starpoint_particles(pos: Vector2, count: int, intensity: float) -> void:
	starpoint_particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		null,
		STARPOINT_PARTICLE_LIFE
	))


func _update_starpoint_particles(fps_scale: float) -> void:
	StarpointParticleState.update_particles(starpoint_particles, fps_scale)


func _draw_door(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var center: Vector2 = machine_pos + shake_offset
	var portal_radius: float = 100.0 * door_open_percent
	for i in range(DOOR_RING_LAYERS):
		var radius: float = portal_radius - float(i) * 3.0
		if radius <= 0.0:
			continue
		var value: float = (110.0 + float(DOOR_RING_LAYERS - 1 - i) * 32.0) / 255.0
		var alpha: float = (190.0 - float(i) * 36.0) / 255.0
		canvas.draw_arc(center, radius, 0.0, TAU, DOOR_RING_SEGMENTS, Color(value, value, min(1.0, value + 30.0 / 255.0), alpha), 3.0, true)


func _draw_machine(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if machine_scale <= 0.0:
		return
	var center: Vector2 = machine_pos + shake_offset
	var alpha: float = 0.78 * machine_scale
	var beam_width: float = 30.0 * machine_scale
	var beam_length: float = 100.0 * machine_scale
	if beam_width > 0.5 and beam_length > 0.5:
		var beam_color := Color(100.0 / 255.0, 100.0 / 255.0, 130.0 / 255.0, alpha)
		canvas.draw_rect(Rect2(center - Vector2(beam_width * 0.5, beam_length * 0.5), Vector2(beam_width, beam_length)), beam_color)
		canvas.draw_rect(Rect2(center - Vector2(beam_length * 0.5, beam_width * 0.5), Vector2(beam_length, beam_width)), beam_color)
		canvas.draw_line(center + Vector2(0.0, -beam_length * 0.5), center + Vector2(0.0, beam_length * 0.5), Color(0.78, 0.78, 0.86, alpha), 2.0)
		canvas.draw_line(center + Vector2(-beam_length * 0.5, 0.0), center + Vector2(beam_length * 0.5, 0.0), Color(0.78, 0.78, 0.86, alpha), 2.0)

	var core_radius: float = 25.0 * machine_scale
	if core_radius > 0.5:
		canvas.draw_arc(center, core_radius, 0.0, TAU, MACHINE_CORE_ARC_SEGMENTS, Color(0.39, 0.39, 0.47, alpha), 3.0, true)
		canvas.draw_arc(center, max(1.0, core_radius - 5.0), 0.0, TAU, MACHINE_CORE_ARC_SEGMENTS, Color(0.59, 0.59, 0.67, alpha), 2.0, true)
		canvas.draw_circle(center, 5.0 * machine_scale, Color(0.78, 0.78, 0.86, alpha))

	var joint_size: float = 8.0 * machine_scale
	for joint in [Vector2(-beam_length * 0.5, 0.0), Vector2(beam_length * 0.5, 0.0), Vector2(0.0, -beam_length * 0.5), Vector2(0.0, beam_length * 0.5)]:
		canvas.draw_circle(center + joint, joint_size, Color(0.47, 0.47, 0.55, alpha))
		canvas.draw_arc(center + joint, joint_size, 0.0, TAU, MACHINE_JOINT_ARC_SEGMENTS, Color(0.70, 0.70, 0.78, alpha), 2.0, true)

	for i in range(MACHINE_BARREL_COUNT):
		var angle: float = TAU / float(MACHINE_BARREL_COUNT) * float(i)
		var barrel_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * 35.0 * machine_scale
		var barrel_size: float = 10.0 * machine_scale
		if barrel_size <= 0.5:
			continue
		canvas.draw_line(center, barrel_pos, Color(0.39, 0.39, 0.47, alpha * 0.5), 2.0)
		canvas.draw_circle(barrel_pos, barrel_size, Color(0.24, 0.24, 0.31, alpha))
		canvas.draw_circle(barrel_pos, max(1.0, barrel_size - 2.0), Color(0.12, 0.12, 0.16, alpha))
		canvas.draw_arc(barrel_pos, barrel_size, 0.0, TAU, MACHINE_BARREL_ARC_SEGMENTS, Color(0.59, 0.59, 0.67, alpha), 2.0, true)

	if phase == "shooting":
		var pulse: float = 0.65 + 0.35 * sin(timer_frames * 0.25)
		canvas.draw_circle(center, 8.0 * machine_scale * pulse, Color(1.0, 0.30, 0.30, alpha))


func _draw_balloon(canvas: CanvasItem, balloon: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(balloon, "pos", Vector2.ZERO) + shake_offset
	var radius: float = float(balloon.get("radius", 30.0))
	var color: Color = _get_color(balloon.get("color", Color.WHITE), Color.WHITE)
	var is_special: bool = bool(balloon.get("is_special", false))
	if is_special:
		var glow_intensity: float = 0.7 + 0.3 * sin(timer_frames * 0.05)
		for i in range(SPECIAL_BALLOON_GLOW_LAYERS):
			var glow_radius: float = radius * (1.45 - float(i) * 0.25)
			var hue: float = fposmod(timer_frames * 2.0 + float(i) * 30.0, 360.0) / 360.0
			var glow_color: Color = Color.from_hsv(hue, 0.9, 1.0, (0.018 + float(i) * 0.018) * glow_intensity)
			canvas.draw_circle(pos, glow_radius, glow_color)

	if _draw_balloon_sprite(canvas, balloon, pos):
		return

	canvas.draw_circle(pos, radius, color)
	canvas.draw_arc(pos, radius, 0.0, TAU, 48, Color.WHITE, 2.0, true)
	canvas.draw_circle(pos + Vector2(-radius * 0.33, -radius * 0.33), radius * 0.25, Color(1.0, 1.0, 1.0, 0.55))
	canvas.draw_line(pos + Vector2(0.0, radius), pos + Vector2(0.0, radius + 20.0), Color(0.39, 0.39, 0.39, 0.9), 2.0)
	var vel: Vector2 = _get_vector2(balloon, "vel", Vector2.ZERO)
	canvas.draw_line(pos, pos + vel * 8.0, Color(0.78, 0.78, 0.78, 0.75), 1.0)


func _draw_balloon_sprite(canvas: CanvasItem, balloon: Dictionary, pos: Vector2) -> bool:
	var radius: float = float(balloon.get("radius", 30.0))
	var is_special: bool = bool(balloon.get("is_special", false))
	var kind := "special" if is_special else "normal"
	var frame_index: int
	var draw_size: float
	var anchor_y: float
	var handle_split_ratio: float
	if is_special:
		frame_index = int(timer_frames / 8.0) % SPECIAL_BALLOON_FRAME_COUNT
		draw_size = max(88.0 * BALLOON_SPRITE_VISUAL_SCALE, radius * 3.4 * BALLOON_SPRITE_VISUAL_SCALE)
		anchor_y = 0.45
		handle_split_ratio = 0.70
	else:
		frame_index = int(balloon.get("sprite_index", 0))
		draw_size = max(96.0 * BALLOON_SPRITE_VISUAL_SCALE, radius * 4.2 * BALLOON_SPRITE_VISUAL_SCALE)
		anchor_y = 0.42
		handle_split_ratio = 0.62

	var sprite: Texture2D = _get_balloon_texture(kind)
	var body: Texture2D = _get_body_yaw_texture(kind)
	if sprite == null or body == null:
		return false

	var frame_count: int = SPECIAL_BALLOON_FRAME_COUNT if is_special else NORMAL_BALLOON_FRAME_COUNT
	var frame_width: float = float(sprite.get_width()) / float(frame_count)
	var frame_height: float = float(sprite.get_height())
	if frame_width <= 0.0 or frame_height <= 0.0:
		return false

	var split_source_y: float = frame_height * handle_split_ratio
	var split_dest_y: float = draw_size * handle_split_ratio
	var yaw_frame_index: int = int(round(float(balloon.get("rotation", 0.0)) / (360.0 / BALLOON_YAW_FRAME_COUNT))) % BALLOON_YAW_FRAME_COUNT
	var body_draw_size: float = max(82.0 * BALLOON_SPRITE_VISUAL_SCALE, radius * (3.35 if is_special else 3.25) * BALLOON_SPRITE_VISUAL_SCALE)
	var body_frame_width: float = float(body.get_width()) / float(BALLOON_YAW_FRAME_COUNT)
	var body_frame_height: float = float(body.get_height())
	var body_center_y: float = pos.y - draw_size * anchor_y + split_dest_y * 0.5
	canvas.draw_texture_rect_region(
		body,
		Rect2(Vector2(pos.x - body_draw_size * 0.5, body_center_y - body_draw_size * 0.5), Vector2(body_draw_size, body_draw_size)),
		Rect2(Vector2(body_frame_width * float(yaw_frame_index), 0.0), Vector2(body_frame_width, body_frame_height)),
		Color.WHITE if is_special else _get_color(balloon.get("color", Color.WHITE), Color.WHITE)
	)

	canvas.draw_texture_rect_region(
		sprite,
		Rect2(
			Vector2(pos.x - draw_size * 0.5, pos.y - draw_size * anchor_y + split_dest_y),
			Vector2(draw_size, max(1.0, draw_size - split_dest_y))
		),
		Rect2(
			Vector2(frame_width * float(frame_index % frame_count), split_source_y),
			Vector2(frame_width, max(1.0, frame_height - split_source_y))
		),
		Color.WHITE
	)
	return true


func _draw_pop_effects(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for effect_index in range(_recent_start(pop_effects, POP_EFFECT_RENDER_LIMIT), pop_effects.size()):
		var effect: Dictionary = pop_effects[effect_index]
		match str(effect.get("type", "")):
			"sprite":
				if balloon_pop_sheet == null:
					balloon_pop_sheet = _load_texture(BALLOON_POP_SHEET_PATH)
				if balloon_pop_sheet == null:
					continue
				var frame_width: float = float(balloon_pop_sheet.get_width()) / float(BALLOON_POP_FRAME_COUNT)
				var frame_height: float = float(balloon_pop_sheet.get_height())
				var frame_index: int = clampi(int(float(effect.get("timer", 0.0)) / BALLOON_POP_FRAME_DURATION), 0, BALLOON_POP_FRAME_COUNT - 1)
				var radius: float = float(effect.get("radius", 30.0))
				var draw_size: float = max(96.0, radius * (5.4 if bool(effect.get("is_special", false)) else 5.0))
				var pos: Vector2 = _get_vector2(effect, "pos", Vector2.ZERO) + shake_offset
				canvas.draw_texture_rect_region(
					balloon_pop_sheet,
					Rect2(pos - Vector2(draw_size, draw_size) * 0.5, Vector2(draw_size, draw_size)),
					Rect2(Vector2(frame_width * float(frame_index), 0.0), Vector2(frame_width, frame_height)),
					Color.WHITE
				)
			"burst":
				var pos: Vector2 = _get_vector2(effect, "pos", Vector2.ZERO) + shake_offset
				var radius: float = max(1.0, float(effect.get("radius", 1.0)))
				var color: Color = _get_color(effect.get("color", Color.WHITE), Color.WHITE)
				var alpha: float = clamp(float(effect.get("alpha", 0.0)), 0.0, 1.0)
				canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, alpha * 0.35))
				canvas.draw_circle(pos, radius * 0.55, Color(1.0, 1.0, 1.0, alpha * 0.5))
			_:
				var pos: Vector2 = _get_vector2(effect, "pos", Vector2.ZERO) + shake_offset
				var color: Color = _get_color(effect.get("color", Color.WHITE), Color.WHITE)
				var alpha: float = clamp(float(effect.get("alpha", 0.0)), 0.0, 1.0)
				canvas.draw_circle(pos, float(effect.get("size", 4.0)), Color(color.r, color.g, color.b, alpha))


func _draw_starpoint_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle_index in range(_recent_start(starpoint_particles, STARPOINT_PARTICLE_RENDER_LIMIT), starpoint_particles.size()):
		var particle: Dictionary = starpoint_particles[particle_index]
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle, "pos", Vector2.ZERO) + shake_offset
		var color: Color = _get_starpoint_particle_color(float(particle.get("color_shift", 0.5)), alpha)
		canvas.draw_circle(pos, max(1.0, float(particle.get("size", 2.0))), color)


func _draw_starpoint_drops(
	canvas: CanvasItem,
	shake_offset: Vector2,
	game_offset: Vector2 = Vector2.ZERO,
	render_scale: float = 1.0
) -> void:
	if starpoint_drops.is_empty():
		CommonStarpointVisualHost.hide_on_canvas(canvas)
		return
	# Common host owns the GPU-shader path with full 4-layer glow (the original
	# CPU constant STARPOINT_DROP_GLOW_LAYERS=1 collapsed it to one layer under
	# the prior optimization; the shader restores all 4 at near-zero CPU cost).
	# CPU loop below remains as the early-boot / headless fallback.
	#
	# The host is a child of the outer canvas (BattleSceneShell), NOT the
	# transformed playfield canvas. Playfield-coordinate drop positions and
	# sizes must be shifted and scaled into rendered-playfield screen space.
	# Without this, drops appeared at the screen left edge instead of from the
	# balloon pop site (see CLAUDE.md draw_set_transform trap).
	var host: Node = CommonStarpointVisualHost.get_or_create_on_canvas(canvas)
	if host != null and host.has_method("sync_drop"):
		host.begin_frame()
		var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
		var scale: float = maxf(0.001, render_scale)
		for drop in starpoint_drops:
			var is_star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
			var playfield_pos: Vector2 = _get_vector2(drop, "pos", Vector2.ZERO) + shake_offset
			host.sync_drop({
				"pos": game_offset + playfield_pos * scale,
				"size": float(drop.get("size", STARPOINT_DROP_SIZE)) * scale,
				"life": float(drop.get("life", 0.0)),
				"rotation": float(drop.get("rotation", 0.0)),
				"glow_intensity": float(drop.get("glow_intensity", 1.0)),
				"star_detector_bonus": is_star_detector_bonus,
				"elapsed": elapsed,
				# Use the shader's default 5-tip shape (matches the original
				# pre-optimization look across stages 1/2/3/4).
				# Normal drops: vivid pink body with iridescent multicolor
				# shimmer + pink 4-layer glow halo + yellow outline. Detector
				# bonus drops keep the cyan/white palette + cyan rim shimmer.
				"glow_color": Color(0.30, 0.92, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.45, 0.74, 1.0),
				"fill_color": Color(0.16, 0.82, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.42, 0.78, 1.0),
				"outline_color": Color(1.0, 1.0, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 1.0, 0.0, 1.0),
				"iridescent_shimmer_intensity": 0.0 if is_star_detector_bonus else 1.0,
				# Sparkle ray cross gives the pink drop a "shining jewel" look
				# (rotating 8-ray lens-flare highlight with rainbow tint + pulse).
				"sparkle_ray_intensity": 0.0 if is_star_detector_bonus else 1.0,
			})
		host.end_frame()
		return
	for drop in starpoint_drops:
		var pos: Vector2 = _get_vector2(drop, "pos", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(drop.get("size", STARPOINT_DROP_SIZE)))
		var alpha: float = clamp(float(drop.get("life", 0.0)) * 2.0 / 255.0, 0.0, 1.0)
		var glow_intensity: float = clamp(float(drop.get("glow_intensity", 1.0)), 0.0, 1.0)
		var glow_alpha: float = alpha * 0.5 * glow_intensity
		var is_star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
		var glow_color := Color(0.30, 0.92, 1.0, 1.0) if is_star_detector_bonus else Color(1.0, 0.45, 0.74, 1.0)
		var fill_color := Color(0.16, 0.82, 1.0, alpha) if is_star_detector_bonus else Color(1.0, 0.0, 0.0, alpha)
		var outline_color := Color(1.0, 1.0, 1.0, alpha) if is_star_detector_bonus else Color(1.0, 1.0, 0.0, alpha)
		for i in range(STARPOINT_DROP_GLOW_LAYERS):
			var glow_radius: float = size * (4.0 - float(i) * 0.7)
			var layer_alpha: float = glow_alpha / float(STARPOINT_DROP_GLOW_LAYERS - i)
			canvas.draw_circle(pos, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, layer_alpha))

		var points := PackedVector2Array()
		var rotation: float = float(drop.get("rotation", 0.0))
		for i in range(STARPOINT_DROP_STAR_POINTS):
			var radius: float = size if i % 2 == 0 else size * 0.5
			var angle: float = rotation + float(i) * TAU / float(STARPOINT_DROP_STAR_POINTS)
			points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
		if points.size() >= 3:
			canvas.draw_colored_polygon(points, fill_color)
			var outline_points := PackedVector2Array(points)
			outline_points.append(points[0])
			canvas.draw_polyline(outline_points, outline_color, 2.5)
		canvas.draw_circle(pos, 3.0, Color(1.0, 1.0, 1.0, alpha * glow_intensity))


func _get_starpoint_particle_color(color_shift: float, alpha: float) -> Color:
	var clamped_shift: float = clamp(color_shift, 0.0, 1.0)
	if clamped_shift < 0.33:
		var low_t: float = clamped_shift * 3.0
		return Color(1.0, 1.0, (100.0 + 155.0 * low_t) / 255.0, alpha)
	if clamped_shift < 0.66:
		var mid_t: float = (clamped_shift - 0.33) * 3.0
		return Color((255.0 - 55.0 * mid_t) / 255.0, (255.0 - 30.0 * mid_t) / 255.0, 1.0, alpha)
	var t: float = (clamped_shift - 0.66) * 3.0
	return Color((200.0 - 100.0 * t) / 255.0, (225.0 + 30.0 * t) / 255.0, 1.0, alpha)


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_texture_step_index >= BALLOON_TEXTURE_PREWARM_STEPS:
		return true
	match _prewarm_texture_step_index:
		0:
			if normal_balloon_sheet == null:
				normal_balloon_sheet = _load_texture(NORMAL_BALLOON_SHEET_PATH)
		1:
			if special_balloon_sheet == null:
				special_balloon_sheet = _load_texture(SPECIAL_BALLOON_SHEET_PATH)
		2:
			if normal_balloon_body_yaw_sheet == null:
				normal_balloon_body_yaw_sheet = _load_texture(NORMAL_BALLOON_BODY_YAW_SHEET_PATH)
		3:
			if special_balloon_body_yaw_sheet == null:
				special_balloon_body_yaw_sheet = _load_texture(SPECIAL_BALLOON_BODY_YAW_SHEET_PATH)
		4:
			if balloon_pop_sheet == null:
				balloon_pop_sheet = _load_texture(BALLOON_POP_SHEET_PATH)
	_prewarm_texture_step_index += 1
	return _prewarm_texture_step_index >= BALLOON_TEXTURE_PREWARM_STEPS


func _prewarm_active_event_assets() -> void:
	if _prewarm_texture_step_index < BALLOON_TEXTURE_PREWARM_STEPS:
		prewarm_assets_step()


func _ensure_textures() -> void:
	if normal_balloon_sheet == null:
		normal_balloon_sheet = _load_texture(NORMAL_BALLOON_SHEET_PATH)
	if special_balloon_sheet == null:
		special_balloon_sheet = _load_texture(SPECIAL_BALLOON_SHEET_PATH)
	if normal_balloon_body_yaw_sheet == null:
		normal_balloon_body_yaw_sheet = _load_texture(NORMAL_BALLOON_BODY_YAW_SHEET_PATH)
	if special_balloon_body_yaw_sheet == null:
		special_balloon_body_yaw_sheet = _load_texture(SPECIAL_BALLOON_BODY_YAW_SHEET_PATH)
	if balloon_pop_sheet == null:
		balloon_pop_sheet = _load_texture(BALLOON_POP_SHEET_PATH)


func _load_texture(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(path, "Missing Stage 1 balloon texture at %s", "Failed to load Stage 1 balloon texture at %s")


func _get_balloon_texture(kind: String) -> Texture2D:
	if kind == "special":
		if special_balloon_sheet == null:
			special_balloon_sheet = _load_texture(SPECIAL_BALLOON_SHEET_PATH)
		return special_balloon_sheet
	if normal_balloon_sheet == null:
		normal_balloon_sheet = _load_texture(NORMAL_BALLOON_SHEET_PATH)
	return normal_balloon_sheet


func _get_body_yaw_texture(kind: String) -> Texture2D:
	if kind == "special":
		if special_balloon_body_yaw_sheet == null:
			special_balloon_body_yaw_sheet = _load_texture(SPECIAL_BALLOON_BODY_YAW_SHEET_PATH)
		return special_balloon_body_yaw_sheet
	if normal_balloon_body_yaw_sheet == null:
		normal_balloon_body_yaw_sheet = _load_texture(NORMAL_BALLOON_BODY_YAW_SHEET_PATH)
	return normal_balloon_body_yaw_sheet


func _build_shuffled_indices(count: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(count):
		result.append(i)
	result.shuffle()
	return result


func _build_special_indices(count: int) -> Array[int]:
	var candidates: Array[int] = _build_shuffled_indices(count)
	var special_count: int = randi_range(0, min(2, count))
	var result: Array[int] = []
	for i in range(special_count):
		result.append(candidates[i])
	return result


func _build_shoot_angles(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in range(count):
		result.append(TAU / float(count) * float(i) + randf_range(-PI / 12.0, PI / 12.0))
	result.shuffle()
	return result


func _play_pop_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_pop"):
		audio.play_stage1_balloon_pop()


func _play_door_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_door"):
		audio.play_stage1_balloon_door()


func _play_machine_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_machine"):
		audio.play_stage1_balloon_machine()


func _play_starpoint_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _is_whip_active(deps: Dictionary) -> bool:
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state == null or not whip_state.has_method("get_draw_context"):
		return false
	var draw_context: Dictionary = whip_state.get_draw_context()
	return bool(draw_context.get("boss_whip_active", false))


func _is_player_status_immune(deps: Dictionary, context: Dictionary = {}) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("is_immune"):
		if bool(cleanse_state.is_immune()):
			return true
	var mythic_item_runtime: Object = StarpointBonusDropPolicy.get_mythic_item_runtime(deps, context)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		var status_deps: Dictionary = deps.duplicate()
		status_deps["context"] = context
		if context.get("owner", null) is Object:
			status_deps["owner"] = context.get("owner", null)
		if bool(mythic_item_runtime.try_consume_celestial_armor_immunity("stage1_balloon", "knockback", status_deps)):
			return true
	return false


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 3.0)


func _ease_in_cubic(t: float) -> float:
	var clamped: float = clamp(t, 0.0, 1.0)
	return clamped * clamped * clamped


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit < 0:
		return 0
	return max(0, source.size() - max(0, render_limit))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func get_render_budget_status() -> Dictionary:
	return {
		"pop_effect_render_limit": POP_EFFECT_RENDER_LIMIT,
		"pop_effect_fallback_normal_particles": POP_EFFECT_FALLBACK_NORMAL_PARTICLES,
		"pop_effect_fallback_special_particles": POP_EFFECT_FALLBACK_SPECIAL_PARTICLES,
		"starpoint_particle_count": STARPOINT_PARTICLE_COUNT,
		"starpoint_particle_render_limit": STARPOINT_PARTICLE_RENDER_LIMIT,
		"special_balloon_glow_layers": SPECIAL_BALLOON_GLOW_LAYERS,
		"starpoint_drop_glow_layers": STARPOINT_DROP_GLOW_LAYERS,
		"starpoint_drop_star_points": STARPOINT_DROP_STAR_POINTS,
		"door_ring_layers": DOOR_RING_LAYERS,
		"door_ring_segments": DOOR_RING_SEGMENTS,
		"machine_core_arc_segments": MACHINE_CORE_ARC_SEGMENTS,
		"machine_joint_arc_segments": MACHINE_JOINT_ARC_SEGMENTS,
		"machine_barrel_count": MACHINE_BARREL_COUNT,
		"machine_barrel_arc_segments": MACHINE_BARREL_ARC_SEGMENTS,
		"balloon_texture_prewarm_steps": BALLOON_TEXTURE_PREWARM_STEPS,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
