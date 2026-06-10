extends RefCounted

const SKILL_NAME := "smasher_wheel"
const GAUGE_COST := 200.0
const DURATION_MSEC := 1200
const COMMAND_WINDOW_MSEC := 600
const COMMAND_BUFFER_MAX := 6
const ACTIVE_SPEED_MULT := 0.85
const ACTIVE_REVERSE_ACCEL_MULT := 0.18
const BALL_SPEED_MULT := 3.0
const HIT_MIN_SPEED := 30.0
const HIT_MAX_SPEED := 60.0
const HIT_ANGLE_MIN_DEG := 54.0
const HIT_ANGLE_MAX_DEG := 66.0
const HIT_CURVE_STRENGTH := 0.62
const HIT_GOLD := 30
const HIT_CURVE_PARTICLE_COUNT := 18
const HIT_TRAIL_FRAMES := 42
const PLAYER_COLLISION_COOLDOWN_FRAMES := 6.0
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BODY_SPIN_FRAME_START := 0
const BODY_SPIN_FRAME_END := 15
const BODY_SPIN_FRAME_MSEC := 40.0 / 1.5
const BODY_SPIN_GRID_COLS := 4
const BODY_SPIN_CELL_SIZE := Vector2(160.0, 160.0)
const BODY_SPIN_SHEET_FRAME_COUNT := 16
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_KEY := "smasher_wheel"
const TIMER_STACK_INDEX := 0

var active := false
var direction := 0
var start_msec := 0
var end_msec := 0
var collision_consumed := false
var activated_this_frame := false
var trail_timer_frames := 0
var command_buffer: Array[Dictionary] = []
var previous_command_keys := {
	"a": false,
	"w": false,
	"d": false,
}
var _last_player_pos := Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_SIZE.x * 0.5, FIELD_HEIGHT - DEFAULT_PLAYER_SIZE.y)
var _last_player_size := DEFAULT_PLAYER_SIZE
var _cached_body_spin_msec := -1
var _cached_body_spin_frame := BODY_SPIN_FRAME_START
var _timer_font: Font


func prewarm_assets() -> void:
	_get_timer_font()


func reset() -> void:
	active = false
	direction = 0
	start_msec = 0
	end_msec = 0
	collision_consumed = false
	activated_this_frame = false
	trail_timer_frames = 0
	_cached_body_spin_msec = -1
	_cached_body_spin_frame = BODY_SPIN_FRAME_START
	command_buffer.clear()
	_clear_previous_command_keys()


func reset_round() -> void:
	reset()


func is_active() -> bool:
	return active


func was_activated_this_frame() -> bool:
	return activated_this_frame


func has_visible_effects() -> bool:
	return active


func needs_effect_update() -> bool:
	return active or trail_timer_frames > 0


func get_remaining_ratio(current_msec: int = -1) -> float:
	if not active:
		return 0.0
	var now_msec: int = current_msec if current_msec >= 0 else Time.get_ticks_msec()
	return clamp(float(end_msec - now_msec) / float(max(1, DURATION_MSEC)), 0.0, 1.0)


func get_status_context() -> Dictionary:
	var now_msec: int = Time.get_ticks_msec() if active else 0
	return {
		"active": active,
		"direction": direction,
		"remaining_ratio": get_remaining_ratio(now_msec) if active else 0.0,
		"remaining_msec": max(0, end_msec - now_msec) if active else 0,
		"collision_consumed": collision_consumed,
		"trail_timer_frames": trail_timer_frames,
	}


func get_body_spin_frame(current_msec: int = -1) -> int:
	var frame_span: int = max(1, BODY_SPIN_FRAME_END - BODY_SPIN_FRAME_START + 1)
	if not active:
		return BODY_SPIN_FRAME_START
	var now_msec: int = current_msec if current_msec >= 0 else Time.get_ticks_msec()
	if now_msec == _cached_body_spin_msec:
		return _cached_body_spin_frame
	var elapsed_msec: int = max(0, now_msec - start_msec)
	_cached_body_spin_msec = now_msec
	_cached_body_spin_frame = BODY_SPIN_FRAME_START + (int(elapsed_msec / BODY_SPIN_FRAME_MSEC) % frame_span)
	return _cached_body_spin_frame


func get_actor_draw_context(current_msec: int = -1) -> Dictionary:
	return {
		"player_wheel_spin_active": active,
		"player_wheel_spin_frame": get_body_spin_frame(current_msec),
		"player_wheel_spin_cell_width": BODY_SPIN_CELL_SIZE.x,
		"player_wheel_spin_cell_height": BODY_SPIN_CELL_SIZE.y,
		"player_wheel_spin_frame_count": BODY_SPIN_SHEET_FRAME_COUNT,
		"player_wheel_spin_grid_cols": BODY_SPIN_GRID_COLS,
		"player_wheel_spin_draw_size": BODY_SPIN_CELL_SIZE,
	}


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	activated_this_frame = false
	_expire_if_needed(current_msec)
	_update_command_buffer(input_snapshot, current_msec)
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
	}

	if active:
		command_buffer.clear()
		_clear_previous_command_keys()
		return result
	if not _can_activate(current_msec, special_gauge, config, deps):
		return result

	var triggered_dir: int = 0
	if _check_sequence(["a", "w", "d"], current_msec):
		triggered_dir = 1
	elif _check_sequence(["d", "w", "a"], current_msec):
		triggered_dir = -1
	if triggered_dir == 0:
		return result

	var cost: float = _get_skill_cost(deps.get("skill_config", null))
	var next_gauge: float = max(0.0, special_gauge - cost)
	_activate(current_msec, triggered_dir, player_pos, config, deps)
	_trigger_cooldown(current_msec, deps)
	result["special_gauge"] = next_gauge
	result["activated"] = true
	result["player_speed"] = _get_active_launch_speed(config) * float(triggered_dir)
	return result


func get_movement_direction(input_direction: float) -> float:
	if not active:
		return input_direction
	if abs(input_direction) <= 0.001 and direction != 0:
		return float(direction)
	return input_direction


func apply_movement_config(config: Dictionary, player_speed: float, input_direction: float) -> Dictionary:
	if not active:
		return config
	var motion_config := config.duplicate()
	motion_config["paddle_max_speed"] = float(motion_config.get("paddle_max_speed", 6.0)) * ACTIVE_SPEED_MULT
	motion_config["paddle_turn_decel"] = 0.0
	if _is_reversing(player_speed, input_direction):
		motion_config["paddle_accel"] = float(motion_config.get("paddle_accel", 0.5)) * ACTIVE_REVERSE_ACCEL_MULT
	return motion_config


func update_effects(_fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	if active:
		_expire_if_needed(current_msec)
	_update_trail(context, deps)


func consume_ball_hit(ball_pos: Vector2, ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not active or collision_consumed:
		return {}
	var incoming_speed: float = ball_vel.length()
	var base_speed: float = max(1.0, float(context.get("base_ball_speed", 9.0)))
	var speed_cap: float = HIT_MAX_SPEED
	var launch_speed: float = max(incoming_speed * BALL_SPEED_MULT, base_speed * BALL_SPEED_MULT, HIT_MIN_SPEED)
	launch_speed = min(launch_speed, speed_cap)
	var curve_dir: int = -1 if randf() < 0.5 else 1
	var angle_rad: float = deg_to_rad(randf_range(HIT_ANGLE_MIN_DEG, HIT_ANGLE_MAX_DEG))
	var next_vel := Vector2(
		cos(angle_rad) * launch_speed * float(curve_dir),
		-abs(sin(angle_rad) * launch_speed)
	)
	collision_consumed = true
	trail_timer_frames = HIT_TRAIL_FRAMES
	_register_hit_feedback(ball_pos, next_vel, deps)
	return {
		"ball_pos": _snap_ball_above_player(ball_pos, context),
		"ball_vel": next_vel,
		"ball_spin_strength": HIT_CURVE_STRENGTH,
		"ball_spin_direction": curve_dir,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": max(0.0, launch_speed - incoming_speed),
		"player_collision_cooldown": PLAYER_COLLISION_COOLDOWN_FRAMES,
		"smasher_wheel_speed_cap": speed_cap,
		"smasher_wheel_hit": true,
		"runtime_perk_gold": _award_hit_gold(deps),
	}


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not active or collision_consumed:
		return {}
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var player_pos: Vector2 = _get_vector2(context, "player_pos", _last_player_pos)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", _last_player_size)
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var ball_rect := Rect2(ball_pos.x - ball_size * 0.5, ball_pos.y - ball_size * 0.5, ball_size, ball_size)
	var player_rect := Rect2(
		player_pos.x - hitbox_padding,
		player_pos.y - hitbox_padding,
		player_size.x + hitbox_padding * 2.0,
		player_size.y + hitbox_padding * 2.0
	)
	if not _player_or_mirror_rect_hits_ball(player_rect, ball_rect, float(context.get("player_paddle_mirror_offset_x", 0.0))):
		return {}
	var hit_context: Dictionary = context.duplicate()
	hit_context.merge(scene, true)
	return consume_ball_hit(ball_pos, _get_vector2(scene, "ball_vel", Vector2.ZERO), hit_context, deps)


func draw(canvas: CanvasItem, _shake_offset: Vector2 = Vector2.ZERO, timer_stack: Object = null) -> void:
	if canvas == null or not active:
		return
	_draw_timer_bar(canvas, timer_stack, Time.get_ticks_msec())


func _activate(current_msec: int, next_direction: int, player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	active = true
	direction = clamp(next_direction, -1, 1)
	start_msec = current_msec
	end_msec = current_msec + DURATION_MSEC
	collision_consumed = false
	activated_this_frame = true
	_cached_body_spin_msec = current_msec
	_cached_body_spin_frame = BODY_SPIN_FRAME_START
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	command_buffer.clear()
	_clear_previous_command_keys()
	_trigger_activation_feedback(deps)


func _expire_if_needed(current_msec: int) -> void:
	if not active:
		return
	if current_msec < end_msec:
		return
	active = false
	direction = 0
	start_msec = 0
	end_msec = 0
	collision_consumed = false
	_cached_body_spin_msec = -1
	_cached_body_spin_frame = BODY_SPIN_FRAME_START


func _can_activate(current_msec: int, special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if active:
		return false
	if not bool(config.get("ball_active", false)):
		return false
	if _is_input_blocked(config, deps):
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return false
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return false
	return true


func _is_input_blocked(config: Dictionary, deps: Dictionary) -> bool:
	if bool(config.get("player_skill_input_locked", false)):
		return true
	var power_state: Object = deps.get("power_state", null)
	if power_state != null:
		if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
			return true
		if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
			return true
	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if plasma_state != null and plasma_state.has_method("is_charging") and bool(plasma_state.is_charging()):
		return true
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if magnum_state != null and magnum_state.has_method("is_active") and bool(magnum_state.is_active()):
		return true
	var shield_state: Object = deps.get("smasher_shield_kiting_state", null)
	if _has_live_shield_projectile(shield_state):
		return true
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		if dash_state.has_method("is_active") and bool(dash_state.is_active()):
			return true
		if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
			return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	return false


func _has_live_shield_projectile(shield_state: Object) -> bool:
	if shield_state == null or not shield_state.has_method("get_snapshot"):
		return false
	var snapshot: Variant = shield_state.get_snapshot()
	if not (snapshot is Dictionary):
		return false
	var projectile: Variant = snapshot.get("projectile", {})
	return projectile is Dictionary and not projectile.is_empty() and bool(projectile.get("active", false))


func _update_command_buffer(input_snapshot: Dictionary, current_msec: int) -> void:
	var current_keys := {
		"a": bool(input_snapshot.get("left_pressed", false)),
		"w": bool(input_snapshot.get("up_pressed", false)),
		"d": bool(input_snapshot.get("right_pressed", false)),
	}
	for key in ["a", "w", "d"]:
		if bool(current_keys[key]) and not bool(previous_command_keys[key]):
			_push_command(key, current_msec)
		previous_command_keys[key] = bool(current_keys[key])
	_trim_expired_commands(current_msec)


func _push_command(key: String, current_msec: int) -> void:
	command_buffer.append({
		"key": key,
		"msec": current_msec,
	})
	while command_buffer.size() > COMMAND_BUFFER_MAX:
		command_buffer.pop_front()


func _trim_expired_commands(current_msec: int) -> void:
	if command_buffer.is_empty():
		return
	var trimmed: Array[Dictionary] = []
	for item in command_buffer:
		if current_msec - int(item.get("msec", current_msec)) <= COMMAND_WINDOW_MSEC * 3:
			trimmed.append(item)
	command_buffer.clear()
	command_buffer.append_array(trimmed)


func _check_sequence(sequence: Array, current_msec: int) -> bool:
	if command_buffer.size() < 3:
		return false
	var start_index: int = command_buffer.size() - 3
	for i in range(3):
		if str(command_buffer[start_index + i].get("key", "")) != str(sequence[i]):
			return false
	var t1: int = int(command_buffer[start_index].get("msec", current_msec))
	var t2: int = int(command_buffer[start_index + 1].get("msec", current_msec))
	var t3: int = int(command_buffer[start_index + 2].get("msec", current_msec))
	if t2 - t1 > COMMAND_WINDOW_MSEC:
		return false
	if t3 - t2 > COMMAND_WINDOW_MSEC:
		return false
	if current_msec - t3 > COMMAND_WINDOW_MSEC:
		return false
	command_buffer.clear()
	return true


func _clear_previous_command_keys() -> void:
	previous_command_keys["a"] = false
	previous_command_keys["w"] = false
	previous_command_keys["d"] = false


func _is_reversing(player_speed: float, input_direction: float) -> bool:
	if abs(input_direction) <= 0.001 or abs(player_speed) <= 0.001:
		return false
	return sign(player_speed) != sign(input_direction)


func _get_active_launch_speed(config: Dictionary) -> float:
	return max(1.0, float(config.get("paddle_max_speed", 6.0))) * ACTIVE_SPEED_MULT


func _update_trail(context: Dictionary, deps: Dictionary) -> void:
	if trail_timer_frames <= 0:
		return
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var impact_effects: Object = deps.get("impact_effects", null)
	trail_timer_frames = max(0, trail_timer_frames - 1)
	if impact_effects == null or not impact_effects.has_method("spawn_drive_particles"):
		return
	if trail_timer_frames % 2 == 0:
		impact_effects.spawn_drive_particles(ball_pos, 2)
	impact_effects.spawn_drive_particles(ball_pos, 1)


func _register_hit_feedback(ball_pos: Vector2, next_vel: Vector2, deps: Dictionary) -> void:
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null and ball_intensity.has_method("register_hit"):
		ball_intensity.register_hit("player")
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(ball_pos, next_vel, 1.0, "smasher_wheel")
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null:
		if impact_effects.has_method("spawn_drive_particles"):
			impact_effects.spawn_drive_particles(ball_pos, HIT_CURVE_PARTICLE_COUNT)
		if impact_effects.has_method("spawn_paddle_hit_particles"):
			impact_effects.spawn_paddle_hit_particles(ball_pos, true, next_vel, 1.0)
		if impact_effects.has_method("create_energy_explosion"):
			impact_effects.create_energy_explosion(ball_pos, 0.72, 1.0)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.12, 9.0)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(0.12, 9.0)


func _award_hit_gold(deps: Dictionary) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
		return int(runtime_perk_state.award_gold(HIT_GOLD))
	return HIT_GOLD


func _snap_ball_above_player(ball_pos: Vector2, context: Dictionary) -> Vector2:
	var next_pos := ball_pos
	next_pos.y = float(context.get("player_y", _last_player_pos.y)) - float(context.get("ball_size", 0.0)) - 2.0
	return next_pos


func _player_or_mirror_rect_hits_ball(player_rect: Rect2, ball_rect: Rect2, mirror_offset_x: float) -> bool:
	if player_rect.intersects(ball_rect):
		return true
	if abs(mirror_offset_x) <= 0.01:
		return false
	return Rect2(player_rect.position + Vector2(mirror_offset_x, 0.0), player_rect.size).intersects(ball_rect)


func _draw_timer_bar(canvas: CanvasItem, timer_stack: Object = null, current_msec: int = -1) -> void:
	var ratio: float = get_remaining_ratio(current_msec)
	if ratio <= 0.0:
		return
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	canvas.draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(rect, Color(0.12, 0.055, 0.025, 0.82))
	var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * ratio, rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, Color(1.0, 0.54, 0.16, 0.92))
	canvas.draw_rect(rect, Color(1.0, 0.82, 0.38, 0.88), false, 2.0)
	var font: Font = _get_timer_font()
	if font != null:
		canvas.draw_string(font, rect.position + Vector2(6.0, rect.size.y - 3.0), "휠", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.92, 0.62, 0.95))


func _get_timer_font() -> Font:
	if _timer_font == null:
		_timer_font = ThemeDB.fallback_font
	return _timer_font


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		FIELD_WIDTH - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * 18.0
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _get_cooldown_remaining(current_msec: int, deps: Dictionary) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_configured_cooldown_remaining"):
		return 0.0
	return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
	return false


func _trigger_activation_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.06, 3.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _get_player_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", DEFAULT_PLAYER_SIZE.x))),
		max(1.0, float(config.get("paddle_height", DEFAULT_PLAYER_SIZE.y)))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
