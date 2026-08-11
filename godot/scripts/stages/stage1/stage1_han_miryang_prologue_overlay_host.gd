extends Control

const FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const CHAPTER_REVEAL_START := 45.0

const A1_TO_A2_START := 11.2
const A1_TO_A2_END := 12.6
const A2_TO_A3_START := 15.0
const A2_TO_A3_END := 16.2
const A3_TO_B1_START := 18.4
const A3_TO_B1_END := 19.6
const B1_TO_B2_START := 22.4
const B1_TO_B2_END := 23.6
const B2_TO_C1_START := 26.0
const B2_TO_C1_END := 27.4
const C1_TO_D1_START := 29.6
const C1_TO_D1_END := 30.8
const D1_TO_D2_START := 33.0
const D1_TO_D2_END := 34.0

const PLATE_A1 := "a1"
const PLATE_A2 := "a2"
const PLATE_A3 := "a3"
const PLATE_B1 := "b1"
const PLATE_B2 := "b2"
const PLATE_C1 := "c1"
const PLATE_D1 := "d1"
const PLATE_D2 := "d2"


class PrologueDrawBridge:
	extends Control

	var presentation_host: Object = null

	func _draw() -> void:
		if presentation_host != null:
			presentation_host.call("draw_prologue", self)


var _elapsed := 0.0
var _fade_alpha := 0.0
var _plate_textures: Dictionary = {}
var _copy: Dictionary = {}
var _skip_allowed := false
var _applied_font_locale := ""
var _elapsed_card_visible := false

var _screen_black: ColorRect = null
var _draw_bridge: PrologueDrawBridge = null
var _fade_cover: ColorRect = null
var _title_label: Label = null
var _speaker_label: Label = null
var _subtitle_label: Label = null
var _skip_label: Label = null


func _init() -> void:
	name = "Stage1HanMiryangPrologueOverlayHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	top_level = true
	z_as_relative = false
	z_index = 3130
	visible = false
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	_build_nodes()


func begin(startup_textures: Dictionary, copy: Dictionary) -> bool:
	_build_nodes()
	for plate_key in [PLATE_A1, PLATE_A2, PLATE_A3]:
		var texture_value: Variant = startup_textures.get(plate_key, null)
		if not (texture_value is Texture2D):
			return false
	_plate_textures.clear()
	for key_value in startup_textures:
		var texture_value: Variant = startup_textures[key_value]
		if texture_value is Texture2D:
			_plate_textures[str(key_value)] = texture_value
	_copy = copy.duplicate(true)
	_applied_font_locale = ""
	_elapsed = 0.0
	_fade_alpha = 0.0
	_skip_allowed = false
	_elapsed_card_visible = false
	visible = true
	_screen_black.visible = true
	_draw_bridge.visible = true
	_sync_fade_cover()
	_apply_copy()
	set_dialogue({})
	_queue_visual_redraw()
	return true


func set_plate_texture(plate_key: String, texture: Texture2D) -> void:
	if plate_key == "" or texture == null:
		return
	_plate_textures[plate_key] = texture
	_queue_visual_redraw()


func release_plate_texture(plate_key: String) -> void:
	_plate_textures.erase(plate_key)
	_queue_visual_redraw()


func sync_timeline(
	elapsed: float,
	fade_alpha: float,
	segment: Dictionary,
	skip_allowed: bool = true
) -> void:
	_elapsed = maxf(0.0, elapsed)
	_fade_alpha = clampf(fade_alpha, 0.0, 1.0)
	_skip_allowed = skip_allowed
	_sync_fade_cover()
	set_dialogue(segment)
	_apply_copy()
	_queue_visual_redraw()


func set_dialogue(segment: Dictionary) -> void:
	_build_nodes()
	var speaker := str(segment.get("speaker", ""))
	var text := str(segment.get("text", ""))
	_elapsed_card_visible = bool(segment.get("elapsed_card", false))
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != "" and _elapsed < CHAPTER_REVEAL_START
	_subtitle_label.text = text
	_subtitle_label.visible = text != "" and _elapsed < CHAPTER_REVEAL_START


func sync_layout(view_size: Vector2) -> void:
	_build_nodes()
	position = Vector2.ZERO
	size = view_size
	_screen_black.position = Vector2.ZERO
	_screen_black.size = view_size
	_draw_bridge.position = Vector2.ZERO
	_draw_bridge.size = view_size
	_fade_cover.position = Vector2.ZERO
	_fade_cover.size = view_size
	var scale_factor := clampf(minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y), 0.62, 1.35)
	_apply_title_layout(view_size, scale_factor)
	_speaker_label.position = Vector2(view_size.x * 0.080, view_size.y * 0.765)
	_speaker_label.size = Vector2(view_size.x * 0.84, 38.0 * scale_factor)
	_speaker_label.add_theme_font_size_override("font_size", maxi(15, int(round(22.0 * scale_factor))))
	if _elapsed_card_visible:
		_subtitle_label.position = Vector2(view_size.x * 0.12, view_size.y * 0.72)
		_subtitle_label.size = Vector2(view_size.x * 0.76, view_size.y * 0.15)
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		_subtitle_label.position = Vector2(view_size.x * 0.080, view_size.y * 0.805)
		_subtitle_label.size = Vector2(view_size.x * 0.84, view_size.y * 0.145)
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_subtitle_label.add_theme_font_size_override("font_size", maxi(18, int(round(30.0 * scale_factor))))
	_skip_label.position = Vector2(view_size.x * 0.63, view_size.y * 0.045)
	_skip_label.size = Vector2(view_size.x * 0.32, 32.0 * scale_factor)
	_skip_label.add_theme_font_size_override("font_size", maxi(11, int(round(15.0 * scale_factor))))


func _apply_title_layout(view_size: Vector2, scale_factor: float) -> void:
	var show_chapter := _elapsed >= CHAPTER_REVEAL_START
	if show_chapter:
		_title_label.position = Vector2(view_size.x * 0.08, view_size.y * 0.36)
		_title_label.size = Vector2(view_size.x * 0.84, view_size.y * 0.28)
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_label.add_theme_font_size_override("font_size", maxi(28, int(round(44.0 * scale_factor))))
		return
	_title_label.position = Vector2(view_size.x * 0.065, view_size.y * 0.075)
	_title_label.size = Vector2(view_size.x * 0.70, 72.0 * scale_factor)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", maxi(24, int(round(38.0 * scale_factor))))


func set_inactive() -> void:
	visible = false
	if _screen_black != null:
		_screen_black.visible = false
	if _draw_bridge != null:
		_draw_bridge.visible = false
	if _fade_cover != null:
		_fade_cover.visible = false
	if _title_label != null:
		_title_label.visible = false
	if _speaker_label != null:
		_speaker_label.visible = false
	if _subtitle_label != null:
		_subtitle_label.visible = false
	if _skip_label != null:
		_skip_label.visible = false


func tear_down(free_self: bool = false) -> void:
	set_inactive()
	_plate_textures.clear()
	if free_self and is_inside_tree():
		queue_free()


func get_snapshot() -> Dictionary:
	var readiness: Dictionary = {}
	for plate_key in [PLATE_A1, PLATE_A2, PLATE_A3, PLATE_B1, PLATE_B2, PLATE_C1, PLATE_D1, PLATE_D2]:
		readiness[plate_key] = _plate_textures.get(plate_key, null) is Texture2D
	return {
		"visible": visible,
		"process_enabled": is_processing(),
		"physics_process_enabled": is_physics_processing(),
		"elapsed": _elapsed,
		"plate_ready": readiness,
		"skip_allowed": _skip_allowed,
		"uses_fallback_font": _title_label != null and _title_label.get_theme_font("font") == ThemeDB.fallback_font,
		"speaker": _speaker_label.text if _speaker_label != null else "",
		"subtitle": _subtitle_label.text if _subtitle_label != null else "",
		"title": _title_label.text if _title_label != null else "",
		"title_centered": _title_label != null and _title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"title_wrap_enabled": _title_label != null and _title_label.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"elapsed_card_visible": _elapsed_card_visible,
		"fade_alpha": _fade_alpha,
		"fade_cover_alpha": _fade_cover.color.a if _fade_cover != null else 0.0,
		"fade_cover_above_title": _fade_cover != null and _title_label != null and _fade_cover.z_index > _title_label.z_index,
		"size": size,
	}


func draw_prologue(canvas: CanvasItem) -> void:
	if canvas == null or not visible:
		return
	var view_size := _draw_bridge.size if _draw_bridge != null else size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	_draw_timeline_plate(canvas, view_size)
	_draw_cinematic_grade(canvas, view_size)
	_draw_event_flashes(canvas, view_size)
	_draw_frame_accents(canvas, view_size)


func _draw_timeline_plate(canvas: CanvasItem, view_size: Vector2) -> void:
	if _elapsed < A1_TO_A2_START:
		_draw_single_plate(canvas, view_size, PLATE_A1, 1.025, Vector2(0.49, 0.50))
	elif _elapsed < A1_TO_A2_END:
		_draw_plate_blend(canvas, view_size, PLATE_A1, PLATE_A2, A1_TO_A2_START, A1_TO_A2_END, 1.04, Vector2(0.50, 0.49))
	elif _elapsed < A2_TO_A3_START:
		_draw_single_plate(canvas, view_size, PLATE_A2, 1.045, Vector2(0.50, 0.49))
	elif _elapsed < A2_TO_A3_END:
		_draw_plate_blend(canvas, view_size, PLATE_A2, PLATE_A3, A2_TO_A3_START, A2_TO_A3_END, 1.05, Vector2(0.50, 0.49))
	elif _elapsed < A3_TO_B1_START:
		_draw_single_plate(canvas, view_size, PLATE_A3, 1.055, Vector2(0.50, 0.49))
	elif _elapsed < A3_TO_B1_END:
		_draw_plate_blend(canvas, view_size, PLATE_A3, PLATE_B1, A3_TO_B1_START, A3_TO_B1_END, 1.06, Vector2(0.50, 0.46))
	elif _elapsed < B1_TO_B2_START:
		_draw_single_plate(canvas, view_size, PLATE_B1, 1.065, Vector2(0.50, 0.44))
	elif _elapsed < B1_TO_B2_END:
		_draw_plate_blend(canvas, view_size, PLATE_B1, PLATE_B2, B1_TO_B2_START, B1_TO_B2_END, 1.07, Vector2(0.50, 0.44))
	elif _elapsed < B2_TO_C1_START:
		_draw_single_plate(canvas, view_size, PLATE_B2, 1.07, Vector2(0.50, 0.44))
	elif _elapsed < B2_TO_C1_END:
		_draw_plate_blend(canvas, view_size, PLATE_B2, PLATE_C1, B2_TO_C1_START, B2_TO_C1_END, 1.05, Vector2(0.50, 0.48))
	elif _elapsed < C1_TO_D1_START:
		_draw_single_plate(canvas, view_size, PLATE_C1, 1.045, Vector2(0.50, 0.49))
	elif _elapsed < C1_TO_D1_END:
		_draw_plate_blend(canvas, view_size, PLATE_C1, PLATE_D1, C1_TO_D1_START, C1_TO_D1_END, 1.055, Vector2(0.50, 0.48))
	elif _elapsed < D1_TO_D2_START:
		_draw_single_plate(canvas, view_size, PLATE_D1, 1.06, Vector2(0.50, 0.48))
	elif _elapsed < D1_TO_D2_END:
		_draw_plate_blend(canvas, view_size, PLATE_D1, PLATE_D2, D1_TO_D2_START, D1_TO_D2_END, 1.065, Vector2(0.50, 0.48))
	else:
		_draw_single_plate(canvas, view_size, PLATE_D2, 1.07, Vector2(0.50, 0.48))


func _draw_single_plate(canvas: CanvasItem, view_size: Vector2, plate_key: String, zoom: float, focus: Vector2) -> void:
	var texture := _get_plate_texture(plate_key)
	if texture == null:
		texture = _get_latest_available_plate(plate_key)
	_draw_cover_texture(canvas, texture, view_size, zoom, focus, 1.0)


func _draw_plate_blend(
	canvas: CanvasItem,
	view_size: Vector2,
	from_key: String,
	to_key: String,
	start_time: float,
	end_time: float,
	zoom: float,
	focus: Vector2
) -> void:
	var from_texture := _get_plate_texture(from_key)
	if from_texture == null:
		from_texture = _get_latest_available_plate(from_key)
	var to_texture := _get_plate_texture(to_key)
	if to_texture == null:
		_draw_cover_texture(canvas, from_texture, view_size, zoom, focus, 1.0)
		return
	var blend := _smoothstep(start_time, end_time, _elapsed)
	_draw_cover_texture(canvas, from_texture, view_size, zoom, focus, 1.0 - blend)
	_draw_cover_texture(canvas, to_texture, view_size, zoom, focus, blend)


func _get_plate_texture(plate_key: String) -> Texture2D:
	var value: Variant = _plate_textures.get(plate_key, null)
	return value as Texture2D if value is Texture2D else null


func _get_latest_available_plate(target_key: String) -> Texture2D:
	var ordered := [PLATE_A1, PLATE_A2, PLATE_A3, PLATE_B1, PLATE_B2, PLATE_C1, PLATE_D1, PLATE_D2]
	var target_index := ordered.find(target_key)
	for index in range(target_index, -1, -1):
		var texture := _get_plate_texture(str(ordered[index]))
		if texture != null:
			return texture
	return null


func _build_nodes() -> void:
	if _draw_bridge != null:
		return
	_screen_black = ColorRect.new()
	_screen_black.name = "HanMiryangPrologueScreenBlack"
	_screen_black.color = Color.BLACK
	_screen_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_black.z_index = 0
	add_child(_screen_black)

	_draw_bridge = PrologueDrawBridge.new()
	_draw_bridge.name = "HanMiryangPrologueDraw"
	_draw_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_bridge.presentation_host = self
	_draw_bridge.z_index = 1
	add_child(_draw_bridge)

	_title_label = _new_label("HanMiryangPrologueTitle", HORIZONTAL_ALIGNMENT_LEFT, 3)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.modulate = Color(0.96, 0.86, 0.61, 1.0)
	add_child(_title_label)
	_speaker_label = _new_label("HanMiryangPrologueSpeaker", HORIZONTAL_ALIGNMENT_LEFT, 3)
	_speaker_label.modulate = Color(0.58, 0.92, 0.87, 1.0)
	add_child(_speaker_label)
	_subtitle_label = _new_label("HanMiryangPrologueSubtitle", HORIZONTAL_ALIGNMENT_LEFT, 3)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.modulate = Color(0.98, 0.98, 0.96, 1.0)
	add_child(_subtitle_label)
	_skip_label = _new_label("HanMiryangPrologueSkip", HORIZONTAL_ALIGNMENT_RIGHT, 3)
	_skip_label.modulate = Color(0.82, 0.84, 0.85, 0.82)
	add_child(_skip_label)

	_fade_cover = ColorRect.new()
	_fade_cover.name = "HanMiryangPrologueFadeCover"
	_fade_cover.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_cover.z_index = 4
	add_child(_fade_cover)
	set_inactive()


func _new_label(label_name: String, alignment: HorizontalAlignment, z_value: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	label.add_theme_constant_override("outline_size", 7)
	label.z_index = z_value
	return label


func _apply_copy() -> void:
	if _title_label == null:
		return
	var show_chapter := _elapsed >= CHAPTER_REVEAL_START
	if size.x > 1.0 and size.y > 1.0:
		var scale_factor := clampf(minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y), 0.62, 1.35)
		_apply_title_layout(size, scale_factor)
	_apply_locale_font(str(_copy.get("locale", "ko")))
	_title_label.text = str(_copy.get("chapter", "")) if show_chapter else str(_copy.get("title", ""))
	_title_label.visible = visible
	_skip_label.text = str(_copy.get("skip", ""))
	_skip_label.visible = visible and not show_chapter and _skip_allowed


func _sync_fade_cover() -> void:
	if _fade_cover == null:
		return
	_fade_cover.color = Color(0.0, 0.0, 0.0, _fade_alpha)
	_fade_cover.visible = visible and _fade_alpha > 0.0


func _apply_locale_font(locale: String) -> void:
	var normalized := locale.strip_edges().to_lower()
	if normalized == _applied_font_locale:
		return
	var font: Font = FONT
	if normalized in ["ja", "zh"] and ThemeDB.fallback_font != null:
		font = ThemeDB.fallback_font
	var labels: Array[Label] = [_title_label, _speaker_label, _subtitle_label, _skip_label]
	for label in labels:
		if label != null:
			label.add_theme_font_override("font", font)
	_applied_font_locale = normalized


func _draw_cover_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	view_size: Vector2,
	zoom: float,
	focus: Vector2,
	alpha: float
) -> void:
	if texture == null or alpha <= 0.001:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var source_size := texture_size
	var source_aspect := texture_size.x / texture_size.y
	var target_aspect := view_size.x / view_size.y
	if source_aspect > target_aspect:
		source_size.x = texture_size.y * target_aspect
	else:
		source_size.y = texture_size.x / target_aspect
	var safe_zoom := maxf(1.0, zoom)
	source_size /= safe_zoom
	var max_origin := texture_size - source_size
	var source_origin := Vector2(max_origin.x * clampf(focus.x, 0.0, 1.0), max_origin.y * clampf(focus.y, 0.0, 1.0))
	canvas.draw_texture_rect_region(
		texture,
		Rect2(Vector2.ZERO, view_size),
		Rect2(source_origin, source_size),
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	)


func _draw_cinematic_grade(canvas: CanvasItem, view_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, view_size.y * 0.105)), Color(0.005, 0.008, 0.012, 0.72), true)
	canvas.draw_rect(Rect2(0.0, view_size.y * 0.735, view_size.x, view_size.y * 0.265), Color(0.004, 0.006, 0.010, 0.72), true)
	for index in range(7):
		var ratio := float(index) / 6.0
		var band_y := lerpf(view_size.y * 0.66, view_size.y, ratio)
		canvas.draw_rect(Rect2(0.0, band_y, view_size.x, view_size.y * 0.075), Color(0.0, 0.0, 0.0, 0.035 + ratio * 0.055), true)
	var fade_in := 1.0 - _smoothstep(0.0, 0.8, _elapsed)
	if fade_in > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, fade_in), true)


func _draw_event_flashes(canvas: CanvasItem, view_size: Vector2) -> void:
	var flash := 0.0
	for cue_time in [11.2, 22.4, 27.4, 33.4]:
		var distance := absf(_elapsed - float(cue_time))
		if distance < 0.28:
			flash = maxf(flash, (1.0 - distance / 0.28) * 0.20)
	if flash > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.55, 1.0, 0.92, flash), true)


func _draw_frame_accents(canvas: CanvasItem, view_size: Vector2) -> void:
	var gold := Color(0.73, 0.58, 0.30, 0.64)
	var teal := Color(0.35, 0.88, 0.82, 0.48)
	canvas.draw_line(Vector2(view_size.x * 0.065, view_size.y * 0.145), Vector2(view_size.x * 0.27, view_size.y * 0.145), gold, 2.0)
	canvas.draw_line(Vector2(view_size.x * 0.080, view_size.y * 0.795), Vector2(view_size.x * 0.135, view_size.y * 0.795), teal, 3.0)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if edge1 <= edge0:
		return 1.0 if value >= edge1 else 0.0
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _queue_visual_redraw() -> void:
	if _draw_bridge != null:
		_draw_bridge.queue_redraw()
