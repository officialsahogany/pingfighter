extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage2MonkeyBananaPayloadFactory := preload("res://scripts/stages/stage2/stage2_monkey_banana_payload_factory.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const FIRST_EVENT_MIN_SEC := 5.0
const FIRST_EVENT_MAX_SEC := 10.0
const REPEAT_EVENT_MIN_SEC := 15.0
const REPEAT_EVENT_MAX_SEC := 30.0
const PLAYER_TARGET_PROBABILITY := 0.40
const BOSS_TARGET_PROBABILITY := 0.60
const MONKEY_CLIMB_SPEED := 2.4
const MONKEY_LEAVE_SPEED_MULTIPLIER := 1.5
const MONKEY_THROW_DELAY_MIN_SEC := 1.5
const MONKEY_THROW_DELAY_MAX_SEC := 3.0
# The throw sheet holds the banana in-hand on frames 0-2 and shows an empty
# extended hand from frame 3, so the projectile must spawn exactly when
# frame 3 lands or the banana visibly vanishes for the gap.
const MONKEY_THROW_RELEASE_SEC := 2.0 / 7.0
const MONKEY_THROW_HAND_EMPTY_FRAME := 3
const MONKEY_THROW_TOTAL_SEC := 1.0
const BANANA_FLIGHT_DURATION_SEC := 1.0
const BANANA_ARC_HEIGHT := -200.0
const BANANA_ROTATION_SPEED_DEGREES := 360.0 * 1.5
const BANANA_LAND_DURATION_SEC := 2.0
const BANANA_BURST_DURATION_SEC := 0.4
const BANANA_SIZE := 48.0
const PLAYER_SLIP_DURATION_SEC := 0.8
const PLAYER_WALL_SLIP_DURATION_SEC := 1.2
const PLAYER_SLIP_SPEED := 15.0
const PLAYER_WALL_SLIP_SPEED := 25.0
const BOSS_SLIP_DURATION_SEC := 1.0
const BOSS_SLIP_SPEED := 20.0
const MONKEY_CLIMB_FRAME_COUNT := 8
const MONKEY_THROW_FRAME_COUNT := 8
const MONKEY_RUNTIME_SIZE_MULTIPLIER := 2.0
const MONKEY_CLIMB_DRAW_SCALE := 1.65
const MONKEY_THROW_DRAW_SCALE := 1.85
const BANANA_DRAW_SIZE := 44.0
const BANANA_HAND_OFFSET_X_FACTOR := 0.28
const BANANA_HAND_OFFSET_Y_FACTOR := 0.18
const TREE_LEFT_SOURCE_SIZE := Vector2(265.0, 832.0)
const TREE_RIGHT_SOURCE_SIZE := Vector2(267.0, 831.0)
const TREE_TEXTURE_PATH := "res://assets/sprites/hud/stage2_layered_tree_sprites_imagegen_v3.png"
const TREE_LEFT_SOURCE_REGION := Rect2(212.0, 81.0, 265.0, 832.0)
const TREE_RIGHT_SOURCE_REGION := Rect2(1103.0, 81.0, 267.0, 831.0)
const TREE_TRUNK_SEGMENTS := 18
const TREE_TRUNK_BASE_Y_FACTOR := 0.94
const TREE_TRUNK_TOP_Y_FACTOR := 0.16
const TREE_TRUNK_ALPHA_THRESHOLD := 30.0
const TREE_TRUNK_SCAN_HALF_HEIGHT := 8
const DEFAULT_VIEW_SIZE := Vector2(1488.0, 918.0)
const DEFAULT_GAME_OFFSET := Vector2(364.0, 84.0)
const DEFAULT_GAME_SIZE := Vector2(WIDTH, HEIGHT)
const MONKEY_CLIMB_SHEET_PATH := "res://assets/sprites/hud/stage2_monkey_climb_sheet_imagegen_v2.png"
const MONKEY_THROW_SHEET_PATH := "res://assets/sprites/hud/stage2_monkey_throw_sheet_imagegen_v3.png"
const BANANA_TEXTURE_PATH := "res://assets/sprites/items/banana.png"
const BURST_COLORS := [
	Color(1.0, 0.88, 0.20, 1.0),
	Color(0.89, 0.74, 0.20, 1.0),
	Color(0.78, 0.61, 0.16, 1.0),
	Color(1.0, 1.0, 0.78, 1.0),
	Color(0.55, 0.35, 0.17, 1.0),
]

var rng := RandomNumberGenerator.new()
var event_timer := 0.0
var next_event_time := 0.0
var active_monkeys: Array = []
var bananas: Array = []
var player_slip_active := false
var player_slip_timer := 0.0
var player_slip_duration := PLAYER_SLIP_DURATION_SEC
var player_slip_direction := 0
var player_wall_slip := false
var boss_slip_active := false
var boss_slip_timer := 0.0
var boss_slip_direction := 0
var view_size := DEFAULT_VIEW_SIZE
var game_offset := DEFAULT_GAME_OFFSET
var game_size := DEFAULT_GAME_SIZE
var render_scale := 1.0
var climb_sheet: Texture2D = null
var throw_sheet: Texture2D = null
var banana_texture: Texture2D = null
var tree_source_image: Image = null
var tree_source_image_load_attempted := false
var tree_source_path_cache: Dictionary = {}
var _prewarm_done := false
var _prewarm_step_index := 0


func _init() -> void:
	rng.randomize()
	next_event_time = rng.randf_range(FIRST_EVENT_MIN_SEC, FIRST_EVENT_MAX_SEC)


func reset() -> void:
	event_timer = 0.0
	next_event_time = rng.randf_range(REPEAT_EVENT_MIN_SEC, REPEAT_EVENT_MAX_SEC)
	active_monkeys.clear()
	bananas.clear()
	player_slip_active = false
	player_slip_timer = 0.0
	player_slip_duration = PLAYER_SLIP_DURATION_SEC
	player_slip_direction = 0
	player_wall_slip = false
	boss_slip_active = false
	boss_slip_timer = 0.0
	boss_slip_direction = 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_done:
		return true
	match _prewarm_step_index:
		0, 1, 2:
			_prewarm_texture_step(_prewarm_step_index)
		3:
			_get_tree_source_image()
		4:
			_get_tree_source_path_points("left", TREE_LEFT_SOURCE_REGION)
		5:
			_get_tree_source_path_points("right", TREE_RIGHT_SOURCE_REGION)
		_:
			_prewarm_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 5:
		_prewarm_done = true
		_prewarm_step_index = 0
		return true
	return false


func sync_layout(context: Dictionary) -> void:
	view_size = _get_vector2(context.get("view_size", view_size), view_size)
	game_offset = _get_vector2(context.get("game_offset", game_offset), game_offset)
	game_size = _get_vector2(context.get("game_size", game_size), game_size)
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		game_size = DEFAULT_GAME_SIZE
	render_scale = max(0.01, game_size.x / WIDTH)


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", 2)) != 2:
		return {}
	var clamped_delta: float = max(0.0, delta)
	sync_layout(context)
	_update_event_timer(clamped_delta, deps)
	_update_monkeys(clamped_delta, deps)
	_update_bananas(clamped_delta, context, deps)
	_update_slip_timers(clamped_delta)
	return _build_player_slip_result(clamped_delta, context, deps)


func has_visible_effects() -> bool:
	return (
		not active_monkeys.is_empty()
		or not bananas.is_empty()
		or player_slip_active
		or boss_slip_active
	)


func is_player_slipping() -> bool:
	return player_slip_active


func is_boss_slipping() -> bool:
	return boss_slip_active


func get_slip_offset() -> float:
	return _get_player_slip_speed()


func get_boss_slip_offset() -> float:
	return _get_boss_slip_speed()


func get_boss_ai_context() -> Dictionary:
	return {
		"stage2_monkey_banana_boss_slip_active": boss_slip_active,
		"stage2_monkey_banana_boss_slip_direction": boss_slip_direction,
		"stage2_monkey_banana_boss_slip_speed": abs(_get_boss_slip_speed()),
		"stage2_monkey_banana_boss_slip_ratio": (
			1.0 - clamp(boss_slip_timer / BOSS_SLIP_DURATION_SEC, 0.0, 1.0)
			if BOSS_SLIP_DURATION_SEC > 0.0
			else 0.0
		),
	}


func draw_pillar(canvas: CanvasItem, context: Dictionary = {}) -> void:
	if canvas == null:
		return
	sync_layout(context)
	_ensure_textures()
	for monkey_value in active_monkeys:
		if not (monkey_value is Dictionary):
			continue
		_draw_monkey(canvas, monkey_value)


func draw_playfield(canvas: CanvasItem, _context: Dictionary = {}, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_ensure_textures()
	for banana_value in bananas:
		if not (banana_value is Dictionary):
			continue
		_draw_banana(canvas, banana_value, shake_offset)


func force_spawn_monkey(side: String = "") -> bool:
	return _spawn_monkey(side)


func debug_spawn_landed_banana(position: Vector2, target_player: bool = true) -> void:
	bananas.append(Stage2MonkeyBananaPayloadFactory.build_landed_banana(position, target_player))


func debug_trigger_boss_slip(direction: int = 1) -> void:
	_trigger_boss_slip(Rect2(Vector2.ZERO, Vector2(100.0, 40.0)), direction)


func get_debug_snapshot() -> Dictionary:
	return {
		"event_timer": event_timer,
		"next_event_time": next_event_time,
		"active_monkey_count": active_monkeys.size(),
		"banana_count": bananas.size(),
		"player_slip_active": player_slip_active,
		"boss_slip_active": boss_slip_active,
		"first_event_min": FIRST_EVENT_MIN_SEC,
		"first_event_max": FIRST_EVENT_MAX_SEC,
		"repeat_event_min": REPEAT_EVENT_MIN_SEC,
		"repeat_event_max": REPEAT_EVENT_MAX_SEC,
		"player_target_probability": PLAYER_TARGET_PROBABILITY,
		"boss_target_probability": BOSS_TARGET_PROBABILITY,
		"throw_delay_min": MONKEY_THROW_DELAY_MIN_SEC,
		"throw_delay_max": MONKEY_THROW_DELAY_MAX_SEC,
		"tree_path_source": "stage2_tree_alpha_median",
		"tree_trunk_segments": TREE_TRUNK_SEGMENTS,
	}


func debug_get_trunk_points(side: String = "left") -> Array:
	return _build_trunk_points(side)


func _update_event_timer(delta: float, deps: Dictionary) -> void:
	event_timer += delta
	if event_timer < next_event_time:
		return
	_spawn_monkey()
	event_timer = 0.0
	next_event_time = rng.randf_range(REPEAT_EVENT_MIN_SEC, REPEAT_EVENT_MAX_SEC)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("queue_redraw"):
		feedback.queue_redraw()


func _spawn_monkey(side_override: String = "") -> bool:
	var side: String = side_override
	if side not in ["left", "right"]:
		side = "left" if rng.randi_range(0, 1) == 0 else "right"
	var trunk_points: Array = _build_trunk_points(side)
	if trunk_points.size() < 2:
		return false
	active_monkeys.append(Stage2MonkeyBananaPayloadFactory.build_monkey(
		side,
		trunk_points,
		MONKEY_THROW_DELAY_MIN_SEC,
		MONKEY_THROW_DELAY_MAX_SEC,
		rng
	))
	return true


func _update_monkeys(delta: float, deps: Dictionary) -> void:
	if active_monkeys.is_empty():
		return
	var survivors: Array = []
	for monkey_value in active_monkeys:
		if not (monkey_value is Dictionary):
			continue
		var monkey: Dictionary = monkey_value
		monkey["anim_timer"] = float(monkey.get("anim_timer", 0.0)) + delta
		var state: String = str(monkey.get("state", "climbing"))
		if state == "climbing":
			_update_monkey_climbing(monkey, delta)
		elif state == "sitting":
			_update_monkey_sitting(monkey, delta)
		elif state == "throwing":
			_update_monkey_throwing(monkey, delta, deps)
		elif state == "leaving":
			_update_monkey_leaving(monkey, delta)
		if not _is_monkey_done(monkey):
			survivors.append(monkey)
	active_monkeys = survivors


func _update_monkey_climbing(monkey: Dictionary, delta: float) -> void:
	var progress: float = float(monkey.get("climb_progress", 0.0)) + MONKEY_CLIMB_SPEED * delta
	var target_idx: int = int(monkey.get("target_point_idx", 0))
	if progress >= 1.0:
		target_idx += 1
		progress = 0.0
		if target_idx >= int(monkey.get("sit_point_idx", 1)):
			monkey["state"] = "sitting"
			monkey["throw_timer"] = 0.0
	monkey["target_point_idx"] = target_idx
	monkey["climb_progress"] = progress
	monkey["position"] = _sample_monkey_path(monkey, target_idx, target_idx + 1, progress)


func _update_monkey_sitting(monkey: Dictionary, delta: float) -> void:
	var throw_timer: float = float(monkey.get("throw_timer", 0.0)) + delta
	monkey["throw_timer"] = throw_timer
	if throw_timer >= float(monkey.get("throw_delay", MONKEY_THROW_DELAY_MIN_SEC)) and not bool(monkey.get("has_thrown", false)):
		monkey["state"] = "throwing"
		monkey["throw_timer"] = 0.0


func _update_monkey_throwing(monkey: Dictionary, delta: float, deps: Dictionary) -> void:
	var throw_timer: float = float(monkey.get("throw_timer", 0.0)) + delta
	monkey["throw_timer"] = throw_timer
	if throw_timer >= MONKEY_THROW_RELEASE_SEC and not bool(monkey.get("has_thrown", false)):
		_throw_banana(monkey, deps)
		monkey["has_thrown"] = true
	if throw_timer >= MONKEY_THROW_TOTAL_SEC:
		monkey["state"] = "leaving"
		monkey["climb_progress"] = 0.0


func _update_monkey_leaving(monkey: Dictionary, delta: float) -> void:
	var progress: float = float(monkey.get("climb_progress", 0.0)) + MONKEY_CLIMB_SPEED * MONKEY_LEAVE_SPEED_MULTIPLIER * delta
	var target_idx: int = int(monkey.get("target_point_idx", 0))
	if progress >= 1.0:
		target_idx -= 1
		progress = 0.0
	monkey["target_point_idx"] = target_idx
	monkey["climb_progress"] = progress
	monkey["position"] = _sample_monkey_path(monkey, target_idx, target_idx - 1, progress)


func _sample_monkey_path(monkey: Dictionary, from_idx: int, to_idx: int, progress: float) -> Vector2:
	var trunk_points: Array = monkey.get("trunk_points", [])
	if trunk_points.is_empty():
		return _get_vector2(monkey.get("position", Vector2.ZERO), Vector2.ZERO)
	var p1: Vector2 = _get_vector2(trunk_points[clampi(from_idx, 0, trunk_points.size() - 1)], Vector2.ZERO)
	var p2: Vector2 = _get_vector2(trunk_points[clampi(to_idx, 0, trunk_points.size() - 1)], p1)
	return p1.lerp(p2, clamp(progress, 0.0, 1.0))


func _is_monkey_done(monkey: Dictionary) -> bool:
	return str(monkey.get("state", "")) == "leaving" and int(monkey.get("target_point_idx", 0)) <= 0


func _throw_banana(monkey: Dictionary, deps: Dictionary) -> void:
	var start_viewport: Vector2 = _get_vector2(monkey.get("position", Vector2.ZERO), Vector2.ZERO)
	var facing_dir: float = 1.0 if _is_monkey_facing_right(monkey) else -1.0
	var monkey_draw_size: float = _get_monkey_draw_size(MONKEY_THROW_DRAW_SCALE)
	var hand_offset := Vector2(
		facing_dir * monkey_draw_size * BANANA_HAND_OFFSET_X_FACTOR,
		-monkey_draw_size * BANANA_HAND_OFFSET_Y_FACTOR
	)
	var start_game: Vector2 = _viewport_to_game(start_viewport + hand_offset)
	var target_player: bool = rng.randf() < PLAYER_TARGET_PROBABILITY
	var target_y: float = 700.0 if target_player else 50.0
	var target_x: float = rng.randf_range(30.0, WIDTH - 30.0)
	bananas.append(Stage2MonkeyBananaPayloadFactory.build_flying_banana(
		start_game,
		Vector2(target_x, target_y),
		target_player
	))
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_banana_throw"):
		audio.play_banana_throw()


func _update_bananas(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if bananas.is_empty():
		return
	var survivors: Array = []
	for banana_value in bananas:
		if not (banana_value is Dictionary):
			continue
		var banana: Dictionary = banana_value
		var state: String = str(banana.get("state", "flying"))
		if state == "flying":
			_update_flying_banana(banana, delta)
		elif state == "landed":
			_update_landed_banana(banana, delta, context, deps)
		elif state == "bursting":
			_update_bursting_banana(banana, delta)
		if str(banana.get("state", "")) != "expired":
			survivors.append(banana)
	bananas = survivors


func _update_flying_banana(banana: Dictionary, delta: float) -> void:
	var progress: float = float(banana.get("flight_progress", 0.0)) + delta / BANANA_FLIGHT_DURATION_SEC
	banana["rotation_degrees"] = fposmod(float(banana.get("rotation_degrees", 0.0)) + BANANA_ROTATION_SPEED_DEGREES * delta, 360.0)
	if progress >= 1.0:
		progress = 1.0
		banana["state"] = "landed"
		banana["position"] = _get_vector2(banana.get("target", Vector2.ZERO), Vector2.ZERO)
	else:
		var start: Vector2 = _get_vector2(banana.get("start", Vector2.ZERO), Vector2.ZERO)
		var target: Vector2 = _get_vector2(banana.get("target", Vector2.ZERO), Vector2.ZERO)
		var pos := Vector2(
			lerp(start.x, target.x, progress),
			lerp(start.y, target.y, progress) + BANANA_ARC_HEIGHT * 4.0 * progress * (1.0 - progress)
		)
		banana["position"] = pos
	banana["flight_progress"] = progress


func _update_landed_banana(banana: Dictionary, delta: float, context: Dictionary, deps: Dictionary) -> void:
	var land_timer: float = float(banana.get("land_timer", 0.0)) + delta
	banana["land_timer"] = land_timer
	if _resolve_banana_collisions(banana, context, deps):
		return
	if land_timer >= BANANA_LAND_DURATION_SEC:
		banana["state"] = "expired"


func _update_bursting_banana(banana: Dictionary, delta: float) -> void:
	var burst_timer: float = float(banana.get("burst_timer", 0.0)) + delta
	banana["burst_timer"] = burst_timer
	var particles: Array = banana.get("particles", [])
	var survivors: Array = []
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life: float = float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		vel.y += 300.0 * delta
		pos += vel * delta
		particle["pos"] = pos
		particle["vel"] = vel
		particle["life"] = life
		particle["rotation_degrees"] = float(particle.get("rotation_degrees", 0.0)) + float(particle.get("rot_speed", 0.0)) * delta
		survivors.append(particle)
	banana["particles"] = survivors
	if burst_timer >= BANANA_BURST_DURATION_SEC:
		banana["state"] = "expired"


func _resolve_banana_collisions(banana: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var pos: Vector2 = _get_vector2(banana.get("position", Vector2.ZERO), Vector2.ZERO)
	var ground_rect := Rect2(Vector2(pos.x - BANANA_SIZE, pos.y - 10.0), Vector2(BANANA_SIZE * 2.0, 20.0))
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_rect := Rect2(player_pos, player_size)
	if not bool(banana.get("slip_triggered", false)) and player_rect.intersects(ground_rect):
		banana["slip_triggered"] = true
		_trigger_banana_burst(banana)
		_play_banana_slip_audio(deps)
		if not _is_player_slip_immune(context, deps):
			_trigger_player_slip(player_rect, _get_player_dash_direction(context))
		return true

	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_height: float = float(context.get("boss_hitbox_height", 40.0))
	var boss_rect := Rect2(boss_pos, Vector2(boss_width, boss_height))
	if not bool(banana.get("boss_slip_triggered", false)) and boss_rect.intersects(ground_rect):
		banana["boss_slip_triggered"] = true
		_trigger_banana_burst(banana)
		_play_banana_slip_audio(deps)
		_trigger_boss_slip(boss_rect, _get_boss_move_direction(context))
		return true
	return false


func _trigger_banana_burst(banana: Dictionary) -> void:
	banana["state"] = "bursting"
	banana["burst_timer"] = 0.0
	var origin: Vector2 = _get_vector2(banana.get("position", Vector2.ZERO), Vector2.ZERO)
	var count: int = rng.randi_range(12, 16)
	banana["particles"] = Stage2MonkeyBananaPayloadFactory.build_burst_particles(
		origin,
		count,
		BURST_COLORS,
		rng
	)


func _trigger_player_slip(player_rect: Rect2, dash_dir: int = 0) -> void:
	player_slip_active = true
	player_slip_timer = 0.0
	if dash_dir != 0:
		player_wall_slip = true
		player_slip_direction = dash_dir
		player_slip_duration = PLAYER_WALL_SLIP_DURATION_SEC
	else:
		player_wall_slip = false
		player_slip_duration = PLAYER_SLIP_DURATION_SEC
		var center_x: float = WIDTH * 0.5
		player_slip_direction = -1 if player_rect.get_center().x < center_x else 1


func _trigger_boss_slip(boss_rect: Rect2, boss_move_dir: int = 0) -> void:
	boss_slip_active = true
	boss_slip_timer = 0.0
	if boss_move_dir != 0:
		boss_slip_direction = boss_move_dir
	else:
		boss_slip_direction = -1 if boss_rect.get_center().x < WIDTH * 0.5 else 1


func _update_slip_timers(delta: float) -> void:
	if player_slip_active:
		player_slip_timer += delta
		if player_slip_timer >= player_slip_duration:
			player_slip_active = false
			player_slip_timer = 0.0
			player_wall_slip = false
	if boss_slip_active:
		boss_slip_timer += delta
		if boss_slip_timer >= BOSS_SLIP_DURATION_SEC:
			boss_slip_active = false
			boss_slip_timer = 0.0


func _build_player_slip_result(delta: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not player_slip_active:
		return {}
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	player_pos.x += _get_player_slip_speed() * delta * 60.0
	var special_gauge: float = float(context.get("special_gauge", 0.0))
	var result: Dictionary = {}
	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)
	if warp_gate_state != null and warp_gate_state.has_method("wrap_player_position"):
		var wrapped: Dictionary = warp_gate_state.wrap_player_position(player_pos, player_size, special_gauge, deps)
		result["player_pos"] = _get_vector2(wrapped.get("player_pos", player_pos), player_pos)
		result["special_gauge"] = float(wrapped.get("special_gauge", special_gauge))
	else:
		player_pos.x = clamp(player_pos.x, 0.0, WIDTH - max(1.0, player_size.x))
		result["player_pos"] = player_pos
	return result


func _get_player_slip_speed() -> float:
	if not player_slip_active:
		return 0.0
	var progress: float = player_slip_timer / max(0.001, player_slip_duration)
	var strength: float = 1.0 - clamp(progress, 0.0, 1.0)
	var speed: float = PLAYER_WALL_SLIP_SPEED if player_wall_slip else PLAYER_SLIP_SPEED
	return float(player_slip_direction) * speed * strength


func _get_boss_slip_speed() -> float:
	if not boss_slip_active:
		return 0.0
	var progress: float = boss_slip_timer / max(0.001, BOSS_SLIP_DURATION_SEC)
	return float(boss_slip_direction) * BOSS_SLIP_SPEED * (1.0 - clamp(progress, 0.0, 1.0))


func _get_player_dash_direction(context: Dictionary) -> int:
	var dash_snapshot: Dictionary = context.get("dash_snapshot", {})
	if not (dash_snapshot is Dictionary):
		return 0
	if not bool(dash_snapshot.get("active", false)):
		return 0
	var direction_value: float = float(dash_snapshot.get("direction", 0.0))
	if abs(direction_value) <= 0.001:
		return 0
	return 1 if direction_value > 0.0 else -1


func _get_boss_move_direction(context: Dictionary) -> int:
	var boss_vel: float = float(context.get("boss_vel", 0.0))
	if abs(boss_vel) <= 0.001:
		return 0
	return 1 if boss_vel > 0.0 else -1


func _is_player_slip_immune(context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("player_in_smoke", false)):
		return true
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	return cleanse_state != null and cleanse_state.has_method("is_immune") and bool(cleanse_state.is_immune())


func _play_banana_slip_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_banana_slip"):
		audio.play_banana_slip()


func _build_trunk_points(side: String) -> Array:
	var rect: Rect2 = _get_tree_rect(side)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return []
	var source_rect: Rect2 = _get_tree_source_rect(side)
	var source_points: Array = _get_tree_source_path_points(side, source_rect)
	if not source_points.is_empty():
		var exact_points: Array = []
		for point_value in source_points:
			var point: Vector2 = _get_vector2(point_value, Vector2.ZERO)
			exact_points.append(Vector2(
				rect.position.x + point.x / source_rect.size.x * rect.size.x,
				rect.position.y + point.y / source_rect.size.y * rect.size.y
			))
		return exact_points
	var points: Array = []
	var base_x: float = rect.position.x + rect.size.x * (0.56 if side == "left" else 0.44)
	var bottom_y: float = rect.position.y + rect.size.y * 0.92
	var top_y: float = rect.position.y + rect.size.y * 0.18
	for i in range(12):
		var t: float = float(i) / 11.0
		var sway: float = sin(t * PI * 1.2 + (0.4 if side == "left" else -0.4)) * rect.size.x * 0.045
		var lean: float = lerp(0.0, rect.size.x * (0.075 if side == "left" else -0.075), t)
		points.append(Vector2(base_x + sway + lean, lerp(bottom_y, top_y, t)))
	return points


func _get_tree_source_path_points(side: String, source_rect: Rect2) -> Array:
	if tree_source_path_cache.has(side):
		return tree_source_path_cache[side]
	var image: Image = _get_tree_source_image()
	if image == null or image.is_empty() or source_rect.size.x <= 1.0 or source_rect.size.y <= 1.0:
		return []
	var points: Array = []
	var previous_x := -1.0
	var source_w: int = int(round(source_rect.size.x))
	var source_h: int = int(round(source_rect.size.y))
	for idx in range(TREE_TRUNK_SEGMENTS + 1):
		var t: float = float(idx) / float(TREE_TRUNK_SEGMENTS)
		var y_factor: float = TREE_TRUNK_BASE_Y_FACTOR - (TREE_TRUNK_BASE_Y_FACTOR - TREE_TRUNK_TOP_Y_FACTOR) * t
		var local_y: int = clampi(int(round(float(source_h) * y_factor)), 0, source_h - 1)
		var xs: Array[int] = []
		for yy in range(maxi(0, local_y - TREE_TRUNK_SCAN_HALF_HEIGHT), mini(source_h, local_y + TREE_TRUNK_SCAN_HALF_HEIGHT + 1)):
			for xx in range(source_w):
				var sample := image.get_pixel(int(source_rect.position.x) + xx, int(source_rect.position.y) + yy)
				if sample.a * 255.0 > TREE_TRUNK_ALPHA_THRESHOLD:
					xs.append(xx)
		var center_x: float = previous_x
		if not xs.is_empty():
			xs.sort()
			center_x = float(xs[int(floor(float(xs.size()) * 0.5))])
		elif center_x < 0.0:
			center_x = float(source_w) * (0.42 if side == "left" else 0.58)
		previous_x = center_x
		points.append(Vector2(center_x, float(local_y)))
	tree_source_path_cache[side] = points
	return points


func _prewarm_tree_path_cache() -> void:
	_get_tree_source_path_points("left", TREE_LEFT_SOURCE_REGION)
	_get_tree_source_path_points("right", TREE_RIGHT_SOURCE_REGION)


# Exported builds pack only the imported texture (.ctex), never the original
# PNG, so a raw Image.load_from_file here would silently return null in every
# shipped build and the climb path would fall back to the procedural sway
# curve. The failure is cached so a dead load is not retried on every spawn.
func _get_tree_source_image() -> Image:
	if tree_source_image != null and not tree_source_image.is_empty():
		return tree_source_image
	if tree_source_image_load_attempted:
		return null
	tree_source_image_load_attempted = true
	var texture: Texture2D = ProjectResourceLoader.load_texture(TREE_TEXTURE_PATH)
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	tree_source_image = image
	return tree_source_image


func _get_tree_source_rect(side: String) -> Rect2:
	return TREE_LEFT_SOURCE_REGION if side == "left" else TREE_RIGHT_SOURCE_REGION


func _get_tree_rect(side: String) -> Rect2:
	var left_w: float = max(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = max(0.0, view_size.x - right_x)
	var source_size: Vector2 = TREE_LEFT_SOURCE_SIZE if side == "left" else TREE_RIGHT_SOURCE_SIZE
	var max_w: float = (left_w if side == "left" else right_w) * 0.58
	var max_h: float = view_size.y * 0.62
	if max_w <= 1.0:
		max_w = source_size.x * render_scale
	var scale_factor: float = min(max_w / source_size.x, max_h / source_size.y)
	var target_size: Vector2 = source_size * max(0.01, scale_factor)
	var midbottom: Vector2
	if side == "left":
		midbottom = Vector2(left_w * 0.20, view_size.y - 34.0)
	else:
		midbottom = Vector2(right_x + right_w * 0.80, view_size.y - 34.0)
	return Rect2(midbottom - Vector2(target_size.x * 0.5, target_size.y), target_size)


func _viewport_to_game(pos: Vector2) -> Vector2:
	return (pos - game_offset) / render_scale


func _ensure_textures() -> void:
	for step_index in range(3):
		_prewarm_texture_step(step_index)


func _prewarm_texture_step(step_index: int) -> void:
	match step_index:
		0:
			if climb_sheet == null:
				climb_sheet = ProjectResourceLoader.load_texture(MONKEY_CLIMB_SHEET_PATH)
		1:
			if throw_sheet == null:
				throw_sheet = ProjectResourceLoader.load_texture(MONKEY_THROW_SHEET_PATH)
		2:
			if banana_texture == null:
				banana_texture = ProjectResourceLoader.load_texture(BANANA_TEXTURE_PATH)


func _draw_monkey(canvas: CanvasItem, monkey: Dictionary) -> void:
	var pos: Vector2 = _get_vector2(monkey.get("position", Vector2.ZERO), Vector2.ZERO)
	var state: String = str(monkey.get("state", "climbing"))
	var anim_timer: float = float(monkey.get("anim_timer", 0.0))
	var frame_index: int = 0
	var texture: Texture2D = climb_sheet
	var frame_count: int = MONKEY_CLIMB_FRAME_COUNT
	var draw_scale: float = MONKEY_CLIMB_DRAW_SCALE
	var offset_y := 0.0
	var flip_h := false
	if state == "sitting" or state == "throwing":
		texture = throw_sheet
		frame_count = MONKEY_THROW_FRAME_COUNT
		draw_scale = MONKEY_THROW_DRAW_SCALE
		offset_y = 1.0 * render_scale
		flip_h = _should_flip_throw_sprite(monkey)
		if state == "sitting":
			frame_index = 0
		else:
			frame_index = _get_throw_frame_index(float(monkey.get("throw_timer", 0.0)))
	else:
		frame_index = int(anim_timer * 4.0) % MONKEY_CLIMB_FRAME_COUNT
		if state == "leaving":
			frame_index = MONKEY_CLIMB_FRAME_COUNT - 1 - frame_index
	var target_size: float = _get_monkey_draw_size(draw_scale)
	if texture != null:
		_draw_sheet_frame(canvas, texture, frame_index, frame_count, pos + Vector2(0.0, offset_y), Vector2(target_size, target_size), flip_h)
	else:
		_draw_monkey_fallback(canvas, pos, target_size * 0.5)


func _get_throw_frame_index(throw_timer: float) -> int:
	return min(MONKEY_THROW_FRAME_COUNT - 1, 1 + int(clamp(throw_timer, 0.0, 0.999) * 7.0))


func _is_monkey_facing_right(monkey: Dictionary) -> bool:
	return bool(monkey.get("facing_right", str(monkey.get("side", "left")) == "left"))


# The throw sheet is authored right-facing, so a right-tree monkey
# (throwing leftward into the playfield) must mirror.
func _should_flip_throw_sprite(monkey: Dictionary) -> bool:
	return not _is_monkey_facing_right(monkey)


func _get_monkey_draw_size(draw_scale: float) -> float:
	return max(28.0, 28.0 * draw_scale * MONKEY_RUNTIME_SIZE_MULTIPLIER * render_scale)


func _draw_sheet_frame(canvas: CanvasItem, texture: Texture2D, frame_index: int, frame_count: int, center: Vector2, size: Vector2, flip_h: bool = false) -> void:
	if frame_count <= 0:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var frame_w: float = texture_size.x / float(frame_count)
	var source_rect := Rect2(Vector2(frame_w * clampi(frame_index, 0, frame_count - 1), 0.0), Vector2(frame_w, texture_size.y))
	var rect := Rect2(center - size * 0.5, size)
	if flip_h:
		_draw_flipped_sheet_frame(canvas, texture, source_rect, rect)
		return
	canvas.draw_texture_rect_region(texture, rect, source_rect)


# Mirrors through swapped, texture-size-normalized UVs (negative-width
# Rect2 flips can drift off the draw center on some canvas paths).
func _draw_flipped_sheet_frame(canvas: CanvasItem, texture: Texture2D, source_rect: Rect2, target_rect: Rect2) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_monkey_fallback(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center + Vector2(0.0, radius * 0.18), radius * 0.58, Color(0.48, 0.30, 0.13, 1.0))
	canvas.draw_circle(center + Vector2(0.0, -radius * 0.25), radius * 0.46, Color(0.58, 0.37, 0.18, 1.0))
	canvas.draw_circle(center + Vector2(0.0, -radius * 0.25), radius * 0.28, Color(0.88, 0.68, 0.48, 1.0))


func _draw_banana(canvas: CanvasItem, banana: Dictionary, shake_offset: Vector2) -> void:
	var state: String = str(banana.get("state", "flying"))
	var pos: Vector2 = _get_vector2(banana.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
	if state == "bursting":
		_draw_banana_burst(canvas, banana, shake_offset)
		return
	if not _is_banana_in_draw_area(pos):
		return
	if state == "landed":
		var land_timer: float = float(banana.get("land_timer", 0.0))
		var alpha := 1.0
		if BANANA_LAND_DURATION_SEC > 0.0:
			alpha = 1.0 - min(0.40, land_timer / BANANA_LAND_DURATION_SEC * 0.40)
			if land_timer > BANANA_LAND_DURATION_SEC * 0.70 and int(land_timer * 10.0) % 2 == 0:
				alpha = min(alpha, 0.45)
		_draw_ellipse(canvas, Rect2(pos + Vector2(-BANANA_SIZE, 5.0), Vector2(BANANA_SIZE * 2.0, 10.0)), Color(0.0, 0.0, 0.0, 0.16 * alpha))
		_draw_banana_texture(canvas, pos, 0.0, alpha)
	else:
		_draw_banana_texture(canvas, pos, deg_to_rad(float(banana.get("rotation_degrees", 0.0))), 1.0)


func _draw_banana_texture(canvas: CanvasItem, center: Vector2, rotation: float, alpha: float) -> void:
	if banana_texture == null:
		_draw_banana_fallback(canvas, center, rotation, alpha)
		return
	var size := Vector2(BANANA_DRAW_SIZE, BANANA_DRAW_SIZE)
	var texture_size: Vector2 = banana_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	canvas.draw_texture_rect(
		banana_texture,
		Rect2(center - size * 0.5, size),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)


func _draw_banana_fallback(canvas: CanvasItem, center: Vector2, rotation: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(12):
		var t: float = float(i) / 11.0
		var x: float = lerp(-18.0, 18.0, t)
		var y: float = -sin(t * PI) * 9.0
		points.append(center + Vector2(x, y).rotated(rotation))
	for i in range(11, -1, -1):
		var t2: float = float(i) / 11.0
		var x2: float = lerp(-18.0, 18.0, t2)
		var y2: float = -sin(t2 * PI) * 4.0 + 5.0
		points.append(center + Vector2(x2, y2).rotated(rotation))
	canvas.draw_colored_polygon(points, Color(1.0, 0.86, 0.18, alpha))


func _draw_banana_burst(canvas: CanvasItem, banana: Dictionary, shake_offset: Vector2) -> void:
	var particles: Array = banana.get("particles", [])
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(0.001, float(particle.get("max_life", 0.4)))
		var color: Color = particle.get("color", Color(1.0, 0.85, 0.18, 1.0))
		color.a *= clamp(life / max_life, 0.0, 1.0)
		canvas.draw_circle(pos, float(particle.get("size", 4.0)), color)


# The launch point sits on a letterbox tree well outside 0..WIDTH (about
# -290 / +1050 game px in the default layout), so the horizontal cull must
# span the whole letterbox band or the banana pops into view mid-flight.
func _is_banana_in_draw_area(pos: Vector2) -> bool:
	var letterbox_left: float = max(0.0, game_offset.x) / render_scale
	var letterbox_right: float = max(0.0, view_size.x - game_offset.x - game_size.x) / render_scale
	return (
		pos.x >= -letterbox_left - 120.0
		and pos.x <= WIDTH + letterbox_right + 120.0
		and pos.y >= -120.0
		and pos.y <= HEIGHT + 120.0
	)


func _draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color, segments: int = 28) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	var count: int = maxi(8, segments)
	for idx in range(count):
		var angle: float = TAU * float(idx) / float(count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_colored_polygon(points, color)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
