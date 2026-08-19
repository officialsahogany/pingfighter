extends Control

var _flow: Object = null


func configure(flow: Object) -> void:
	_flow = flow
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4096
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.012, 0.02, 1.0), true)
	if _flow != null and _flow.has_method("draw"):
		_flow.draw(self)
