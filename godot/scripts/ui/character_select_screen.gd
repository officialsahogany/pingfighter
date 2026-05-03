@tool
extends Control

signal character_confirmed(character_id: String, runtime_character_id: String)
signal back_requested

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

@export var battle_scene_path: String = "res://scenes/main.tscn"
@export var auto_start_battle: bool = true

var characters: Array = []
var visible_indices: Array = []
var portrait_textures: Dictionary = {}
var selected_index: int = 0
var hovered_index: int = -1
var hover_lifts: Array = []
var hover_scales: Array = []
var card_rects: Dictionary = {}
var confirm_rect := Rect2()
var back_rect := Rect2()
var animation_time: float = 0.0
var preview: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	characters = CharacterSelectData.get_characters()
	_refresh_visible_indices()
	_prepare_hover_state()
	_load_portraits()
	preview = get_node_or_null("LivePreview")
	if preview != null:
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_preview()
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	_update_hover_from_mouse(get_local_mouse_position())
	_update_hover_animation(delta)
	_update_preview_layout()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		_update_hover_from_mouse(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if confirm_rect.has_point(pos):
			_confirm_selection()
			accept_event()
			return
		if back_rect.has_point(pos):
			_go_back()
			accept_event()
			return
		for idx in card_rects.keys():
			var card_rect: Rect2 = card_rects[idx]
			if card_rect.has_point(pos):
				_select_index(int(idx))
				if event.double_click:
					_confirm_selection()
				accept_event()
				return


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_D:
			_move_selection(1)
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_confirm_selection()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_go_back()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var view_size := size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = get_viewport_rect().size
	_draw_background(view_size)
	_draw_header(view_size)
	var preview_rect := _preview_rect(view_size)
	var detail_rect := _detail_rect(view_size, preview_rect)
	_draw_detail_panel(detail_rect)
	_draw_card_row(view_size)
	_draw_action_bar(view_size)


func _refresh_visible_indices() -> void:
	visible_indices.clear()
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		if bool(character.get("unlocked", false)):
			visible_indices.append(i)
	if visible_indices.is_empty():
		for i in range(characters.size()):
			visible_indices.append(i)
	if not visible_indices.is_empty():
		selected_index = int(visible_indices[0])


func _prepare_hover_state() -> void:
	hover_lifts.resize(characters.size())
	hover_scales.resize(characters.size())
	for i in range(characters.size()):
		hover_lifts[i] = 0.0
		hover_scales[i] = 1.0


func _load_portraits() -> void:
	portrait_textures.clear()
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		var path := str(character.get("portrait_path", ""))
		if path == "":
			continue
		var texture := ProjectResourceLoader.load_texture(
			path,
			"Missing character-select portrait: %s",
			"Failed to load character-select portrait: %s"
		)
		if texture != null:
			portrait_textures[i] = texture


func _update_hover_from_mouse(pos: Vector2) -> void:
	hovered_index = -1
	for idx in card_rects.keys():
		var card_rect: Rect2 = card_rects[idx]
		if card_rect.has_point(pos):
			hovered_index = int(idx)


func _update_hover_animation(delta: float) -> void:
	var t: float = min(1.0, delta * 11.0)
	for i in range(characters.size()):
		var target_lift := 0.0
		var target_scale := 1.0
		if i == selected_index:
			target_lift += 18.0
			target_scale = 1.08
		if i == hovered_index:
			target_lift += 18.0
			target_scale = max(target_scale, 1.06)
		hover_lifts[i] = lerp(float(hover_lifts[i]), target_lift, t)
		hover_scales[i] = lerp(float(hover_scales[i]), target_scale, t)


func _move_selection(delta: int) -> void:
	if visible_indices.is_empty():
		return
	var current_pos := visible_indices.find(selected_index)
	if current_pos < 0:
		current_pos = 0
	var next_pos := (current_pos + delta + visible_indices.size()) % visible_indices.size()
	_select_index(int(visible_indices[next_pos]))


func _select_index(index: int) -> void:
	if index < 0 or index >= characters.size() or index == selected_index:
		return
	selected_index = index
	_sync_preview()
	queue_redraw()


func _sync_preview() -> void:
	if preview == null or selected_index < 0 or selected_index >= characters.size():
		return
	var texture: Texture2D = portrait_textures.get(selected_index, null)
	if preview.has_method("set_character"):
		preview.set_character(characters[selected_index], texture)


func _update_preview_layout() -> void:
	if preview == null:
		return
	var rect := _preview_rect(size if size.x > 1.0 else get_viewport_rect().size)
	preview.position = rect.position
	preview.size = rect.size


func _confirm_selection() -> void:
	if Engine.is_editor_hint():
		return
	if selected_index < 0 or selected_index >= characters.size():
		return
	var character: Dictionary = characters[selected_index]
	if not bool(character.get("unlocked", false)):
		return
	_store_selection(character)
	character_confirmed.emit(str(character.get("id", "")), str(character.get("runtime_id", "")))
	if auto_start_battle and battle_scene_path != "":
		get_tree().change_scene_to_file(battle_scene_path)


func _go_back() -> void:
	back_requested.emit()


func _store_selection(character: Dictionary) -> void:
	var state: Node = get_node_or_null("/root/GameSelectionState")
	if state != null and state.has_method("set_character"):
		state.set_character(character)


func _draw_background(view_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.015, 0.018, 0.032, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, view_size.y * 0.38)), Color(0.025, 0.052, 0.073, 0.92))
	var step: float = max(36.0, view_size.x / 32.0)
	var offset: float = fmod(animation_time * 18.0, step)
	var line_color := Color(0.0, 0.85, 1.0, 0.075)
	var x: float = -view_size.y * 0.22 + offset
	while x < view_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x + view_size.y * 0.22, view_size.y), line_color, 1.0)
		x += step
	var y: float = fmod(animation_time * 12.0, step)
	while y < view_size.y:
		draw_line(Vector2(0.0, y), Vector2(view_size.x, y), Color(1.0, 0.76, 0.26, 0.035), 1.0)
		y += step
	var floor_y: float = view_size.y * 0.74
	draw_rect(Rect2(0.0, floor_y, view_size.x, view_size.y - floor_y), Color(0.02, 0.018, 0.026, 0.74))
	draw_line(Vector2(0.0, floor_y), Vector2(view_size.x, floor_y), Color(0.0, 0.95, 1.0, 0.24), 2.0)


func _draw_header(view_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	_draw_text_center(font, "캐릭터 선택", Vector2(view_size.x * 0.5, 52.0), 38, Color(1.0, 1.0, 1.0, 0.98))
	_draw_text_center(font, "PINGFIGHTER PLAYER DATABASE", Vector2(view_size.x * 0.5, 88.0), 14, Color(0.0, 0.88, 1.0, 0.80))


func _draw_detail_panel(rect: Rect2) -> void:
	var character: Dictionary = characters[selected_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var font := ThemeDB.fallback_font
	draw_rect(rect.grow(8.0), Color(glow.r, glow.g, glow.b, 0.10 + sin(animation_time * 2.0) * 0.03))
	draw_rect(rect, Color(0.025, 0.035, 0.055, 0.94))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.82), false, 2.0)
	draw_rect(rect.grow(-6.0), Color(1.0, 1.0, 1.0, 0.10), false, 1.0)

	var name := str(character.get("name", ""))
	var role := str(character.get("role", ""))
	_draw_text_left(font, role, rect.position + Vector2(28.0, 28.0), 14, Color(accent.r, accent.g, accent.b, 0.92))
	_draw_text_left(font, name, rect.position + Vector2(28.0, 62.0), 34, Color.WHITE)
	_draw_emblem(rect.position + Vector2(rect.size.x - 62.0, 70.0), accent, glow)

	var desc_lines := str(character.get("description", "")).split("\n")
	var desc_y := rect.position.y + 122.0
	for line_idx in range(desc_lines.size()):
		_draw_text_left(font, desc_lines[line_idx], Vector2(rect.position.x + 30.0, desc_y + float(line_idx) * 28.0), 18, Color(0.74, 0.86, 0.96, 0.96))

	_draw_text_left(font, str(character.get("special", "")), rect.position + Vector2(30.0, rect.size.y - 94.0), 17, Color(glow.r, glow.g, glow.b, 0.98))
	_draw_stats(rect.position + Vector2(30.0, rect.size.y - 54.0), rect.size.x - 60.0, character)


func _draw_stats(origin: Vector2, max_width: float, character: Dictionary) -> void:
	var stats_value: Variant = character.get("stats", {})
	if not (stats_value is Dictionary):
		return
	var stats: Dictionary = stats_value
	var font := ThemeDB.fallback_font
	var keys: Array = ["속도", "파워", "방어"]
	var col_w: float = max_width / float(keys.size())
	for i in range(keys.size()):
		var key: String = str(keys[i])
		var value := int(stats.get(key, 0))
		var x := origin.x + float(i) * col_w
		_draw_text_left(font, key, Vector2(x, origin.y), 13, Color(0.80, 0.84, 0.88, 0.90))
		var track := Rect2(x, origin.y + 18.0, col_w - 26.0, 8.0)
		draw_rect(track, Color(0.0, 0.0, 0.0, 0.42))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clamp(float(value) / 8.0, 0.0, 1.0), track.size.y)), Color(1.0, 0.76, 0.26, 0.88))
		draw_rect(track, Color(1.0, 1.0, 1.0, 0.18), false, 1.0)


func _draw_emblem(center: Vector2, accent: Color, glow: Color) -> void:
	var pulse := 1.0 + sin(animation_time * 3.0) * 0.08
	draw_circle(center, 29.0 * pulse, Color(glow.r, glow.g, glow.b, 0.18))
	draw_circle(center, 22.0 * pulse, Color(0.03, 0.04, 0.07, 0.94))
	var pts := PackedVector2Array([
		center + Vector2(0.0, -15.0 * pulse),
		center + Vector2(13.0 * pulse, 0.0),
		center + Vector2(0.0, 15.0 * pulse),
		center + Vector2(-13.0 * pulse, 0.0),
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.92))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.WHITE, 1.4)


func _draw_card_row(view_size: Vector2) -> void:
	card_rects = _layout_cards(view_size)
	var ordered := visible_indices.duplicate()
	ordered.sort()
	for idx in ordered:
		_draw_character_card(int(idx), card_rects.get(int(idx), Rect2()))


func _draw_character_card(index: int, rect: Rect2) -> void:
	if rect.size.x <= 1.0:
		return
	var character: Dictionary = characters[index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var selected := index == selected_index
	var hovered := index == hovered_index
	var alpha := 0.94 if bool(character.get("unlocked", false)) else 0.38
	if selected or hovered:
		draw_rect(rect.grow(10.0), Color(glow.r, glow.g, glow.b, 0.18 if selected else 0.10))
	draw_rect(rect, Color(0.02, 0.025, 0.038, 0.96))
	var texture: Texture2D = portrait_textures.get(index, null)
	if texture != null:
		_draw_texture_cover(texture, rect.grow(-5.0), Color(1.0, 1.0, 1.0, alpha))
	else:
		draw_rect(rect.grow(-5.0), Color(accent.r, accent.g, accent.b, 0.22))
	draw_rect(Rect2(rect.position.x, rect.end.y - 46.0, rect.size.x, 46.0), Color(0.0, 0.0, 0.0, 0.66))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.92 if selected else 0.42), false, 2.0 if selected else 1.0)
	draw_rect(rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.16 if selected else 0.08), false, 1.0)
	var font := ThemeDB.fallback_font
	_draw_text_center(font, str(character.get("name", "")), Vector2(rect.get_center().x, rect.end.y - 24.0), 18 if selected else 15, Color.WHITE)
	if selected:
		draw_line(Vector2(rect.position.x + 12.0, rect.end.y + 10.0), Vector2(rect.end.x - 12.0, rect.end.y + 10.0), Color(glow.r, glow.g, glow.b, 0.92), 3.0)


func _draw_action_bar(view_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var bar_h := 58.0
	var bar_y := view_size.y - bar_h
	draw_rect(Rect2(0.0, bar_y, view_size.x, bar_h), Color(0.0, 0.0, 0.0, 0.34))
	confirm_rect = Rect2(view_size.x - 250.0, bar_y + 12.0, 172.0, 34.0)
	back_rect = Rect2(78.0, bar_y + 12.0, 132.0, 34.0)
	var character: Dictionary = characters[selected_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	draw_rect(back_rect, Color(0.08, 0.09, 0.12, 0.86))
	draw_rect(back_rect, Color(0.55, 0.62, 0.70, 0.46), false, 1.0)
	_draw_text_center(font, "뒤로", back_rect.get_center(), 16, Color(0.88, 0.90, 0.94, 0.96))
	draw_rect(confirm_rect, Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.92))
	draw_rect(confirm_rect, Color(accent.r, accent.g, accent.b, 0.86), false, 2.0)
	_draw_text_center(font, "선택 확정", confirm_rect.get_center(), 16, Color.WHITE)
	_draw_text_center(font, "← →", Vector2(view_size.x * 0.5, bar_y + 31.0), 15, Color(0.76, 0.82, 0.88, 0.78))


func _layout_cards(view_size: Vector2) -> Dictionary:
	var rects: Dictionary = {}
	var count: int = visible_indices.size()
	if count <= 0:
		return rects
	var base_scale: float = clamp(view_size.y / 1246.0, 0.68, 1.10)
	var base_w: float = 150.0 * base_scale
	var base_h: float = 214.0 * base_scale
	var usable_w: float = max(1.0, view_size.x - 250.0)
	var step: float = base_w * 0.88
	if count > 1:
		step = min(step, usable_w / float(count - 1))
	var total_w: float = step * float(max(0, count - 1))
	var first_x: float = view_size.x * 0.5 - total_w * 0.5
	var base_y: float = view_size.y - 122.0 - base_h * 0.5
	for pos in range(count):
		var index := int(visible_indices[pos])
		var scale_factor := float(hover_scales[index])
		var card_size := Vector2(base_w, base_h) * scale_factor
		var center := Vector2(first_x + float(pos) * step, base_y - float(hover_lifts[index]))
		rects[index] = Rect2(center - card_size * 0.5, card_size)
	return rects


func _preview_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		return Rect2(40.0, 108.0, view_size.x - 80.0, view_size.y * 0.34)
	return Rect2(view_size.x * 0.075, 126.0, min(560.0, view_size.x * 0.31), view_size.y * 0.48)


func _detail_rect(view_size: Vector2, preview_rect_value: Rect2) -> Rect2:
	if view_size.x < 980.0:
		return Rect2(40.0, preview_rect_value.end.y + 22.0, view_size.x - 80.0, min(270.0, view_size.y * 0.28))
	var x := preview_rect_value.end.x + 42.0
	return Rect2(x, preview_rect_value.position.y + 28.0, view_size.x - x - 86.0, min(350.0, preview_rect_value.size.y - 56.0))


func _draw_texture_cover(texture: Texture2D, target: Rect2, modulate: Color = Color.WHITE) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return
	var source := Rect2(Vector2.ZERO, tex_size)
	var target_aspect := target.size.x / target.size.y
	var tex_aspect := tex_size.x / tex_size.y
	if tex_aspect > target_aspect:
		source.size.x = tex_size.y * target_aspect
		source.position.x = (tex_size.x - source.size.x) * 0.5
	else:
		source.size.y = tex_size.x / target_aspect
		source.position.y = (tex_size.y - source.size.y) * 0.5
	draw_texture_rect_region(texture, target, source, modulate, false, true)


func _character_color(character: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = character.get(key, fallback)
	return value if value is Color else fallback


func _draw_text_left(font: Font, text: String, top_left: Vector2, font_size: int, color: Color) -> void:
	var baseline := top_left + Vector2(0.0, float(font_size))
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_center(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.70))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
