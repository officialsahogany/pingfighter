extends RefCounted

const ActiveItemHudPanelRenderer := preload("res://scripts/hud/active_item_hud_panel_renderer.gd")
const ActiveItemHudSlotContextBuilder := preload("res://scripts/hud/active_item_hud_slot_context_builder.gd")
const ActiveItemHudSlotRenderer := preload("res://scripts/hud/active_item_hud_slot_renderer.gd")

var panel_renderer: Object = ActiveItemHudPanelRenderer.new()
var slot_context_builder: Object = ActiveItemHudSlotContextBuilder.new()
var slot_renderer: Object = ActiveItemHudSlotRenderer.new()


func draw_slots(
	canvas: Node2D,
	layout: Dictionary,
	active_item_slots: Array,
	round_start_time_msec: int,
	hud_state,
	visuals,
	registry: Object = null,
	game_offset: Vector2 = Vector2.ZERO,
	render_scale: Vector2 = Vector2.ONE
) -> void:
	if canvas == null or not bool(layout.get("visible", false)):
		return

	var scale_factor: float = float(layout["scale_factor"])
	var slot_rects: Array = layout["slot_rects"]
	var slot_overflow_flags: Array = layout["slot_overflow_flags"]
	var actual_item_count: int = int(layout["actual_item_count"])
	var selected_item_index: int = slot_context_builder.get_selected_index(hud_state)
	var current_time: int = Time.get_ticks_msec()
	var time_since_round_start: int = slot_context_builder.get_time_since_round_start(current_time, round_start_time_msec)
	var main_box_rect: Rect2 = layout["main_box_rect"]
	var runtime_perk_state: Object = registry.get_instance("runtime_perk_state") if registry != null and registry.has_method("get_instance") else null
	var item_data_by_slot: Array[Dictionary] = []
	var slot_status_by_slot: Array[Dictionary] = []
	var has_ready_slot := false
	for i in range(slot_rects.size()):
		var item_data: Dictionary = slot_context_builder.get_item_data(active_item_slots, i, actual_item_count)
		var slot_status: Dictionary = slot_context_builder.get_slot_status(
			hud_state,
			i,
			item_data,
			current_time,
			time_since_round_start,
			registry,
			runtime_perk_state
		)
		item_data_by_slot.append(item_data)
		slot_status_by_slot.append(slot_status)
		has_ready_slot = has_ready_slot or _should_draw_ready_glow(item_data, slot_status)

	var cooldown_frame_rect: Rect2 = _get_cooldown_frame_rect(layout)
	if has_ready_slot:
		_draw_ready_group_glow(canvas, cooldown_frame_rect, scale_factor)
	panel_renderer.draw_slot_panel(
		canvas,
		main_box_rect,
		Color(18.0 / 255.0, 20.0 / 255.0, 32.0 / 255.0, 200.0 / 255.0),
		Color(120.0 / 255.0, 150.0 / 255.0, 190.0 / 255.0)
	)
	if bool(layout.get("overflow_visible", false)):
		var overflow_box_rect: Rect2 = layout["overflow_box_rect"]
		panel_renderer.draw_slot_panel(
			canvas,
			overflow_box_rect,
			Color(18.0 / 255.0, 20.0 / 255.0, 32.0 / 255.0, 120.0 / 255.0),
			Color(100.0 / 255.0, 125.0 / 255.0, 160.0 / 255.0, 130.0 / 255.0)
		)

	var cooldown_group_remaining_ratio := 0.0
	for i in range(slot_rects.size()):
		var slot_rect: Rect2 = slot_rects[i]
		var item_data: Dictionary = item_data_by_slot[i]
		var slot_status: Dictionary = slot_status_by_slot[i]
		var remaining_ratio: float = slot_renderer.draw_slot(
			canvas,
			slot_rect,
			item_data,
			scale_factor,
			visuals,
			slot_status,
			i == selected_item_index,
			bool(slot_overflow_flags[i]),
			str(i + 1)
		)
		cooldown_group_remaining_ratio = max(cooldown_group_remaining_ratio, remaining_ratio)

	if cooldown_group_remaining_ratio > 0.0:
		slot_renderer.draw_group_cooldown_frame(canvas, cooldown_frame_rect, cooldown_group_remaining_ratio, scale_factor)

	_draw_slot_flights(
		canvas,
		hud_state,
		slot_rects,
		main_box_rect,
		scale_factor,
		visuals,
		game_offset,
		render_scale,
		current_time
	)


func _get_cooldown_frame_rect(layout: Dictionary) -> Rect2:
	var frame_rect: Rect2 = _get_rect(layout.get("main_box_rect", Rect2()))
	if bool(layout.get("overflow_visible", false)):
		var overflow_rect: Rect2 = _get_rect(layout.get("overflow_box_rect", Rect2()))
		if overflow_rect.size.x > 0.0 and overflow_rect.size.y > 0.0:
			frame_rect = frame_rect.merge(overflow_rect)
	return frame_rect


func _should_draw_ready_glow(item_data: Dictionary, slot_status: Dictionary) -> bool:
	return (
		ActiveItemHudSlotRenderer.is_slot_ready(item_data, slot_status)
		and float(slot_status.get("alchemy_notice_ratio", 0.0)) <= 0.0
		and not bool(slot_status.get("flight_incoming", false))
	)


func _draw_slot_flights(
	canvas: Node2D,
	hud_state,
	slot_rects: Array,
	main_box_rect: Rect2,
	scale_factor: float,
	visuals,
	game_offset: Vector2,
	render_scale: Vector2,
	now_msec: int
) -> void:
	if hud_state == null or not hud_state.has_method("get_active_slot_flights"):
		return
	if render_scale.x <= 0.0 or render_scale.y <= 0.0:
		return
	var flights: Array = hud_state.get_active_slot_flights(now_msec)
	if flights.is_empty():
		return
	var icon_renderer: Object = slot_renderer.icon_renderer if slot_renderer != null else null
	var pulse: float = 0.5 + 0.5 * sin(float(now_msec) * 0.02)
	for flight_value in flights:
		if flight_value is Dictionary:
			_draw_single_slot_flight(
				canvas,
				flight_value,
				slot_rects,
				main_box_rect,
				scale_factor,
				visuals,
				game_offset,
				render_scale,
				icon_renderer,
				pulse
			)


func _draw_single_slot_flight(
	canvas: Node2D,
	flight: Dictionary,
	slot_rects: Array,
	main_box_rect: Rect2,
	scale_factor: float,
	visuals,
	game_offset: Vector2,
	render_scale: Vector2,
	icon_renderer: Object,
	pulse: float
) -> void:
	var slot_index: int = int(flight.get("slot_index", -1))
	var target: Vector2
	var slot_size: float
	if slot_index >= 0 and slot_index < slot_rects.size() and slot_rects[slot_index] is Rect2:
		var slot_rect: Rect2 = slot_rects[slot_index]
		target = slot_rect.get_center()
		slot_size = min(slot_rect.size.x, slot_rect.size.y)
	else:
		target = main_box_rect.get_center()
		slot_size = max(8.0, min(main_box_rect.size.x, main_box_rect.size.y) - 8.0 * scale_factor)

	var field_pos: Vector2 = _get_vector2(flight.get("source_field_pos", Vector2.ZERO))
	var source: Vector2 = game_offset + Vector2(field_pos.x * render_scale.x, field_pos.y * render_scale.y)
	if source == target:
		source = target - Vector2(0.0, slot_size * 3.0)
	var progress: float = clamp(float(flight.get("progress", 0.0)), 0.0, 1.0)
	var color: Color = _get_color(flight.get("color", Color(0.42, 0.82, 1.0)))
	var eased: float = _ease_out_cubic(progress)
	var arc: float = 62.0 * scale_factor
	var pos: Vector2 = _flight_bezier(source, target, eased, arc)

	_draw_flight_takeoff(canvas, source, color, progress, scale_factor)
	_draw_flight_trail(canvas, source, target, arc, eased, color, progress, scale_factor)

	var size: float = lerpf(slot_size * 1.55, slot_size, eased)
	var half: Vector2 = Vector2(size, size) * 0.5
	canvas.draw_circle(pos, size * 0.74, Color(color.r, color.g, color.b, 0.30 * (1.0 - progress * 0.4)))
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		icon_renderer.draw_icon(canvas, Rect2(pos - half, Vector2(size, size)), _get_dict(flight.get("item_data", {})), scale_factor, visuals)
	canvas.draw_arc(pos, size * 0.60, 0.0, TAU, 22, Color(1.0, 1.0, 1.0, 0.42 * (1.0 - progress)), max(1.0, 1.4 * scale_factor))

	_draw_flight_arrival(canvas, target, color, progress, pulse, slot_size)


func _draw_flight_takeoff(canvas: Node2D, source: Vector2, color: Color, progress: float, scale_factor: float) -> void:
	var alpha: float = clamp(1.0 - progress * 3.0, 0.0, 1.0)
	if alpha <= 0.0:
		return
	for ring in range(2):
		var ring_t: float = clamp(progress * 3.0 - float(ring) * 0.2, 0.0, 1.0)
		if ring_t <= 0.0:
			continue
		var radius: float = lerpf(5.0, 26.0 + float(ring) * 8.0, _ease_out_cubic(ring_t)) * scale_factor
		canvas.draw_arc(source, radius, 0.0, TAU, 22, Color(color.r, color.g, color.b, alpha * (0.30 - float(ring) * 0.09)), max(1.0, 1.6 * scale_factor))


func _draw_flight_trail(canvas: Node2D, source: Vector2, target: Vector2, arc: float, eased: float, color: Color, progress: float, scale_factor: float) -> void:
	for step in range(1, 5):
		var t: float = clamp(eased - float(step) * 0.06, 0.0, 1.0)
		if t <= 0.0:
			continue
		var trail_pos: Vector2 = _flight_bezier(source, target, t, arc)
		var fade: float = (1.0 - float(step) / 5.0) * (1.0 - progress * 0.3)
		canvas.draw_circle(trail_pos, max(1.0, (3.0 - float(step) * 0.4) * scale_factor), Color(color.r, color.g, color.b, 0.34 * fade))


func _draw_flight_arrival(canvas: Node2D, target: Vector2, color: Color, progress: float, pulse: float, slot_size: float) -> void:
	var arrival: float = clamp((progress - 0.62) / 0.38, 0.0, 1.0)
	if arrival <= 0.0:
		return
	var settle: float = _ease_out_cubic(arrival)
	for ring in range(2):
		var local_t: float = clamp(arrival - float(ring) * 0.15, 0.0, 1.0)
		if local_t <= 0.0:
			continue
		var radius: float = lerpf(slot_size * 1.15, slot_size * 0.34, _ease_out_cubic(local_t))
		canvas.draw_arc(target, radius, 0.0, TAU, 24, Color(color.r, color.g, color.b, (1.0 - local_t) * 0.40), 2.2)
	canvas.draw_circle(target, max(2.0, slot_size * 0.22 * settle) * (1.0 + 0.05 * pulse), Color(1.0, 1.0, 1.0, 0.48 * settle))


func _flight_bezier(source: Vector2, target: Vector2, t: float, arc: float) -> Vector2:
	var control: Vector2 = (source + target) * 0.5 + Vector2(0.0, -arc)
	var inv: float = 1.0 - t
	return source * inv * inv + control * 2.0 * inv * t + target * t * t


func _ease_out_cubic(t: float) -> float:
	var clamped: float = clamp(t, 0.0, 1.0)
	var inv: float = 1.0 - clamped
	return 1.0 - inv * inv * inv


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color(0.42, 0.82, 1.0)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _draw_ready_group_glow(canvas: Node2D, frame_rect: Rect2, scale_factor: float) -> void:
	if canvas == null or frame_rect.size.x <= 0.0 or frame_rect.size.y <= 0.0:
		return
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * ActiveItemHudSlotRenderer.READY_GLOW_TICK_SCALE)
	var outer_rect: Rect2 = frame_rect.grow((3.0 + 2.0 * pulse) * scale_factor)
	var inner_rect: Rect2 = frame_rect.grow(1.0 * scale_factor)
	canvas.draw_rect(outer_rect, Color(0.20, 0.76, 1.0, 0.08 + 0.08 * pulse))
	canvas.draw_rect(outer_rect, Color(0.42, 0.94, 1.0, 0.28 + 0.12 * pulse), false, max(1.0, 2.0 * scale_factor))
	canvas.draw_rect(inner_rect, Color(0.62, 1.0, 1.0, 0.14 + 0.06 * pulse), false, max(1.0, scale_factor))


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()
