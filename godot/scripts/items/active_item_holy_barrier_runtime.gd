extends RefCounted

const HOLY_BARRIER_DURATION_FRAMES := 360.0
const HOLY_BARRIER_GLOW_ADVANCE_PER_FRAME := 0.1


func start_state(duration_multiplier: float = 1.0) -> Dictionary:
	var duration_frames: float = _scale_duration_frames(HOLY_BARRIER_DURATION_FRAMES, duration_multiplier)
	return {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"glow_phase": 0.0,
		"particle_accumulator_frames": 0.0,
		"clear_particles": true,
		"advance_idle_particles": false,
		"update_fade_particles": false,
		"fps_scale": 0.0,
	}


func clear_state(clear_particles: bool = true) -> Dictionary:
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"glow_phase": 0.0,
		"particle_accumulator_frames": 0.0,
		"clear_particles": clear_particles,
		"advance_idle_particles": false,
		"update_fade_particles": false,
		"fps_scale": 0.0,
	}


func update_state(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	glow_phase: float,
	particle_accumulator_frames: float,
	delta: float
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	if not active:
		return {
			"active": false,
			"timer_frames": 0.0,
			"initial_timer_frames": 0.0,
			"glow_phase": 0.0,
			"particle_accumulator_frames": 0.0,
			"clear_particles": false,
			"advance_idle_particles": false,
			"update_fade_particles": true,
			"fps_scale": fps_scale,
		}

	var next_timer: float = max(0.0, timer_frames - fps_scale)
	if next_timer <= 0.0:
		return {
			"active": false,
			"timer_frames": 0.0,
			"initial_timer_frames": 0.0,
			"glow_phase": glow_phase,
			"particle_accumulator_frames": particle_accumulator_frames,
			"clear_particles": true,
			"advance_idle_particles": false,
			"update_fade_particles": false,
			"fps_scale": fps_scale,
		}

	return {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": initial_timer_frames,
		"glow_phase": glow_phase + HOLY_BARRIER_GLOW_ADVANCE_PER_FRAME * fps_scale,
		"particle_accumulator_frames": particle_accumulator_frames,
		"clear_particles": false,
		"advance_idle_particles": true,
		"update_fade_particles": false,
		"fps_scale": fps_scale,
	}


func apply_update(
	target: Object,
	particles: Array[Dictionary],
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	glow_phase: float,
	particle_accumulator_frames: float,
	delta: float,
	state_applier: Object,
	particles_helper: Object
) -> void:
	var state: Dictionary = update_state(
		active,
		timer_frames,
		initial_timer_frames,
		glow_phase,
		particle_accumulator_frames,
		delta
	)
	state_applier.apply_holy_barrier_state(target, state)

	var fps_scale: float = float(state.get("fps_scale", delta * 60.0))
	if bool(state.get("advance_idle_particles", false)):
		target.set("holy_barrier_particle_accumulator_frames", particles_helper.advance_idle_particles(
			particles,
			float(state.get("particle_accumulator_frames", particle_accumulator_frames)),
			fps_scale,
			delta
		))
	elif bool(state.get("update_fade_particles", false)):
		particles_helper.update_particles(particles, fps_scale, delta)


func _scale_duration_frames(base_duration_frames: float, duration_multiplier: float) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return max(1.0, float(int(base_duration_frames * max(0.0, duration_multiplier))))
