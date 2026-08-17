extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const ACTIVATION_FLASH_SEC := 0.46
const ECHO_LIFETIME_SEC := 0.44
const ECHO_SPAWN_INTERVAL_SEC := 0.075
const MIN_ECHO_TRAVEL_PX := 5.0
const TELEPORT_DISTANCE_PX := 180.0
const MAX_ECHO_COUNT := 6
const PLAYER_SIZE_FALLBACK := Vector2(155.0, 50.0)

var _active := false
var _activation_flash_remaining_sec := 0.0
var _phase_sec := 0.0
var _spawn_cooldown_sec := 0.0
var _sample_ready := false
var _player_center := Vector2.ZERO
var _player_size := PLAYER_SIZE_FALLBACK
var _last_sample_center := Vector2.ZERO
var _last_move_direction := Vector2.RIGHT
var _echoes: Array[Dictionary] = []
var _trigger_count := 0
var _next_echo_id := 1


func trigger() -> void:
	if not _active:
		_echoes.clear()
		_sample_ready = false
	_active = true
	_activation_flash_remaining_sec = ACTIVATION_FLASH_SEC
	_spawn_cooldown_sec = 0.0
	_phase_sec = 0.0
	_trigger_count += 1


func advance(delta: float, owner: Object, buff_active: bool) -> bool:
	var safe_delta := maxf(0.0, delta)
	if not buff_active:
		clear_visuals()
		return false
	_active = true
	_phase_sec += safe_delta
	_activation_flash_remaining_sec = maxf(0.0, _activation_flash_remaining_sec - safe_delta)
	_spawn_cooldown_sec = maxf(0.0, _spawn_cooldown_sec - safe_delta)
	_age_echoes(safe_delta)
	if owner == null:
		return has_visible_effects()

	_player_size = _read_player_size(owner)
	_player_center = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		_player_center - _player_size * 0.5
	) + _player_size * 0.5
	if not _sample_ready:
		_last_sample_center = _player_center
		_sample_ready = true
		return true

	var displacement := _player_center - _last_sample_center
	var travel := displacement.length()
	if travel > TELEPORT_DISTANCE_PX:
		_echoes.clear()
	elif travel >= MIN_ECHO_TRAVEL_PX and _spawn_cooldown_sec <= 0.0:
		_last_move_direction = displacement / travel
		_spawn_echo(_last_sample_center, _last_move_direction)
		_spawn_cooldown_sec = ECHO_SPAWN_INTERVAL_SEC
	_last_sample_center = _player_center
	return true


func clear_visuals() -> void:
	_active = false
	_activation_flash_remaining_sec = 0.0
	_phase_sec = 0.0
	_spawn_cooldown_sec = 0.0
	_sample_ready = false
	_player_center = Vector2.ZERO
	_last_sample_center = Vector2.ZERO
	_last_move_direction = Vector2.RIGHT
	_echoes.clear()


func reset_round() -> void:
	clear_visuals()


func reset_all() -> void:
	clear_visuals()
	_trigger_count = 0
	_next_echo_id = 1


func has_visible_effects() -> bool:
	return _active and _sample_ready


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not has_visible_effects():
		return
	for echo: Dictionary in _echoes:
		_draw_echo(canvas, echo, shake_offset)
	_draw_active_wind_seal(canvas, _player_center + shake_offset)
	if _activation_flash_remaining_sec > 0.0:
		_draw_activation_flash(canvas, _player_center + shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"reverb_vfx_active": has_visible_effects(),
		"reverb_vfx_activation_flash_remaining_sec": _activation_flash_remaining_sec,
		"reverb_vfx_phase_sec": _phase_sec,
		"reverb_vfx_echo_count": _echoes.size(),
		"reverb_vfx_echoes": _echoes.duplicate(true),
		"reverb_vfx_player_center": _player_center,
		"reverb_vfx_player_size": _player_size,
		"reverb_vfx_move_direction": _last_move_direction,
		"reverb_vfx_trigger_count": _trigger_count,
	}


func _age_echoes(delta: float) -> void:
	for index in range(_echoes.size() - 1, -1, -1):
		var echo: Dictionary = _echoes[index]
		echo["age_sec"] = float(echo.get("age_sec", 0.0)) + delta
		if float(echo.get("age_sec", 0.0)) >= ECHO_LIFETIME_SEC:
			_echoes.remove_at(index)


func _spawn_echo(center: Vector2, direction: Vector2) -> void:
	_echoes.append({
		"id": _next_echo_id,
		"center": center,
		"size": _player_size,
		"direction": direction,
		"age_sec": 0.0,
	})
	_next_echo_id += 1
	while _echoes.size() > MAX_ECHO_COUNT:
		_echoes.pop_front()


func _draw_echo(canvas: CanvasItem, echo: Dictionary, shake_offset: Vector2) -> void:
	var age := clampf(float(echo.get("age_sec", 0.0)), 0.0, ECHO_LIFETIME_SEC)
	var life := 1.0 - age / ECHO_LIFETIME_SEC
	var alpha := life * life
	var center: Vector2 = echo.get("center", Vector2.ZERO) + shake_offset
	var size: Vector2 = echo.get("size", PLAYER_SIZE_FALLBACK)
	var direction: Vector2 = echo.get("direction", Vector2.RIGHT)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var perpendicular := Vector2(-direction.y, direction.x)
	var radius := maxf(18.0, size.y * (0.46 + life * 0.08))
	var facing_angle := direction.angle()
	canvas.draw_arc(center, radius, facing_angle - PI * 0.72, facing_angle + PI * 0.72, 18, Color(0.36, 0.96, 1.0, 0.48 * alpha), 2.8, true)
	canvas.draw_arc(center, radius + 6.0, facing_angle + PI * 0.28, facing_angle + PI * 1.28, 16, Color(1.0, 0.80, 0.24, 0.38 * alpha), 2.1, true)
	var chevron_tip := center + direction * (radius + 3.0)
	canvas.draw_line(chevron_tip - direction * 12.0 + perpendicular * 7.0, chevron_tip, Color(0.78, 0.98, 1.0, 0.42 * alpha), 2.0, true)
	canvas.draw_line(chevron_tip - direction * 12.0 - perpendicular * 7.0, chevron_tip, Color(0.78, 0.98, 1.0, 0.42 * alpha), 2.0, true)
	for lane in range(3):
		var lane_offset := perpendicular * (float(lane) - 1.0) * size.y * 0.22
		var start := center + lane_offset - direction * (radius * 0.28)
		var length := 30.0 + float(lane) * 10.0
		var color := Color(0.32, 0.94, 1.0, (0.30 + float(lane) * 0.07) * alpha)
		if lane == 1:
			color = Color(1.0, 0.82, 0.30, 0.44 * alpha)
		canvas.draw_line(start, start - direction * length, color, 2.5 - float(lane) * 0.35, true)


func _draw_active_wind_seal(canvas: CanvasItem, center: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_phase_sec * 9.0)
	var radius := maxf(31.0, _player_size.y * (0.70 + pulse * 0.08))
	var sweep := fposmod(_phase_sec * 3.6, TAU)
	canvas.draw_arc(center, radius, sweep, sweep + PI * 0.72, 18, Color(0.40, 0.96, 1.0, 0.46 + pulse * 0.14), 2.7, true)
	canvas.draw_arc(center, radius + 7.0, sweep + PI, sweep + PI * 1.72, 18, Color(1.0, 0.78, 0.22, 0.38 + pulse * 0.12), 2.1, true)
	var direction := _last_move_direction
	var perpendicular := Vector2(-direction.y, direction.x)
	var streak_alpha := 0.22 + pulse * 0.12
	for lane in range(3):
		var start := center - direction * (_player_size.x * 0.26) + perpendicular * (float(lane) - 1.0) * 12.0
		var color := Color(0.28, 0.92, 1.0, streak_alpha)
		if lane == 1:
			color = Color(1.0, 0.78, 0.22, streak_alpha * 1.12)
		canvas.draw_line(start, start - direction * (30.0 + float(lane) * 11.0), color, 2.2, true)


func _draw_activation_flash(canvas: CanvasItem, center: Vector2) -> void:
	var progress := 1.0 - _activation_flash_remaining_sec / ACTIVATION_FLASH_SEC
	var fade := (1.0 - progress) * (1.0 - progress)
	var outer_radius := lerpf(24.0, maxf(74.0, _player_size.x * 0.56), progress)
	canvas.draw_arc(center, outer_radius, 0.0, TAU, 48, Color(0.46, 0.98, 1.0, 0.82 * fade), 4.2, true)
	canvas.draw_arc(center, outer_radius * 0.72, -PI * 0.5, PI * 1.5, 32, Color(1.0, 0.80, 0.24, 0.68 * fade), 2.8, true)
	for ray_index in range(8):
		var angle := TAU * float(ray_index) / 8.0 + _phase_sec * 1.8
		var direction := Vector2(cos(angle), sin(angle))
		canvas.draw_line(
			center + direction * (outer_radius + 4.0),
			center + direction * (outer_radius + 15.0 + float(ray_index % 2) * 5.0),
			Color(0.76, 0.98, 1.0, 0.62 * fade),
			2.0,
			true
		)


func _read_player_size(owner: Object) -> Vector2:
	return Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_SIZE_FALLBACK.x))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_SIZE_FALLBACK.y)))
	)
