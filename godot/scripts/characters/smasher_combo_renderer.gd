extends RefCounted

const SmasherComboBurstRenderer := preload("res://scripts/characters/smasher_combo_burst_renderer.gd")
const SmasherComboGaugeRenderer := preload("res://scripts/characters/smasher_combo_gauge_renderer.gd")
const SmasherComboParticleRenderer := preload("res://scripts/characters/smasher_combo_particle_renderer.gd")

var burst_renderer: Object = SmasherComboBurstRenderer.new()
var gauge_renderer: Object = SmasherComboGaugeRenderer.new()
var particle_renderer: Object = SmasherComboParticleRenderer.new()


func draw_effect(canvas: Node2D, combo_state, shake_offset: Vector2) -> void:
	if canvas == null or combo_state == null:
		return

	var combo_particles: Array[Dictionary] = combo_state.get_particles()
	var effect_count: int = combo_state.get_effect_count()
	var effect_timer_frames: float = combo_state.get_effect_timer_frames()

	particle_renderer.draw(canvas, combo_particles, effect_count, shake_offset)
	burst_renderer.draw(canvas, combo_state, shake_offset, effect_count, effect_timer_frames)


func draw_hud(canvas: Node2D, combo_state, anchor_rect: Rect2 = Rect2(), ui_scale: float = 1.0) -> void:
	gauge_renderer.draw(canvas, combo_state, anchor_rect, ui_scale)
