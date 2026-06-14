extends RefCounted

const PowerSmashLifecycleState := preload("res://scripts/characters/smasher_power_smash_lifecycle_state.gd")
const PowerSmashSpeedState := preload("res://scripts/characters/smasher_power_smash_speed_state.gd")
const PowerSmashTextState := preload("res://scripts/characters/smasher_power_smash_text_state.gd")

var lifecycle_state: Object = PowerSmashLifecycleState.new()
var speed_state: Object = PowerSmashSpeedState.new()
var text_state: Object = PowerSmashTextState.new()


func reset(clear_text: bool = true) -> void:
	lifecycle_state.reset()
	speed_state.reset()
	text_state.reset(clear_text)


func can_activate(
	waiting_for_serve: bool,
	ball_active: bool,
	gauge: float,
	gauge_cost: float,
	frame_cooldown_blocked: bool,
	skill_cooldown_remaining: float
) -> bool:
	return lifecycle_state.can_activate(
		waiting_for_serve,
		ball_active,
		gauge,
		gauge_cost,
		frame_cooldown_blocked,
		skill_cooldown_remaining
	)


func begin_activation(
	new_direction: int,
	new_arc_strength: float,
	new_combo_consumed: int,
	text_duration_frames: float
) -> void:
	lifecycle_state.begin_activation(new_direction, new_arc_strength, new_combo_consumed)
	speed_state.reset()
	text_state.begin(text_duration_frames)


func finish_motion() -> void:
	lifecycle_state.finish_motion()
	speed_state.reset()


func lock_freeze_pose(pos: Vector2) -> void:
	lifecycle_state.lock_freeze_pose(pos)


func update_freeze(delta: float, freeze_duration: float) -> bool:
	return lifecycle_state.update_freeze(delta, freeze_duration)


func step_motion(fps_scale: float, boost_duration: float) -> bool:
	if not lifecycle_state.step_motion(fps_scale):
		return false
	speed_state.update_initial_boost(lifecycle_state.get_elapsed(), boost_duration)
	return true


func notify_wall_bounce(side: String) -> void:
	lifecycle_state.notify_wall_bounce(side)


func update_text_timer(fps_scale: float) -> void:
	text_state.update(fps_scale)


func set_original_speed(value: float) -> void:
	speed_state.set_original_speed(value)


func set_target_speed(value: float) -> void:
	speed_state.set_target_speed(value)


func start_initial_boost(value: float) -> void:
	speed_state.start_initial_boost(value)


func stop_initial_boost() -> void:
	speed_state.stop_initial_boost()


func is_freeze_active() -> bool:
	return lifecycle_state.is_freeze_active()


func get_freeze_timer() -> float:
	return lifecycle_state.get_freeze_timer()


func is_freeze_ball_locked() -> bool:
	return lifecycle_state.is_freeze_ball_locked()


func get_freeze_ball_pos() -> Vector2:
	return lifecycle_state.get_freeze_ball_pos()


func is_parabola_active() -> bool:
	return lifecycle_state.is_parabola_active()


func get_elapsed() -> float:
	return lifecycle_state.get_elapsed()


func get_direction() -> int:
	return lifecycle_state.get_direction()


func get_arc_strength() -> float:
	return lifecycle_state.get_arc_strength()


func get_original_speed() -> float:
	return speed_state.get_original_speed()


func is_initial_boost_active() -> bool:
	return speed_state.is_initial_boost_active()


func get_target_speed() -> float:
	return speed_state.get_target_speed()


func get_boosted_speed() -> float:
	return speed_state.get_boosted_speed()


func get_combo_consumed() -> int:
	return lifecycle_state.get_combo_consumed()


func get_text_timer_frames() -> float:
	return text_state.get_text_timer_frames()
