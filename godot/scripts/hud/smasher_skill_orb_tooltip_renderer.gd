extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")

const TOOLTIP_WIDTH := 300.0
const HEADER_HEIGHT := 36.0
const EFFECT_PREVIEW_HEIGHT := 100.0
const PADDING := 12.0
const CONTROL_ROW_HEIGHT := 20.0

const CONTROL_ROWS := {
	"plasma": [
		[["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "홀드 후 손 떼면 발동"]],
	],
	"recovery": [
		[["text", "대쉬후딜 중"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"cleanse": [
		[["text", "상태이상 중"], ["key", "W"], ["accent", "발동"]],
	],
	"shield_kiting": [
		[["mouse_left", ""], ["accent", "더블클릭"], ["dim", "또는"], ["key", "SPACE"], ["accent", "더블탭"], ["text", "발동"]],
	],
	"drive": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_left", ""], ["accent", "발동"]],
	],
	"power_smashing": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_left", ""], ["accent", "홀드 발동"]],
		[["text", "단독"], ["mouse_left", ""], ["text", "홀드 시 반대쪽 자동 발동"]],
	],
	"ghost_shot": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_left", ""], ["accent", "홀드 발동"]],
	],
	"magnum_grip": [
		[["key", "←"], ["plus", "+"], ["key", "→"], ["dim", "또는"], ["key", "A"], ["plus", "+"], ["key", "D"], ["accent", "발동"]],
	],
	"warp_gate": [
		[["key", "S"], ["dim", "또는"], ["key", "↓"], ["accent", "0.5초 홀드 발동"]],
	],
	"smasher_wheel": [
		[["key", "A"], ["arrow", "→"], ["key", "W"], ["arrow", "→"], ["key", "D"], ["accent", "우회전 발동"]],
		[["key", "D"], ["arrow", "→"], ["key", "W"], ["arrow", "→"], ["key", "A"], ["accent", "좌회전 발동"]],
	],
}

var layout_helper: Object = Stage1PillarUiLayout.new()
var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()


func draw(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, scene_context: Dictionary) -> void:
	if canvas == null or registry == null:
		return

	var hover_context: Dictionary = _build_hover_context(canvas, registry, view_size, layout, scene_context)
	if hover_context.is_empty():
		return

	var skill_data: Dictionary = _find_hovered_skill(hover_context)
	if skill_data.is_empty():
		return

	_draw_tooltip(canvas, hover_context, skill_data)


func _build_hover_context(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	layout: Dictionary,
	scene_context: Dictionary
) -> Dictionary:
	var skill_config: Object = _get_instance(registry, "smasher_skill_config")
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return {}

	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_context.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var snapshot: Dictionary = skill_config.get_snapshot()
	var textures: Dictionary = _get_dictionary(scene_context.get("textures", {}))
	var skill_orb_context: Dictionary = layout_helper.build_skill_orb_context({
		"cluster_frame_texture": textures.get("smasher_skill_cluster_frame_texture", null),
		"skill_orb_frame_texture": textures.get("skill_orb_frame_texture", null),
		"skill_icons": scene_context.get("skill_icons", {}),
		"skill_state": _get_instance(registry, "smasher_skill_state"),
		"special_gauge": scene_context.get("special_gauge", 0.0),
		"skill_config_snapshot": snapshot,
	}, _get_instance(registry, "pillar_orb_drawer"))
	var orb_renderer: Object = _get_instance(registry, "smasher_skill_orb_renderer")
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		orb_renderer = fallback_orb_renderer

	return {
		"mouse_pos": canvas.get_viewport().get_mouse_position(),
		"view_size": view_size,
		"game_offset": game_offset,
		"game_size": game_size,
		"scale_factor": scale_factor,
		"left_center": _get_vector2(ui_layout, "left_center", Vector2.ZERO),
		"orb_radius": float(ui_layout.get("orb_radius", 55.0)),
		"skill_context": skill_orb_context,
		"skill_config_snapshot": snapshot,
		"skill_state": _get_instance(registry, "smasher_skill_state"),
		"special_gauge": float(scene_context.get("special_gauge", 0.0)),
		"orb_renderer": orb_renderer,
	}


func _find_hovered_skill(hover_context: Dictionary) -> Dictionary:
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var snapshot: Dictionary = _get_dictionary(hover_context.get("skill_config_snapshot", {}))
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var skill_data_map: Dictionary = _get_dictionary(snapshot.get("skill_data", {}))
	if equipped_skills.is_empty() or skill_data_map.is_empty():
		return {}

	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var orb_renderer: Object = hover_context.get("orb_renderer", null)
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		return {}

	var positions: Array = orb_renderer.get_slot_positions(
		_get_vector2(hover_context, "left_center", Vector2.ZERO),
		float(hover_context.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	var mouse_pos: Vector2 = _get_vector2(hover_context, "mouse_pos", Vector2.ZERO)
	var equipped_count: int = min(equipped_skills.size(), positions.size())
	for i in range(equipped_count):
		var skill_name: String = str(equipped_skills[i])
		if not skill_data_map.has(skill_name):
			continue
		var rect := Rect2(
			positions[i] - Vector2(icon_radius, icon_radius),
			Vector2(icon_radius * 2.0, icon_radius * 2.0)
		)
		if rect.has_point(mouse_pos):
			var data: Dictionary = _get_dictionary(skill_data_map.get(skill_name, {})).duplicate(true)
			data["slot_rect"] = rect
			return data
	return {}


func _draw_tooltip(canvas: CanvasItem, hover_context: Dictionary, skill_data: Dictionary) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var tooltip_width: float = TOOLTIP_WIDTH * scale_factor
	var padding: float = PADDING * scale_factor
	var title_size: int = max(14, int(round(16.0 * scale_factor)))
	var normal_size: int = max(11, int(round(12.0 * scale_factor)))
	var small_size: int = max(9, int(round(10.0 * scale_factor)))
	var max_text_width: float = tooltip_width - padding * 2.0
	var desc_lines: Array[String] = _wrap_text(str(skill_data.get("description", "")), font, normal_size, max_text_width, 3)
	var control_rows: Array = _build_control_rows(
		str(skill_data.get("name", "")),
		str(skill_data.get("motion_hint", "")),
		font,
		normal_size,
		max_text_width - 16.0 * scale_factor
	)
	var control_lines: Array[String] = []
	if control_rows.is_empty():
		control_lines = _wrap_text(str(skill_data.get("how_to_use", "")), font, normal_size, max_text_width - 16.0 * scale_factor, 2)

	var control_box_height: float = 0.0
	if not control_rows.is_empty():
		control_box_height = max(38.0 * scale_factor, float(control_rows.size()) * CONTROL_ROW_HEIGHT * scale_factor + 12.0 * scale_factor)
	elif not control_lines.is_empty():
		control_box_height = max(34.0 * scale_factor, float(control_lines.size()) * 18.0 * scale_factor + 16.0 * scale_factor)

	var content_bottom_y: float = padding + HEADER_HEIGHT * scale_factor + 6.0 * scale_factor + 22.0 * scale_factor
	content_bottom_y += float(desc_lines.size()) * 18.0 * scale_factor + 6.0 * scale_factor
	if control_box_height > 0.0:
		content_bottom_y += control_box_height + 8.0 * scale_factor

	var preview_height: float = EFFECT_PREVIEW_HEIGHT * scale_factor
	var min_height: float = 0.0
	var skill_name: String = str(skill_data.get("name", ""))
	if skill_name != "drive" and skill_name != "power_smashing":
		min_height = 300.0 * scale_factor
	var tooltip_height: float = max(min_height, content_bottom_y + preview_height + padding)
	var tooltip_pos: Vector2 = _get_tooltip_position(hover_context, tooltip_width, tooltip_height, scale_factor)
	var tooltip_rect := Rect2(tooltip_pos, Vector2(tooltip_width, tooltip_height))
	var skill_color: Color = _get_color(skill_data.get("color", Color.WHITE), Color.WHITE)

	_draw_panel(canvas, tooltip_rect, Color(20.0 / 255.0, 25.0 / 255.0, 35.0 / 255.0, 0.92), skill_color, 2.0 * scale_factor, 8.0 * scale_factor)
	var header_rect := Rect2(
		tooltip_pos + Vector2(2.0 * scale_factor, 2.0 * scale_factor),
		Vector2(tooltip_width - 4.0 * scale_factor, HEADER_HEIGHT * scale_factor)
	)
	_draw_panel(canvas, header_rect, Color(skill_color.r, skill_color.g, skill_color.b, 0.24), Color(0.0, 0.0, 0.0, 0.0), 0.0, 6.0 * scale_factor)

	var cursor_y: float = tooltip_pos.y + padding
	_draw_text(canvas, font, Vector2(tooltip_pos.x + padding, cursor_y), str(skill_data.get("korean", "")), title_size, Color.WHITE)
	var active_text := "ACTIVE"
	var active_size: Vector2 = font.get_string_size(active_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size)
	_draw_text(
		canvas,
		font,
		Vector2(tooltip_pos.x + tooltip_width - padding - active_size.x, cursor_y),
		active_text,
		title_size,
		Color(1.0, 120.0 / 255.0, 80.0 / 255.0)
	)

	cursor_y += HEADER_HEIGHT * scale_factor + 6.0 * scale_factor
	_draw_cost_and_cooldown_line(canvas, font, hover_context, skill_data, tooltip_pos, tooltip_width, padding, cursor_y, normal_size, small_size)
	cursor_y += 22.0 * scale_factor

	for line in desc_lines:
		_draw_text(canvas, font, Vector2(tooltip_pos.x + padding, cursor_y), line, normal_size, Color(220.0 / 255.0, 220.0 / 255.0, 220.0 / 255.0))
		cursor_y += 18.0 * scale_factor

	cursor_y += 6.0 * scale_factor
	if control_box_height > 0.0:
		var control_rect := Rect2(
			Vector2(tooltip_pos.x + padding, cursor_y),
			Vector2(tooltip_width - padding * 2.0, control_box_height)
		)
		_draw_panel(canvas, control_rect, Color(40.0 / 255.0, 45.0 / 255.0, 60.0 / 255.0, 0.78), Color(skill_color.r, skill_color.g, skill_color.b, 0.32), 1.0 * scale_factor, 4.0 * scale_factor)
		if not control_rows.is_empty():
			_draw_control_rows(canvas, font, control_rows, control_rect.position + Vector2(8.0 * scale_factor, 7.0 * scale_factor), normal_size, small_size, scale_factor)
		else:
			var line_y: float = control_rect.position.y + 8.0 * scale_factor
			for line in control_lines:
				_draw_text(canvas, font, Vector2(control_rect.position.x + 8.0 * scale_factor, line_y), line, normal_size, Color(224.0 / 255.0, 229.0 / 255.0, 238.0 / 255.0))
				line_y += 18.0 * scale_factor
		cursor_y += control_box_height + 8.0 * scale_factor

	var effect_rect := Rect2(
		Vector2(tooltip_pos.x + padding, tooltip_pos.y + tooltip_height - preview_height - padding),
		Vector2(tooltip_width - padding * 2.0, preview_height)
	)
	_draw_panel(canvas, effect_rect, Color(10.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 0.78), Color(skill_color.r, skill_color.g, skill_color.b, 0.40), 1.0 * scale_factor, 6.0 * scale_factor)
	_draw_effect_preview(canvas, effect_rect, str(skill_data.get("effect_type", "")), skill_color, float(Time.get_ticks_msec() % 2000) / 2000.0)
	_draw_text(canvas, font, effect_rect.position + Vector2(4.0 * scale_factor, 4.0 * scale_factor), "이펙트 미리보기", small_size, Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0))


func _draw_cost_and_cooldown_line(
	canvas: CanvasItem,
	font: Font,
	hover_context: Dictionary,
	skill_data: Dictionary,
	tooltip_pos: Vector2,
	tooltip_width: float,
	padding: float,
	y: float,
	normal_size: int,
	small_size: int
) -> void:
	var current_gauge: float = float(hover_context.get("special_gauge", 0.0))
	var cost: float = float(skill_data.get("cost", 0.0))
	var can_use: bool = current_gauge >= cost
	var cost_color := Color(100.0 / 255.0, 1.0, 150.0 / 255.0) if can_use else Color(1.0, 100.0 / 255.0, 100.0 / 255.0)
	_draw_text(canvas, font, Vector2(tooltip_pos.x + padding, y), "게이지 비용: %s" % _format_number(cost), normal_size, cost_color)

	var cooldown_seconds: float = float(skill_data.get("cooldown", 0.0))
	var cooldown_ratio: float = _get_cooldown_remaining(
		hover_context.get("skill_state", null),
		str(skill_data.get("name", "")),
		Time.get_ticks_msec(),
		cooldown_seconds
	)
	var cooldown_text: String
	var cooldown_color: Color
	if cooldown_ratio > 0.0:
		cooldown_text = "쿨타임: %.1f초" % (cooldown_seconds * cooldown_ratio)
		cooldown_color = Color(1.0, 180.0 / 255.0, 80.0 / 255.0)
	else:
		cooldown_text = "쿨타임: %s초" % _format_number(cooldown_seconds)
		cooldown_color = Color(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0)
	var cd_size: Vector2 = font.get_string_size(cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size)
	_draw_text(canvas, font, Vector2(tooltip_pos.x + tooltip_width - padding - cd_size.x, y + 2.0), cooldown_text, small_size, cooldown_color)


func _get_tooltip_position(hover_context: Dictionary, tooltip_width: float, tooltip_height: float, scale_factor: float) -> Vector2:
	var view_size: Vector2 = _get_vector2(hover_context, "view_size", Vector2(1488.0, 918.0))
	var game_offset: Vector2 = _get_vector2(hover_context, "game_offset", Vector2.ZERO)
	var mouse_pos: Vector2 = _get_vector2(hover_context, "mouse_pos", Vector2.ZERO)
	var tooltip_x: float = game_offset.x + 10.0 * scale_factor
	var tooltip_y: float = mouse_pos.y - tooltip_height * 0.5
	tooltip_x = clamp(tooltip_x, 5.0, max(5.0, view_size.x - tooltip_width - 5.0))
	tooltip_y = clamp(tooltip_y, 10.0, max(10.0, view_size.y - tooltip_height - 10.0))
	return Vector2(tooltip_x, tooltip_y)


func _build_control_rows(skill_name: String, motion_hint: String, font: Font, font_size: int, max_width: float) -> Array:
	var rows: Array = _get_control_rows(skill_name).duplicate(true)
	if not motion_hint.is_empty():
		for line in _wrap_text(motion_hint, font, font_size, max_width, 2):
			rows.append([["dim", line]])
	return rows


func _draw_control_rows(canvas: CanvasItem, font: Font, rows: Array, start: Vector2, normal_size: int, small_size: int, scale_factor: float) -> void:
	var row_height: float = CONTROL_ROW_HEIGHT * scale_factor
	for row_index in range(rows.size()):
		var row: Array = _get_array(rows[row_index])
		var cursor_x: float = start.x
		var row_y: float = start.y + float(row_index) * row_height
		for token_value in row:
			var token: Array = _get_array(token_value)
			if token.size() < 2:
				continue
			var token_type: String = str(token[0])
			var value: String = str(token[1])
			if token_type == "key":
				cursor_x += _draw_keycap(canvas, font, Vector2(cursor_x, row_y - scale_factor), value, small_size, scale_factor) + 4.0 * scale_factor
			elif token_type == "mouse_left":
				_draw_mouse_left_icon(canvas, Vector2(cursor_x, row_y - scale_factor), 18.0 * scale_factor)
				cursor_x += 22.0 * scale_factor
			else:
				var color: Color = _token_color(token_type)
				var text_size: Vector2 = _draw_text(canvas, font, Vector2(cursor_x, row_y + scale_factor), value, normal_size, color)
				cursor_x += text_size.x + 6.0 * scale_factor


func _draw_keycap(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, scale_factor: float) -> float:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var width: float = max(20.0 * scale_factor, text_size.x + 14.0 * scale_factor)
	var height: float = 18.0 * scale_factor
	var rect := Rect2(pos, Vector2(width, height))
	_draw_panel(canvas, rect, Color(18.0 / 255.0, 22.0 / 255.0, 32.0 / 255.0, 0.92), Color(120.0 / 255.0, 130.0 / 255.0, 150.0 / 255.0, 0.85), 1.0 * scale_factor, 4.0 * scale_factor)
	_draw_text(canvas, font, Vector2(pos.x + (width - text_size.x) * 0.5, pos.y + (height - text_size.y) * 0.48), text, font_size, Color.WHITE)
	return width


func _draw_mouse_left_icon(canvas: CanvasItem, pos: Vector2, size: float) -> void:
	var rect := Rect2(pos, Vector2(size * 0.72, size))
	var center_x: float = rect.position.x + rect.size.x * 0.5
	_draw_panel(canvas, rect, Color(18.0 / 255.0, 22.0 / 255.0, 32.0 / 255.0, 0.92), Color(120.0 / 255.0, 130.0 / 255.0, 150.0 / 255.0, 0.85), max(1.0, size * 0.06), size * 0.22)
	canvas.draw_line(Vector2(center_x, rect.position.y + size * 0.08), Vector2(center_x, rect.position.y + size * 0.44), Color(0.75, 0.8, 0.9), max(1.0, size * 0.06))
	canvas.draw_circle(Vector2(rect.position.x + rect.size.x * 0.31, rect.position.y + size * 0.25), max(1.2, size * 0.08), Color(1.0, 214.0 / 255.0, 96.0 / 255.0))


func _draw_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color, progress: float) -> void:
	var inner := rect.grow(-8.0)
	var floor_y: float = inner.position.y + inner.size.y * 0.76
	var player_x: float = inner.position.x + inner.size.x * 0.26
	var boss_x: float = inner.position.x + inner.size.x * 0.74
	var ball_t: float = clamp(progress, 0.0, 1.0)

	canvas.draw_line(Vector2(inner.position.x + 6.0, floor_y), Vector2(inner.end.x - 6.0, floor_y), Color(0.25, 0.31, 0.42, 0.55), 1.0)
	_draw_preview_paddle(canvas, Vector2(player_x, floor_y), color)

	if effect_type == "drive_curve":
		_draw_curve_preview(canvas, Vector2(player_x, floor_y - 6.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.35), color, ball_t)
	elif effect_type == "smash_orange":
		_draw_smash_preview(canvas, Vector2(player_x, floor_y - 8.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.28), color, ball_t)
	elif effect_type == "projectile_cyan":
		_draw_projectile_preview(canvas, Vector2(player_x, floor_y - 16.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.38), color, ball_t)
	elif effect_type == "heal_green":
		_draw_recovery_preview(canvas, Vector2(player_x, floor_y), color, ball_t)
	elif effect_type == "cleanse_light":
		_draw_cleanse_preview(canvas, Vector2(player_x, floor_y - 10.0), color, ball_t)
	elif effect_type == "shield_kiting_arc":
		_draw_shield_preview(canvas, Vector2(player_x, floor_y - 10.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.42), color, ball_t)
	elif effect_type == "magnetic_pull_blue":
		_draw_magnetic_preview(canvas, Vector2(player_x, floor_y - 8.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.36), color, ball_t)
	elif effect_type == "ghost_purple":
		_draw_ghost_preview(canvas, Vector2(player_x, floor_y - 10.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.32), color, ball_t)
	elif effect_type == "portal_purple":
		_draw_portal_preview(canvas, inner, color, ball_t)
	elif effect_type == "wheel_spin":
		_draw_wheel_preview(canvas, Vector2(player_x, floor_y - 8.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.32), color, ball_t)
	else:
		_draw_curve_preview(canvas, Vector2(player_x, floor_y - 6.0), Vector2(boss_x, inner.position.y + inner.size.y * 0.35), color, ball_t)


func _draw_preview_paddle(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	var rect := Rect2(center + Vector2(-18.0, -3.0), Vector2(36.0, 6.0))
	canvas.draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.38), true)
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.92), true)


func _draw_curve_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var points := PackedVector2Array()
	for i in range(18):
		var t: float = float(i) / 17.0
		var pos: Vector2 = start.lerp(end, t) + Vector2(0.0, sin(t * PI) * -22.0)
		points.append(pos)
	canvas.draw_polyline(points, Color(color.r, color.g, color.b, 0.65), 2.0)
	var ball_pos: Vector2 = start.lerp(end, progress) + Vector2(0.0, sin(progress * PI) * -22.0)
	canvas.draw_circle(ball_pos, 5.0, Color.WHITE)
	canvas.draw_circle(ball_pos, 7.0, Color(color.r, color.g, color.b, 0.35))


func _draw_smash_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	for i in range(4):
		var offset := Vector2(0.0, float(i - 1) * 5.0)
		canvas.draw_line(start + offset, end + offset * 0.25, Color(color.r, color.g, color.b, 0.18 + float(i) * 0.12), 2.0 + float(i))
	var ball_pos: Vector2 = start.lerp(end, progress)
	canvas.draw_circle(ball_pos, 5.0 + sin(progress * PI) * 2.0, Color.WHITE)
	canvas.draw_circle(end, 14.0 * progress, Color(color.r, color.g, color.b, 0.18 * (1.0 - progress)))


func _draw_projectile_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var ball_pos: Vector2 = start.lerp(end, progress)
	for i in range(5):
		var t: float = max(0.0, progress - float(i) * 0.07)
		var trail_pos: Vector2 = start.lerp(end, t)
		canvas.draw_circle(trail_pos, max(1.0, 6.0 - float(i)), Color(color.r, color.g, color.b, max(0.08, 0.34 - float(i) * 0.05)))
	canvas.draw_circle(ball_pos, 8.0, Color(color.r, color.g, color.b, 0.75))
	canvas.draw_circle(ball_pos, 4.0, Color.WHITE)
	canvas.draw_arc(end, 18.0, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.36), 2.0)


func _draw_recovery_preview(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	for i in range(4):
		var shift: float = (float(i) * 12.0 + progress * 36.0)
		var alpha: float = max(0.0, 0.42 - float(i) * 0.08)
		canvas.draw_line(center + Vector2(-26.0 - shift * 0.2, -16.0 + float(i) * 6.0), center + Vector2(16.0 - shift * 0.2, -16.0 + float(i) * 6.0), Color(color.r, color.g, color.b, alpha), 3.0)
	canvas.draw_circle(center + Vector2(sin(progress * TAU) * 5.0, -10.0), 16.0, Color(color.r, color.g, color.b, 0.18))
	canvas.draw_arc(center + Vector2(0.0, -10.0), 18.0 + progress * 8.0, 0.0, TAU * 0.78, 28, Color(color.r, color.g, color.b, 0.75), 2.0)


func _draw_cleanse_preview(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	for i in range(3):
		var radius: float = 14.0 + float(i) * 10.0 + progress * 12.0
		canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, max(0.06, 0.34 - float(i) * 0.08)), 2.0)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var p0: Vector2 = center + Vector2(cos(angle), sin(angle)) * 8.0
		var p1: Vector2 = center + Vector2(cos(angle), sin(angle)) * 30.0
		canvas.draw_line(p0, p1, Color.WHITE, 1.5)


func _draw_shield_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var arc_mid: Vector2 = start.lerp(end, progress) + Vector2(0.0, -sin(progress * PI) * 24.0)
	canvas.draw_arc(start, 20.0, -PI * 0.72, PI * 0.12, 18, Color(color.r, color.g, color.b, 0.68), 3.0)
	_draw_curve_preview(canvas, start, end, color, progress)
	canvas.draw_arc(arc_mid, 10.0, -PI * 0.85, PI * 0.85, 18, Color.WHITE, 2.0)
	canvas.draw_arc(arc_mid, 13.0, -PI * 0.85, PI * 0.85, 18, Color(color.r, color.g, color.b, 0.64), 2.0)


func _draw_magnetic_preview(canvas: CanvasItem, start: Vector2, ball: Vector2, color: Color, progress: float) -> void:
	var current_ball: Vector2 = ball.lerp(start + Vector2(20.0, -4.0), progress)
	for i in range(3):
		canvas.draw_arc(start, 24.0 + float(i) * 12.0, -PI * 0.25, PI * 0.25, 18, Color(color.r, color.g, color.b, 0.34 - float(i) * 0.08), 2.0)
	canvas.draw_line(current_ball, start, Color(color.r, color.g, color.b, 0.46), 1.5)
	canvas.draw_circle(current_ball, 6.0, Color.WHITE)


func _draw_ghost_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var t: float = float(i) / 19.0
		points.append(start.lerp(end, t) + Vector2(0.0, sin(t * TAU * 1.6 + progress * TAU) * 12.0))
	canvas.draw_polyline(points, Color(color.r, color.g, color.b, 0.68), 2.0)
	var ball_pos: Vector2 = start.lerp(end, progress) + Vector2(0.0, sin(progress * TAU * 1.6 + progress * TAU) * 12.0)
	canvas.draw_circle(ball_pos, 5.0, Color.WHITE)
	for i in range(3):
		var ghost_pos: Vector2 = ball_pos - Vector2(18.0 + float(i) * 9.0, -6.0 + float(i) * 3.0)
		canvas.draw_circle(ghost_pos, 6.0 - float(i), Color(color.r, color.g, color.b, 0.24))


func _draw_portal_preview(canvas: CanvasItem, inner: Rect2, color: Color, progress: float) -> void:
	var left := Vector2(inner.position.x + 28.0, inner.position.y + inner.size.y * 0.45)
	var right := Vector2(inner.end.x - 28.0, inner.position.y + inner.size.y * 0.45)
	for center in [left, right]:
		canvas.draw_arc(center, 17.0 + sin(progress * TAU) * 3.0, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.76), 3.0)
		canvas.draw_arc(center, 9.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	var ball_pos: Vector2 = left.lerp(right, progress)
	canvas.draw_circle(ball_pos, 5.0, Color.WHITE)


func _draw_wheel_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	for i in range(4):
		var angle: float = progress * TAU * 2.0 + float(i) * PI * 0.5
		canvas.draw_line(start, start + Vector2(cos(angle), sin(angle)) * 24.0, Color(color.r, color.g, color.b, 0.75), 3.0)
	canvas.draw_arc(start, 29.0, progress * TAU, progress * TAU + PI * 1.35, 28, Color(color.r, color.g, color.b, 0.46), 3.0)
	_draw_curve_preview(canvas, start + Vector2(22.0, -2.0), end, color, progress)


func _wrap_text(text: String, font: Font, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	if text.is_empty() or max_lines <= 0:
		return lines
	for hard_line in text.split("\n", false):
		var line: String = ""
		var segment: String = str(hard_line)
		for index in range(segment.length()):
			var glyph: String = segment.substr(index, 1)
			var candidate: String = line + glyph
			if line.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
				line = candidate
			else:
				lines.append(line)
				if lines.size() >= max_lines:
					return lines
				line = glyph
		if not line.is_empty():
			lines.append(line)
			if lines.size() >= max_lines:
				return lines
	return lines


func _draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> Vector2:
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(pos.x, pos.y + font.get_ascent(font_size))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return size


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill_color: Color, border_color: Color, border_width: float, corner_radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	var width: int = max(0, int(round(border_width)))
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var radius: int = max(0, int(round(corner_radius)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	canvas.draw_style_box(style, rect)


func _get_control_rows(skill_name: String) -> Array:
	var rows: Variant = CONTROL_ROWS.get(skill_name, [])
	if rows is Array:
		return rows
	return []


func _get_cooldown_remaining(skill_state: Object, skill_name: String, time_now: int, cooldown_seconds: float) -> float:
	if skill_state != null and skill_state.has_method("get_cooldown_remaining"):
		return float(skill_state.get_cooldown_remaining(skill_name, time_now, cooldown_seconds))
	return 0.0


func _token_color(token_type: String) -> Color:
	if token_type == "dim":
		return Color(184.0 / 255.0, 192.0 / 255.0, 208.0 / 255.0)
	if token_type == "accent":
		return Color(1.0, 214.0 / 255.0, 96.0 / 255.0)
	if token_type in ["arrow", "plus", "slash"]:
		return Color(190.0 / 255.0, 196.0 / 255.0, 210.0 / 255.0)
	return Color(224.0 / 255.0, 229.0 / 255.0, 238.0 / 255.0)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
