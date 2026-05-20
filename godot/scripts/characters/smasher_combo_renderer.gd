extends RefCounted

const SmasherComboGaugeRenderer := preload("res://scripts/characters/smasher_combo_gauge_renderer.gd")

var gauge_renderer: Object = SmasherComboGaugeRenderer.new()


func draw_effect(_canvas: Node2D, _combo_state, _shake_offset: Vector2) -> void:
	return


func draw_hud(canvas: Node2D, combo_state, anchor_rect: Rect2 = Rect2(), ui_scale: float = 1.0) -> void:
	gauge_renderer.draw(canvas, combo_state, anchor_rect, ui_scale)
