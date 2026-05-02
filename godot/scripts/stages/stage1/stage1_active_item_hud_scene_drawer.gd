extends RefCounted


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var active_item_slots: Array = _get_array(context.get("active_item_slots", []))
	var layout_builder: Object = registry.get_instance("active_item_hud_layout")
	var layout: Dictionary = {"visible": false}
	if layout_builder != null:
		layout = layout_builder.build_layout(
			view_size,
			game_offset,
			game_size,
			float(context.get("width", 760.0)),
			active_item_slots.size()
		)

	var renderer: Object = registry.get_instance("active_item_hud_renderer")
	if renderer == null:
		return
	var round_state: Object = registry.get_instance("round_flow_state")
	renderer.draw_slots(
		canvas,
		layout,
		active_item_slots,
		round_state.get_round_start_time_msec() if round_state != null else 0,
		registry.get_instance("active_item_hud_state"),
		registry.get_instance("active_item_hud_visuals")
	)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
