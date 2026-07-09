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
	var active_item_slot_capacity: int = _get_active_item_slot_capacity(registry, active_item_slots.size())
	var layout_builder: Object = _get_module(registry, "active_item_hud_layout")
	var layout: Dictionary = {"visible": false}
	if layout_builder != null:
		layout = layout_builder.build_layout(
			view_size,
			game_offset,
			game_size,
			float(context.get("width", 760.0)),
			active_item_slots.size(),
			active_item_slot_capacity
		)

	var renderer: Object = _get_module(registry, "active_item_hud_renderer")
	if renderer == null:
		return
	var round_state: Object = _get_module(registry, "round_flow_state")
	# Playfield -> screen scale for the acquisition flight source (field items live in
	# 0..width / 0..height playfield space; the HUD canvas is screen space with
	# game_offset baked into the slot rects).
	var field_width: float = max(1.0, float(context.get("width", 760.0)))
	var field_height: float = max(1.0, float(context.get("height", 750.0)))
	var render_scale := Vector2(game_size.x / field_width, game_size.y / field_height)
	renderer.draw_slots(
		canvas,
		layout,
		active_item_slots,
		round_state.get_round_start_time_msec() if round_state != null else 0,
		_get_module(registry, "active_item_hud_state"),
		_get_module(registry, "active_item_hud_visuals"),
		registry,
		game_offset,
		render_scale
	)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_active_item_slot_capacity(registry: Object, minimum_capacity: int = 0) -> int:
	var capacity: int = max(3, minimum_capacity)
	if registry == null:
		return capacity
	var runtime_perk_state: Object = _get_module(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(runtime_perk_state.get_active_item_slot_capacity(3)))
	var mythic_item_runtime: Object = _get_module(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(mythic_item_runtime.get_active_item_slot_capacity(capacity)))
	return capacity


func _get_module(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
		return null
	if registry.has_method("get_instance"):
		var instance: Variant = registry.get_instance(key)
		if typeof(instance) == TYPE_OBJECT and is_instance_valid(instance):
			return instance as Object
	return null
