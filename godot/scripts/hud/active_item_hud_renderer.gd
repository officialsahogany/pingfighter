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
	registry: Object = null
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
	var cooldown_frame_rect: Rect2 = _get_cooldown_frame_rect(layout)
	for i in range(slot_rects.size()):
		var slot_rect: Rect2 = slot_rects[i]
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


func _get_cooldown_frame_rect(layout: Dictionary) -> Rect2:
	var frame_rect: Rect2 = _get_rect(layout.get("main_box_rect", Rect2()))
	if bool(layout.get("overflow_visible", false)):
		var overflow_rect: Rect2 = _get_rect(layout.get("overflow_box_rect", Rect2()))
		if overflow_rect.size.x > 0.0 and overflow_rect.size.y > 0.0:
			frame_rect = frame_rect.merge(overflow_rect)
	return frame_rect


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()
