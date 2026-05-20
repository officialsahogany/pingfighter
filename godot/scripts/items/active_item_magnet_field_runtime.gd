extends RefCounted

const MAGNET_FIELD_DURATION_FRAMES := 480.0
const MAGNET_FIELD_PHASE_ADVANCE_PER_FRAME := 0.08


func start_state(player_center: Vector2, duration_multiplier: float = 1.0) -> Dictionary:
	var duration_frames: float = _scale_duration_frames(MAGNET_FIELD_DURATION_FRAMES, duration_multiplier)
	return {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"phase": 0.0,
		"player_center": player_center,
		"particle_accumulator_frames": 0.0,
		"clear_particles": true,
		"fps_scale": 0.0,
	}


func update_state(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	player_center: Vector2,
	particle_accumulator_frames: float,
	owner_available: bool,
	delta: float
) -> Dictionary:
	if not active:
		return {
			"active": false,
			"timer_frames": 0.0,
			"initial_timer_frames": 0.0,
			"phase": phase,
			"player_center": player_center,
			"particle_accumulator_frames": 0.0,
			"clear_particles": false,
			"fps_scale": 0.0,
		}

	if not owner_available:
		return clear_state(player_center)

	var fps_scale: float = delta * 60.0
	var next_timer: float = max(0.0, timer_frames - fps_scale)
	if next_timer <= 0.0:
		return clear_state(player_center)

	return {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": initial_timer_frames,
		"phase": phase + MAGNET_FIELD_PHASE_ADVANCE_PER_FRAME * fps_scale,
		"player_center": player_center,
		"particle_accumulator_frames": particle_accumulator_frames,
		"clear_particles": false,
		"fps_scale": fps_scale,
	}


func apply_update(
	target: Object,
	particles: Array[Dictionary],
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	player_center: Vector2,
	particle_accumulator_frames: float,
	owner_available: bool,
	delta: float,
	state_applier: Object,
	particles_helper: Object
) -> void:
	var state: Dictionary = update_state(
		active,
		timer_frames,
		initial_timer_frames,
		phase,
		player_center,
		particle_accumulator_frames,
		owner_available,
		delta
	)
	state_applier.apply_magnet_field_state(target, state)
	if not bool(state.get("active", false)):
		return

	var fps_scale: float = float(state.get("fps_scale", delta * 60.0))
	target.set("magnet_field_particle_accumulator_frames", particles_helper.advance_particles(
		particles,
		_get_vector2(state, "player_center", player_center),
		float(state.get("particle_accumulator_frames", particle_accumulator_frames)),
		fps_scale
	))


func clear_state(player_center: Vector2, clear_particles: bool = true) -> Dictionary:
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"phase": 0.0,
		"player_center": player_center,
		"particle_accumulator_frames": 0.0,
		"clear_particles": clear_particles,
		"fps_scale": 0.0,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _scale_duration_frames(base_duration_frames: float, duration_multiplier: float) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return max(1.0, float(int(base_duration_frames * max(0.0, duration_multiplier))))
