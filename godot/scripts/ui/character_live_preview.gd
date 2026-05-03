@tool
extends Control

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LAYER_ORDER := [
	"back_hair",
	"body",
	"arm_back",
	"head",
	"eyes_open",
	"mouth",
	"front_hair",
	"arm_front",
	"accessory",
]
const LOAD_LAYER_KEYS := [
	"back_hair",
	"body",
	"arm_back",
	"head",
	"eyes_open",
	"eyes_closed",
	"mouth",
	"front_hair",
	"arm_front",
	"accessory",
]

var character: Dictionary = {}
var portrait_texture: Texture2D = null
var layer_textures: Dictionary = {}
var fullframe_sheet_texture: Texture2D = null
var fullframe_cols: int = 1
var fullframe_rows: int = 1
var fullframe_count: int = 1
var fullframe_interval: float = 0.16
var elapsed: float = 0.0
var look_offset: Vector2 = Vector2.ZERO


func set_character(data: Dictionary, texture: Texture2D) -> void:
	character = data.duplicate(true)
	portrait_texture = _load_preview_still_texture(texture)
	_load_fullframe_sheet()
	_load_layer_textures()
	if fullframe_sheet_texture != null:
		layer_textures.clear()
	if not bool(character.get("live2d_canvas_locked", false)) and not bool(character.get("allow_free_live2d_parts", false)):
		layer_textures.clear()
	if bool(character.get("live2d_canvas_locked", false)) and not _has_registered_layer_set():
		layer_textures.clear()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	var local_mouse := get_local_mouse_position()
	var target := Vector2.ZERO
	if Rect2(Vector2.ZERO, size).has_point(local_mouse):
		var center := size * 0.5
		var denom: float = max(1.0, min(size.x, size.y))
		target = (local_mouse - center) / denom * 34.0
		target.x = clamp(target.x, -18.0, 18.0)
		target.y = clamp(target.y, -14.0, 14.0)
	look_offset = look_offset.lerp(target, min(1.0, delta * 8.0))
	queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var accent := _accent_color()
	var glow := _glow_color()
	_draw_preview_backdrop(accent, glow)

	var art_w: float = min(size.x * 0.72, size.y * 0.52)
	var art_h: float = min(size.y * 0.78, art_w * 1.40)
	var art_rect := Rect2(
		Vector2((size.x - art_w) * 0.5, size.y * 0.15),
		Vector2(art_w, art_h)
	)

	if fullframe_sheet_texture != null:
		_draw_fullframe_sheet_preview(art_rect)
	elif _has_layer_textures():
		_draw_layered_preview(art_rect)
	elif portrait_texture != null:
		_draw_card_parallax_preview(art_rect)
	else:
		_draw_procedural_preview(art_rect)

	_draw_scanlines(glow)
	_draw_nameplate(accent, glow)


func _load_fullframe_sheet() -> void:
	fullframe_sheet_texture = null
	fullframe_cols = max(1, int(character.get("live2d_fullframe_cols", 1)))
	fullframe_rows = max(1, int(character.get("live2d_fullframe_rows", 1)))
	var max_frame_count: int = fullframe_cols * fullframe_rows
	fullframe_count = clamp(int(character.get("live2d_fullframe_count", max_frame_count)), 1, max_frame_count)
	fullframe_interval = max(0.04, float(character.get("live2d_fullframe_interval", 0.16)))
	var sheet_path := str(character.get("live2d_fullframe_sheet_path", ""))
	if sheet_path == "":
		return
	fullframe_sheet_texture = ProjectResourceLoader.load_texture(
		sheet_path,
		"Missing character full-frame preview sheet: %s",
		"Failed to load character full-frame preview sheet: %s"
	)


func _load_preview_still_texture(fallback: Texture2D) -> Texture2D:
	var still_path := str(character.get("live2d_preview_still_path", ""))
	if still_path == "":
		return fallback
	var still_texture := ProjectResourceLoader.load_texture(
		still_path,
		"Missing character preview still: %s",
		"Failed to load character preview still: %s"
	)
	return still_texture if still_texture != null else fallback


func _load_layer_textures() -> void:
	layer_textures.clear()
	var layers_value: Variant = character.get("live2d_layers", {})
	if not (layers_value is Dictionary):
		return
	var layers: Dictionary = layers_value
	for key in LOAD_LAYER_KEYS:
		var path := str(layers.get(key, ""))
		if path == "":
			continue
		var texture := ProjectResourceLoader.load_texture(path)
		if texture != null:
			layer_textures[key] = texture


func _has_layer_textures() -> bool:
	return layer_textures.has("body") or layer_textures.has("head")


func _has_registered_layer_set() -> bool:
	for required_key in ["body", "head", "eyes_open", "front_hair", "arm_front"]:
		if not layer_textures.has(required_key):
			return false
	var body: Texture2D = layer_textures.get("body", null)
	if body == null:
		return false
	var body_size := body.get_size()
	if body_size.x < 250.0 or body_size.y < 350.0:
		return false
	for key in layer_textures.keys():
		var texture: Texture2D = layer_textures.get(key, null)
		if texture == null:
			continue
		var size_value := texture.get_size()
		if abs(size_value.x - body_size.x) > 2.0 or abs(size_value.y - body_size.y) > 2.0:
			return false
	return true


func _draw_preview_backdrop(accent: Color, glow: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.065, 0.96))
	for ring in range(4):
		var inset := 8.0 + float(ring) * 13.0
		var alpha := 0.18 - float(ring) * 0.035
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0)), Color(glow.r, glow.g, glow.b, alpha), false, 1.0)
	var grid_step: float = max(22.0, size.x / 18.0)
	var x: float = fmod(elapsed * 12.0, grid_step)
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x - size.y * 0.35, size.y), Color(accent.r, accent.g, accent.b, 0.08), 1.0)
		x += grid_step
	var horizon_y: float = size.y * 0.78
	draw_line(Vector2(size.x * 0.12, horizon_y), Vector2(size.x * 0.88, horizon_y), Color(glow.r, glow.g, glow.b, 0.38), 2.0)
	draw_line(Vector2(size.x * 0.24, horizon_y + 10.0), Vector2(size.x * 0.76, horizon_y + 10.0), Color(1.0, 1.0, 1.0, 0.18), 1.0)


func _draw_fullframe_sheet_preview(art_rect: Rect2) -> void:
	if fullframe_sheet_texture == null:
		return
	var texture_size := fullframe_sheet_texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var frame_index := int(floor(elapsed / fullframe_interval)) % fullframe_count
	var col := frame_index % fullframe_cols
	var row := int(floor(float(frame_index) / float(fullframe_cols)))
	var cell_size := Vector2(texture_size.x / float(fullframe_cols), texture_size.y / float(fullframe_rows))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var bob := sin(elapsed * 2.0) * 5.0
	var target_rect := _scale_rect(art_rect, 1.0 + sin(elapsed * 1.6) * 0.010)
	target_rect.position += Vector2(look_offset.x * 0.16, look_offset.y * 0.12 + bob)
	var fitted_rect := _fit_region_rect(source_rect.size, target_rect)
	var glow := _glow_color()
	var pulse := 0.5 + sin(elapsed * 3.0) * 0.5
	draw_rect(fitted_rect.grow(4.0), Color(glow.r, glow.g, glow.b, 0.12 + pulse * 0.08), false, 2.0)
	_draw_texture_region_fit(fullframe_sheet_texture, source_rect, target_rect, Color.WHITE)


func _draw_layered_preview(art_rect: Rect2) -> void:
	var breath := sin(elapsed * 2.1) * 5.0
	var blink := fmod(elapsed, 4.2) > 4.06
	for key in LAYER_ORDER:
		var key_name: String = str(key)
		if key_name == "eyes_open" and blink and layer_textures.has("eyes_closed"):
			continue
		var draw_key: String = key_name
		if key_name == "eyes_open" and blink and layer_textures.has("eyes_closed"):
			draw_key = "eyes_closed"
		var texture_value: Variant = layer_textures.get(draw_key, null)
		if not (texture_value is Texture2D):
			continue
		var texture: Texture2D = texture_value
		var parallax: float = _layer_parallax(draw_key)
		var canvas_locked := bool(character.get("live2d_canvas_locked", false))
		var layer_rect: Rect2 = art_rect if canvas_locked else _layer_target_rect(draw_key, art_rect)
		if canvas_locked:
			layer_rect.position += _canvas_locked_layer_offset(draw_key, art_rect)
		layer_rect.position += Vector2(look_offset.x * parallax, look_offset.y * parallax + breath * parallax)
		layer_rect = _scale_rect(layer_rect, 1.0 + sin(elapsed * 2.0) * 0.008 * max(0.2, parallax))
		_draw_texture_fit(texture, layer_rect, Color.WHITE)


func _draw_card_parallax_preview(art_rect: Rect2) -> void:
	var accent := _accent_color()
	var glow := _glow_color()
	var bob := sin(elapsed * 2.0) * 5.0
	var base_rect := _scale_rect(art_rect, 1.0 + sin(elapsed * 1.8) * 0.018)
	base_rect.position += Vector2(look_offset.x * 0.16, look_offset.y * 0.12 + bob)
	_draw_texture_cover(portrait_texture, base_rect, Color(1.0, 1.0, 1.0, 0.96))

	var pulse := 0.5 + sin(elapsed * 3.2) * 0.5
	draw_rect(base_rect.grow(3.0), Color(glow.r, glow.g, glow.b, 0.28 + pulse * 0.14), false, 2.0)
	draw_rect(base_rect.grow(8.0), Color(accent.r, accent.g, accent.b, 0.12), false, 1.0)
	var glint_y := base_rect.position.y + base_rect.size.y * 0.32 + sin(elapsed * 5.0) * 2.0
	draw_line(
		Vector2(base_rect.position.x + base_rect.size.x * 0.34, glint_y),
		Vector2(base_rect.position.x + base_rect.size.x * 0.66, glint_y + 2.0),
		Color(1.0, 1.0, 1.0, 0.25 + pulse * 0.25),
		2.0
	)


func _draw_procedural_preview(art_rect: Rect2) -> void:
	var accent := _accent_color()
	var glow := _glow_color()
	var center := art_rect.get_center() + look_offset * 0.18
	var bob := sin(elapsed * 2.0) * 5.0
	var body_rect := Rect2(center + Vector2(-art_rect.size.x * 0.18, art_rect.size.y * 0.02 + bob), Vector2(art_rect.size.x * 0.36, art_rect.size.y * 0.34))
	draw_rect(body_rect, Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.92))
	draw_rect(body_rect, Color(glow.r, glow.g, glow.b, 0.85), false, 2.0)
	var head_center := center + Vector2(look_offset.x * 0.45, -art_rect.size.y * 0.17 + bob * 0.5)
	draw_circle(head_center, art_rect.size.x * 0.135, Color(0.92, 0.88, 0.82, 1.0))
	draw_circle(head_center + Vector2(0.0, -2.0), art_rect.size.x * 0.15, Color(accent.r, accent.g, accent.b, 0.36))
	var arm_swing := sin(elapsed * 2.8) * art_rect.size.x * 0.04
	draw_line(body_rect.position + Vector2(0.0, body_rect.size.y * 0.2), body_rect.position + Vector2(-art_rect.size.x * 0.16, body_rect.size.y * 0.55 + arm_swing), Color(glow.r, glow.g, glow.b, 0.9), 7.0)
	draw_line(body_rect.position + Vector2(body_rect.size.x, body_rect.size.y * 0.2), body_rect.position + Vector2(body_rect.size.x + art_rect.size.x * 0.16, body_rect.size.y * 0.55 - arm_swing), Color(glow.r, glow.g, glow.b, 0.9), 7.0)
	draw_line(head_center + Vector2(-art_rect.size.x * 0.055, -3.0), head_center + Vector2(art_rect.size.x * 0.055, -2.0), Color(0.08, 0.12, 0.16, 0.85), 2.0)


func _draw_scanlines(glow: Color) -> void:
	var y := fmod(elapsed * 18.0, 10.0)
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(glow.r, glow.g, glow.b, 0.045), 1.0)
		y += 10.0


func _draw_nameplate(accent: Color, glow: Color) -> void:
	var label := str(character.get("role", "Live Preview"))
	var name := str(character.get("name", ""))
	var font := ThemeDB.fallback_font
	var role_size := 14
	var name_size := 26
	var y := size.y - 54.0
	draw_rect(Rect2(22.0, y - 18.0, size.x - 44.0, 54.0), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(Rect2(22.0, y - 18.0, size.x - 44.0, 54.0), Color(glow.r, glow.g, glow.b, 0.28), false, 1.0)
	_draw_centered_text(font, label, Vector2(size.x * 0.5, y - 1.0), role_size, Color(accent.r, accent.g, accent.b, 0.9))
	_draw_centered_text(font, name, Vector2(size.x * 0.5, y + 26.0), name_size, Color(1.0, 1.0, 1.0, 0.98))


func _layer_parallax(key: String) -> float:
	match key:
		"back_hair":
			return 0.10
		"body":
			return 0.14
		"arm_back":
			return 0.20
		"head":
			return 0.42
		"eyes_open", "eyes_closed", "mouth", "front_hair":
			return 0.55
		"arm_front", "accessory":
			return 0.34
	return 0.22


func _layer_target_rect(key: String, art_rect: Rect2) -> Rect2:
	var center_ratio := Vector2(0.5, 0.5)
	var size_ratio := Vector2(0.42, 0.32)
	match key:
		"back_hair":
			center_ratio = Vector2(0.49, 0.34)
			size_ratio = Vector2(0.50, 0.36)
		"body":
			center_ratio = Vector2(0.50, 0.66)
			size_ratio = Vector2(0.66, 0.54)
		"arm_back":
			center_ratio = Vector2(0.37, 0.64)
			size_ratio = Vector2(0.50, 0.44)
		"head":
			center_ratio = Vector2(0.50, 0.37)
			size_ratio = Vector2(0.46, 0.38)
		"eyes_open", "eyes_closed":
			center_ratio = Vector2(0.50, 0.35)
			size_ratio = Vector2(0.26, 0.10)
		"mouth":
			center_ratio = Vector2(0.50, 0.43)
			size_ratio = Vector2(0.15, 0.075)
		"front_hair":
			center_ratio = Vector2(0.50, 0.29)
			size_ratio = Vector2(0.52, 0.34)
		"arm_front":
			center_ratio = Vector2(0.61, 0.64)
			size_ratio = Vector2(0.54, 0.48)
		"accessory":
			center_ratio = Vector2(0.70, 0.55)
			size_ratio = Vector2(0.30, 0.24)
	var draw_size := Vector2(art_rect.size.x * size_ratio.x, art_rect.size.y * size_ratio.y)
	var center := art_rect.position + Vector2(art_rect.size.x * center_ratio.x, art_rect.size.y * center_ratio.y)
	return Rect2(center - draw_size * 0.5, draw_size)


func _canvas_locked_layer_offset(key: String, art_rect: Rect2) -> Vector2:
	match key:
		"arm_front":
			return Vector2(art_rect.size.x * 0.10, art_rect.size.y * 0.13)
		"accessory":
			return Vector2(art_rect.size.x * 0.04, art_rect.size.y * 0.05)
	return Vector2.ZERO


func _accent_color() -> Color:
	var color_value: Variant = character.get("card_color", Color(0.0, 0.9, 1.0, 1.0))
	return color_value if color_value is Color else Color(0.0, 0.9, 1.0, 1.0)


func _glow_color() -> Color:
	var color_value: Variant = character.get("glow_color", _accent_color())
	return color_value if color_value is Color else _accent_color()


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


func _draw_texture_fit(texture: Texture2D, target: Rect2, modulate: Color = Color.WHITE) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0:
		return
	var scale_factor: float = min(target.size.x / tex_size.x, target.size.y / tex_size.y)
	var draw_size := tex_size * scale_factor
	var draw_rect := Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false, modulate)


func _draw_texture_region_fit(texture: Texture2D, source: Rect2, target: Rect2, modulate: Color = Color.WHITE) -> void:
	if source.size.x <= 1.0 or source.size.y <= 1.0:
		return
	var draw_rect := _fit_region_rect(source.size, target)
	draw_texture_rect_region(texture, draw_rect, source, modulate, false, true)


func _fit_region_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 1.0 or source_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor: float = min(target.size.x / source_size.x, target.size.y / source_size.y)
	var draw_size := source_size * scale_factor
	return Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)


func _scale_rect(rect: Rect2, scale_factor: float) -> Rect2:
	var center := rect.get_center()
	var scaled_size := rect.size * scale_factor
	return Rect2(center - scaled_size * 0.5, scaled_size)


func _draw_centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.7))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
