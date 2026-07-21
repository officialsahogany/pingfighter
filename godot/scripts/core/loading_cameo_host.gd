extends Node2D

const LoadingCameoCatalog := preload("res://scripts/core/loading_cameo_catalog.gd")

const HOST_NAME := "LoadingCameoHost"
const HOST_Z_INDEX := 3000
const GLOW_SCALES := [1.30, 1.15, 1.0]
const GLOW_ALPHAS := [0.05, 0.10, 1.0]

var _rng := RandomNumberGenerator.new()
var _sprites: Array[Sprite2D] = []
var _copy_label: Label = null
var _selected_entry: Dictionary = {}
var _session_pick_count := 0


static func prewarm_assets() -> void:
	LoadingCameoCatalog.prewarm_assets()


func _init() -> void:
	name = HOST_NAME
	z_as_relative = false
	z_index = HOST_Z_INDEX
	set_process(false)
	_rng.randomize()


func show_loading(view_size: Vector2, tick_seconds: float, font: Font = null) -> void:
	if _selected_entry.is_empty():
		_select_entry_for_session()
	var texture := LoadingCameoCatalog.get_prewarmed_texture(_selected_entry)
	if texture == null:
		visible = false
		return
	_ensure_sprites()
	var cols := maxi(1, int(_selected_entry.get("cols", 1)))
	var rows := maxi(1, int(_selected_entry.get("rows", 1)))
	var frame_count := clampi(int(_selected_entry.get("frame_count", cols * rows)), 1, cols * rows)
	var fps := maxf(0.1, float(_selected_entry.get("fps", 1.0)))
	var frame_index := int(floor(maxf(0.0, tick_seconds) * fps)) % frame_count
	var cell_size := Vector2(texture.get_width() / float(cols), texture.get_height() / float(rows))
	if cell_size.y <= 1.0:
		visible = false
		return
	var target_height := view_size.y * float(_selected_entry.get("base_height_ratio", 0.09))
	var content_height := maxf(1.0, float(_selected_entry.get("content_height_px", cell_size.y)))
	var base_scale := target_height / content_height
	var center := LoadingCameoCatalog.get_cameo_center(view_size)
	var cameo_material := LoadingCameoCatalog.get_cameo_material()
	for index in range(_sprites.size()):
		var sprite := _sprites[index]
		sprite.texture = texture
		sprite.hframes = cols
		sprite.vframes = rows
		sprite.frame = frame_index
		sprite.position = center
		var layer_scale := base_scale * float(GLOW_SCALES[index])
		sprite.scale = Vector2(layer_scale, layer_scale)
		sprite.self_modulate = Color(1.0, 1.0, 1.0, float(GLOW_ALPHAS[index]))
		sprite.material = cameo_material
		sprite.visible = true
	_sync_copy_label(view_size, font)
	visible = true


func hide_loading() -> void:
	visible = false
	_selected_entry.clear()
	_session_pick_count = 0
	for sprite in _sprites:
		sprite.visible = false
	if _copy_label != null:
		_copy_label.visible = false


func get_debug_state() -> Dictionary:
	return {
		"entry_id": str(_selected_entry.get("id", "")),
		"frame_count": int(_selected_entry.get("frame_count", 0)),
		"session_pick_count": _session_pick_count,
		"visible": visible,
		"sprite_count": _sprites.size(),
	}


func _select_entry_for_session() -> void:
	_selected_entry = LoadingCameoCatalog.pick_random_entry(_rng)
	_session_pick_count += 1


func _ensure_sprites() -> void:
	if _sprites.size() == GLOW_SCALES.size():
		return
	for child in get_children():
		if child is Sprite2D:
			remove_child(child)
			child.queue_free()
	_sprites.clear()
	for index in range(GLOW_SCALES.size()):
		var sprite := Sprite2D.new()
		sprite.name = "Glow%d" % index if index < GLOW_SCALES.size() - 1 else "Cameo"
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		add_child(sprite)
		_sprites.append(sprite)


func _sync_copy_label(view_size: Vector2, font: Font) -> void:
	if font == null:
		return
	if _copy_label == null:
		_copy_label = Label.new()
		_copy_label.name = "LoadingCopy"
		_copy_label.text = "Now Loading..." # Intentional international literal; never localize.
		_copy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_copy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_copy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_copy_label.z_index = 1
		add_child(_copy_label)
	var view_scale := LoadingCameoCatalog.get_view_scale(view_size)
	var label_size := Vector2(220.0, 40.0) * view_scale
	var label_center := Vector2(
		LoadingCameoCatalog.get_cameo_center(view_size).x,
		LoadingCameoCatalog.get_copy_band_y(view_size)
	)
	_copy_label.position = label_center - label_size * 0.5
	_copy_label.size = label_size
	_copy_label.add_theme_font_override("font", font)
	_copy_label.add_theme_font_size_override(
		"font_size",
		maxi(12, int(round(LoadingCameoCatalog.LOADING_COPY_FONT_SIZE * view_scale)))
	)
	_copy_label.add_theme_color_override("font_color", LoadingCameoCatalog.LOADING_COPY_COLOR)
	_copy_label.visible = true
