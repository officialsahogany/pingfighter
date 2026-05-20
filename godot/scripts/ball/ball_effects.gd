extends RefCounted

const BallGhostTrailState := preload("res://scripts/ball/ball_ghost_trail_state.gd")
const BallIntensityEffectState := preload("res://scripts/ball/ball_intensity_effect_state.gd")

var ghost_trail_state: Object = BallGhostTrailState.new()
var intensity_effect_state: Object = BallIntensityEffectState.new()
var hit_pulse_event_id := 0
var hit_pulse_event: Dictionary = {}


func clear_all() -> void:
	ghost_trail_state.clear()
	clear_intensity()
	hit_pulse_event_id = 0
	hit_pulse_event = {}


func clear_intensity() -> void:
	intensity_effect_state.clear()


func update_ghost_trail(ball_center: Vector2, ball_size: float, fps_scale: float) -> void:
	ghost_trail_state.update(ball_center, ball_size, fps_scale)


func update_intensity_particles(
	ball_center: Vector2,
	ball_velocity: Vector2,
	fps_scale: float,
	intensity: float,
	colors: Array[Color],
	effect_lod_scale: float = 1.0
) -> void:
	intensity_effect_state.update(ball_center, ball_velocity, fps_scale, intensity, colors, effect_lod_scale)


func get_ghost_trail() -> Array[Dictionary]:
	return ghost_trail_state.get_trail()


func get_intensity_particles() -> Array[Dictionary]:
	return intensity_effect_state.get_particles()


func get_intensity_trail() -> Array[Dictionary]:
	return intensity_effect_state.get_trail()


func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float = 0.0, kind: String = "hit") -> void:
	hit_pulse_event_id += 1
	hit_pulse_event = {
		"id": hit_pulse_event_id,
		"pos": pos,
		"velocity": velocity,
		"intensity": clamp(intensity, 0.0, 1.0),
		"kind": kind,
	}


func get_hit_pulse_event() -> Dictionary:
	return hit_pulse_event.duplicate()
