extends RefCounted

const CARD_RADIUS := 8.0
const PANEL_RADIUS := 8.0


func draw(canvas: CanvasItem, runtime_state: Object, catalog: Object, view_size: Vector2, icon_renderer: Object = null) -> void:
	if canvas == null or runtime_state == null or not runtime_state.has_method("is_choice_active"):
		return
	if not bool(runtime_state.is_choice_active()):
		_draw_feedback(canvas, runtime_state, view_size)
		return

	var snapshot: Dictionary = runtime_state.get_snapshot()
	var choices: Array = _get_array(snapshot.get("current_choices", []))
	if choices.is_empty():
		return

	var selected_index: int = int(snapshot.get("selected_index", 0))
	var layout: Dictionary = runtime_state.build_layout(view_size)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.62))
	_draw_particles(canvas, snapshot)
	_draw_title(canvas, _get_vector2(layout.get("title_pos", Vector2.ZERO)), float(snapshot.get("animation_time", 0.0)))
	_draw_cards(canvas, runtime_state, choices, selected_index, view_size, float(snapshot.get("animation_time", 0.0)), icon_renderer)
	_draw_description(canvas, choices, selected_index, _get_rect2(layout.get("desc_rect", Rect2())))
	_draw_status_panel(canvas, snapshot, catalog, _get_rect2(layout.get("panel_rect", Rect2())), icon_renderer)
	_draw_pending_hint(canvas, snapshot, _get_vector2(layout.get("hint_pos", Vector2.ZERO)), runtime_state)
	_draw_feedback(canvas, runtime_state, view_size)


func _draw_title(canvas: CanvasItem, center: Vector2, animation_time: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var alpha: float = clamp(animation_time / 0.22, 0.0, 1.0)
	var title := "SKILL UP!"
	var size := 34
	var text_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var pos := center - Vector2(text_size.x * 0.5, text_size.y * 0.28)
	for glow in range(4, 0, -1):
		canvas.draw_string(
			font,
			pos + Vector2(float(glow), float(glow)) * 0.55,
			title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			size,
			Color(1.0, 190.0 / 255.0, 70.0 / 255.0, alpha * 0.11 * float(glow))
		)
	canvas.draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(1.0, 220.0 / 255.0, 100.0 / 255.0, alpha))


func _draw_cards(canvas: CanvasItem, runtime_state: Object, choices: Array, selected_index: int, view_size: Vector2, animation_time: float, icon_renderer: Object) -> void:
	var rects: Array = runtime_state.get_card_rects(view_size)
	for index in range(min(choices.size(), rects.size())):
		var choice: Dictionary = _get_dict(choices[index])
		var rect: Rect2 = rects[index]
		var selected: bool = index == selected_index
		_draw_card(canvas, choice, rect, selected, animation_time, icon_renderer)


func _draw_card(canvas: CanvasItem, choice: Dictionary, rect: Rect2, selected: bool, animation_time: float, icon_renderer: Object) -> void:
	var icon_color: Color = _get_color(choice.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
	var rarity: String = str(choice.get("rarity", "common"))
	var is_unique: bool = bool(choice.get("is_unique", false)) or rarity == "legendary"
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var alpha: float = clamp(animation_time / 0.24, 0.0, 1.0)

	if selected:
		var glow_color: Color = Color(icon_color.r, icon_color.g, icon_color.b, 0.20 + 0.18 * pulse)
		for grow in [10.0, 6.0, 3.0]:
			canvas.draw_rect(rect.grow(grow), glow_color, false, max(1.0, 6.0 - grow * 0.35))
	elif is_unique:
		canvas.draw_rect(rect.grow(5.0), Color(1.0, 210.0 / 255.0, 40.0 / 255.0, 0.18 + 0.12 * pulse), false, 2.0)

	var bg: Color = Color(25.0 / 255.0, 30.0 / 255.0, 50.0 / 255.0, 0.86 * alpha)
	if selected:
		bg = Color(40.0 / 255.0, 50.0 / 255.0, 90.0 / 255.0, 0.94 * alpha)
	elif is_unique:
		bg = Color(45.0 / 255.0, 38.0 / 255.0, 20.0 / 255.0, 0.90 * alpha)
	canvas.draw_rect(rect, bg)

	var border_color: Color = icon_color if selected else Color(60.0 / 255.0, 70.0 / 255.0, 90.0 / 255.0, alpha)
	if is_unique:
		border_color = Color(1.0, 215.0 / 255.0, 0.0, alpha)
	canvas.draw_rect(rect, border_color, false, 3.0 if selected else 2.0)
	_draw_character_edge(canvas, rect, str(choice.get("character_restriction", "")), alpha, pulse)

	var icon_margin: float = max(10.0, rect.size.y * 0.13)
	var icon_size: float = rect.size.y - icon_margin * 2.0
	var icon_rect := Rect2(rect.position + Vector2(12.0, icon_margin), Vector2(icon_size, icon_size))
	canvas.draw_rect(icon_rect, Color(15.0 / 255.0, 19.0 / 255.0, 31.0 / 255.0, 0.92 * alpha))
	canvas.draw_rect(icon_rect, Color(icon_color.r, icon_color.g, icon_color.b, 0.70 * alpha), false, 2.0)
	_draw_icon(canvas, icon_renderer, choice, icon_rect, alpha)

	var text_x: float = icon_rect.end.x + 10.0
	var name := str(choice.get("name", "Unknown"))
	var max_chars := 7
	if name.length() > max_chars:
		name = name.substr(0, max_chars)
	var name_color: Color = Color(1.0, 215.0 / 255.0, 0.0, alpha) if is_unique else Color(1.0, 1.0, 1.0, alpha)
	_draw_text(canvas, name, Vector2(text_x, rect.position.y + rect.size.y * 0.38), 17, name_color)
	_draw_text(canvas, _level_text(choice), Vector2(text_x, rect.position.y + rect.size.y * 0.67), 14, _level_color(choice, is_unique, alpha))

	if str(choice.get("unlocks_skill", "")) != "":
		var badge_rect := Rect2(rect.end - Vector2(33.0, 27.0), Vector2(24.0, 18.0))
		canvas.draw_rect(badge_rect, Color(18.0 / 255.0, 32.0 / 255.0, 42.0 / 255.0, 0.92 * alpha))
		canvas.draw_rect(badge_rect, Color(icon_color.r, icon_color.g, icon_color.b, 0.82 * alpha), false, 1.0)
		_draw_text_centered(canvas, "A", badge_rect.get_center() + Vector2(0.0, 1.0), 12, Color(1.0, 1.0, 1.0, alpha))


func _draw_character_edge(canvas: CanvasItem, rect: Rect2, restriction: String, alpha: float, pulse: float) -> void:
	if restriction == "":
		return
	var color := Color(0.0, 200.0 / 255.0, 1.0, (0.26 + 0.18 * pulse) * alpha)
	if restriction == "viper":
		color = Color(200.0 / 255.0, 80.0 / 255.0, 1.0, (0.24 + 0.18 * pulse) * alpha)
	canvas.draw_rect(rect.grow(3.0), color, false, 1.5)
	canvas.draw_line(rect.position + Vector2(9.0, 5.0), rect.position + Vector2(36.0, 5.0), color, 2.0)
	canvas.draw_line(rect.end - Vector2(36.0, 5.0), rect.end - Vector2(9.0, 5.0), color, 2.0)


func _draw_description(canvas: CanvasItem, choices: Array, selected_index: int, rect: Rect2) -> void:
	if selected_index < 0 or selected_index >= choices.size():
		return
	var choice: Dictionary = _get_dict(choices[selected_index])
	var icon_color: Color = _get_color(choice.get("icon_color", Color.WHITE))
	canvas.draw_rect(rect, Color(30.0 / 255.0, 35.0 / 255.0, 55.0 / 255.0, 0.90))
	canvas.draw_rect(rect, Color(icon_color.r, icon_color.g, icon_color.b, 0.82), false, 2.0)

	var title := str(choice.get("name", "Unknown"))
	var level_info := _long_level_text(choice)
	_draw_text(canvas, title, rect.position + Vector2(14.0, 22.0), 16, Color.WHITE)
	_draw_text(canvas, level_info, rect.position + Vector2(14.0 + min(180.0, title.length() * 12.0), 23.0), 13, Color(1.0, 205.0 / 255.0, 120.0 / 255.0))

	var desc_lines: Array = _wrap_text(str(choice.get("description", "")), 48, 2)
	for i in range(desc_lines.size()):
		_draw_text(canvas, str(desc_lines[i]), rect.position + Vector2(14.0, 47.0 + float(i) * 18.0), 13, Color(210.0 / 255.0, 220.0 / 255.0, 235.0 / 255.0))


func _draw_status_panel(canvas: CanvasItem, snapshot: Dictionary, catalog: Object, rect: Rect2, icon_renderer: Object) -> void:
	canvas.draw_rect(rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.82))
	canvas.draw_rect(rect, Color(110.0 / 255.0, 96.0 / 255.0, 58.0 / 255.0, 0.72), false, 2.0)
	canvas.draw_line(rect.position + Vector2(12.0, 3.0), Vector2(rect.end.x - 12.0, rect.position.y + 3.0), Color(190.0 / 255.0, 160.0 / 255.0, 82.0 / 255.0, 0.65), 1.0)

	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	var gold: int = int(snapshot.get("gold_from_perks", 0))

	_draw_text(canvas, "◆ 현재 퍽", rect.position + Vector2(14.0, 23.0), 14, Color(1.0, 215.0 / 255.0, 100.0 / 255.0))
	_draw_text(canvas, "선택 대기: %d" % pending, rect.position + Vector2(rect.size.x - 118.0, 23.0), 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0))
	_draw_text(canvas, "퍽 골드: %d" % gold, rect.position + Vector2(rect.size.x - 118.0, 45.0), 13, Color(1.0, 215.0 / 255.0, 100.0 / 255.0))

	var acquired: Array = _build_acquired_perks(levels, catalog)
	if acquired.is_empty():
		_draw_text(canvas, "획득한 퍽 없음", rect.position + Vector2(108.0, 27.0), 13, Color(115.0 / 255.0, 120.0 / 255.0, 140.0 / 255.0))
		return

	var icon_size := 27.0
	var gap := 6.0
	var start := rect.position + Vector2(108.0, 18.0)
	var max_count: int = max(1, int((rect.size.x - 122.0) / (icon_size + gap)))
	for idx in range(min(max_count, acquired.size())):
		var skill: Dictionary = acquired[idx]
		var icon_rect := Rect2(start + Vector2(float(idx) * (icon_size + gap), 0.0), Vector2(icon_size, icon_size))
		var color: Color = _get_color(skill.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
		canvas.draw_rect(icon_rect, Color(max(0.0, color.r - 0.28), max(0.0, color.g - 0.28), max(0.0, color.b - 0.28), 0.92))
		canvas.draw_rect(icon_rect, Color(color.r, color.g, color.b, 0.72), false, 1.0)
		_draw_icon(canvas, icon_renderer, skill, icon_rect.grow(-4.0), 1.0)
		var badge := Rect2(icon_rect.end - Vector2(12.0, 12.0), Vector2(12.0, 12.0))
		canvas.draw_circle(badge.get_center(), 6.0, Color(1.0, 215.0 / 255.0, 70.0 / 255.0))
		_draw_text_centered(canvas, str(skill.get("level", 1)), badge.get_center() + Vector2(0.0, 1.0), 9, Color(42.0 / 255.0, 30.0 / 255.0, 0.0))
	if acquired.size() > max_count:
		_draw_text(canvas, "+%d" % (acquired.size() - max_count), start + Vector2(float(max_count) * (icon_size + gap), 20.0), 13, Color(160.0 / 255.0, 160.0 / 255.0, 175.0 / 255.0))


func _draw_pending_hint(canvas: CanvasItem, snapshot: Dictionary, pos: Vector2, runtime_state: Object) -> void:
	var selectable: bool = runtime_state.has_method("is_selectable") and bool(runtime_state.is_selectable())
	var text := "마우스 클릭 또는 ← → / Enter 로 선택"
	if not selectable:
		text = "선택지를 불러오는 중"
	_draw_text_centered(canvas, text, pos, 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0, 0.92))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	if pending > 1:
		_draw_text_centered(canvas, "+%d more" % (pending - 1), pos + Vector2(0.0, -22.0), 12, Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 0.95))


func _draw_feedback(canvas: CanvasItem, runtime_state: Object, view_size: Vector2) -> void:
	if runtime_state == null or not runtime_state.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = runtime_state.get_snapshot()
	var timer: float = float(snapshot.get("feedback_timer", 0.0))
	var text: String = str(snapshot.get("feedback_text", ""))
	if timer <= 0.0 or text == "":
		return
	var alpha: float = clamp(timer, 0.0, 1.0)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.20 - (1.0 - alpha) * 16.0)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var size := 18
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var bg := Rect2(center - Vector2(text_size.x * 0.5 + 16.0, 22.0), Vector2(text_size.x + 32.0, 34.0))
	canvas.draw_rect(bg, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.72 * alpha))
	canvas.draw_rect(bg, Color(1.0, 215.0 / 255.0, 90.0 / 255.0, 0.58 * alpha), false, 1.0)
	canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(1.0, 230.0 / 255.0, 130.0 / 255.0, alpha))


func _draw_particles(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var particles: Array = _get_array(snapshot.get("particles", []))
	for particle_value in particles:
		var particle: Dictionary = _get_dict(particle_value)
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		if pos == Vector2.ZERO:
			continue
		var age: float = float(particle.get("age", 0.0))
		var life_ratio: float = clamp(1.0 - age / 1.45, 0.0, 1.0)
		if life_ratio <= 0.0:
			continue
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		var size: float = float(particle.get("size", 3.0))
		canvas.draw_circle(pos, size * (1.0 + 0.4 * life_ratio), Color(color.r, color.g, color.b, 0.18 * life_ratio))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.76 * life_ratio))


func _draw_icon(canvas: CanvasItem, icon_renderer: Object, skill: Dictionary, rect: Rect2, alpha: float) -> void:
	var skill_id: String = str(skill.get("id", ""))
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		if bool(icon_renderer.draw_icon(canvas, skill_id, rect, alpha, true)):
			return
	_draw_perk_symbol(canvas, rect, _get_color(skill.get("icon_color", Color.WHITE)), str(skill.get("tree", "")), skill_id, alpha)


func _draw_perk_symbol(canvas: CanvasItem, rect: Rect2, color: Color, tree: String, skill_id: String, alpha: float) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.36
	var c := Color(color.r, color.g, color.b, alpha)
	var hi := Color(1.0, 1.0, 1.0, 0.82 * alpha)
	if skill_id == "convert_to_gold":
		canvas.draw_circle(center, radius, Color(1.0, 200.0 / 255.0, 40.0 / 255.0, 0.95 * alpha))
		_draw_text_centered(canvas, "G", center + Vector2(0.0, 2.0), int(radius * 1.35), Color(70.0 / 255.0, 42.0 / 255.0, 0.0, alpha))
	elif tree.find("unlock") >= 0:
		canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.36 * alpha))
		canvas.draw_arc(center, radius, -PI * 0.75, PI * 0.75, 28, c, 3.0)
		canvas.draw_line(center + Vector2(-radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), hi, 2.0)
		canvas.draw_line(center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), hi, 2.0)
	elif tree == "dash":
		var points: PackedVector2Array = [
			center + Vector2(-radius * 0.8, radius * 0.5),
			center + Vector2(-radius * 0.1, -radius * 0.8),
			center + Vector2(radius * 0.05, -radius * 0.15),
			center + Vector2(radius * 0.8, -radius * 0.35),
			center + Vector2(radius * 0.05, radius * 0.8),
			center + Vector2(-radius * 0.08, radius * 0.15),
		]
		canvas.draw_colored_polygon(points, c)
		canvas.draw_polyline(points, hi, 1.2, true)
	elif tree == "item":
		canvas.draw_rect(Rect2(center - Vector2(radius * 0.75, radius * 0.52), Vector2(radius * 1.5, radius * 1.05)), Color(c.r, c.g, c.b, 0.72 * alpha))
		canvas.draw_line(center + Vector2(-radius * 0.55, -radius * 0.62), center + Vector2(radius * 0.55, -radius * 0.62), hi, 2.0)
		canvas.draw_line(center + Vector2(0.0, -radius * 0.75), center + Vector2(0.0, radius * 0.55), hi, 1.4)
	else:
		canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.36 * alpha))
		canvas.draw_arc(center, radius, 0.0, TAU, 32, c, 2.4)
		canvas.draw_circle(center, radius * 0.36, hi)


func _build_acquired_perks(levels: Dictionary, catalog: Object) -> Array:
	var result: Array = []
	for skill_id in levels.keys():
		var level: int = int(levels[skill_id])
		if level <= 0:
			continue
		var data: Dictionary = {}
		if catalog != null and catalog.has_method("get_perk_data"):
			data = catalog.get_perk_data(str(skill_id))
		if data.is_empty():
			data = {"name": str(skill_id), "icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0), "tree": ""}
		data = data.duplicate(true)
		data["id"] = str(skill_id)
		data["level"] = level
		result.append(data)
	result.sort_custom(Callable(self, "_sort_perks_by_level"))
	return result


func _sort_perks_by_level(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("level", 0)) > int(b.get("level", 0))


func _level_text(choice: Dictionary) -> String:
	if bool(choice.get("is_gold_conversion", false)):
		return "골드"
	if bool(choice.get("is_instant", false)):
		return "즉시"
	var max_level: int = int(choice.get("max_level", 1))
	if max_level <= 1 and str(choice.get("character_restriction", "")) != "":
		return "ACTIVE"
	return "Lv.%d" % int(choice.get("next_level", 1))


func _long_level_text(choice: Dictionary) -> String:
	if bool(choice.get("is_gold_conversion", false)):
		return "  (500 Gold)"
	if bool(choice.get("is_instant", false)):
		return "  (즉시 효과)"
	var max_level: int = int(choice.get("max_level", 1))
	if max_level <= 1 and str(choice.get("character_restriction", "")) != "":
		return "  (액티브 해금)"
	return "  (Lv.%d → Lv.%d)" % [int(choice.get("current_level", 0)), int(choice.get("next_level", 1))]


func _level_color(choice: Dictionary, unique: bool, alpha: float) -> Color:
	if unique:
		return Color(1.0, 205.0 / 255.0, 50.0 / 255.0, alpha)
	if bool(choice.get("is_instant", false)):
		return Color(100.0 / 255.0, 1.0, 200.0 / 255.0, alpha)
	return Color(1.0, 200.0 / 255.0, 100.0 / 255.0, alpha)


func _wrap_text(text: String, max_chars: int, max_lines: int) -> Array:
	var lines: Array = []
	var remaining := text.strip_edges()
	while remaining.length() > max_chars and lines.size() < max_lines:
		lines.append(remaining.substr(0, max_chars))
		remaining = remaining.substr(max_chars).strip_edges()
	if remaining != "" and lines.size() < max_lines:
		lines.append(remaining)
	return lines


func _draw_text(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or text == "":
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_centered(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or text == "":
		return
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	canvas.draw_string(font, center - Vector2(size.x * 0.5, -size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()
