extends RefCounted

# Stage 6 Tetriser super-transform and one-shot cube-laser lifecycle.
#
# The host retains public boss_gauge/status fields and applies audio, cube melt,
# EMP, obstacle-clear, and debris side effects from the events returned here.

const LASER_EVENT_NONE := 0
const LASER_EVENT_FIRED := 1

const ACTIVATE_GAUGE := 500.0
const DRAIN_PER_SEC := 25.0
const BODY_SCALE := 2.0
const SCALE_LERP_PER_SEC := 4.0
const INTRO_SEC := 0.6
const LASER_CHARGE_SEC := 0.8
const LASER_DURATION_SEC := 1.2

var _active: bool = false
var _intro_timer: float = 0.0
var _scale: float = 1.0
var _target_scale: float = 1.0
var _laser_state: String = "idle"
var _laser_timer: float = 0.0
var _laser_fired_this_super: bool = false


func reset() -> void:
	_active = false
	_intro_timer = 0.0
	_scale = 1.0
	_target_scale = 1.0
	_laser_state = "idle"
	_laser_timer = 0.0
	_laser_fired_this_super = false


# `status_super` deliberately reports whether the frame STARTED active. This
# preserves the original host order: activation frames still display charging,
# while the final drain-to-zero frame still displays super.
func update_super(delta: float, current_gauge: float) -> Dictionary:
	_intro_timer = maxf(0.0, _intro_timer - delta)
	var status_super: bool = _active
	var activated := false
	var next_gauge := current_gauge
	if _active:
		next_gauge = maxf(0.0, current_gauge - DRAIN_PER_SEC * delta)
		if next_gauge <= 0.0:
			_active = false
			_target_scale = 1.0
			_reset_laser_cycle()
	elif current_gauge >= ACTIVATE_GAUGE:
		_active = true
		_target_scale = BODY_SCALE
		_intro_timer = INTRO_SEC
		next_gauge = ACTIVATE_GAUGE
		activated = true
	_scale = move_toward(_scale, _target_scale, SCALE_LERP_PER_SEC * delta)
	return {
		"gauge": next_gauge,
		"activated": activated,
		"status_super": status_super,
	}


func update_laser(delta: float, cube_active: bool) -> int:
	if not _active:
		return LASER_EVENT_NONE
	match _laser_state:
		"idle":
			if not _laser_fired_this_super and cube_active:
				_laser_state = "charging"
				_laser_timer = LASER_CHARGE_SEC
		"charging":
			_laser_timer -= delta
			if _laser_timer <= 0.0:
				_laser_state = "firing"
				_laser_timer = LASER_DURATION_SEC
				_laser_fired_this_super = true
				return LASER_EVENT_FIRED
		"firing":
			_laser_timer -= delta
			if _laser_timer <= 0.0:
				_laser_state = "idle"
	return LASER_EVENT_NONE


func get_actor_draw_context(laser_target: Vector2) -> Dictionary:
	return {
		"stage6_tetriser_super_active": _active,
		"stage6_tetriser_super_scale": _scale,
		"stage6_tetriser_super_intro": _intro_timer > 0.0,
		"stage6_tetriser_laser": _build_laser_draw_data(laser_target),
	}


func is_active() -> bool:
	return _active


func get_scale() -> float:
	return _scale


func is_intro_active() -> bool:
	return _intro_timer > 0.0


func get_laser_state() -> String:
	return _laser_state


func _reset_laser_cycle() -> void:
	_laser_state = "idle"
	_laser_timer = 0.0
	_laser_fired_this_super = false


func _build_laser_draw_data(target: Vector2) -> Dictionary:
	if _laser_state == "idle":
		return {}
	var total: float = LASER_CHARGE_SEC if _laser_state == "charging" else LASER_DURATION_SEC
	return {
		"state": _laser_state,
		"progress": clampf(1.0 - _laser_timer / maxf(0.001, total), 0.0, 1.0),
		"target": target,
	}
