extends RefCounted

const PowerSmashEffectsState := preload("res://scripts/characters/smasher_power_smash_effects_state.gd")
const PowerSmashRuntimeState := preload("res://scripts/characters/smasher_power_smash_runtime_state.gd")
const PowerSmashVelocityFacade := preload("res://scripts/characters/smasher_power_smash_velocity_facade.gd")

var runtime_state: Object = PowerSmashRuntimeState.new()
var effects_state: Object = PowerSmashEffectsState.new()
var velocity_facade: Object = PowerSmashVelocityFacade.new()


func reset(clear_text: bool = true) -> void:
	runtime_state.reset(clear_text)
	clear_effects()


func can_activate(
	waiting_for_serve: bool,
	ball_active: bool,
	gauge: float,
	gauge_cost: float,
	frame_cooldown_blocked: bool,
	skill_cooldown_remaining: float
) -> bool:
	return runtime_state.can_activate(
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
	runtime_state.begin_activation(new_direction, new_arc_strength, new_combo_consumed, text_duration_frames)
	clear_effects()


func lock_freeze_pose(pos: Vector2) -> void:
	runtime_state.lock_freeze_pose(pos)


func update_freeze(delta: float, freeze_duration: float) -> bool:
	return runtime_state.update_freeze(delta, freeze_duration)


func apply_hit_velocity(
	ball_velocity: Vector2,
	ball_position: Vector2,
	player_position: Vector2,
	paddle_width: float,
	base_speed: float,
	ball_physics: Object,
	combo_min_count: int
) -> Vector2:
	return velocity_facade.apply_hit_velocity(
		runtime_state,
		ball_velocity,
		ball_position,
		player_position,
		paddle_width,
		base_speed,
		ball_physics,
		combo_min_count
	)


func apply_motion(ball_velocity: Vector2, fps_scale: float, gravity_effect: float, boost_duration: float) -> Vector2:
	return velocity_facade.apply_motion(runtime_state, ball_velocity, fps_scale, gravity_effect, boost_duration)


func clear_effects() -> void:
	effects_state.clear()


func spawn_trail(pos: Vector2, ball_size: float, combo_count: int = 0) -> void:
	effects_state.spawn_trail(pos, ball_size, combo_count)


func spawn_particles(pos: Vector2, count: int, combo_count: int = 0) -> void:
	effects_state.spawn_particles(pos, count, combo_count)


func spawn_initial_burst(pos: Vector2) -> void:
	effects_state.spawn_initial_burst(pos)


func update_effects(fps_scale: float, ball_pos: Vector2, ball_active: bool, ball_size: float) -> void:
	effects_state.update(
		fps_scale,
		ball_pos,
		ball_active,
		ball_size,
		is_parabola_active() or is_freeze_active(),
		is_parabola_active(),
		get_combo_consumed()
	)


func update_text_timer(fps_scale: float) -> void:
	runtime_state.update_text_timer(fps_scale)


func is_freeze_active() -> bool:
	return runtime_state.is_freeze_active()


func get_freeze_timer() -> float:
	return runtime_state.get_freeze_timer()


func is_freeze_ball_locked() -> bool:
	return runtime_state.is_freeze_ball_locked()


func get_freeze_ball_pos() -> Vector2:
	return runtime_state.get_freeze_ball_pos()


func is_parabola_active() -> bool:
	return runtime_state.is_parabola_active()


func get_original_speed() -> float:
	return runtime_state.get_original_speed()


func get_combo_consumed() -> int:
	return runtime_state.get_combo_consumed()


func get_text_timer_frames() -> float:
	return runtime_state.get_text_timer_frames()


func get_trails() -> Array[Dictionary]:
	return effects_state.get_trails()


func get_particles() -> Array[Dictionary]:
	return effects_state.get_particles()
