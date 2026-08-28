extends RefCounted

const PowerSmashEffectsState := preload("res://scripts/characters/smasher_power_smash_effects_state.gd")
const SmasherGhostShotState := preload("res://scripts/characters/smasher_ghost_shot_state.gd")
const PowerSmashRuntimeState := preload("res://scripts/characters/smasher_power_smash_runtime_state.gd")
const PowerSmashVelocityFacade := preload("res://scripts/characters/smasher_power_smash_velocity_facade.gd")
const PowerSmashCutinState := preload("res://scripts/characters/smasher_power_smash_cutin_state.gd")
const SmasherDriveCutinState := preload("res://scripts/characters/smasher_drive_cutin_state.gd")
const SmasherGhostPossessionState := preload("res://scripts/characters/smasher_ghost_possession_state.gd")
const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")

var runtime_state: Object = PowerSmashRuntimeState.new()
var effects_state: Object = PowerSmashEffectsState.new()
var ghost_state: Object = SmasherGhostShotState.new()
var velocity_facade: Object = PowerSmashVelocityFacade.new()
var cutin_state: Object = PowerSmashCutinState.new()
# Non-freezing partial-screen Drive cut-in (Mika portrait slide-in). Hosted here
# so it shares the per-frame update / draw / reset lifecycle that already exists
# for the power-smash cut-in, but it never pauses the rally.
var drive_cutin_state: Object = SmasherDriveCutinState.new()
# Ghost-smashing possession presentation: hides the player paddle while Mika is
# "inside" the ball, then flies her home when the returned ball reaches the
# player paddle. Separate lifecycle from ghost_state -- see
# smasher_ghost_possession_state.gd.
var ghost_possession_state: Object = SmasherGhostPossessionState.new()
var _runtime_perk_modal_pause_started_msec := -1


func reset(clear_text: bool = true) -> void:
	runtime_state.reset(clear_text)
	clear_effects()
	ghost_state.reset()
	cutin_state.reset()
	drive_cutin_state.reset()
	ghost_possession_state.reset()
	_runtime_perk_modal_pause_started_msec = -1


# 퍽 모달 동안 벽시계 앵커 동결. 파워스매싱 자신은 프레임 타이머로 돌지만
# 소유한 잔영(ghost_state)이 벽시계 예약(`arrive_msec`)을 쓰므로 여기로 흘린다.
# 규칙은 runtime_perk_modal_time_shift.gd 참조.
func pause_runtime_perk_modal_time(current_msec: int) -> void:
	_runtime_perk_modal_pause_started_msec = RuntimePerkModalTimeShift.begin_pause(
		_runtime_perk_modal_pause_started_msec, current_msec
	)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	shift_runtime_perk_modal_time(pause_started_msec, current_msec)


func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	if ghost_state != null and ghost_state.has_method("shift_runtime_perk_modal_time"):
		ghost_state.shift_runtime_perk_modal_time(pause_started_msec, resumed_msec)


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
	text_duration_frames: float,
	ghost_shot: bool = false,
	current_msec: int = 0,
	freeze_duration: float = 0.0
) -> void:
	runtime_state.begin_activation(new_direction, new_arc_strength, new_combo_consumed, text_duration_frames)
	clear_effects()
	if ghost_shot:
		ghost_state.begin(current_msec if current_msec > 0 else Time.get_ticks_msec())
		# Mika is sucked into the ball: hide the field paddle until the boss
		# returns the ball. The freeze cut-in covers the dramatic suck-in beat.
		ghost_possession_state.begin()
	else:
		ghost_state.reset()
		ghost_possession_state.reset()
	if freeze_duration > 0.0:
		cutin_state.begin(freeze_duration, "ghost_shot" if ghost_shot else "power_smashing")
	else:
		cutin_state.reset()


func begin_cinematic_freeze(freeze_duration: float, skill_name: String) -> void:
	if freeze_duration <= 0.0:
		return
	runtime_state.begin_cinematic_freeze()
	clear_effects()
	ghost_state.reset()
	ghost_possession_state.reset()
	cutin_state.begin(freeze_duration, skill_name)


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
	combo_min_count: int,
	launch_speed_multiplier: float = 1.0,
	smash_speed_amp: float = 0.0
) -> Vector2:
	return velocity_facade.apply_hit_velocity(
		runtime_state,
		ball_velocity,
		ball_position,
		player_position,
		paddle_width,
		base_speed,
		ball_physics,
		combo_min_count,
		launch_speed_multiplier,
		smash_speed_amp
	)


func apply_motion(
	ball_velocity: Vector2,
	fps_scale: float,
	gravity_effect: float,
	boost_duration: float,
	initial_boost_decay_reduction: float = 0.0
) -> Vector2:
	return velocity_facade.apply_motion(
		runtime_state,
		ball_velocity,
		fps_scale,
		gravity_effect,
		boost_duration,
		initial_boost_decay_reduction
	)


func notify_wall_bounce(side: String) -> void:
	if not is_parabola_active() or is_ghost_shot_motion_active():
		return
	runtime_state.notify_wall_bounce(side)


func apply_ghost_shot_motion(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not is_ghost_shot_motion_active():
		return {}
	if not runtime_state.step_motion(fps_scale, 0.0):
		return {}
	var result: Dictionary = ghost_state.apply_motion(
		scene,
		fps_scale,
		runtime_state.get_elapsed(),
		runtime_state.get_arc_strength(),
		context,
		deps
	)
	if bool(result.get("finish_power_motion", false)):
		runtime_state.finish_motion()
		# The ghost ball has been fired at the boss. Possession stays hidden
		# through the boss return, then pops on the player-side counter.
		ghost_possession_state.notify_ball_fired()
	return result


func finish_after_boss_counter(origin: Vector2 = Vector2.ZERO) -> void:
	var scatter_origin: Vector2 = origin
	if scatter_origin == Vector2.ZERO:
		scatter_origin = ghost_state.get_last_visible_ball_pos()
	var should_scatter_ghosts: bool = ghost_state.is_active() or ghost_state.has_pending_teleport()
	runtime_state.reset(false)
	effects_state.clear()
	if should_scatter_ghosts:
		ghost_state.scatter_from(scatter_origin)
	else:
		ghost_state.reset()
	# The ghost shot is being cancelled by the boss counter -- fly Mika home from
	# the scatter origin so the paddle is never left hidden.
	ghost_possession_state.release_with_fly_back(scatter_origin)


func clear_effects() -> void:
	effects_state.clear()
	ghost_state.reset()


func spawn_trail(pos: Vector2, ball_size: float, combo_count: int = 0) -> void:
	effects_state.spawn_trail(pos, ball_size, combo_count)


func spawn_particles(pos: Vector2, count: int, combo_count: int = 0) -> void:
	effects_state.spawn_particles(pos, count, combo_count)


func spawn_initial_burst(pos: Vector2) -> void:
	effects_state.spawn_initial_burst(pos)


func update_effects(
	fps_scale: float,
	ball_pos: Vector2,
	ball_active: bool,
	ball_size: float,
	_context: Dictionary = {}
) -> void:
	var ghost_motion_active: bool = is_ghost_shot_motion_active()
	effects_state.update(
		fps_scale,
		ball_pos,
		ball_active,
		ball_size,
		(is_parabola_active() or is_freeze_active()) and not ghost_motion_active,
		is_parabola_active() and not ghost_motion_active,
		get_combo_consumed()
	)
	ghost_state.update_effects(fps_scale, ball_pos, ball_active, ball_size)
	if ghost_possession_state.is_active():
		# Possession only needs to tick its fly-back timer now; the boss-defend
		# event restores the paddle immediately (notify_ghost_possession_boss_returned),
		# so there is no deferred player-zone return to drive here.
		ghost_possession_state.update(fps_scale / 60.0, ball_pos)
	if cutin_state.is_active():
		cutin_state.update(fps_scale / 60.0)
	if drive_cutin_state.is_active():
		drive_cutin_state.update(fps_scale / 60.0)


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


func is_ghost_shot_active() -> bool:
	return ghost_state.is_active()


func is_ghost_shot_motion_active() -> bool:
	return ghost_state.is_motion_active()


func has_ghost_shot_pending_teleport() -> bool:
	return ghost_state.has_pending_teleport()


func scatter_ghost_shot_from_boss(origin: Vector2) -> void:
	ghost_state.scatter_from(origin)


# --- Ghost-smashing possession (paddle hide + fly-back) delegation ---

func is_ghost_possession_active() -> bool:
	return ghost_possession_state.is_active()


func is_ghost_possession_paddle_hidden() -> bool:
	return ghost_possession_state.is_paddle_hidden()


func get_ghost_possession_player_override() -> Dictionary:
	return ghost_possession_state.get_player_visual_override()


func notify_ghost_possession_boss_returned(from_pos: Vector2 = Vector2.ZERO) -> bool:
	return ghost_possession_state.notify_boss_returned(from_pos)


func has_ghost_possession_boss_returned() -> bool:
	return ghost_possession_state.has_boss_returned()


func trigger_ghost_possession_fly_back(from_pos: Vector2) -> bool:
	return ghost_possession_state.trigger_fly_back(from_pos)


func force_release_ghost_possession() -> void:
	ghost_possession_state.force_release()


func get_original_speed() -> float:
	return runtime_state.get_original_speed()


func get_arc_strength() -> float:
	return runtime_state.get_arc_strength()


func get_combo_consumed() -> int:
	return runtime_state.get_combo_consumed()


func get_text_timer_frames() -> float:
	return runtime_state.get_text_timer_frames()


func get_trails() -> Array[Dictionary]:
	return effects_state.get_trails()


func get_particles() -> Array[Dictionary]:
	return effects_state.get_particles()


func has_visible_effects() -> bool:
	return effects_state.has_effects() or ghost_state.has_visible_effects()


func get_ghost_shot_ghosts() -> Array[Dictionary]:
	return ghost_state.get_ghosts()


func get_ghost_shot_blackhole_effects() -> Array[Dictionary]:
	return ghost_state.get_blackhole_effects()


func get_ghost_shot_trajectory_points() -> Array[Dictionary]:
	return ghost_state.get_trajectory_points()


func get_ghost_shot_last_visible_ball_pos() -> Vector2:
	return ghost_state.get_last_visible_ball_pos()


func has_ghost_shot_visible_aura() -> bool:
	return ghost_state.has_visible_aura()


func is_cutin_active() -> bool:
	return cutin_state.is_active()


func get_cutin_progress() -> float:
	return cutin_state.get_progress()


func get_cutin_phase() -> String:
	return cutin_state.get_phase()


func begin_drive_cutin(enraged: bool = false) -> void:
	drive_cutin_state.begin(SmasherDriveCutinState.DEFAULT_DURATION, enraged)


func is_drive_cutin_active() -> bool:
	return drive_cutin_state.is_active()


func is_drive_cutin_enraged() -> bool:
	return drive_cutin_state.is_enraged()


func get_drive_cutin_progress() -> float:
	return drive_cutin_state.get_progress()
