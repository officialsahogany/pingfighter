extends RefCounted

const PowerSmashActivationRules := preload("res://scripts/characters/smasher_power_smash_activation_rules.gd")
const PowerSmashFreezeState := preload("res://scripts/characters/smasher_power_smash_freeze_state.gd")
const PowerSmashParabolaState := preload("res://scripts/characters/smasher_power_smash_parabola_state.gd")

var activation_rules: Object = PowerSmashActivationRules.new()
var freeze_state: Object = PowerSmashFreezeState.new()
var parabola_state: Object = PowerSmashParabolaState.new()


func reset() -> void:
	freeze_state.reset()
	parabola_state.reset()


func can_activate(
	waiting_for_serve: bool,
	ball_active: bool,
	gauge: float,
	gauge_cost: float,
	frame_cooldown_blocked: bool,
	skill_cooldown_remaining: float
) -> bool:
	return activation_rules.can_activate(
		waiting_for_serve,
		ball_active,
		gauge,
		gauge_cost,
		freeze_state.is_active(),
		parabola_state.is_active(),
		frame_cooldown_blocked,
		skill_cooldown_remaining
	)


func begin_activation(new_direction: int, new_arc_strength: float, new_combo_consumed: int) -> void:
	freeze_state.begin()
	parabola_state.prepare(new_direction, new_arc_strength, new_combo_consumed)


func finish_motion() -> void:
	freeze_state.reset()
	parabola_state.finish()


func lock_freeze_pose(pos: Vector2) -> void:
	freeze_state.lock_pose(pos)


func update_freeze(delta: float, freeze_duration: float) -> bool:
	if not freeze_state.update(delta, freeze_duration):
		return false

	parabola_state.start()
	return true


func step_motion(fps_scale: float) -> bool:
	return parabola_state.step(fps_scale)


func notify_wall_bounce(side: String) -> void:
	parabola_state.repoint_arc_away_from(side)


func is_freeze_active() -> bool:
	return freeze_state.is_active()


func get_freeze_timer() -> float:
	return freeze_state.get_timer()


func is_freeze_ball_locked() -> bool:
	return freeze_state.is_ball_locked()


func get_freeze_ball_pos() -> Vector2:
	return freeze_state.get_ball_pos()


func is_parabola_active() -> bool:
	return parabola_state.is_active()


func get_elapsed() -> float:
	return parabola_state.get_elapsed()


func get_direction() -> int:
	return parabola_state.get_direction()


func get_arc_strength() -> float:
	return parabola_state.get_arc_strength()


func get_combo_consumed() -> int:
	return parabola_state.get_combo_consumed()
