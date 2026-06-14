extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage4BrazierMonkPayloadFactory := preload("res://scripts/stages/stage4/stage4_brazier_monk_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const ENTRANCE_POS := Vector2(380.0, 450.0)
const BRAZIER_POSITION := Vector2(380.0, 570.0)
const NORMAL_SPAWN_MIN_SEC := 20.0
const NORMAL_SPAWN_MAX_SEC := 40.0
const RETURN_SPAWN_MIN_SEC := 15.0
const RETURN_SPAWN_MAX_SEC := 30.0
const SMOKE_RETURN_SEC := 30.0
const MAX_NORMAL_MONKS := 1
const MONK_HIT_EFFECT_RENDER_LIMIT := 24
const MONK_DEATH_PARTICLE_RENDER_LIMIT := 56
const STAFF_TRIGGER_RADIUS := 60.0
const STAFF_HIT_START_FRAME := 10.0
const STAFF_HIT_END_FRAME := 15.0
const STAFF_BALL_SPEED_MIN_MULT := 1.50
const STAFF_BALL_SPEED_MAX_MULT := 1.80
const TEMPLE_GHOST_WALK_LEFT_SHEET_PATH := "res://assets/sprites/stage4/temple_ghost_walk_left.png"
const TEMPLE_GHOST_WALK_RIGHT_SHEET_PATH := "res://assets/sprites/stage4/temple_ghost_walk_right.png"
const TEMPLE_GHOST_ATTACK_SHEET_PATH := "res://assets/sprites/stage4/temple_ghost_attack.png"
const TEMPLE_GHOST_SHEET_COLUMNS := 4
const TEMPLE_GHOST_SHEET_ROWS := 2
const TEMPLE_GHOST_FRAME_COUNT := TEMPLE_GHOST_SHEET_COLUMNS * TEMPLE_GHOST_SHEET_ROWS
const TEMPLE_GHOST_WALK_PHASE_PER_FRAME := 0.45
const TEMPLE_GHOST_SWING_TOTAL_FRAMES := 20.0
const TEMPLE_GHOST_DRAW_SIZE := Vector2(112.0, 125.0)
const TEMPLE_GHOST_DRAW_OFFSET := Vector2(0.0, -28.0)
const TEMPLE_GHOST_HIT_TIP_OFFSET := Vector2(42.0, -28.0)
const TEMPLE_GHOST_FLOAT_AMPLITUDE := 5.0
const TEMPLE_GHOST_FLOAT_SPEED := 1.45

const SMOKE_MONK_TYPES := [
	{
		"monk_type": "straw_hat",
		"robe_color": Color(0.27, 0.24, 0.20, 1.0),
		"hat_type": "straw",
		"weapon_type": "bamboo_staff",
		"weapon_color": Color(0.59, 0.47, 0.31, 1.0),
	},
	{
		"monk_type": "crimson",
		"robe_color": Color(0.35, 0.16, 0.14, 1.0),
		"hat_type": "",
		"weapon_type": "iron_staff",
		"weapon_color": Color(0.24, 0.24, 0.28, 1.0),
	},
	{
		"monk_type": "shadow",
		"robe_color": Color(0.10, 0.08, 0.10, 1.0),
		"hat_type": "",
		"weapon_type": "chain_staff",
		"weapon_color": Color(0.16, 0.16, 0.18, 1.0),
	},
	{
		"monk_type": "golden",
		"robe_color": Color(0.31, 0.27, 0.16, 1.0),
		"hat_type": "",
		"weapon_type": "golden_staff",
		"weapon_color": Color(0.70, 0.58, 0.24, 1.0),
	},
	{
		"monk_type": "veteran",
		"robe_color": Color(0.20, 0.18, 0.16, 1.0),
		"hat_type": "hood",
		"weapon_type": "curved_staff",
		"weapon_color": Color(0.27, 0.20, 0.14, 1.0),
	},
]

var rng := RandomNumberGenerator.new()
var monks: Array = []
var monk_hit_effects: Array = []
var monk_death_particles: Array = []
var spawn_timer := 0.0
var spawn_interval := NORMAL_SPAWN_MIN_SEC
var time_sec := 0.0
var temple_collapse_seen := false
var smoke_monks_spawned_since_light := false
var textures_loaded := false
var ghost_walk_left_sheet: Texture2D = null
var ghost_walk_right_sheet: Texture2D = null
var ghost_attack_sheet: Texture2D = null


func _init() -> void:
	rng.randomize()
	spawn_interval = rng.randf_range(NORMAL_SPAWN_MIN_SEC, NORMAL_SPAWN_MAX_SEC)


func prewarm_assets() -> void:
	_ensure_textures()


func reset() -> void:
	monks.clear()
	monk_hit_effects.clear()
	monk_death_particles.clear()
	spawn_timer = 0.0
	spawn_interval = rng.randf_range(NORMAL_SPAWN_MIN_SEC, NORMAL_SPAWN_MAX_SEC)
	time_sec = 0.0
	temple_collapse_seen = false
	smoke_monks_spawned_since_light = false


func update(delta: float, context: Dictionary = {}, _deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", 4)) != 4:
		return {}
	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	time_sec += clamped_delta
	_update_hit_effects(fps_scale)
	_update_death_particles(fps_scale)
	var collapse_progress: float = float(context.get("stage4_collapse_progress", 0.0))
	if (bool(context.get("stage4_temple_destroyed", false)) or collapse_progress > 0.08) and not temple_collapse_seen:
		temple_collapse_seen = true
		explode_all_monks()
	if temple_collapse_seen:
		return {}
	_update_spawn_timer(clamped_delta)
	_update_monks(fps_scale)
	return {}


func draw(canvas: CanvasItem, context: Dictionary = {}, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_ensure_textures()
	var visual_time: float = float(context.get("stage4_monk_visual_time_sec", time_sec))
	if visual_time <= 0.0:
		visual_time = float(Time.get_ticks_msec()) / 1000.0
	var hit_effects: Array = _as_array(context.get("stage4_monk_hit_effects", monk_hit_effects))
	for effect_index in range(_recent_start(hit_effects, MONK_HIT_EFFECT_RENDER_LIMIT), hit_effects.size()):
		var effect_value: Variant = hit_effects[effect_index]
		if effect_value is Dictionary:
			_draw_hit_effect(canvas, effect_value as Dictionary, shake_offset)
	var death_particles: Array = _as_array(context.get("stage4_monk_death_particles", monk_death_particles))
	for particle_index in range(_recent_start(death_particles, MONK_DEATH_PARTICLE_RENDER_LIMIT), death_particles.size()):
		var particle_value: Variant = death_particles[particle_index]
		if particle_value is Dictionary:
			_draw_death_particle(canvas, particle_value as Dictionary, shake_offset)
	for monk_value in _as_array(context.get("stage4_monks", monks)):
		if monk_value is Dictionary:
			_draw_monk(canvas, monk_value as Dictionary, shake_offset, visual_time)


func force_spawn_monk(is_smoke_grenade_monk: bool = false) -> bool:
	return _spawn_monk(is_smoke_grenade_monk)


func spawn_smoke_grenade_monks_from_brazier() -> int:
	if has_smoke_grenade_monks():
		return 0
	smoke_monks_spawned_since_light = true
	for idx in range(SMOKE_MONK_TYPES.size()):
		var info: Dictionary = SMOKE_MONK_TYPES[idx]
		monks.append(_make_monk({
			"x": FIELD_WIDTH * 0.5 + float(idx - 2) * 20.0,
			"y": ENTRANCE_POS.y,
			"target_x": rng.randf_range(100.0, 500.0),
			"target_y": rng.randf_range(480.0, 550.0),
			"speed": 0.5,
			"direction": -1 if rng.randi_range(0, 1) == 0 else 1,
			"walking_phase": float(idx) * 0.5,
			"state": "walking",
			"state_timer": rng.randf_range(3.0, 6.0),
			"opacity": 1.0,
			"fade_in": false,
			"is_smoke_grenade_monk": true,
			"smoke_return_timer": 0.0,
			"monk_type": str(info.get("monk_type", "")),
			"robe_color": info.get("robe_color", Color(0.27, 0.24, 0.20, 1.0)),
			"hat_type": str(info.get("hat_type", "")),
			"weapon_type": str(info.get("weapon_type", "basic_staff")),
			"weapon_color": info.get("weapon_color", Color(0.31, 0.24, 0.16, 1.0)),
			"swing_chance": 0.3,
			"speed_boost": 1.3,
		}))
	return SMOKE_MONK_TYPES.size()


func trigger_smoke_grenade_monk_return() -> int:
	var count := 0
	for monk_value in monks:
		if not (monk_value is Dictionary):
			continue
		var monk: Dictionary = monk_value
		if bool(monk.get("is_smoke_grenade_monk", false)) and not bool(monk.get("returning_to_temple", false)):
			monk["smoke_return_timer"] = SMOKE_RETURN_SEC
			count += 1
	return count


func has_smoke_grenade_monks() -> bool:
	for monk_value in monks:
		if monk_value is Dictionary and bool((monk_value as Dictionary).get("is_smoke_grenade_monk", false)):
			return true
	return false


func consumed_smoke_monk_cycle() -> bool:
	return smoke_monks_spawned_since_light and not has_smoke_grenade_monks()


func get_monk_positions() -> Array:
	var result: Array = []
	for idx in range(monks.size()):
		var monk_value: Variant = monks[idx]
		if not (monk_value is Dictionary):
			continue
		var monk: Dictionary = monk_value
		result.append({
			"x": float(monk.get("x", 0.0)),
			"y": float(monk.get("y", 0.0)),
			"radius": 28.0,
			"index": idx,
			"state": str(monk.get("state", "")),
			"is_smoke_grenade_monk": bool(monk.get("is_smoke_grenade_monk", false)),
		})
	return result


func trigger_monk_swing(ball_x: float, ball_y: float, last_hit_by: String = "player") -> bool:
	var hit_owner := last_hit_by.strip_edges().to_lower()
	if hit_owner not in ["player", "boss"]:
		return false
	var is_boss_ball := hit_owner == "boss"
	var ball_pos := Vector2(ball_x, ball_y)
	for idx in range(monks.size()):
		var monk_value: Variant = monks[idx]
		if not (monk_value is Dictionary):
			continue
		var monk: Dictionary = monk_value
		if (
			str(monk.get("state", "")) in ["swinging", "returning"]
			or float(monk.get("swing_cooldown", 0.0)) > 0.0
			or int(monk.get("swing_count", 0)) >= 2
			or not bool(monk.get("can_deflect", true))
			or bool(monk.get("returning_to_temple", false))
		):
			continue
		var monk_pos := Vector2(float(monk.get("x", 0.0)), float(monk.get("y", 0.0)))
		var distance: float = monk_pos.distance_to(ball_pos)
		if distance >= STAFF_TRIGGER_RADIUS:
			monk["swing_chance_used"] = false
			monks[idx] = monk
			continue
		if bool(monk.get("swing_chance_used", false)):
			continue
		monk["swing_chance_used"] = true
		var swing_probability: float = 0.3 if is_boss_ball else float(monk.get("swing_chance", 0.2))
		if rng.randf() < swing_probability:
			monk["state"] = "swinging"
			monk["swing_animation"] = 0.0
			monk["has_hit_ball"] = false
			monk["is_countering_boss"] = is_boss_ball
			monk["direction"] = 1 if ball_x > monk_pos.x else -1
			monks[idx] = monk
			return true
		monks[idx] = monk
	return false


func get_monk_staff_deflection(ball_x: float = 300.0, _ball_y: float = 400.0) -> Dictionary:
	for idx in range(monks.size()):
		var monk_value: Variant = monks[idx]
		if not (monk_value is Dictionary):
			continue
		var monk: Dictionary = monk_value
		if str(monk.get("state", "")) != "swinging" or bool(monk.get("has_hit_ball", false)):
			continue
		var swing_frame: float = float(monk.get("swing_animation", 0.0))
		if swing_frame < STAFF_HIT_START_FRAME or swing_frame > STAFF_HIT_END_FRAME:
			continue

		var is_countering_boss: bool = bool(monk.get("is_countering_boss", false))
		var deflection := Vector2.ZERO
		if is_countering_boss:
			var curve_direction: float = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
			deflection.x = curve_direction * rng.randf_range(0.3, 0.6)
			deflection.y = -absf(rng.randf_range(2.5, 3.5))
			deflection *= float(monk.get("speed_boost", 1.0)) * 1.3
		else:
			var ball_from_left: bool = ball_x < float(monk.get("x", 0.0))
			deflection.x = rng.randf_range(0.3, 0.5) if ball_from_left else rng.randf_range(-0.5, -0.3)
			deflection.y = rng.randf_range(-0.6, -0.4)
			deflection *= float(monk.get("speed_boost", 1.0))
			deflection.x += rng.randf_range(-0.1, 0.1)

		monk["has_hit_ball"] = true
		_create_monk_hit_effect(monk)
		monks[idx] = monk
		return {
			"deflection": deflection,
			"speed_multiplier": rng.randf_range(STAFF_BALL_SPEED_MIN_MULT, STAFF_BALL_SPEED_MAX_MULT),
			"monk_index": idx,
			"countering_boss": is_countering_boss,
		}
	return {}


func get_brazier_position() -> Vector2:
	return BRAZIER_POSITION


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage4_monks": _draw_array(monks, copy_arrays),
		"stage4_monk_hit_effects": _draw_array(monk_hit_effects, copy_arrays),
		"stage4_monk_death_particles": _draw_array(monk_death_particles, copy_arrays),
		"stage4_monk_count": monks.size(),
		"stage4_smoke_monk_count": _count_smoke_monks(),
		"stage4_monk_visual_time_sec": time_sec,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"monk_count": monks.size(),
		"smoke_monk_count": _count_smoke_monks(),
		"smoke_returning_count": _count_smoke_returning_monks(),
		"hit_effect_count": monk_hit_effects.size(),
		"death_particle_count": monk_death_particles.size(),
		"hit_effect_render_limit": MONK_HIT_EFFECT_RENDER_LIMIT,
		"death_particle_render_limit": MONK_DEATH_PARTICLE_RENDER_LIMIT,
		"spawn_timer": spawn_timer,
		"spawn_interval": spawn_interval,
		"normal_spawn_min_sec": NORMAL_SPAWN_MIN_SEC,
		"normal_spawn_max_sec": NORMAL_SPAWN_MAX_SEC,
		"smoke_return_sec": SMOKE_RETURN_SEC,
	}


func get_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"temple_ghost_walk_left_sheet": ghost_walk_left_sheet != null,
		"temple_ghost_walk_right_sheet": ghost_walk_right_sheet != null,
		"temple_ghost_attack_sheet": ghost_attack_sheet != null,
		"temple_ghost_frame_count": TEMPLE_GHOST_FRAME_COUNT,
		"temple_ghost_grid_columns": TEMPLE_GHOST_SHEET_COLUMNS,
		"temple_ghost_grid_rows": TEMPLE_GHOST_SHEET_ROWS,
		"temple_ghost_float_amplitude": TEMPLE_GHOST_FLOAT_AMPLITUDE,
		"temple_ghost_float_speed": TEMPLE_GHOST_FLOAT_SPEED,
		"monk_hit_effect_render_limit": MONK_HIT_EFFECT_RENDER_LIMIT,
		"monk_death_particle_render_limit": MONK_DEATH_PARTICLE_RENDER_LIMIT,
		"temple_ghost_sprite_runtime": (
			ghost_walk_left_sheet != null
			and ghost_walk_right_sheet != null
			and ghost_attack_sheet != null
		),
	}


func explode_all_monks() -> void:
	if monks.is_empty():
		return
	for monk_value in monks:
		if monk_value is Dictionary:
			var monk: Dictionary = monk_value
			_create_monk_explosion(
				Vector2(float(monk.get("x", 0.0)), float(monk.get("y", 0.0))),
				_as_color(monk.get("robe_color", Color(0.24, 0.20, 0.16, 1.0))),
				str(monk.get("monk_type", "")) == "golden"
			)
	monks.clear()


func _update_spawn_timer(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return
	_spawn_monk(false)
	spawn_timer = 0.0
	spawn_interval = rng.randf_range(NORMAL_SPAWN_MIN_SEC, NORMAL_SPAWN_MAX_SEC)


func _spawn_monk(is_smoke_grenade_monk: bool = false) -> bool:
	if not is_smoke_grenade_monk and _count_normal_monks() >= MAX_NORMAL_MONKS:
		return false
	monks.append(_make_monk({
		"x": ENTRANCE_POS.x,
		"y": ENTRANCE_POS.y,
		"target_x": [100.0, 200.0, 400.0, 500.0][rng.randi_range(0, 3)],
		"target_y": rng.randf_range(480.0, 550.0),
		"speed": 0.3,
		"direction": -1 if rng.randi_range(0, 1) == 0 else 1,
		"walking_phase": 0.0,
		"state": "walking",
		"state_timer": rng.randf_range(3.0, 6.0),
		"opacity": 0.0,
		"fade_in": true,
		"is_smoke_grenade_monk": is_smoke_grenade_monk,
		"smoke_return_timer": 0.0,
		"monk_type": "normal",
		"robe_color": Color(0.24, 0.20, 0.16, 1.0),
		"hat_type": "",
		"weapon_type": "basic_staff",
		"weapon_color": Color(0.31, 0.24, 0.16, 1.0),
		"swing_chance": 0.2,
		"speed_boost": 1.0,
	}))
	return true


func _make_monk(overrides: Dictionary) -> Dictionary:
	return Stage4BrazierMonkPayloadFactory.build_monk(ENTRANCE_POS, overrides)


func _update_monks(fps_scale: float) -> void:
	var alive: Array = []
	for monk_value in monks:
		if not (monk_value is Dictionary):
			continue
		var monk: Dictionary = monk_value
		var remove_monk := false
		if bool(monk.get("fade_in", false)) and float(monk.get("opacity", 0.0)) < 1.0:
			monk["opacity"] = minf(1.0, float(monk.get("opacity", 0.0)) + (5.0 / 255.0) * fps_scale)
			if float(monk.get("opacity", 0.0)) >= 1.0:
				monk["fade_in"] = false
		monk["swing_cooldown"] = maxf(0.0, float(monk.get("swing_cooldown", 0.0)) - fps_scale)
		if bool(monk.get("is_smoke_grenade_monk", false)) and float(monk.get("smoke_return_timer", 0.0)) > 0.0 and not bool(monk.get("returning_to_temple", false)):
			monk["smoke_return_timer"] = maxf(0.0, float(monk.get("smoke_return_timer", 0.0)) - fps_scale / 60.0)
			if float(monk.get("smoke_return_timer", 0.0)) <= 0.0:
				_start_returning(monk)
		if int(monk.get("swing_count", 0)) >= 2 and not bool(monk.get("returning_to_temple", false)):
			_start_returning(monk)
		var state := str(monk.get("state", "walking"))
		if state not in ["swinging", "returning"]:
			monk["state_timer"] = float(monk.get("state_timer", 0.0)) - fps_scale / 60.0
			if float(monk.get("state_timer", 0.0)) <= 0.0:
				_pick_next_state(monk)
		state = str(monk.get("state", "walking"))
		match state:
			"walking":
				_update_walking(monk, fps_scale)
			"standing":
				monk["robe_sway"] = sin(time_sec * 1.2) * 2.0
			"meditating":
				monk["meditation_timer"] = float(monk.get("meditation_timer", 0.0)) + fps_scale
				monk["robe_sway"] = sin(time_sec * 0.6) * 1.0
			"swinging":
				_update_swinging(monk, fps_scale)
			"returning":
				remove_monk = _update_returning(monk, fps_scale)
		if bool(monk.get("returning_to_temple", false)) and str(monk.get("state", "")) != "returning":
			_start_returning(monk)
		if not remove_monk:
			if str(monk.get("state", "")) != "swinging":
				monk["staff_angle"] = sin(float(monk.get("walking_phase", 0.0))) * 0.1
			if not bool(monk.get("fade_in", false)) and rng.randf() < 0.0002 * fps_scale:
				_start_returning(monk)
			alive.append(monk)
		else:
			if not bool(monk.get("is_smoke_grenade_monk", false)):
				spawn_timer = 0.0
				spawn_interval = rng.randf_range(RETURN_SPAWN_MIN_SEC, RETURN_SPAWN_MAX_SEC)
	monks = alive


func _pick_next_state(monk: Dictionary) -> void:
	var state_idx: int = rng.randi_range(0, 2)
	var next_state := "walking"
	if state_idx == 1:
		next_state = "standing"
	elif state_idx == 2:
		next_state = "meditating"
	monk["state"] = next_state
	monk["state_timer"] = rng.randf_range(3.0, 6.0)
	if next_state == "walking":
		monk["target_x"] = rng.randf_range(100.0, 500.0)
		monk["target_y"] = rng.randf_range(480.0, 550.0)


func _update_walking(monk: Dictionary, fps_scale: float) -> void:
	var pos := Vector2(float(monk.get("x", 0.0)), float(monk.get("y", 0.0)))
	var target := Vector2(float(monk.get("target_x", 0.0)), float(monk.get("target_y", 0.0)))
	var delta_vec: Vector2 = target - pos
	if delta_vec.length() > 5.0:
		var speed: float = float(monk.get("speed", 0.3)) * float(monk.get("speed_boost", 1.0))
		var step: Vector2 = delta_vec.normalized() * speed * fps_scale
		pos += step
		monk["x"] = pos.x
		monk["y"] = pos.y
		monk["walking_phase"] = float(monk.get("walking_phase", 0.0)) + 0.05 * fps_scale
		monk["direction"] = 1 if delta_vec.x > 0.0 else -1
	else:
		monk["state"] = "standing" if rng.randi_range(0, 1) == 0 else "meditating"
		monk["state_timer"] = rng.randf_range(3.0, 6.0)


func _update_swinging(monk: Dictionary, fps_scale: float) -> void:
	monk["swing_animation"] = float(monk.get("swing_animation", 0.0)) + fps_scale
	var frame: float = float(monk.get("swing_animation", 0.0))
	if frame < 10.0:
		monk["staff_angle"] = -PI / 4.0 * (frame / 10.0)
	elif frame < 20.0:
		monk["staff_angle"] = -PI / 4.0 + (PI / 2.0) * ((frame - 10.0) / 10.0)
	else:
		monk["swing_count"] = int(monk.get("swing_count", 0)) + 1
		if int(monk.get("swing_count", 0)) >= 2:
			_start_returning(monk)
		else:
			monk["state"] = "standing"
			monk["state_timer"] = 1.0
		monk["swing_animation"] = 0.0
		monk["staff_angle"] = 0.0
		monk["swing_cooldown"] = 120.0
		monk["has_hit_ball"] = false


func _update_returning(monk: Dictionary, fps_scale: float) -> bool:
	var pos := Vector2(float(monk.get("x", 0.0)), float(monk.get("y", 0.0)))
	var delta_vec: Vector2 = ENTRANCE_POS - pos
	if delta_vec.length() > 5.0:
		var step: Vector2 = delta_vec.normalized() * float(monk.get("speed", 0.3)) * 2.0 * fps_scale
		pos += step
		monk["x"] = pos.x
		monk["y"] = pos.y
		monk["walking_phase"] = float(monk.get("walking_phase", 0.0)) + 0.08 * fps_scale
		monk["direction"] = 1 if delta_vec.x > 0.0 else -1
		return false
	monk["opacity"] = float(monk.get("opacity", 1.0)) - (10.0 / 255.0) * fps_scale
	return float(monk.get("opacity", 0.0)) <= 0.0


func _start_returning(monk: Dictionary) -> void:
	monk["returning_to_temple"] = true
	monk["state"] = "returning"
	monk["target_x"] = ENTRANCE_POS.x
	monk["target_y"] = ENTRANCE_POS.y
	monk["swing_count"] = max(2, int(monk.get("swing_count", 0)))


func _create_monk_hit_effect(monk: Dictionary) -> void:
	monk_hit_effects.append_array(Stage4BrazierMonkPayloadFactory.build_hit_effects(
		monk,
		TEMPLE_GHOST_HIT_TIP_OFFSET,
		rng
	))


func _update_hit_effects(fps_scale: float) -> void:
	var alive: Array = []
	for effect_value in monk_hit_effects:
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		if str(effect.get("type", "")) == "shockwave":
			effect["radius"] = float(effect.get("radius", 0.0)) + 5.0 * fps_scale
			effect["alpha"] = float(effect.get("alpha", 0.0)) - 10.0 * fps_scale
		else:
			effect["x"] = float(effect.get("x", 0.0)) + float(effect.get("vx", 0.0)) * fps_scale
			effect["y"] = float(effect.get("y", 0.0)) + float(effect.get("vy", 0.0)) * fps_scale
			effect["life"] = float(effect.get("life", 0.0)) - fps_scale
		if float(effect.get("alpha", 255.0)) > 0.0 and float(effect.get("life", 1.0)) > 0.0:
			alive.append(effect)
	monk_hit_effects = alive


func _update_death_particles(fps_scale: float) -> void:
	var alive: Array = []
	for particle_value in monk_death_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["vy"] = float(particle.get("vy", 0.0)) + float(particle.get("gravity", 0.12)) * fps_scale
		particle["rotation"] = float(particle.get("rotation", 0.0)) + float(particle.get("rotation_speed", 0.0)) * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		if float(particle.get("life", 0.0)) < 30.0:
			particle["opacity"] = clampf(float(particle.get("life", 0.0)) / 30.0, 0.0, 1.0)
		if float(particle.get("life", 0.0)) > 0.0 and float(particle.get("y", 0.0)) <= FIELD_HEIGHT + 60.0:
			alive.append(particle)
	monk_death_particles = alive


func _create_monk_explosion(pos: Vector2, robe_color: Color, hero: bool = false) -> void:
	monk_death_particles.append_array(Stage4BrazierMonkPayloadFactory.build_explosion_particles(
		pos,
		robe_color,
		hero,
		rng
	))


func _draw_monk(canvas: CanvasItem, monk: Dictionary, shake_offset: Vector2, visual_time: float = 0.0) -> void:
	var pos := Vector2(float(monk.get("x", 0.0)), float(monk.get("y", 0.0))) + shake_offset
	var opacity: float = clampf(float(monk.get("opacity", 1.0)), 0.0, 1.0)
	if opacity <= 0.01:
		return
	if _draw_monk_sprite(canvas, monk, pos, opacity, visual_time):
		return
	var direction: float = float(int(monk.get("direction", 1)))
	var walk_offset: float = absf(sin(float(monk.get("walking_phase", 0.0)))) * 2.0 if str(monk.get("state", "")) == "walking" else 0.0
	var robe_color: Color = _as_color(monk.get("robe_color", Color(0.24, 0.20, 0.16, 1.0)))
	robe_color.a *= opacity
	var staff_color: Color = _as_color(monk.get("weapon_color", Color(0.31, 0.24, 0.16, 1.0)))
	staff_color.a *= opacity
	var skin_color := Color(0.71, 0.63, 0.55, opacity)
	_draw_monk_staff(canvas, pos, monk, staff_color, direction)
	var robe_center := pos + Vector2(0.0, -15.0 - walk_offset)
	var sway: float = float(monk.get("robe_sway", 0.0))
	canvas.draw_colored_polygon(PackedVector2Array([
		robe_center + Vector2(-15.0 + sway, 30.0),
		robe_center + Vector2(15.0 + sway, 30.0),
		robe_center + Vector2(10.0, 10.0),
		robe_center + Vector2(5.0, 0.0),
		robe_center + Vector2(-5.0, 0.0),
		robe_center + Vector2(-10.0, 10.0),
	]), robe_color)
	canvas.draw_line(robe_center + Vector2(-5.0, 10.0), robe_center + Vector2(-8.0, 25.0), robe_color.darkened(0.22), 1.0, true)
	canvas.draw_line(robe_center + Vector2(5.0, 10.0), robe_center + Vector2(8.0, 25.0), robe_color.darkened(0.22), 1.0, true)
	var head_center := pos + Vector2(0.0, -35.0 - walk_offset)
	var hat_type := str(monk.get("hat_type", ""))
	if hat_type == "hood":
		canvas.draw_circle(head_center, 9.0, Color(0.12, 0.10, 0.09, opacity))
		canvas.draw_circle(head_center + Vector2(0.0, 2.0), 6.0, skin_color)
	elif hat_type == "straw":
		canvas.draw_circle(head_center, 8.0, skin_color)
		canvas.draw_colored_polygon(PackedVector2Array([
			head_center + Vector2(0.0, -12.0),
			head_center + Vector2(-18.0, 4.0),
			head_center + Vector2(18.0, 4.0),
		]), Color(0.39, 0.33, 0.22, opacity))
		canvas.draw_line(head_center + Vector2(-18.0, 4.0), head_center + Vector2(18.0, 4.0), Color(0.27, 0.22, 0.14, opacity), 2.0, true)
	else:
		canvas.draw_circle(head_center, 8.0, skin_color)
	var eye_color := Color(0.08, 0.06, 0.04, opacity)
	if str(monk.get("state", "")) == "meditating":
		canvas.draw_line(head_center + Vector2(-4.0, -1.0), head_center + Vector2(-1.0, -1.0), eye_color, 1.0, true)
		canvas.draw_line(head_center + Vector2(1.0, -1.0), head_center + Vector2(4.0, -1.0), eye_color, 1.0, true)
	else:
		canvas.draw_circle(head_center + Vector2(-3.0, -1.0), 1.0, eye_color)
		canvas.draw_circle(head_center + Vector2(3.0, -1.0), 1.0, eye_color)
	if str(monk.get("state", "")) == "meditating":
		canvas.draw_circle(robe_center + Vector2(0.0, 15.0), 4.0, skin_color)
	else:
		var arm_swing: float = sin(float(monk.get("walking_phase", 0.0))) * 5.0 if str(monk.get("state", "")) == "walking" else 0.0
		canvas.draw_line(robe_center + Vector2(-8.0, 10.0), robe_center + Vector2(-10.0 - arm_swing, 20.0), robe_color, 4.0, true)
		canvas.draw_line(robe_center + Vector2(8.0, 10.0), robe_center + Vector2(10.0 + arm_swing, 20.0), robe_color, 4.0, true)


func _draw_monk_sprite(canvas: CanvasItem, monk: Dictionary, pos: Vector2, opacity: float, visual_time: float) -> bool:
	var state := str(monk.get("state", "walking"))
	var direction := 1 if int(monk.get("direction", 1)) >= 0 else -1
	var texture: Texture2D = null
	var frame_index := 0
	var flip_h := false
	if state == "swinging":
		texture = ghost_attack_sheet
		frame_index = _get_attack_frame_index(monk)
		flip_h = direction < 0
	else:
		texture = ghost_walk_right_sheet if direction >= 0 else ghost_walk_left_sheet
		frame_index = _get_walk_frame_index(monk, state, visual_time)
		if texture == null:
			texture = ghost_walk_left_sheet if direction >= 0 else ghost_walk_right_sheet
			flip_h = texture != null
	if texture == null:
		return false
	var float_phase: float = visual_time * TEMPLE_GHOST_FLOAT_SPEED + float(monk.get("walking_phase", 0.0)) * 0.72
	var float_offset: float = sin(float_phase) * TEMPLE_GHOST_FLOAT_AMPLITUDE
	var center := pos + TEMPLE_GHOST_DRAW_OFFSET + Vector2(0.0, float_offset)
	_draw_ghost_sheet_frame(canvas, texture, frame_index, center, TEMPLE_GHOST_DRAW_SIZE, opacity, flip_h)
	return true


func _get_walk_frame_index(monk: Dictionary, state: String, visual_time: float) -> int:
	var phase: float = float(monk.get("walking_phase", 0.0))
	if state == "standing" or state == "meditating":
		phase = visual_time * 1.35
	var frame := int(floor(phase / TEMPLE_GHOST_WALK_PHASE_PER_FRAME))
	return posmod(frame, TEMPLE_GHOST_FRAME_COUNT)


func _get_attack_frame_index(monk: Dictionary) -> int:
	var ratio: float = clampf(float(monk.get("swing_animation", 0.0)) / TEMPLE_GHOST_SWING_TOTAL_FRAMES, 0.0, 0.999)
	return clampi(int(floor(ratio * float(TEMPLE_GHOST_FRAME_COUNT))), 0, TEMPLE_GHOST_FRAME_COUNT - 1)


func _draw_ghost_sheet_frame(canvas: CanvasItem, texture: Texture2D, frame_index: int, center: Vector2, size: Vector2, opacity: float, flip_h: bool = false) -> void:
	var source_rect := _get_ghost_sheet_source_rect(texture, frame_index)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var draw_rect := Rect2(center - size * 0.5, size)
	var modulate := Color(1.0, 1.0, 1.0, opacity)
	if not flip_h:
		canvas.draw_texture_rect_region(texture, draw_rect, source_rect, modulate, false, true)
		return
	_draw_flipped_ghost_sheet_frame(canvas, texture, source_rect, draw_rect, modulate)


func _draw_flipped_ghost_sheet_frame(canvas: CanvasItem, texture: Texture2D, source_rect: Rect2, draw_rect: Rect2, modulate: Color) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		draw_rect.position,
		Vector2(draw_rect.end.x, draw_rect.position.y),
		draw_rect.end,
		Vector2(draw_rect.position.x, draw_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _get_ghost_sheet_source_rect(texture: Texture2D, frame_index: int) -> Rect2:
	if texture == null:
		return Rect2()
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var cell_w: float = texture_size.x / float(TEMPLE_GHOST_SHEET_COLUMNS)
	var cell_h: float = texture_size.y / float(TEMPLE_GHOST_SHEET_ROWS)
	var safe_frame: int = clampi(frame_index, 0, TEMPLE_GHOST_FRAME_COUNT - 1)
	var col: int = safe_frame % TEMPLE_GHOST_SHEET_COLUMNS
	var row: int = int(floor(float(safe_frame) / float(TEMPLE_GHOST_SHEET_COLUMNS)))
	return Rect2(Vector2(float(col) * cell_w, float(row) * cell_h), Vector2(cell_w, cell_h))


func _ensure_textures() -> void:
	if textures_loaded:
		return
	textures_loaded = true
	ghost_walk_left_sheet = ProjectResourceLoader.load_texture(TEMPLE_GHOST_WALK_LEFT_SHEET_PATH)
	ghost_walk_right_sheet = ProjectResourceLoader.load_texture(TEMPLE_GHOST_WALK_RIGHT_SHEET_PATH)
	ghost_attack_sheet = ProjectResourceLoader.load_texture(TEMPLE_GHOST_ATTACK_SHEET_PATH)


func _draw_monk_staff(canvas: CanvasItem, pos: Vector2, monk: Dictionary, staff_color: Color, direction: float) -> void:
	if str(monk.get("state", "")) == "meditating":
		return
	var state := str(monk.get("state", "walking"))
	var base := pos + Vector2(0.0, -20.0)
	var staff_top := pos + Vector2(direction * 15.0 + sin(float(monk.get("staff_angle", 0.0))) * 5.0, -55.0)
	var staff_bottom := pos + Vector2(direction * 15.0, -5.0)
	if state == "swinging":
		var angle: float = float(monk.get("staff_angle", 0.0)) - PI / 2.0
		staff_top = base + Vector2(cos(angle), sin(angle)) * 50.0
		staff_bottom = base
	var width: float = 5.0
	match str(monk.get("weapon_type", "basic_staff")):
		"golden_staff":
			width = 6.0
		"iron_staff":
			width = 7.0
		"chain_staff":
			width = 4.0
	canvas.draw_line(staff_bottom, staff_top, staff_color, width, true)
	canvas.draw_circle(staff_top, 5.0, staff_color)
	if str(monk.get("weapon_type", "")) == "golden_staff":
		for idx in range(3):
			var t: float = 0.30 + float(idx) * 0.2
			canvas.draw_circle(staff_bottom.lerp(staff_top, t), 3.0, Color(1.0, 0.84, 0.0, staff_color.a), false, 1.0, true)
	elif str(monk.get("weapon_type", "")) == "chain_staff":
		var chain_end: Vector2 = staff_top + Vector2(direction * 9.0, 4.0)
		canvas.draw_line(staff_top, chain_end, Color(0.32, 0.32, 0.36, staff_color.a), 2.0, true)
		canvas.draw_circle(chain_end, 4.0, Color(0.40, 0.40, 0.44, staff_color.a))
	if state == "swinging" and float(monk.get("swing_animation", 0.0)) >= 10.0 and float(monk.get("swing_animation", 0.0)) <= 15.0:
		for idx in range(3):
			var blur_angle: float = float(monk.get("staff_angle", 0.0)) - float(idx) * 0.2 - PI / 2.0
			var blur_end: Vector2 = base + Vector2(cos(blur_angle), sin(blur_angle)) * 50.0
			canvas.draw_line(base, blur_end, Color(staff_color.r, staff_color.g, staff_color.b, staff_color.a / float(4 + idx * 2)), maxf(1.0, 3.0 - float(idx)), true)


func _draw_hit_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos := Vector2(float(effect.get("x", 0.0)), float(effect.get("y", 0.0))) + shake_offset
	var alpha: float = clampf(float(effect.get("alpha", 255.0)) / 255.0, 0.0, 1.0)
	if alpha <= 0.01:
		return
	if str(effect.get("type", "")) == "shockwave":
		canvas.draw_circle(pos, float(effect.get("radius", 10.0)), Color(1.0, 0.86, 0.28, alpha), false, 3.0, true)
	else:
		canvas.draw_circle(pos, 2.0, Color(1.0, 0.88, 0.30, alpha))


func _draw_death_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
	var size: float = maxf(2.0, float(particle.get("size", 5.0)))
	var color: Color = _as_color(particle.get("color", Color(0.30, 0.24, 0.18, 1.0)))
	color.a *= clampf(float(particle.get("opacity", 1.0)), 0.0, 1.0)
	if str(particle.get("type", "")) == "spark":
		canvas.draw_circle(pos, size, color)
		return
	var points := PackedVector2Array()
	var rotation: float = deg_to_rad(float(particle.get("rotation", 0.0)))
	var point_count := 6
	for idx in range(point_count):
		var angle: float = (float(idx) / float(point_count)) * TAU + rotation
		var radius: float = size * (1.0 if idx % 2 == 0 else 0.72)
		points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)
		canvas.draw_polyline(points, color.darkened(0.35), 1.2, true)


func _count_normal_monks() -> int:
	var count := 0
	for monk_value in monks:
		if monk_value is Dictionary and not bool((monk_value as Dictionary).get("is_smoke_grenade_monk", false)):
			count += 1
	return count


func _count_smoke_monks() -> int:
	var count := 0
	for monk_value in monks:
		if monk_value is Dictionary and bool((monk_value as Dictionary).get("is_smoke_grenade_monk", false)):
			count += 1
	return count


func _count_smoke_returning_monks() -> int:
	var count := 0
	for monk_value in monks:
		if not (monk_value is Dictionary):
			continue
		var monk: Dictionary = monk_value
		if bool(monk.get("is_smoke_grenade_monk", false)) and float(monk.get("smoke_return_timer", 0.0)) > 0.0:
			count += 1
	return count


func _draw_array(source: Array, copy_arrays: bool) -> Array:
	return source.duplicate(true) if copy_arrays else source


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return source.size()
	return max(0, source.size() - render_limit)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color(1.0, 1.0, 1.0, 1.0)
