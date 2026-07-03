extends RefCounted

const FEED_BOWL_TEXTURE := preload("res://assets/sprites/lingpet/lingpet_feed_bowl.png")

const MOTION_STYLE_PATROL := "patrol"
const PHASE_NONE := ""
const PHASE_TO_BOWL := "to_bowl"
const PHASE_EATING := "eating"
const PHASE_RETURN := "return"
const DEFAULT_APPROACH_SPEED := 360.0
const RETURN_ARRIVAL_RADIUS := 12.0
const DEFAULT_EAT_SECONDS := 1.0
const ARRIVAL_RADIUS := 14.0
const GROUND_ARRIVAL_X := 9.0
const BOWL_DRAW_SIZE := Vector2(34.0, 34.0)
const EATING_BOB_X := 3.8
const EATING_BOB_Y := 5.0
const EATING_CHOMP_RATE := 42.0
const EATING_WIGGLE_RATE := 74.0
const BOWL_EATING_SHAKE_X := 1.2
const BOWL_EATING_PULSE_SCALE := 0.05

var _active := false
var _phase := PHASE_NONE
var _bowl_pos := Vector2.ZERO
var _target_pos := Vector2.ZERO
var _companion_pos := Vector2.ZERO
var _return_pos := Vector2.ZERO
var _eating_base_pos := Vector2.ZERO
var _eating_timer := 0.0
var _eating_total := DEFAULT_EAT_SECONDS
var _eating_elapsed := 0.0
var _ground_tracking := false
var _completed_count := 0


func arm(bowl_pos: Vector2, current_companion_pos: Vector2, motion_style_value: String = MOTION_STYLE_PATROL) -> bool:
	if _active:
		return false
	_active = true
	_phase = PHASE_TO_BOWL
	_bowl_pos = bowl_pos
	_companion_pos = current_companion_pos if current_companion_pos != Vector2.ZERO else bowl_pos
	# Air position the companion descends FROM; flight pets fly back to it after eating.
	_return_pos = _companion_pos
	_ground_tracking = _is_ground_motion_style(motion_style_value)
	_target_pos = _resolve_target_pos()
	_eating_base_pos = Vector2.ZERO
	_eating_timer = 0.0
	_eating_elapsed = 0.0
	return true


func advance(delta: float, current_companion_pos: Vector2, motion_style_value: String = MOTION_STYLE_PATROL) -> Dictionary:
	if not _active:
		return {}
	var safe_delta: float = maxf(0.0, delta)
	if _companion_pos == Vector2.ZERO:
		_companion_pos = current_companion_pos if current_companion_pos != Vector2.ZERO else _bowl_pos
	_ground_tracking = _is_ground_motion_style(motion_style_value)
	var started_eating := false
	var completed := false
	if _phase == PHASE_TO_BOWL:
		_target_pos = _resolve_target_pos()
		var previous_pos := _companion_pos
		_companion_pos = previous_pos.move_toward(_target_pos, DEFAULT_APPROACH_SPEED * safe_delta)
		if _ground_tracking:
			_companion_pos.y = _target_pos.y
		if _has_arrived():
			_eating_base_pos = _resolve_target_pos()
			_phase = PHASE_EATING
			_eating_total = DEFAULT_EAT_SECONDS
			_eating_timer = DEFAULT_EAT_SECONDS
			_eating_elapsed = 0.0
			started_eating = true
	elif _phase == PHASE_EATING:
		_eating_elapsed += safe_delta
		_eating_timer = maxf(0.0, _eating_timer - safe_delta)
		_companion_pos = _get_eating_companion_pos()
		if _eating_timer <= 0.0:
			_completed_count += 1
			completed = true
			# Flight pets descended to the ground bowl. Dropping the position
			# override the instant eating ends teleports them straight back to
			# their air lane (reads as "갑자기 시야에서 사라짐"). Fly them back up
			# to the pre-feed air spot first, then release. Ground pets already
			# keep their lane Y, so they release immediately with no visible jump.
			if _ground_tracking or _return_pos == Vector2.ZERO:
				_clear_active()
			else:
				_phase = PHASE_RETURN
				_eating_base_pos = Vector2.ZERO
	elif _phase == PHASE_RETURN:
		_companion_pos = _companion_pos.move_toward(_return_pos, DEFAULT_APPROACH_SPEED * safe_delta)
		if _companion_pos.distance_to(_return_pos) <= RETURN_ARRIVAL_RADIUS:
			_companion_pos = _return_pos
			_clear_active()
	return {
		"active": _active,
		"phase": _phase,
		"started_eating": started_eating,
		"completed": completed,
		"companion_pos": _companion_pos,
		"bowl_pos": _bowl_pos,
		"eating_remaining": _eating_timer,
	}


func has_companion_position_override() -> bool:
	return _active and _companion_pos != Vector2.ZERO


func get_companion_position_override(fallback: Vector2) -> Vector2:
	return _companion_pos if has_companion_position_override() else fallback


func has_visible_effects() -> bool:
	# The bowl graphic represents the food; once eating ends and the flight pet
	# is gliding home (PHASE_RETURN), the food is gone so the bowl stops drawing.
	return _active and _phase != PHASE_RETURN and _bowl_pos != Vector2.ZERO


func is_active() -> bool:
	return _active


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not has_visible_effects():
		return
	var texture: Texture2D = FEED_BOWL_TEXTURE
	if texture == null:
		return
	var draw_pos := _bowl_pos + shake_offset
	var draw_size := BOWL_DRAW_SIZE
	if _phase == PHASE_EATING:
		var chew := absf(sin(_eating_elapsed * EATING_CHOMP_RATE))
		draw_pos.x += sin(_eating_elapsed * EATING_WIGGLE_RATE) * BOWL_EATING_SHAKE_X
		draw_size *= 1.0 + chew * BOWL_EATING_PULSE_SCALE
	var rect := Rect2(draw_pos - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.96))


func reset_round_transients() -> void:
	_clear_active()


func reset_all() -> void:
	_clear_active()
	_bowl_pos = Vector2.ZERO
	_target_pos = Vector2.ZERO
	_companion_pos = Vector2.ZERO
	_return_pos = Vector2.ZERO
	_eating_base_pos = Vector2.ZERO
	_completed_count = 0


func get_snapshot() -> Dictionary:
	return {
		"feed_bowl_active": _active,
		"feed_bowl_phase": _phase,
		"feed_bowl_pos": _bowl_pos,
		"feed_bowl_companion_pos": _companion_pos,
		"feed_bowl_eating_remaining": _eating_timer,
		"feed_bowl_completed_count": _completed_count,
	}


func is_active_for_tests() -> bool:
	return _active


func get_completed_count_for_tests() -> int:
	return _completed_count


func _resolve_target_pos() -> Vector2:
	if _ground_tracking:
		return Vector2(_bowl_pos.x, _companion_pos.y)
	return _bowl_pos + Vector2(0.0, -10.0)


func _has_arrived() -> bool:
	if _ground_tracking:
		return absf(_companion_pos.x - _target_pos.x) <= GROUND_ARRIVAL_X
	return _companion_pos.distance_to(_target_pos) <= ARRIVAL_RADIUS


func _get_eating_companion_pos() -> Vector2:
	var base := _eating_base_pos if _eating_base_pos != Vector2.ZERO else _resolve_target_pos()
	var chew := absf(sin(_eating_elapsed * EATING_CHOMP_RATE))
	var x_bob := sin(_eating_elapsed * EATING_WIGGLE_RATE) * EATING_BOB_X
	var y_bob := chew * EATING_BOB_Y
	return base + Vector2(x_bob, y_bob)


func _clear_active() -> void:
	_active = false
	_phase = PHASE_NONE
	_eating_base_pos = Vector2.ZERO
	_eating_timer = 0.0
	_eating_elapsed = 0.0
	_ground_tracking = false


func _is_ground_motion_style(value: String) -> bool:
	return value.strip_edges().to_lower() == MOTION_STYLE_PATROL
