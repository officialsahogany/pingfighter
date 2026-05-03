extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

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

const VIPER_CONTROL_ROWS := {
	"shadow_step": [
		[["text", "대쉬 중/직후"], ["key", "S"], ["accent", "발동"]],
	],
	"blade_rush": [
		[["text", "체공 중"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"nerve_strike": [
		[["text", "블레이드 계열 사용 후"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"dive_strike": [
		[["text", "체공 중"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "0.3초 홀드"]],
	],
	"marshal_kick": [
		[["text", "연계 후"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "발동"]],
	],
	"phantom_kick": [
		[["text", "마샬 킥 적중 후"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "발동"]],
	],
	"dark_blade": [
		[["text", "연계 타격 후 공중"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"chaos_spear": [
		[["key", "A"], ["arrow", "→"], ["key", "W"], ["arrow", "→"], ["key", "D"], ["accent", "발동"]],
	],
	"core_flip": [
		[["text", "대쉬 타격 후"], ["key", "A"], ["plus", "+"], ["key", "D"], ["accent", "발동"]],
	],
	"dual_glitch": [
		[["key", "A"], ["arrow", "→"], ["key", "D"], ["arrow", "→"], ["key", "A"], ["arrow", "→"], ["key", "D"]],
	],
	"ignition_aura": [
		[["text", "지상에서"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "0.5초 홀드"]],
	],
}

var layout_helper: Object = Stage1PillarUiLayout.new()
var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()
var character_runtime: Object = PlayerCharacterRuntime.new()


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
	var character_type: String = character_runtime.normalize(scene_context.get("selected_character_type", "smasher"))
	var skill_config: Object = _get_instance(registry, character_runtime.get_skill_config_key(character_type))
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
		"cluster_frame_texture": textures.get(character_runtime.get_skill_cluster_frame_texture_key(character_type), null),
		"skill_orb_frame_texture": textures.get("skill_orb_frame_texture", null),
		"skill_icons": scene_context.get("skill_icons", {}),
		"skill_state": _get_instance(registry, character_runtime.get_skill_state_key(character_type)),
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
		"selected_character_type": character_type,
		"left_center": _get_vector2(ui_layout, "left_center", Vector2.ZERO),
		"orb_radius": float(ui_layout.get("orb_radius", 55.0)),
		"skill_context": skill_orb_context,
		"skill_config_snapshot": snapshot,
		"skill_state": _get_instance(registry, character_runtime.get_skill_state_key(character_type)),
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
		str(hover_context.get("selected_character_type", "smasher")),
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


func _build_control_rows(skill_name: String, character_type: String, motion_hint: String, font: Font, font_size: int, max_width: float) -> Array:
	var rows: Array = _get_control_rows(skill_name, character_type).duplicate(true)
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


func _draw_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color, _progress: float) -> void:
	if effect_type == "drive_curve":
		_draw_drive_curve_preview(canvas, rect, color)
	elif effect_type == "smash_orange":
		_draw_smash_orange_preview(canvas, rect, color)
	elif effect_type == "projectile_cyan":
		_draw_projectile_cyan_preview(canvas, rect, color)
	elif effect_type == "heal_green":
		_draw_heal_green_preview(canvas, rect, color)
	elif effect_type == "cleanse_light":
		_draw_cleanse_light_preview(canvas, rect, color)
	elif effect_type == "shield_kiting_arc":
		_draw_shield_kiting_preview(canvas, rect, color)
	elif effect_type == "magnetic_pull_blue":
		_draw_magnetic_pull_preview(canvas, rect, color)
	elif effect_type == "ghost_purple":
		_draw_ghost_purple_preview(canvas, rect, color)
	elif effect_type == "portal_purple":
		_draw_portal_purple_preview(canvas, rect, color)
	elif effect_type == "wheel_spin":
		_draw_wheel_spin_preview(canvas, rect, color)
	elif effect_type in ["shadow_teleport", "slash_purple", "slash_dark", "stun_purple", "glitch_clone"]:
		_draw_ghost_purple_preview(canvas, rect, color)
	elif effect_type in ["wall_dive_purple", "core_flip_arc", "dive_impact", "ignition_burst"]:
		_draw_wheel_spin_preview(canvas, rect, color)
	elif effect_type == "chaos_vortex":
		_draw_portal_purple_preview(canvas, rect, color)
	else:
		_draw_drive_curve_preview(canvas, rect, color)


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


func _draw_projectile_cyan_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var block := 4.0
	if local_progress < 0.35:
		var phase: float = local_progress / 0.35
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": block, "paddle_lift": phase * 0.6})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		if not paddle.is_empty():
			var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
			var p_radius: float = float(paddle.get("radius", 6.0))
			var charge := p_center + Vector2(0.0, -p_radius - 6.0)
			var core_r: float = max(1.0, 2.0 + phase * 5.0)
			for ring_idx in range(3):
				var ring_r: float = core_r + float(3 - ring_idx) * 2.0
				var ring_alpha: float = max(40.0 / 255.0, (90.0 - float(ring_idx) * 25.0) * phase / 255.0)
				canvas.draw_arc(charge, ring_r, 0.0, TAU, 36, _alpha(color, ring_alpha), 1.0)
			canvas.draw_circle(charge, core_r, color)
			canvas.draw_circle(charge + Vector2(-1.0, -1.0), max(1.0, core_r * 0.5), Color(220.0 / 255.0, 250.0 / 255.0, 1.0))
			for spark_idx in range(6):
				var spark_angle: float = TAU * float(spark_idx) / 6.0 + float(time_ms) * 0.004
				var spark_dist: float = max(2.0, 14.0 - phase * 12.0)
				var spark_pos: Vector2 = charge + Vector2(cos(spark_angle), sin(spark_angle)) * spark_dist
				var spark_alpha: float = max(60.0, 180.0 * (1.0 - phase) + 120.0 * phase) / 255.0
				canvas.draw_circle(spark_pos, 2.0, _alpha(color, spark_alpha))
	elif local_progress < 0.55:
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": block, "paddle_lift": 0.6})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		if not paddle.is_empty():
			var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
			var p_radius: float = float(paddle.get("radius", 6.0))
			var charge := p_center + Vector2(0.0, -p_radius - 6.0)
			var pulse: float = 1.0 + 0.18 * sin(float(time_ms) * 0.025)
			var core_r: float = max(2.0, 7.0 * pulse)
			for ring_idx in range(4):
				canvas.draw_arc(charge, core_r + float(ring_idx) * 3.0, 0.0, TAU, 36, _alpha(color, max(30.0, 130.0 - float(ring_idx) * 26.0) / 255.0), 1.0)
			canvas.draw_circle(charge, core_r, color)
			canvas.draw_circle(charge + Vector2(-1.0, -1.0), 3.0, Color(235.0 / 255.0, 1.0, 1.0))
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 2.0 * block), "W")
	else:
		var phase: float = (local_progress - 0.55) / 0.45
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {
			"block": block,
			"swing_ratio": min(1.0, phase * 1.8),
			"paddle_lift": max(0.0, 0.6 - phase),
		})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var start := p_center + Vector2(0.0, -p_radius - 4.0)
		var end_y: float = preview_top + 6.0
		var ease: float = 1.0 - pow(1.0 - phase, 2.5)
		var ball_pos := Vector2(start.x + sin(phase * TAU) * 5.0, start.y + (end_y - start.y) * ease)
		for trail_idx in range(8):
			var t: float = max(0.0, ease - float(trail_idx) * 0.1)
			if t <= 0.0:
				continue
			var trail_pos := Vector2(start.x + sin(t * TAU) * 5.0, start.y + (end_y - start.y) * t)
			canvas.draw_circle(trail_pos, max(2.0, 6.0 - float(trail_idx) * 0.5), _alpha(color, max(40.0, 200.0 - float(trail_idx) * 22.0) / 255.0))
		canvas.draw_arc(ball_pos, 12.0, 0.0, TAU, 36, _alpha(color, max(30.0, 120.0 * (1.0 - phase * 0.6)) / 255.0), 1.0)
		canvas.draw_arc(ball_pos, 18.0, 0.0, TAU, 36, _alpha(color, max(20.0, 90.0 * (1.0 - phase * 0.6)) / 255.0), 1.0)
		_draw_preview_ball(canvas, ball_pos, 6.0, [Color(0.0, 200.0 / 255.0, 1.0), Color(140.0 / 255.0, 235.0 / 255.0, 1.0), Color(235.0 / 255.0, 1.0, 1.0)], color)


func _draw_heal_green_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var floor_y: float = preview_bottom - 2.0
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), Color(60.0 / 255.0, 110.0 / 255.0, 80.0 / 255.0, 50.0 / 255.0), 2.0)
	if local_progress < 0.30:
		var phase: float = local_progress / 0.30
		var char_x: float = center_x - 12.0
		_draw_smasher_mini_character(canvas, char_x, char_y, {"block": 4.0, "head_offset_y": (1.0 - phase) * 2.0})
		for arrow_idx in range(2):
			var arrow_x: float = char_x - 14.0 - float(arrow_idx) * 6.0
			var arrow_alpha: float = max(40.0, 140.0 - float(arrow_idx) * 50.0) / 255.0
			var arrow_color := Color(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0, arrow_alpha)
			canvas.draw_line(Vector2(arrow_x, char_y - 14.0), Vector2(arrow_x - 6.0, char_y - 14.0), arrow_color, 2.0)
			canvas.draw_line(Vector2(arrow_x - 6.0, char_y - 14.0), Vector2(arrow_x - 3.0, char_y - 17.0), arrow_color, 1.0)
			canvas.draw_line(Vector2(arrow_x - 6.0, char_y - 14.0), Vector2(arrow_x - 3.0, char_y - 11.0), arrow_color, 1.0)
	elif local_progress < 0.55:
		var phase: float = (local_progress - 0.30) / 0.25
		var char_x: float = center_x - 12.0
		_draw_smasher_mini_character(canvas, char_x, char_y, {"block": 4.0})
		var burst := Vector2(char_x, char_y - 2.0)
		for ring_idx in range(3):
			var ring_r: float = 8.0 + phase * 18.0 + float(ring_idx) * 4.0
			var ring_alpha: float = max(0.0, 180.0 * (1.0 - phase) - float(ring_idx) * 30.0) / 255.0
			if ring_alpha > 0.0:
				canvas.draw_arc(burst, ring_r, 0.0, TAU, 36, _alpha(color, ring_alpha), 2.0)
		for p_idx in range(8):
			var p_angle: float = TAU * float(p_idx) / 8.0 + float(time_ms) * 0.003
			var p_dist: float = 12.0 + phase * 18.0
			var p_pos := burst + Vector2(cos(p_angle) * p_dist, sin(p_angle) * p_dist * 0.5 - phase * 12.0)
			canvas.draw_circle(p_pos, 3.0, _alpha(color, max(60.0, 220.0 * (1.0 - phase * 0.5)) / 255.0))
		var cross_size: float = 6.0 + phase * 4.0
		var cross_alpha: float = max(120.0, 255.0 * (1.0 - phase * 0.4)) / 255.0
		canvas.draw_line(burst + Vector2(0.0, -cross_size - 6.0), burst + Vector2(0.0, cross_size - 6.0), _alpha(color, cross_alpha), 3.0)
		canvas.draw_line(burst + Vector2(-cross_size, -6.0), burst + Vector2(cross_size, -6.0), _alpha(color, cross_alpha), 3.0)
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 8.0), "W")
	else:
		var phase: float = (local_progress - 0.55) / 0.45
		var ease: float = 1.0 - pow(1.0 - phase, 2.0)
		var start_x: float = center_x - 12.0
		var end_x: float = center_x + 60.0
		var char_x: float = start_x + (end_x - start_x) * ease
		for ghost_idx in range(4):
			var t: float = max(0.0, ease - float(ghost_idx + 1) * 0.10)
			if t <= 0.0:
				continue
			var gx: float = start_x + (end_x - start_x) * t
			_draw_smasher_mini_character(canvas, gx, char_y + 1.0, {"block": 4.0, "show_shield": false, "alpha": max(40.0, 130.0 - float(ghost_idx) * 28.0) / 255.0, "tint": color})
		_draw_smasher_mini_character(canvas, char_x, char_y, {"block": 4.0})
		for line_idx in range(5):
			var line_t: float = max(0.0, ease - float(line_idx) * 0.08)
			if line_t <= 0.0:
				continue
			var lx: float = start_x + (end_x - start_x) * line_t
			var ly: float = char_y - 6.0 - float(line_idx) * 5.0
			canvas.draw_line(Vector2(lx - 12.0 - float(line_idx) * 3.0, ly), Vector2(lx, ly), _alpha(color, max(40.0, 200.0 - float(line_idx) * 32.0) / 255.0), 2.0)
		_draw_ellipse(canvas, Rect2(Vector2(char_x - 12.0, char_y - 4.0), Vector2(24.0, 6.0)), _alpha(color, max(30.0, 120.0 * (1.0 - phase * 0.5)) / 255.0), true)


func _draw_cleanse_light_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	if local_progress < 0.35:
		var wobble: float = sin(float(time_ms) * 0.012) * 1.5
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "head_offset_y": wobble})
		var star_cy: float = float(anchors.get("helmet_top", char_y - 28.0)) - 2.0
		for star_idx in range(4):
			var ang: float = TAU * float(star_idx) / 4.0 + float(time_ms) * 0.005
			var star_pos := Vector2(center_x + cos(ang) * 14.0, star_cy + sin(ang) * 4.0)
			_draw_mini_star_gd(canvas, star_pos, 3.0, Color(1.0, 240.0 / 255.0, 120.0 / 255.0) if star_idx % 2 == 0 else Color(200.0 / 255.0, 200.0 / 255.0, 1.0))
		for arc_idx in range(2):
			canvas.draw_arc(Vector2(center_x, star_cy), 14.0 + float(arc_idx) * 3.0, 0.0, TAU, 36, Color(200.0 / 255.0, 200.0 / 255.0, 1.0, max(40.0, 100.0 - float(arc_idx) * 30.0) / 255.0), 1.0)
	elif local_progress < 0.55:
		var phase: float = (local_progress - 0.35) / 0.20
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var burst := Vector2(center_x, char_y - 10.0)
		var burst_r: float = 10.0 + phase * 36.0
		for ring_idx in range(4):
			var rr: float = burst_r - float(ring_idx) * 6.0
			if rr <= 0.0:
				continue
			canvas.draw_arc(burst, rr, 0.0, TAU, 36, _alpha(color, max(30.0, 220.0 * (1.0 - phase * 0.4) - float(ring_idx) * 30.0) / 255.0), 2.0)
		for i in range(10):
			var ang: float = TAU * float(i) / 10.0 + float(time_ms) * 0.004
			canvas.draw_line(burst + Vector2(cos(ang), sin(ang)) * 8.0, burst + Vector2(cos(ang), sin(ang)) * (8.0 + phase * 32.0), Color(1.0, 1.0, 220.0 / 255.0, max(80.0, 255.0 * (1.0 - phase * 0.6)) / 255.0), 2.0)
		canvas.draw_circle(burst, max(2.0, 8.0 - phase * 4.0), Color(1.0, 1.0, 240.0 / 255.0))
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 8.0), "W")
	else:
		var phase: float = (local_progress - 0.55) / 0.45
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var aura := Vector2(center_x, char_y - 8.0)
		var aura_pulse: float = 1.0 + 0.08 * sin(float(time_ms) * 0.012)
		for ring_idx in range(3):
			var rx: float = (22.0 + float(ring_idx) * 4.0) * aura_pulse
			var ry: float = (28.0 + float(ring_idx) * 5.0) * aura_pulse
			_draw_ellipse(canvas, Rect2(Vector2(aura.x - rx, aura.y - ry), Vector2(rx * 2.0, ry * 2.0)), _alpha(color, max(30.0, 140.0 - float(ring_idx) * 38.0) / 255.0), false, 2.0)
		for star_idx in range(5):
			var ang: float = TAU * float(star_idx) / 5.0 + float(time_ms) * 0.002
			_draw_mini_star_gd(canvas, aura + Vector2(cos(ang) * 24.0, sin(ang) * 28.0 - phase * 6.0), 2.0, Color(1.0, 245.0 / 255.0, 200.0 / 255.0))


func _draw_shield_kiting_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2600) / 2600.0
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var wind_up_ratio: float = min(1.0, local_progress / max(0.001, 320.0 / 2600.0))
	var player := Vector2(preview_left + 48.0, preview_bottom - 10.0)
	var ball := Vector2(preview_right - 42.0, preview_top + 16.0)
	var shield_r := 12.0
	var floor_y: float = preview_bottom - 2.0
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), Color(90.0 / 255.0, 110.0 / 255.0, 145.0 / 255.0, 45.0 / 255.0), 2.0)
	_draw_round_rect(canvas, Rect2(player + Vector2(-10.0, -18.0), Vector2(20.0, 22.0)), Color(78.0 / 255.0, 112.0 / 255.0, 168.0 / 255.0, 90.0 / 255.0), 5.0)
	_draw_round_rect(canvas, Rect2(player + Vector2(4.0, -18.0), Vector2(7.0, 22.0)), Color(190.0 / 255.0, 220.0 / 255.0, 1.0, 120.0 / 255.0), 4.0)
	var shield_pos: Vector2
	if local_progress < 0.2:
		shield_pos = player + Vector2(16.0 - (1.0 - wind_up_ratio) * 8.0, -18.0 - sin(wind_up_ratio * PI) * 3.0)
		for ring_idx in range(2):
			canvas.draw_arc(shield_pos, shield_r + float(ring_idx) * 5.0 + wind_up_ratio * 6.0, 0.0, TAU, 36, _alpha(color, max(30.0, 120.0 - float(ring_idx) * 28.0) / 255.0), 1.0)
	else:
		var travel_t: float = clamp((local_progress - 0.2) / 0.8, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - travel_t, 3.0)
		shield_pos = (player + Vector2(16.0, -18.0)).lerp(ball, eased) + Vector2(0.0, -sin(travel_t * PI) * 26.0)
		var trail_pts: Array[Vector2] = []
		for step in range(7):
			var t_step: float = max(0.0, travel_t - float(step) * 0.08)
			var e_step: float = 1.0 - pow(1.0 - t_step, 3.0)
			trail_pts.append((player + Vector2(16.0, -18.0)).lerp(ball, e_step) + Vector2(0.0, -sin(t_step * PI) * 26.0))
		for idx in range(trail_pts.size() - 1):
			canvas.draw_line(trail_pts[idx], trail_pts[idx + 1], _alpha(color, max(30.0, 160.0 - float(idx) * 18.0) / 255.0), max(1.0, 3.0 - float(idx) * 0.4))
		if travel_t > 0.55:
			var return_progress: float = (travel_t - 0.55) / 0.45
			canvas.draw_arc(player + Vector2(0.0, -16.0), 18.0 + return_progress * 12.0, deg_to_rad(240.0), deg_to_rad(345.0), 24, Color(210.0 / 255.0, 240.0 / 255.0, 1.0), 2.0)
	_draw_preview_pentagon(canvas, shield_pos, shield_r, -90.0 + local_progress * 360.0, _alpha(color, 200.0 / 255.0), Color(210.0 / 255.0, 245.0 / 255.0, 1.0), 2.0)
	_draw_preview_pentagon(canvas, shield_pos, shield_r * 0.45, -90.0, Color.WHITE, Color.WHITE, 0.0)
	_draw_preview_ball(canvas, ball, 6.0, [Color(110.0 / 255.0, 150.0 / 255.0, 1.0), Color(175.0 / 255.0, 220.0 / 255.0, 1.0), Color(1.0, 250.0 / 255.0, 1.0)])
	if local_progress > 0.45:
		canvas.draw_arc(ball, 14.0, 0.0, TAU, 36, Color(1.0, 240.0 / 255.0, 220.0 / 255.0, max(50.0, 120.0 + 90.0 * sin(local_progress * TAU)) / 255.0), 2.0)
		canvas.draw_line(ball + Vector2(-16.0, 8.0), ball + Vector2(12.0, -10.0), Color.WHITE, 2.0)


func _draw_drive_curve_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_progress: float = float(time_ms % 3000) / 3000.0
	var is_left_cycle: bool = cycle_progress < 0.5
	var local_progress: float = fposmod(cycle_progress, 0.5) * 2.0
	var curve_direction: float = -1.0 if is_left_cycle else 1.0
	var key_text: String = "A" if is_left_cycle else "D"
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var char_top: float = char_y - 18.0
	var ball_radius := 6.0
	if local_progress < 0.3:
		var phase: float = local_progress / 0.3
		var ball_y: float = preview_top - 5.0 + (char_top - 8.0 - (preview_top - 5.0)) * phase
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(curve_direction)})
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), ball_radius)
		if phase > 0.4:
			canvas.draw_arc(Vector2(center_x, ball_y), 14.0 * (1.0 + 0.1 * sin(float(time_ms) * 0.015)), 0.0, TAU, 36, Color.YELLOW, 2.0)
	elif local_progress < 0.5:
		var ball_y: float = char_top - 8.0
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(curve_direction)})
		canvas.draw_arc(Vector2(center_x, ball_y), 15.0 * (1.0 + 0.15 * sin(float(time_ms) * 0.02)), 0.0, TAU, 36, Color.YELLOW, 2.0)
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), ball_radius)
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 8.0), key_text)
	else:
		var phase: float = (local_progress - 0.5) / 0.5
		var ease_phase: float = 1.0 - pow(1.0 - phase, 2.5)
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(curve_direction), "swing_ratio": min(1.0, phase * 2.0)})
		var start_y: float = char_top - 8.0
		var end_y: float = preview_top + 5.0
		var curve_amount: float = 40.0 * sin(ease_phase * PI)
		var ball_pos := Vector2(center_x + curve_direction * curve_amount, start_y + (end_y - start_y) * ease_phase)
		for i in range(12):
			var t: float = max(0.0, ease_phase - float(i) * 0.07)
			if t <= 0.0:
				continue
			var trail_pos := Vector2(center_x + curve_direction * 40.0 * sin(t * PI), start_y + (end_y - start_y) * t)
			canvas.draw_circle(trail_pos, max(2.0, ball_radius - float(i) * 0.4), _rainbow_color(float(time_ms) * 0.003 + float(i) * 0.1))
		for i in range(4):
			canvas.draw_circle(ball_pos, ball_radius + 5.0 - float(i), _rainbow_color(float(time_ms) * 0.005 + float(i) * 0.1))
		canvas.draw_circle(ball_pos, ball_radius - 1.0, Color.WHITE)
		canvas.draw_circle(ball_pos + Vector2(-1.0, -1.0), 2.0, Color(1.0, 1.0, 230.0 / 255.0))


func _draw_smash_orange_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_progress: float = float(time_ms % 4500) / 4500.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var motion_type := "straight"
	var smash_direction := 0
	var key_text := ""
	var local_progress: float
	if cycle_progress < 0.333:
		motion_type = "left"
		smash_direction = -1
		key_text = "A"
		local_progress = cycle_progress / 0.333
	elif cycle_progress < 0.666:
		motion_type = "right"
		smash_direction = 1
		key_text = "D"
		local_progress = (cycle_progress - 0.333) / 0.333
	else:
		local_progress = (cycle_progress - 0.666) / 0.334
	var char_y: float = preview_bottom - 2.0
	var char_top: float = char_y - 18.0
	if local_progress < 0.3:
		var phase: float = local_progress / 0.3
		var ball_y: float = preview_top - 5.0 + (char_top - 8.0 - (preview_top - 5.0)) * phase
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": smash_direction})
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), 6.0)
		if phase > 0.4:
			canvas.draw_arc(Vector2(center_x, ball_y), 14.0 * (1.0 + 0.1 * sin(float(time_ms) * 0.015)), 0.0, TAU, 36, Color(1.0, 80.0 / 255.0, 80.0 / 255.0), 2.0)
	elif local_progress < 0.5:
		var ball_y: float = char_top - 8.0
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": smash_direction})
		canvas.draw_arc(Vector2(center_x, ball_y), 15.0 * (1.0 + 0.15 * sin(float(time_ms) * 0.02)), 0.0, TAU, 36, Color(1.0, 80.0 / 255.0, 80.0 / 255.0), 2.0)
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), 6.0)
		var keycap_x: float = center_x - 55.0
		var keycap_y: float = char_y - 8.0
		if motion_type != "straight":
			_draw_preview_keycap(canvas, Vector2(keycap_x, keycap_y), key_text)
			_draw_preview_plus(canvas, Vector2(keycap_x + 13.0, keycap_y))
			_draw_preview_mouse(canvas, Vector2(keycap_x + 23.0, keycap_y), true)
		else:
			_draw_preview_mouse(canvas, Vector2(keycap_x, keycap_y), true)
	else:
		var phase: float = (local_progress - 0.5) / 0.5
		var ease_phase: float = 1.0 - pow(1.0 - phase, 2.2)
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": smash_direction, "swing_ratio": min(1.0, phase * 2.0)})
		var start := Vector2(center_x, char_top - 8.0)
		var end := Vector2(center_x + float(smash_direction) * 54.0, preview_top + 5.0)
		if motion_type == "straight":
			end.x = center_x
		var ball_pos: Vector2 = start.lerp(end, ease_phase)
		for i in range(8):
			var t: float = max(0.0, ease_phase - float(i) * 0.1)
			if t <= 0.0:
				continue
			var trail_pos: Vector2 = start.lerp(end, t)
			canvas.draw_circle(trail_pos, max(2.0, 6.0 - float(i) * 0.6), Color(1.0, max(40.0, 150.0 - float(i) * 15.0) / 255.0, max(20.0, 60.0 - float(i) * 6.0) / 255.0))
		if phase < 0.6:
			for i in range(4):
				var line_t: float = max(0.0, ease_phase - float(i) * 0.12 - 0.05)
				if line_t <= 0.0:
					continue
				var line_pos: Vector2 = start.lerp(end, line_t)
				var dir_vec: Vector2 = (end - start).normalized()
				if motion_type == "straight":
					canvas.draw_line(line_pos, line_pos + Vector2(0.0, 12.0 * (1.0 - float(i) * 0.2)), Color(1.0, 200.0 / 255.0, 100.0 / 255.0), 1.0)
				else:
					canvas.draw_line(line_pos, line_pos - dir_vec * (12.0 * (1.0 - float(i) * 0.2)), Color(1.0, 200.0 / 255.0, 100.0 / 255.0), 1.0)
		_draw_preview_ball(canvas, ball_pos, 6.0, [Color(1.0, 80.0 / 255.0, 40.0 / 255.0), Color(1.0, 180.0 / 255.0, 70.0 / 255.0), Color(1.0, 245.0 / 255.0, 190.0 / 255.0)], Color(1.0, 220.0 / 255.0, 120.0 / 255.0))
		if phase < 0.25:
			canvas.draw_arc(start, 12.0 + phase * 35.0, 0.0, TAU, 36, Color(1.0, 140.0 / 255.0, 70.0 / 255.0), 2.0)


func _draw_magnetic_pull_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var ball_top_y: float = preview_top + 8.0
	if local_progress < 0.30:
		var phase: float = local_progress / 0.30
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		for ring_idx in range(3):
			canvas.draw_arc(p_center, p_radius * 1.6 + float(ring_idx) * 6.0 + phase * 14.0, 0.0, TAU, 36, _alpha(color, max(40.0, 180.0 * (1.0 - phase * 0.4) - float(ring_idx) * 35.0) / 255.0), 1.0)
		for spark_idx in range(8):
			var ang: float = TAU * float(spark_idx) / 8.0 + float(time_ms) * 0.005
			var sd: float = p_radius * 1.2 + sin(float(time_ms) * 0.01 + float(spark_idx)) * 3.0
			canvas.draw_circle(p_center + Vector2(cos(ang), sin(ang)) * sd, 2.0, _alpha(color, 200.0 / 255.0))
		_draw_preview_ball(canvas, Vector2(center_x, ball_top_y), 6.0, [color, Color(180.0 / 255.0, 230.0 / 255.0, 1.0), Color.WHITE], Color(1.0, 240.0 / 255.0, 180.0 / 255.0))
		_draw_preview_keycap(canvas, Vector2(center_x - 60.0, char_y - 8.0), "A")
		_draw_preview_keycap(canvas, Vector2(center_x - 36.0, char_y - 8.0), "D")
		_draw_preview_plus(canvas, Vector2(center_x - 48.0, char_y - 8.0))
	elif local_progress < 0.85:
		var phase: float = (local_progress - 0.30) / 0.55
		var ease: float = pow(phase, 1.5)
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var target := p_center + Vector2(0.0, -p_radius - 4.0)
		var ball_pos := Vector2(center_x + sin(phase * PI * 3.0) * (12.0 - phase * 10.0), ball_top_y + (target.y - ball_top_y) * ease)
		_draw_preview_keycap(canvas, Vector2(center_x - 12.0, float(metrics["top"]) + 14.0), "A")
		_draw_preview_keycap(canvas, Vector2(center_x + 12.0, float(metrics["top"]) + 14.0), "D")
		_draw_preview_plus(canvas, Vector2(center_x, float(metrics["top"]) + 14.0))
		for line_idx in range(5):
			var la: float = TAU * float(line_idx) / 5.0 + float(time_ms) * 0.006
			var start := p_center + Vector2(cos(la), sin(la)) * (p_radius + 2.0)
			var finish := ball_pos + Vector2(cos(la + PI), sin(la + PI)) * 6.0
			_draw_bezier_polyline(canvas, start, finish, 6.0, _alpha(color, max(60.0, 160.0 * (1.0 - phase * 0.4)) / 255.0), 2.0)
		for trail_idx in range(6):
			var t_t: float = max(0.0, ease - float(trail_idx) * 0.1)
			if t_t <= 0.0:
				continue
			var tx: float = center_x + sin(phase * PI * 3.0 - float(trail_idx) * 0.3) * (12.0 - t_t * 10.0)
			var ty: float = ball_top_y + (target.y - ball_top_y) * t_t
			canvas.draw_circle(Vector2(tx, ty), max(2.0, 5.0 - float(trail_idx)), _alpha(color, max(40.0, 180.0 - float(trail_idx) * 28.0) / 255.0))
		_draw_preview_ball(canvas, ball_pos, 6.0, [color, Color(180.0 / 255.0, 230.0 / 255.0, 1.0), Color.WHITE], Color(1.0, 240.0 / 255.0, 180.0 / 255.0))
	else:
		var phase: float = (local_progress - 0.85) / 0.15
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var burst := p_center + Vector2(0.0, -p_radius - 4.0)
		canvas.draw_arc(burst, p_radius * 1.4 + phase * 18.0, 0.0, TAU, 36, _alpha(color, max(60.0, 220.0 * (1.0 - phase)) / 255.0), 2.0)
		for spark_idx in range(8):
			var ang: float = TAU * float(spark_idx) / 8.0
			canvas.draw_line(burst, burst + Vector2(cos(ang), sin(ang)) * ((p_radius * 1.4 + phase * 18.0) * 0.7), _alpha(color, max(80.0, 220.0 * (1.0 - phase * 0.7)) / 255.0), 2.0)


func _draw_ghost_purple_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3500) / 3500.0
	var cycle_dir: float = -1.0 if int(time_ms / 3500) % 2 == 0 else 1.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	if local_progress < 0.30:
		var phase: float = local_progress / 0.30
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "paddle_lift": phase * 0.5})
		_draw_ghost_charge(canvas, anchors, color, phase, time_ms)
	elif local_progress < 0.50:
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "paddle_lift": 0.5})
		_draw_ghost_charge(canvas, anchors, color, 1.0, time_ms)
		var keycap := Vector2(center_x - 64.0, char_y - 8.0)
		_draw_preview_keycap(canvas, keycap, "A" if cycle_dir < 0.0 else "D")
		_draw_preview_plus(canvas, keycap + Vector2(13.0, 0.0))
		_draw_preview_mouse(canvas, keycap + Vector2(23.0, 0.0), true)
	else:
		var phase: float = (local_progress - 0.50) / 0.50
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(cycle_dir), "swing_ratio": min(1.0, phase * 1.6)})
		var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var start := p_center + Vector2(0.0, -p_radius - 4.0)
		var end_y: float = preview_top + 6.0
		var ease: float = 1.0 - pow(1.0 - phase, 2.5)
		var ball_pos := Vector2(start.x + sin(phase * PI * 5.0) * 18.0 * cycle_dir * ease, start.y + (end_y - start.y) * ease)
		for trail_idx in range(10):
			var t: float = max(0.0, ease - float(trail_idx) * 0.08)
			if t <= 0.0:
				continue
			var trail_pos := Vector2(start.x + sin(phase * PI * 5.0 - float(trail_idx) * 0.4) * 18.0 * cycle_dir * t, start.y + (end_y - start.y) * t)
			canvas.draw_circle(trail_pos, max(2.0, 6.0 - float(trail_idx) * 0.5), _alpha(color, max(40.0, 200.0 - float(trail_idx) * 18.0) / 255.0))
		var ghost_t: float = max(0.0, ease - 0.18)
		if ghost_t > 0.0:
			var ghost_pos := Vector2(start.x + sin(phase * PI * 5.0 - 0.9) * 18.0 * cycle_dir * ghost_t, start.y + (end_y - start.y) * ghost_t)
			_draw_small_ghost(canvas, ghost_pos, color, time_ms)
		_draw_preview_ball(canvas, ball_pos, 6.0, [color, Color(180.0 / 255.0, 110.0 / 255.0, 1.0), Color(235.0 / 255.0, 200.0 / 255.0, 1.0)], color)


func _draw_portal_purple_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3500) / 3500.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var portal_left := Vector2(preview_left + 14.0, char_y - 10.0)
	var portal_right := Vector2(preview_right - 14.0, char_y - 10.0)
	canvas.draw_line(Vector2(preview_left + 4.0, preview_top + 6.0), Vector2(preview_left + 4.0, preview_bottom - 4.0), Color(140.0 / 255.0, 110.0 / 255.0, 180.0 / 255.0, 60.0 / 255.0), 2.0)
	canvas.draw_line(Vector2(preview_right - 4.0, preview_top + 6.0), Vector2(preview_right - 4.0, preview_bottom - 4.0), Color(140.0 / 255.0, 110.0 / 255.0, 180.0 / 255.0, 60.0 / 255.0), 2.0)
	for side_idx in range(2):
		var portal: Vector2 = portal_left if side_idx == 0 else portal_right
		for ring_idx in range(3):
			var rx: float = 12.0 - float(ring_idx) * 3.0
			var ry: float = 18.0 - float(ring_idx) * 4.0
			_draw_ellipse(canvas, Rect2(portal - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), _alpha(color, max(80.0, 220.0 - float(ring_idx) * 50.0) / 255.0), false, 2.0)
		for swirl_idx in range(5):
			var spin_dir: float = 1.0 if side_idx == 0 else -1.0
			var ang: float = TAU * float(swirl_idx) / 5.0 + float(time_ms) * 0.006 * spin_dir
			canvas.draw_circle(portal + Vector2(cos(ang) * 8.0, sin(ang) * 12.0), 2.0, Color(1.0, 220.0 / 255.0, 1.0))
	_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
	_draw_preview_keycap_row(canvas, Vector2(center_x, preview_top + 14.0), ["A", "W", "D"], "arrow", int(time_ms / 600) % 3, color)
	var ball_pos: Vector2
	var ball_alpha := 1.0
	var ball_visible := true
	if local_progress < 0.40:
		var phase: float = local_progress / 0.40
		ball_pos = Vector2(center_x + phase * (portal_right.x - center_x), portal_right.y - 2.0)
	elif local_progress < 0.50:
		var phase: float = (local_progress - 0.40) / 0.10
		ball_pos = portal_right + Vector2(0.0, -2.0)
		ball_alpha = max(0.0, 1.0 - phase)
		ball_visible = ball_alpha > 0.0
		canvas.draw_arc(portal_right, 14.0 + phase * 8.0, 0.0, TAU, 36, _alpha(color, 0.70 * (1.0 - phase)), 2.0)
	elif local_progress < 0.60:
		var phase: float = (local_progress - 0.50) / 0.10
		ball_pos = portal_left + Vector2(0.0, -2.0)
		ball_alpha = min(1.0, phase)
		canvas.draw_arc(portal_left, 14.0 + phase * 8.0, 0.0, TAU, 36, _alpha(color, 0.70 * (1.0 - phase)), 2.0)
	else:
		var phase: float = (local_progress - 0.60) / 0.40
		ball_pos = Vector2(portal_left.x + phase * (center_x - portal_left.x), portal_left.y - 2.0)
	if ball_visible:
		_draw_preview_ball(canvas, ball_pos, 6.0, [_alpha(color, ball_alpha), _alpha(Color(235.0 / 255.0, 200.0 / 255.0, 1.0), ball_alpha), _alpha(Color.WHITE, ball_alpha)], _alpha(Color(235.0 / 255.0, 200.0 / 255.0, 1.0), ball_alpha))


func _draw_wheel_spin_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2400) / 2400.0
	var direction: float = -1.0 if local_progress < 0.5 else 1.0
	var phase: float = fposmod(local_progress, 0.5) * 2.0
	var eased: float = 0.5 - 0.5 * cos(phase * PI)
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 4.0
	var start_x: float = center_x - direction * 56.0
	var end_x: float = center_x + direction * 56.0
	var char_x: float = start_x + (end_x - start_x) * eased
	canvas.draw_line(Vector2(preview_left + 12.0, floor_y), Vector2(preview_right - 12.0, floor_y), Color(110.0 / 255.0, 80.0 / 255.0, 45.0 / 255.0, 55.0 / 255.0), 2.0)
	for stripe_idx in range(4):
		var stripe_y: float = preview_top + 14.0 + float(stripe_idx) * 16.0
		var stripe_offset: float = fposmod(phase * 40.0 + float(stripe_idx) * 9.0, 24.0)
		canvas.draw_line(Vector2(preview_left + stripe_offset, stripe_y), Vector2(preview_right - 8.0, stripe_y - direction * 2.0), Color(1.0, 170.0 / 255.0, 70.0 / 255.0, (30.0 + float(stripe_idx) * 8.0) / 255.0), 1.0)
	for trail_idx in range(5):
		var trail_t: float = max(0.0, eased - float(trail_idx) * 0.10)
		var tx: float = start_x + (end_x - start_x) * trail_t
		_draw_ellipse(canvas, Rect2(Vector2(tx - 23.0, floor_y - 30.0), Vector2(46.0, 30.0)), Color(1.0, 155.0 / 255.0, 58.0 / 255.0, max(18.0, 115.0 - float(trail_idx) * 18.0) / 255.0), false, max(1.0, 3.0 - float(trail_idx) * 0.4))
	var spin: float = phase * TAU * 3.0 * direction
	for ring_idx in range(3):
		var rx: float = 28.0 + float(ring_idx) * 7.0
		var ry: float = 16.0 + float(ring_idx) * 4.0
		var ring_center := Vector2(char_x, floor_y - 44.0)
		_draw_ellipse_arc(canvas, Rect2(ring_center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), spin + float(ring_idx) * 0.8, spin + float(ring_idx) * 0.8 + deg_to_rad(235.0), Color(1.0, 214.0 / 255.0, 116.0 / 255.0, max(70.0, 170.0 - float(ring_idx) * 38.0) / 255.0), max(2.0, 4.0 - float(ring_idx)))
	_draw_smasher_mini_character(canvas, char_x, floor_y + 1.0, {"block": 4.0, "direction": int(direction), "swing_ratio": 0.6, "rotation": -spin * 0.28, "rotation_center": Vector2(char_x, floor_y - 28.0)})
	var hit_t: float = clamp((phase - 0.38) / 0.62, 0.0, 1.0)
	var ball_start := Vector2(char_x + direction * 18.0, floor_y - 30.0)
	var ball_end := Vector2(center_x + direction * 42.0, preview_top + 8.0)
	var ball_pos: Vector2 = ball_start.lerp(ball_end, hit_t)
	for trail_idx in range(7):
		var t: float = max(0.0, hit_t - float(trail_idx) * 0.08)
		if t <= 0.0:
			continue
		canvas.draw_circle(ball_start.lerp(ball_end, t), max(2.0, 6.0 - float(trail_idx) * 0.5), Color(1.0, 180.0 / 255.0, 64.0 / 255.0, max(40.0, 160.0 - float(trail_idx) * 18.0) / 255.0))
	_draw_preview_ball(canvas, ball_pos, 6.0, [Color(1.0, 120.0 / 255.0, 40.0 / 255.0), Color(1.0, 190.0 / 255.0, 78.0 / 255.0), Color(1.0, 245.0 / 255.0, 190.0 / 255.0)])
	_draw_preview_keycap_row(canvas, Vector2(center_x, preview_top + 14.0), ["A" if direction < 0.0 else "D", "A" if direction < 0.0 else "D", "A" if direction < 0.0 else "D"], "arrow", min(2, int(phase * 3.0)), color)


func _preview_metrics(rect: Rect2) -> Dictionary:
	var center: Vector2 = rect.get_center()
	return {
		"center_x": center.x,
		"center_y": center.y,
		"left": center.x - 118.0,
		"right": center.x + 118.0,
		"top": center.y - 42.0,
		"bottom": center.y + 42.0,
	}


func _draw_smasher_mini_character(canvas: CanvasItem, cx: float, cy: float, options: Dictionary = {}) -> Dictionary:
	var b: float = float(options.get("block", 4.0))
	var direction: int = int(options.get("direction", 0))
	var swing_ratio: float = float(options.get("swing_ratio", 0.0))
	var head_offset_y: float = float(options.get("head_offset_y", 0.0))
	var show_paddle: bool = bool(options.get("show_paddle", true))
	var show_shield: bool = bool(options.get("show_shield", true))
	var paddle_lift: float = float(options.get("paddle_lift", 0.0))
	var alpha: float = float(options.get("alpha", 1.0))
	var tint: Color = _get_color(options.get("tint", Color.WHITE), Color.WHITE)
	var rotation: float = float(options.get("rotation", 0.0))
	var rotation_center: Vector2 = _get_vector2(options, "rotation_center", Vector2(cx, cy - 28.0))
	var torso_y: float = cy - 1.5 * b
	var arm_swing: float = swing_ratio * 1.2 * b
	var palette: Dictionary = _smasher_palette(alpha, tint)

	var helmet_rect := Rect2(Vector2(cx - 2.7 * b * 0.5, torso_y - 3.1 * b + head_offset_y), Vector2(2.7 * b, 2.2 * b))
	_draw_ellipse_xf(canvas, helmet_rect, palette["helmet"], true, 1.0, rotation, rotation_center)
	_draw_ellipse_xf(canvas, Rect2(Vector2(helmet_rect.position.x - 0.5 * b, helmet_rect.get_center().y - 0.5 * b), Vector2(0.8 * b, 1.4 * b)), palette["helmet_side"], true, 1.0, rotation, rotation_center)
	_draw_ellipse_xf(canvas, Rect2(Vector2(helmet_rect.end.x - 0.3 * b, helmet_rect.get_center().y - 0.5 * b), Vector2(0.8 * b, 1.4 * b)), palette["helmet_side"], true, 1.0, rotation, rotation_center)
	var visor_rect := Rect2(Vector2(cx - 0.9 * b, helmet_rect.get_center().y - 0.1 * b), Vector2(1.8 * b, 0.9 * b))
	_draw_ellipse_xf(canvas, visor_rect, palette["visor"], true, 1.0, rotation, rotation_center)
	_draw_ellipse_xf(canvas, visor_rect.grow_individual(-0.4 * b, -0.3 * b, -0.4 * b, -0.3 * b), palette["visor_core"], true, 1.0, rotation, rotation_center)
	_draw_ellipse_xf(canvas, helmet_rect.grow_individual(-0.6 * b, -0.5 * b, -0.6 * b, -0.5 * b), palette["helmet_high"], false, 1.0, rotation, rotation_center)
	_draw_rect_xf(canvas, Rect2(Vector2(cx - 0.2 * b, helmet_rect.position.y + 0.2 * b), Vector2(max(1.0, 0.4 * b), 1.5 * b)), palette["helmet_high"], rotation, rotation_center)

	var chest_rect := Rect2(Vector2(cx - 3.4 * b * 0.5, torso_y - 0.4 * b), Vector2(3.4 * b, 2.2 * b))
	_draw_rect_xf(canvas, chest_rect, palette["armor_outer"], rotation, rotation_center)
	var mid_rect: Rect2 = chest_rect.grow_individual(-0.5 * b, -0.4 * b, -0.5 * b, -0.4 * b)
	_draw_rect_xf(canvas, mid_rect, palette["armor_mid"], rotation, rotation_center)
	var inner_panel: Rect2 = mid_rect.grow_individual(-0.5 * b, -0.3 * b, -0.5 * b, -0.3 * b)
	_draw_rect_xf(canvas, inner_panel, palette["armor_inner"], rotation, rotation_center)
	_draw_rect_outline_xf(canvas, chest_rect, palette["trim"], 1.0, rotation, rotation_center)
	_draw_line_xf(canvas, Vector2(cx, inner_panel.position.y + 0.2 * b), Vector2(cx, inner_panel.end.y - 0.2 * b), palette["accent"], max(1.0, 0.15 * b), rotation, rotation_center)

	var abs_rect := Rect2(Vector2(cx - 1.1 * b, inner_panel.end.y - 0.1 * b), Vector2(2.2 * b, 1.2 * b))
	_draw_rect_xf(canvas, abs_rect, palette["undersuit"], rotation, rotation_center)
	var belt_rect := Rect2(Vector2(cx - 1.8 * b, abs_rect.end.y - 0.1 * b), Vector2(3.6 * b, 0.7 * b))
	_draw_rect_xf(canvas, belt_rect, palette["belt"], rotation, rotation_center)

	var left_pauldron := [Vector2(cx - 2.0 * b, torso_y - 0.4 * b), Vector2(cx - 1.1 * b, torso_y - 0.8 * b), Vector2(cx - 0.8 * b, torso_y + 0.7 * b), Vector2(cx - 1.9 * b, torso_y + 0.8 * b)]
	var right_pauldron := [Vector2(cx + 2.0 * b, torso_y - 0.4 * b), Vector2(cx + 1.1 * b, torso_y - 0.8 * b), Vector2(cx + 0.8 * b, torso_y + 0.7 * b), Vector2(cx + 1.9 * b, torso_y + 0.8 * b)]
	_draw_poly_xf(canvas, left_pauldron, palette["armor_mid"], rotation, rotation_center)
	_draw_poly_xf(canvas, right_pauldron, palette["armor_mid"], rotation, rotation_center)
	_draw_line_xf(canvas, left_pauldron[0], left_pauldron[1], palette["trim"], 1.0, rotation, rotation_center)
	_draw_line_xf(canvas, right_pauldron[0], right_pauldron[1], palette["trim"], 1.0, rotation, rotation_center)

	var left_shoulder := Vector2(cx - 1.6 * b, torso_y)
	var left_offset: float = arm_swing if direction == -1 else 0.0
	var left_elbow := Vector2(left_shoulder.x - 0.9 * b - left_offset, torso_y + 0.1 * b)
	var left_wrist := Vector2(left_elbow.x - 0.7 * b - left_offset, torso_y - 0.3 * b - (0.8 * b if direction == -1 and swing_ratio > 0.0 else 0.0))
	var right_shoulder := Vector2(cx + 1.6 * b, torso_y)
	var right_offset: float = arm_swing if direction == 1 else 0.0
	var right_elbow := Vector2(right_shoulder.x + 0.9 * b + right_offset, torso_y + 0.1 * b)
	var right_wrist := Vector2(right_elbow.x + 0.7 * b + right_offset, torso_y - 0.3 * b - (0.8 * b if direction == 1 and swing_ratio > 0.0 else 0.0))

	for limb in [[left_shoulder, left_elbow], [left_elbow, left_wrist], [right_shoulder, right_elbow], [right_elbow, right_wrist]]:
		_draw_line_xf(canvas, limb[0], limb[1], palette["arm_light"], max(2.0, 0.8 * b), rotation, rotation_center)
		_draw_line_xf(canvas, limb[0], limb[1], palette["armor_mid"], max(1.0, 0.55 * b), rotation, rotation_center)
	_draw_circle_xf(canvas, left_wrist, max(2.0, 0.4 * b), palette["glove"], rotation, rotation_center)
	_draw_circle_xf(canvas, right_wrist, max(2.0, 0.4 * b), palette["glove"], rotation, rotation_center)

	if show_shield:
		var shield_center := right_wrist + Vector2(0.5 * b, -0.3 * b)
		_draw_preview_pentagon_xf(canvas, shield_center, 1.8 * b * 1.1, -90.0, palette["shield_glow"], rotation, rotation_center)
		_draw_preview_pentagon_xf(canvas, shield_center, 1.8 * b, -90.0, Color(0.0, 0.0, 0.0, 0.0), rotation, rotation_center, palette["shield_ring"], max(1.0, 0.3 * b))
		_draw_preview_pentagon_xf(canvas, shield_center, 1.8 * b * 0.5, -90.0, palette["shield_core"], rotation, rotation_center)

	var paddle_pos: Dictionary = {}
	if show_paddle:
		var handle_end := left_wrist + Vector2(-0.3 * b, -1.0 * b - (0.5 * b if swing_ratio > 0.0 else 0.0) - paddle_lift * 4.0)
		_draw_line_xf(canvas, left_wrist, handle_end, palette["handle"], max(2.0, 0.35 * b), rotation, rotation_center)
		var paddle_center := handle_end + Vector2(-0.8 * b, -0.3 * b)
		var paddle_r: float = 1.5 * b
		_draw_circle_xf(canvas, paddle_center + Vector2(1.0, 1.0), paddle_r, palette["paddle_shadow"], rotation, rotation_center)
		_draw_circle_xf(canvas, paddle_center, paddle_r, palette["paddle"], rotation, rotation_center)
		_draw_circle_xf(canvas, paddle_center, max(1.0, paddle_r - 0.25 * b), palette["paddle_core"], rotation, rotation_center)
		paddle_pos = {"center": _rotate_point(paddle_center, rotation, rotation_center), "radius": paddle_r}

	return {
		"char_top": cy - 4.5 * b,
		"helmet_top": _rotate_point(Vector2(cx, helmet_rect.position.y), rotation, rotation_center).y,
		"left_wrist": _rotate_point(left_wrist, rotation, rotation_center),
		"right_wrist": _rotate_point(right_wrist, rotation, rotation_center),
		"paddle_pos": paddle_pos,
	}


func _smasher_palette(alpha: float, tint: Color) -> Dictionary:
	return {
		"helmet": _tint(Color(70.0 / 255.0, 102.0 / 255.0, 162.0 / 255.0, alpha), tint),
		"helmet_side": _tint(Color(58.0 / 255.0, 82.0 / 255.0, 136.0 / 255.0, alpha), tint),
		"helmet_high": _tint(Color(148.0 / 255.0, 182.0 / 255.0, 236.0 / 255.0, alpha), tint),
		"visor": _tint(Color(170.0 / 255.0, 224.0 / 255.0, 1.0, alpha), tint),
		"visor_core": _tint(Color(126.0 / 255.0, 192.0 / 255.0, 246.0 / 255.0, alpha), tint),
		"armor_outer": _tint(Color(80.0 / 255.0, 96.0 / 255.0, 150.0 / 255.0, alpha), tint),
		"armor_mid": _tint(Color(60.0 / 255.0, 76.0 / 255.0, 120.0 / 255.0, alpha), tint),
		"armor_inner": _tint(Color(46.0 / 255.0, 58.0 / 255.0, 92.0 / 255.0, alpha), tint),
		"trim": _tint(Color(190.0 / 255.0, 206.0 / 255.0, 236.0 / 255.0, alpha), tint),
		"accent": _tint(Color(118.0 / 255.0, 214.0 / 255.0, 1.0, alpha), tint),
		"undersuit": _tint(Color(36.0 / 255.0, 40.0 / 255.0, 58.0 / 255.0, alpha), tint),
		"arm_light": _tint(Color(132.0 / 255.0, 152.0 / 255.0, 204.0 / 255.0, alpha), tint),
		"glove": _tint(Color(198.0 / 255.0, 182.0 / 255.0, 164.0 / 255.0, alpha), tint),
		"paddle": _tint(Color(220.0 / 255.0, 56.0 / 255.0, 74.0 / 255.0, alpha), tint),
		"paddle_core": _tint(Color(244.0 / 255.0, 116.0 / 255.0, 132.0 / 255.0, alpha), tint),
		"paddle_shadow": _tint(Color(154.0 / 255.0, 42.0 / 255.0, 58.0 / 255.0, alpha), tint),
		"handle": _tint(Color(174.0 / 255.0, 132.0 / 255.0, 98.0 / 255.0, alpha), tint),
		"belt": _tint(Color(88.0 / 255.0, 78.0 / 255.0, 108.0 / 255.0, alpha), tint),
		"shield_glow": _tint(Color(70.0 / 255.0, 160.0 / 255.0, 1.0, alpha), tint),
		"shield_ring": _tint(Color(120.0 / 255.0, 210.0 / 255.0, 1.0, alpha), tint),
		"shield_core": _tint(Color(200.0 / 255.0, 252.0 / 255.0, 1.0, alpha), tint),
	}


func _draw_blue_energy_ball(canvas: CanvasItem, pos: Vector2, radius: float) -> void:
	for i in range(3):
		canvas.draw_circle(pos, radius + 3.0 - float(i), Color((30.0 + float(i) * 15.0) / 255.0, (80.0 + float(i) * 25.0) / 255.0, (180.0 + float(i) * 15.0) / 255.0))
	canvas.draw_circle(pos, radius, Color(100.0 / 255.0, 180.0 / 255.0, 1.0))
	canvas.draw_circle(pos + Vector2(-1.0, -1.0), 2.0, Color(200.0 / 255.0, 235.0 / 255.0, 1.0))


func _draw_preview_ball(canvas: CanvasItem, pos: Vector2, radius: float = 6.0, glow_colors: Array = [], core_color: Color = Color.WHITE) -> void:
	var colors: Array = glow_colors
	if colors.is_empty():
		colors = [Color(36.0 / 255.0, 92.0 / 255.0, 210.0 / 255.0), Color(88.0 / 255.0, 164.0 / 255.0, 1.0), Color(220.0 / 255.0, 242.0 / 255.0, 1.0)]
	for idx in range(colors.size()):
		var c: Color = _get_color(colors[idx], Color.WHITE)
		canvas.draw_circle(pos, radius + float(colors.size() - idx) * 2.0, _alpha(c, min(1.0, (48.0 + float(idx) * 36.0) / 255.0)))
	canvas.draw_circle(pos, radius, core_color)
	canvas.draw_circle(pos + Vector2(-1.0, -1.0), max(1.0, radius / 3.0), Color.WHITE)


func _draw_preview_keycap_row(canvas: CanvasItem, center: Vector2, letters: Array, separator: String = "plus", active_idx: int = -1, accent_color: Color = Color.WHITE) -> void:
	if letters.is_empty():
		return
	var keycap_w := 16.0
	var sep_w := 8.0
	var total_w: float = float(letters.size()) * keycap_w + max(0.0, float(letters.size() - 1)) * sep_w
	var start_x: float = center.x - total_w * 0.5 + keycap_w * 0.5
	for i in range(letters.size()):
		var kx: float = start_x + float(i) * (keycap_w + sep_w)
		_draw_preview_keycap(canvas, Vector2(kx, center.y), str(letters[i]))
		if active_idx == i:
			_draw_round_rect_outline(canvas, Rect2(Vector2(kx - 9.0, center.y - 8.0), Vector2(18.0, 16.0)), _alpha(accent_color, 220.0 / 255.0), 3.0, 1.0)
		if i < letters.size() - 1:
			var sx: float = kx + keycap_w * 0.5 + sep_w * 0.5
			if separator == "arrow":
				_draw_preview_arrow(canvas, Vector2(sx, center.y))
			else:
				_draw_preview_plus(canvas, Vector2(sx, center.y))


func _draw_preview_keycap(canvas: CanvasItem, center: Vector2, letter: String) -> void:
	var rect := Rect2(center - Vector2(8.0, 7.0), Vector2(16.0, 14.0))
	_draw_round_rect(canvas, rect, Color(25.0 / 255.0, 30.0 / 255.0, 40.0 / 255.0), 3.0)
	_draw_round_rect_outline(canvas, rect, Color(70.0 / 255.0, 75.0 / 255.0, 85.0 / 255.0), 3.0, 1.0)
	_draw_round_rect(canvas, Rect2(rect.position + Vector2(2.0, 2.0), Vector2(12.0, 8.0)), Color(45.0 / 255.0, 50.0 / 255.0, 60.0 / 255.0), 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var size := 9
		var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
		canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color.WHITE)


func _draw_preview_mouse(canvas: CanvasItem, center: Vector2, button_left: bool = true) -> void:
	var rect := Rect2(center + Vector2(-5.0, -6.0), Vector2(10.0, 14.0))
	_draw_round_rect(canvas, rect, Color(35.0 / 255.0, 40.0 / 255.0, 50.0 / 255.0), 3.0)
	_draw_round_rect_outline(canvas, rect, Color(75.0 / 255.0, 80.0 / 255.0, 90.0 / 255.0), 3.0, 1.0)
	_draw_round_rect(canvas, Rect2(center + Vector2(-4.0, -5.0), Vector2(4.0, 5.0)), Color(1.0, 200.0 / 255.0, 80.0 / 255.0) if button_left else Color(55.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0), 1.0)
	_draw_round_rect(canvas, Rect2(center + Vector2(0.0, -5.0), Vector2(4.0, 5.0)), Color(55.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0) if button_left else Color(1.0, 200.0 / 255.0, 80.0 / 255.0), 1.0)
	canvas.draw_line(center + Vector2(-1.0, -5.0), center + Vector2(-1.0, 3.0), Color(45.0 / 255.0, 50.0 / 255.0, 60.0 / 255.0), 1.0)


func _draw_preview_plus(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0), 1.0)
	canvas.draw_line(center + Vector2(0.0, -3.0), center + Vector2(0.0, 3.0), Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0), 1.0)


func _draw_preview_arrow(canvas: CanvasItem, center: Vector2) -> void:
	var c := Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0)
	canvas.draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), c, 1.0)
	canvas.draw_line(center + Vector2(1.0, -2.0), center + Vector2(3.0, 0.0), c, 1.0)
	canvas.draw_line(center + Vector2(1.0, 2.0), center + Vector2(3.0, 0.0), c, 1.0)


func _draw_ghost_charge(canvas: CanvasItem, anchors: Dictionary, color: Color, phase: float, time_ms: int) -> void:
	var paddle: Dictionary = _get_dictionary(anchors.get("paddle_pos", {}))
	if paddle.is_empty():
		return
	var p_center: Vector2 = _get_vector2(paddle, "center", Vector2.ZERO)
	var p_radius: float = float(paddle.get("radius", 6.0))
	var charge := p_center + Vector2(0.0, -p_radius - 6.0)
	var pulse: float = 1.0 + 0.18 * sin(float(time_ms) * 0.025)
	var core_r: float = max(2.0, (3.0 + phase * 5.0) * pulse)
	for ring_idx in range(4):
		canvas.draw_arc(charge, core_r + float(ring_idx) * 3.0, 0.0, TAU, 36, _alpha(color, max(30.0, (150.0 - float(ring_idx) * 30.0) * phase) / 255.0), 1.0)
	canvas.draw_circle(charge, core_r, color)
	canvas.draw_circle(charge + Vector2(-1.0, -1.0), max(1.0, core_r * 0.5), Color(235.0 / 255.0, 200.0 / 255.0, 1.0))
	for ghost_idx in range(3):
		var ga: float = TAU * float(ghost_idx) / 3.0 + float(time_ms) * 0.004
		var gd: float = 12.0 + sin(float(time_ms) * 0.008 + float(ghost_idx)) * 3.0
		var gpos: Vector2 = charge + Vector2(cos(ga), sin(ga)) * gd
		canvas.draw_circle(gpos, 3.0, _alpha(color, 160.0 / 255.0))
		canvas.draw_circle(gpos + Vector2(0.0, -1.0), 2.0, Color(220.0 / 255.0, 200.0 / 255.0, 1.0))


func _draw_small_ghost(canvas: CanvasItem, pos: Vector2, color: Color, time_ms: int) -> void:
	canvas.draw_circle(pos + Vector2(0.0, -4.0), 7.0, _alpha(color, 200.0 / 255.0))
	canvas.draw_circle(pos + Vector2(-2.0, -6.0), 2.0, Color(220.0 / 255.0, 200.0 / 255.0, 1.0, 200.0 / 255.0))
	canvas.draw_circle(pos + Vector2(2.0, -6.0), 2.0, Color(220.0 / 255.0, 200.0 / 255.0, 1.0, 200.0 / 255.0))
	canvas.draw_line(pos + Vector2(-2.0, -1.0), pos + Vector2(2.0, -1.0), Color(40.0 / 255.0, 0.0, 60.0 / 255.0), 1.0)
	for tail_idx in range(3):
		var tx: float = pos.x + sin(float(time_ms) * 0.005 + float(tail_idx)) * 3.0
		var ty: float = pos.y + 4.0 + float(tail_idx) * 4.0
		canvas.draw_circle(Vector2(tx, ty), max(2.0, 6.0 - float(tail_idx)), _alpha(color, max(40.0, 140.0 - float(tail_idx) * 35.0) / 255.0))


func _draw_bezier_polyline(canvas: CanvasItem, start: Vector2, finish: Vector2, lift: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for s in range(7):
		var t: float = float(s) / 6.0
		points.append(start.lerp(finish, t) + Vector2(0.0, sin(t * PI) * lift))
	canvas.draw_polyline(points, color, width)


func _draw_mini_star_gd(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(5):
		var outer_angle: float = deg_to_rad(-90.0 + float(i) * 72.0)
		var inner_angle: float = deg_to_rad(-90.0 + float(i) * 72.0 + 36.0)
		points.append(center + Vector2(cos(outer_angle), sin(outer_angle)) * size)
		points.append(center + Vector2(cos(inner_angle), sin(inner_angle)) * size * 0.4)
	canvas.draw_colored_polygon(points, color)


func _draw_preview_pentagon(canvas: CanvasItem, center: Vector2, radius: float, rotation_deg: float, fill_color: Color, outline_color: Color = Color(0.0, 0.0, 0.0, 0.0), outline_width: float = 0.0) -> void:
	_draw_preview_pentagon_xf(canvas, center, radius, rotation_deg, fill_color, 0.0, center, outline_color, outline_width)


func _draw_preview_pentagon_xf(canvas: CanvasItem, center: Vector2, radius: float, rotation_deg: float, fill_color: Color, rotation: float, rotation_center: Vector2, outline_color: Color = Color(0.0, 0.0, 0.0, 0.0), outline_width: float = 0.0) -> void:
	var points := PackedVector2Array()
	for i in range(5):
		var angle: float = deg_to_rad(rotation_deg + float(i) * 72.0)
		points.append(_rotate_point(center + Vector2(cos(angle), sin(angle)) * radius, rotation, rotation_center))
	if fill_color.a > 0.0:
		canvas.draw_colored_polygon(points, fill_color)
	if outline_width > 0.0 and outline_color.a > 0.0:
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		canvas.draw_polyline(outline, outline_color, outline_width)


func _draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	var points := _ellipse_points(rect, 32)
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		canvas.draw_polyline(points, color, width)


func _draw_ellipse_xf(canvas: CanvasItem, rect: Rect2, color: Color, filled: bool, width: float, rotation: float, rotation_center: Vector2) -> void:
	var points := _ellipse_points(rect, 32)
	for i in range(points.size()):
		points[i] = _rotate_point(points[i], rotation, rotation_center)
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		canvas.draw_polyline(points, color, width)


func _draw_ellipse_arc(canvas: CanvasItem, rect: Rect2, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var rx: float = rect.size.x * 0.5
	var ry: float = rect.size.y * 0.5
	for i in range(28):
		var t: float = float(i) / 27.0
		var angle: float = start_angle + (end_angle - start_angle) * t
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_polyline(points, color, width)


func _ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var rx: float = rect.size.x * 0.5
	var ry: float = rect.size.y * 0.5
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _draw_rect_xf(canvas: CanvasItem, rect: Rect2, color: Color, rotation: float, rotation_center: Vector2) -> void:
	_draw_poly_xf(canvas, [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], color, rotation, rotation_center)


func _draw_rect_outline_xf(canvas: CanvasItem, rect: Rect2, color: Color, width: float, rotation: float, rotation_center: Vector2) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
	for i in range(points.size()):
		points[i] = _rotate_point(points[i], rotation, rotation_center)
	canvas.draw_polyline(points, color, width)


func _draw_poly_xf(canvas: CanvasItem, points_array: Array, color: Color, rotation: float, rotation_center: Vector2) -> void:
	var points := PackedVector2Array()
	for p in points_array:
		if p is Vector2:
			points.append(_rotate_point(p, rotation, rotation_center))
	canvas.draw_colored_polygon(points, color)


func _draw_line_xf(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, width: float, rotation: float, rotation_center: Vector2) -> void:
	canvas.draw_line(_rotate_point(start, rotation, rotation_center), _rotate_point(finish, rotation, rotation_center), color, width)


func _draw_circle_xf(canvas: CanvasItem, center: Vector2, radius: float, color: Color, rotation: float, rotation_center: Vector2) -> void:
	canvas.draw_circle(_rotate_point(center, rotation, rotation_center), radius, color)


func _rotate_point(point: Vector2, angle: float, pivot: Vector2) -> Vector2:
	if is_zero_approx(angle):
		return point
	return pivot + (point - pivot).rotated(angle)


func _draw_round_rect(canvas: CanvasItem, rect: Rect2, color: Color, corner_radius: float) -> void:
	_draw_panel(canvas, rect, color, Color(0.0, 0.0, 0.0, 0.0), 0.0, corner_radius)


func _draw_round_rect_outline(canvas: CanvasItem, rect: Rect2, color: Color, corner_radius: float, width: float) -> void:
	_draw_panel(canvas, rect, Color(0.0, 0.0, 0.0, 0.0), color, width, corner_radius)


func _rainbow_color(t: float) -> Color:
	return Color.from_hsv(fposmod(t, 1.0), 1.0, 1.0)


func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))


func _tint(color: Color, tint: Color) -> Color:
	return Color(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a)


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


func _get_control_rows(skill_name: String, character_type: String = "smasher") -> Array:
	var rows: Variant = VIPER_CONTROL_ROWS.get(skill_name, []) if character_runtime.is_viper(character_type) else CONTROL_ROWS.get(skill_name, [])
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
