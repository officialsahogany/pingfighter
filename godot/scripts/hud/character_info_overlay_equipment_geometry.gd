extends RefCounted

const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func slot_positions(content_rect: Rect2, slot_size: float) -> Dictionary:
	var body_x: float = content_rect.position.x + content_rect.size.x * 0.45
	var right_column_x: float = content_rect.end.x - slot_size * 0.54
	var side_span: float = min(content_rect.size.x * 0.31, slot_size * 2.55)
	var head_y: float = content_rect.position.y + content_rect.size.y * 0.13
	var shoulder_y: float = content_rect.position.y + content_rect.size.y * 0.35
	# 상의/벨트 share the body column — keep enough vertical air between them
	# for the 상의 label (slot bottom + ~16px) to clear the 벨트 box.
	var chest_y: float = content_rect.position.y + content_rect.size.y * 0.38
	var waist_y: float = content_rect.position.y + content_rect.size.y * 0.615
	var hip_y: float = content_rect.position.y + content_rect.size.y * 0.66
	var foot_y: float = content_rect.position.y + content_rect.size.y * 0.88
	var accessory_gap: float = min(slot_size * 1.58, content_rect.size.y * 0.21)
	return {
		"head": Vector2(body_x, head_y),
		"left_arm": Vector2(body_x - side_span, shoulder_y),
		"right_arm": Vector2(body_x + side_span, shoulder_y),
		"top": Vector2(body_x, chest_y),
		"belt": Vector2(body_x, waist_y),
		"belt2": Vector2(body_x - side_span * 0.95, hip_y),
		"knee": Vector2(body_x - side_span * 0.28, content_rect.position.y + content_rect.size.y * 0.78),
		"shoes": Vector2(body_x + side_span * 0.58, foot_y),
		"accessory1": Vector2(right_column_x, head_y),
		"accessory2": Vector2(right_column_x, head_y + accessory_gap),
		"accessory3": Vector2(right_column_x, head_y + accessory_gap * 2.0),
		"accessory4": Vector2(right_column_x, head_y + accessory_gap * 3.0),
	}


static func refresh_slot_layout(content_rect: Rect2, slot_size: float, keys: Array[String], rect_cache: Dictionary, rect_list_cache: Array[Rect2], icon_rect_cache: Array[Rect2], fallback_rect_cache: Array[Rect2], placeholder_rect_cache: Array[Rect2], locked_line_a_start_cache: Array[Vector2], locked_line_a_end_cache: Array[Vector2], locked_line_b_start_cache: Array[Vector2], locked_line_b_end_cache: Array[Vector2], center_x_cache: Array[float], center_y_cache: Array[float], label_y_cache: Array[float]) -> void:
	var slot_count: int = keys.size()
	if not CharacterInfoOverlayValueUtils.arrays_match_size([rect_list_cache, icon_rect_cache, fallback_rect_cache, placeholder_rect_cache, locked_line_a_start_cache, locked_line_a_end_cache, locked_line_b_start_cache, locked_line_b_end_cache, center_x_cache, center_y_cache, label_y_cache], slot_count):
		rect_list_cache.resize(slot_count)
		CharacterInfoOverlayValueUtils.resize_arrays([icon_rect_cache, fallback_rect_cache, placeholder_rect_cache, locked_line_a_start_cache, locked_line_a_end_cache, locked_line_b_start_cache, locked_line_b_end_cache, center_x_cache, center_y_cache, label_y_cache], slot_count)
	rect_cache.clear()
	var positions: Dictionary = slot_positions(content_rect, slot_size)
	var fallback_center := content_rect.get_center()
	var slot_extent := Vector2(slot_size, slot_size)
	var label_size: int = 10 if slot_size >= 40.0 else 8
	for i in range(slot_count):
		var key: String = keys[i]
		var center_value: Variant = positions.get(key, fallback_center)
		var slot_center: Vector2 = center_value if center_value is Vector2 else fallback_center
		var slot_rect := Rect2(slot_center - slot_extent * 0.5, slot_extent)
		var slot_x: float = slot_rect.position.x
		var slot_y: float = slot_rect.position.y
		var slot_w: float = slot_rect.size.x
		var slot_h: float = slot_rect.size.y
		rect_cache[key] = slot_rect
		rect_list_cache[i] = slot_rect
		icon_rect_cache[i] = Rect2(slot_x + 5.0, slot_y + 5.0, slot_w - 10.0, slot_h - 10.0)
		fallback_rect_cache[i] = Rect2(slot_x + 8.0, slot_y + 8.0, slot_w - 16.0, slot_h - 16.0)
		placeholder_rect_cache[i] = Rect2(slot_x + 7.0, slot_y + 7.0, slot_w - 14.0, slot_h - 14.0)
		locked_line_a_start_cache[i] = Vector2(slot_x + 9.0, slot_y + 9.0)
		locked_line_a_end_cache[i] = Vector2(slot_x + slot_w - 9.0, slot_y + slot_h - 9.0)
		locked_line_b_start_cache[i] = Vector2(slot_x + slot_w - 9.0, slot_y + 9.0)
		locked_line_b_end_cache[i] = Vector2(slot_x + 9.0, slot_y + slot_h - 9.0)
		center_x_cache[i] = slot_x + slot_w * 0.5
		center_y_cache[i] = slot_y + slot_h * 0.5
		label_y_cache[i] = min(slot_y + slot_h + float(label_size) + 6.0, content_rect.end.y - 2.0)


static func update_overlay_slot_layout(target: Object, content_rect: Rect2, slot_size: float, cached_content: Rect2, cached_slot_size: float, ensure_metadata_callable: Callable, keys: Array[String], rect_cache: Dictionary, rect_list_cache: Array[Rect2], icon_rect_cache: Array[Rect2], fallback_rect_cache: Array[Rect2], placeholder_rect_cache: Array[Rect2], locked_line_a_start_cache: Array[Vector2], locked_line_a_end_cache: Array[Vector2], locked_line_b_start_cache: Array[Vector2], locked_line_b_end_cache: Array[Vector2], center_x_cache: Array[float], center_y_cache: Array[float], label_y_cache: Array[float]) -> void:
	if not rect_cache.is_empty() and cached_content.is_equal_approx(content_rect) and is_equal_approx(cached_slot_size, slot_size):
		return
	ensure_metadata_callable.call()
	target.set("_equipment_layout_content_rect", content_rect)
	target.set("_equipment_layout_slot_size", slot_size)
	refresh_slot_layout(content_rect, slot_size, keys, rect_cache, rect_list_cache, icon_rect_cache, fallback_rect_cache, placeholder_rect_cache, locked_line_a_start_cache, locked_line_a_end_cache, locked_line_b_start_cache, locked_line_b_end_cache, center_x_cache, center_y_cache, label_y_cache)


static func update_overlay_silhouette(target: Object, content_rect: Rect2, slot_size: float, cached_content: Rect2, cached_slot_size: float, torso_poly: PackedVector2Array) -> void:
	if torso_poly.size() > 0 and cached_content.is_equal_approx(content_rect) and is_equal_approx(cached_slot_size, slot_size):
		return
	update_silhouette(target, content_rect, slot_size)


static func update_silhouette(target: Object, content_rect: Rect2, slot_size: float) -> void:
	if target == null:
		return
	target.set("_equipment_silhouette_content_rect", content_rect)
	target.set("_equipment_silhouette_slot_size", slot_size)
	var body_x: float = content_rect.position.x + content_rect.size.x * 0.45
	target.set("_equipment_silhouette_body_x", body_x)
	var top_y: float = content_rect.position.y + content_rect.size.y * 0.09
	var bottom_y: float = content_rect.end.y - slot_size * 0.30
	var height: float = max(1.0, bottom_y - top_y)
	var head_center := Vector2(body_x, top_y + height * 0.08)
	target.set("_equipment_silhouette_head_center", head_center)
	target.set("_equipment_silhouette_neck_rect", Rect2(head_center + Vector2(-slot_size * 0.16, slot_size * 0.42), Vector2(slot_size * 0.32, slot_size * 0.36)))
	var shoulder_y: float = top_y + height * 0.23
	var waist_y: float = top_y + height * 0.58
	var hip_y: float = top_y + height * 0.70
	var shoulder_w: float = min(content_rect.size.x * 0.43, slot_size * 3.75)
	var waist_w: float = min(content_rect.size.x * 0.25, slot_size * 2.25)
	var hip_w: float = min(content_rect.size.x * 0.31, slot_size * 2.70)
	target.set("_equipment_silhouette_shoulder_y", shoulder_y)
	target.set("_equipment_silhouette_waist_y", waist_y)
	target.set("_equipment_silhouette_hip_y", hip_y)
	target.set("_equipment_silhouette_waist_w", waist_w)
	target.set("_equipment_silhouette_torso_poly", PackedVector2Array([
		Vector2(body_x - shoulder_w * 0.5, shoulder_y),
		Vector2(body_x + shoulder_w * 0.5, shoulder_y),
		Vector2(body_x + waist_w * 0.5, waist_y),
		Vector2(body_x + hip_w * 0.5, hip_y),
		Vector2(body_x - hip_w * 0.5, hip_y),
		Vector2(body_x - waist_w * 0.5, waist_y),
	]))
	target.set("_equipment_silhouette_left_arm_poly", PackedVector2Array([
		Vector2(body_x - shoulder_w * 0.52, shoulder_y + slot_size * 0.16),
		Vector2(body_x - shoulder_w * 0.92, shoulder_y + slot_size * 0.56),
		Vector2(body_x - shoulder_w * 0.92, shoulder_y + slot_size * 1.02),
		Vector2(body_x - shoulder_w * 0.52, shoulder_y + slot_size * 0.70),
	]))
	target.set("_equipment_silhouette_right_arm_poly", PackedVector2Array([
		Vector2(body_x + shoulder_w * 0.52, shoulder_y + slot_size * 0.16),
		Vector2(body_x + shoulder_w * 0.92, shoulder_y + slot_size * 0.56),
		Vector2(body_x + shoulder_w * 0.92, shoulder_y + slot_size * 1.02),
		Vector2(body_x + shoulder_w * 0.52, shoulder_y + slot_size * 0.70),
	]))
	target.set("_equipment_silhouette_left_leg_poly", PackedVector2Array([
		Vector2(body_x - hip_w * 0.30, hip_y),
		Vector2(body_x - hip_w * 0.02, hip_y),
		Vector2(body_x - hip_w * 0.10, bottom_y - slot_size * 0.18),
		Vector2(body_x - hip_w * 0.52, bottom_y - slot_size * 0.08),
	]))
	target.set("_equipment_silhouette_right_leg_poly", PackedVector2Array([
		Vector2(body_x + hip_w * 0.02, hip_y),
		Vector2(body_x + hip_w * 0.30, hip_y),
		Vector2(body_x + hip_w * 0.52, bottom_y - slot_size * 0.08),
		Vector2(body_x + hip_w * 0.10, bottom_y - slot_size * 0.18),
	]))


static func draw_silhouette(canvas: CanvasItem, slot_size: float, show_detail: bool, head_center: Vector2, neck_rect: Rect2, torso_poly: PackedVector2Array, body_x: float, shoulder_y: float, waist_y: float, hip_y: float, waist_w: float, left_arm_poly: PackedVector2Array, right_arm_poly: PackedVector2Array, left_leg_poly: PackedVector2Array, right_leg_poly: PackedVector2Array, head_color: Color, neck_color: Color, base_color: Color, deep_detail_color: Color, base_detail_color: Color, line_color: Color, ring_segments: int, arc_segments: int) -> void:
	if canvas == null:
		return
	canvas.draw_circle(head_center, slot_size * 0.43, head_color)
	canvas.draw_rect(neck_rect, neck_color)
	canvas.draw_colored_polygon(torso_poly, base_color)
	if show_detail:
		canvas.draw_colored_polygon(left_arm_poly, deep_detail_color)
		canvas.draw_colored_polygon(right_arm_poly, deep_detail_color)
		canvas.draw_colored_polygon(left_leg_poly, base_detail_color)
		canvas.draw_colored_polygon(right_leg_poly, base_detail_color)
		canvas.draw_arc(head_center, slot_size * 0.43, 0.0, TAU, ring_segments, line_color, 1.0)
		canvas.draw_line(Vector2(body_x, shoulder_y + slot_size * 0.08), Vector2(body_x, hip_y + slot_size * 0.14), line_color, 1.0)
		canvas.draw_arc(Vector2(body_x, shoulder_y + slot_size * 0.64), slot_size * 0.72, PI * 0.10, PI * 0.90, arc_segments, line_color, 1.0)
		canvas.draw_arc(Vector2(body_x, shoulder_y + slot_size * 0.64), slot_size * 0.72, PI * 1.10, PI * 1.90, arc_segments, line_color, 1.0)
		canvas.draw_line(Vector2(body_x - waist_w * 0.45, waist_y), Vector2(body_x + waist_w * 0.45, waist_y), line_color, 1.0)
