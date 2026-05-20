extends RefCounted

const SmasherComboParticleState := preload("res://scripts/characters/smasher_combo_particle_state.gd")

const SMASHER_COMBO_EFFECT_DURATION_FRAMES := 60.0

var effect_active := false
var effect_timer_frames := 0.0
var effect_pos := Vector2.ZERO
var effect_count := 0
var particle_state: Object = SmasherComboParticleState.new()


func reset() -> void:
	effect_active = false
	effect_timer_frames = 0.0
	effect_count = 0
	effect_pos = Vector2.ZERO
	particle_state.reset()


func update(fps_scale: float) -> void:
	if effect_timer_frames > 0.0:
		effect_timer_frames = max(0.0, effect_timer_frames - fps_scale)
		effect_active = effect_timer_frames > 0.0
	else:
		effect_active = false
	particle_state.update(fps_scale)


func start(_pos: Vector2, _new_combo_count: int, _combo_color: Color) -> void:
	reset()


func is_active() -> bool:
	return effect_active


func has_particles() -> bool:
	return particle_state.has_particles()


func get_timer_frames() -> float:
	return effect_timer_frames


func get_pos() -> Vector2:
	return effect_pos


func get_count() -> int:
	return effect_count


func get_particles() -> Array[Dictionary]:
	return particle_state.get_particles()


func get_effect_duration_frames() -> float:
	return SMASHER_COMBO_EFFECT_DURATION_FRAMES
