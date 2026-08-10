extends RefCounted

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")

const DEFAULT_NPC_MESSAGE := "필요한 물건이 있으면 테이블의 물건을 골라봐."
const DEFAULT_SHOPKEEPER_MESSAGE := "필요한 거 있어?\n좋은 걸로 골라왔지."


static func build_title_snapshot(title: String, subtitle: String, gold: int, scale: float) -> Dictionary:
	if scale <= 0.0:
		return {}
	var title_rect := _scale_rect(PlazaInteriorLayout.TITLE_RECT, scale)
	var gold_rect := _scale_rect(PlazaInteriorLayout.GOLD_RECT, scale)
	var exit_rect := _scale_rect(PlazaInteriorLayout.EXIT_RECT, scale)
	return {
		"title_rect": title_rect,
		"title_fill_color": Color(0.020, 0.016, 0.052, 0.78),
		"title_border_color": Color(0.78, 0.18, 1.0, 0.62),
		"title_border_width": maxf(1.0, 1.2 * scale),
		"title": "VR " + title,
		"title_position": title_rect.position + Vector2(18.0, 34.0) * scale,
		"title_font_size": int(27.0 * scale),
		"title_color": Color(0.94, 0.70, 1.0, 1.0),
		"subtitle": subtitle,
		"subtitle_position": title_rect.position + Vector2(20.0, 58.0) * scale,
		"subtitle_font_size": int(13.0 * scale),
		"subtitle_color": Color(0.88, 0.96, 1.0, 0.82),
		"gold_rect": gold_rect,
		"gold_fill_color": Color(0.014, 0.018, 0.022, 0.82),
		"gold_border_color": Color(1.0, 0.78, 0.24, 0.42),
		"gold_border_width": maxf(1.0, 1.0 * scale),
		"gold_text": "%dG" % gold,
		"gold_position": gold_rect.position + Vector2(24.0, 23.0) * scale,
		"gold_font_size": int(15.0 * scale),
		"gold_color": Color(1.0, 0.90, 0.52, 0.96),
		"exit_rect": exit_rect,
		"exit_fill_color": Color(0.040, 0.015, 0.070, 0.86),
		"exit_border_color": Color(0.88, 0.20, 1.0, 0.56),
		"exit_border_width": maxf(1.0, 1.0 * scale),
		"exit_text": "나가기",
		"exit_position": exit_rect.position + Vector2(20.0, 21.0) * scale,
		"exit_font_size": int(14.0 * scale),
		"exit_color": Color(0.96, 0.80, 1.0, 0.96),
	}


static func build_npc_snapshot(
	npc_name: String,
	last_message: String,
	accent: Color,
	texture_present: bool,
	texture_size: Vector2,
	scale: float
) -> Dictionary:
	if scale <= 0.0:
		return {}
	var npc_rect := _scale_rect(PlazaInteriorLayout.NPC_RECT, scale)
	var texture_rect := Rect2()
	if texture_present and texture_size.x > 0.0 and texture_size.y > 0.0:
		var fit_rect := Rect2(
			(PlazaInteriorLayout.NPC_RECT.position + Vector2(6.0, 10.0)) * scale,
			(PlazaInteriorLayout.NPC_RECT.size - Vector2(12.0, 72.0)) * scale
		)
		var fit_scale := minf(fit_rect.size.x / texture_size.x, fit_rect.size.y / texture_size.y)
		var draw_size := texture_size * fit_scale
		var draw_position := Vector2(fit_rect.get_center().x - draw_size.x * 0.5, fit_rect.end.y - draw_size.y)
		texture_rect = Rect2(draw_position, draw_size)
	var message := last_message if last_message != "" else DEFAULT_NPC_MESSAGE
	return {
		"rect": npc_rect,
		"fill_color": Color(0.006, 0.010, 0.020, 0.92),
		"accent_color": Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.14, 0.44),
		"border_color": Color(0.76, 0.20, 1.0, 0.52),
		"border_width": maxf(1.0, 1.4 * scale),
		"texture_rect": texture_rect,
		"show_placeholder": not texture_present,
		"placeholder": _build_npc_placeholder_snapshot(scale),
		"name": npc_name,
		"name_position": (PlazaInteriorLayout.NPC_RECT.position + Vector2(18.0, PlazaInteriorLayout.NPC_RECT.size.y - 40.0)) * scale,
		"name_font_size": int(15.0 * scale),
		"name_color": Color(0.94, 0.98, 1.0, 0.95),
		"message": message,
		"message_position": (PlazaInteriorLayout.NPC_RECT.position + Vector2(18.0, PlazaInteriorLayout.NPC_RECT.size.y - 18.0)) * scale,
		"message_font_size": int(12.0 * scale),
		"message_color": Color(1.0, 0.78, 0.95, 0.88),
	}


static func build_topview_npc_snapshot(texture_present: bool, texture_size: Vector2, scale: float) -> Dictionary:
	if not texture_present or texture_size.x <= 0.0 or texture_size.y <= 0.0 or scale <= 0.0:
		return {}
	var target_rect := _scale_rect(PlazaInteriorLayout.SHOP_TOPVIEW_NPC_RECT, scale)
	var fit_scale := minf(target_rect.size.x / texture_size.x, target_rect.size.y / texture_size.y)
	var draw_size := texture_size * fit_scale
	var draw_position := Vector2(target_rect.get_center().x - draw_size.x * 0.5, target_rect.end.y - draw_size.y)
	var draw_rect := Rect2(draw_position, draw_size)
	return {
		"shadow_rect": Rect2(draw_rect.position + Vector2(7.0, 8.0) * scale, draw_rect.size),
		"shadow_color": Color(0.0, 0.0, 0.0, 0.34),
		"draw_rect": draw_rect,
		"draw_color": Color(0.92, 0.86, 1.0, 0.88),
	}


static func build_speech_bubble_snapshot(last_message: String, scale: float) -> Dictionary:
	if scale <= 0.0:
		return {}
	var bubble_rect := Rect2(Vector2(286.0, 204.0) * scale, Vector2(244.0, 72.0) * scale)
	var tail := PackedVector2Array([
		Vector2(286.0, 242.0) * scale,
		Vector2(286.0, 262.0) * scale,
		Vector2(246.0, 258.0) * scale,
	])
	var message := last_message if last_message != "" else DEFAULT_SHOPKEEPER_MESSAGE
	var line_values := message.split("\n", false, 2)
	if line_values.size() == 1:
		line_values = str(line_values[0]).split("|", false, 2)
	var lines: Array[String] = []
	for index in range(mini(line_values.size(), 2)):
		lines.append(str(line_values[index]))
	return {
		"rect": bubble_rect,
		"fill_color": Color(0.018, 0.012, 0.036, 0.82),
		"border_color": Color(0.86, 0.18, 1.0, 0.58),
		"border_width": maxf(1.0, 1.1 * scale),
		"tail": tail,
		"tail_fill_color": Color(0.018, 0.012, 0.036, 0.82),
		"tail_line_color": Color(0.86, 0.18, 1.0, 0.44),
		"tail_line_width": maxf(1.0, 1.0 * scale),
		"lines": lines,
		"line_start_position": bubble_rect.position + Vector2(18.0, 27.0) * scale,
		"line_spacing": 24.0 * scale,
		"font_size": int(15.0 * scale),
		"text_color": Color(1.0, 0.72, 1.0, 0.96),
	}


static func build_object_panel_snapshot(
	object_spec: Dictionary,
	accent: Color,
	ap_current: int,
	last_message: String,
	scale: float
) -> Dictionary:
	if object_spec.is_empty() or scale <= 0.0:
		return {}
	var panel_rect := _scale_rect(PlazaInteriorLayout.PANEL_RECT, scale)
	return {
		"rect": panel_rect,
		"fill_color": Color(0.010, 0.014, 0.024, 0.96),
		"accent_color": Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.50),
		"border_color": Color(0.0, 0.90, 1.0, 0.48),
		"border_width": maxf(1.0, 1.2 * scale),
		"title": str(object_spec.get("label", "")),
		"title_position": panel_rect.position + Vector2(20.0, 32.0) * scale,
		"title_font_size": int(18.0 * scale),
		"title_color": Color(0.94, 0.98, 1.0, 0.96),
		"description": "선택한 오브젝트의 기능을 실행합니다.",
		"description_position": panel_rect.position + Vector2(20.0, 62.0) * scale,
		"description_font_size": int(12.0 * scale),
		"description_color": Color(0.78, 0.92, 0.96, 0.78),
		"ap_text": "AP %d" % ap_current,
		"ap_position": panel_rect.position + Vector2(20.0, 92.0) * scale,
		"ap_font_size": int(13.0 * scale),
		"ap_color": Color(0.72, 1.0, 0.88, 0.90),
		"message": last_message,
		"message_position": panel_rect.position + Vector2(20.0, 118.0) * scale,
		"message_font_size": int(12.0 * scale),
		"message_color": Color(1.0, 0.78, 0.58, 0.90),
		"confirm_button": {
			"rect": PlazaInteriorLayout.PANEL_CONFIRM_RECT,
			"label": "실행",
			"color": Color(0.0, 0.84, 1.0, 0.86),
		},
		"cancel_button": {
			"rect": PlazaInteriorLayout.PANEL_CANCEL_RECT,
			"label": "취소",
			"color": Color(1.0, 0.30, 0.90, 0.70),
		},
	}


static func _build_npc_placeholder_snapshot(scale: float) -> Dictionary:
	var center := PlazaInteriorLayout.NPC_RECT.position + Vector2(PlazaInteriorLayout.NPC_RECT.size.x * 0.5, 216.0)
	return {
		"head_center": center * scale,
		"head_radius": 42.0 * scale,
		"head_color": Color(0.64, 0.68, 0.76, 0.92),
		"body_rect": Rect2((center + Vector2(-46.0, 46.0)) * scale, Vector2(92.0, 150.0) * scale),
		"body_color": Color(0.22, 0.22, 0.30, 0.94),
		"left_arm_start": (center + Vector2(-34.0, 76.0)) * scale,
		"left_arm_end": (center + Vector2(-86.0, 126.0)) * scale,
		"right_arm_start": (center + Vector2(34.0, 76.0)) * scale,
		"right_arm_end": (center + Vector2(88.0, 120.0)) * scale,
		"arm_color": Color(0.78, 0.76, 0.86, 0.86),
		"arm_width": maxf(1.0, 8.0 * scale),
	}


static func _scale_rect(rect: Rect2, scale: float) -> Rect2:
	return Rect2(rect.position * scale, rect.size * scale)
