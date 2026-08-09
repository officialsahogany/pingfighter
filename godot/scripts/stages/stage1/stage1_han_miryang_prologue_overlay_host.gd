extends Control

const FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const STRIKE_SCENE_BLEND_START := 15.55
const STRIKE_SCENE_BLEND_END := 17.10
const TABLET_REVEAL_BLEND_START := 19.50
const TABLET_REVEAL_BLEND_END := 21.00
const CHAPTER_REVEAL_START := 35.00


class PrologueDrawBridge:
	extends Control

	var presentation_host: Object = null

	func _draw() -> void:
		if presentation_host != null:
			presentation_host.call("draw_prologue", self)


var _elapsed := 0.0
var _fade_alpha := 0.0
var _first_texture: Texture2D = null
var _strike_texture: Texture2D = null
var _second_texture: Texture2D = null
var _copy: Dictionary = {}
var _skip_allowed := false
var _applied_font_locale := ""

var _screen_black: ColorRect = null
var _draw_bridge: PrologueDrawBridge = null
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


func begin(
	first_texture: Texture2D,
	strike_texture: Texture2D,
	second_texture: Texture2D,
	copy: Dictionary
) -> bool:
	_build_nodes()
	if first_texture == null or strike_texture == null or second_texture == null:
		return false
	_first_texture = first_texture
	_strike_texture = strike_texture
	_second_texture = second_texture
	_copy = copy.duplicate(true)
	_applied_font_locale = ""
	_elapsed = 0.0
	_fade_alpha = 0.0
	_skip_allowed = false
	visible = true
	_screen_black.visible = true
	_draw_bridge.visible = true
	_apply_copy()
	set_dialogue({})
	_queue_visual_redraw()
	return true


func sync_timeline(
	elapsed: float,
	fade_alpha: float,
	segment: Dictionary,
	skip_allowed: bool = true
) -> void:
	_elapsed = maxf(0.0, elapsed)
	_fade_alpha = clampf(fade_alpha, 0.0, 1.0)
	_skip_allowed = skip_allowed
	set_dialogue(segment)
	_apply_copy()
	_queue_visual_redraw()


func set_dialogue(segment: Dictionary) -> void:
	_build_nodes()
	var speaker := str(segment.get("speaker", ""))
	var text := str(segment.get("text", ""))
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
	var scale_factor := clampf(minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y), 0.62, 1.35)
	_apply_title_layout(view_size, scale_factor)
	_speaker_label.position = Vector2(view_size.x * 0.080, view_size.y * 0.765)
	_speaker_label.size = Vector2(view_size.x * 0.84, 38.0 * scale_factor)
	_speaker_label.add_theme_font_size_override("font_size", maxi(15, int(round(22.0 * scale_factor))))
	_subtitle_label.position = Vector2(view_size.x * 0.080, view_size.y * 0.805)
	_subtitle_label.size = Vector2(view_size.x * 0.84, view_size.y * 0.145)
	_subtitle_label.add_theme_font_size_override("font_size", maxi(18, int(round(30.0 * scale_factor))))
	_skip_label.position = Vector2(view_size.x * 0.63, view_size.y * 0.045)
	_skip_label.size = Vector2(view_size.x * 0.32, 32.0 * scale_factor)
	_skip_label.add_theme_font_size_override("font_size", maxi(11, int(round(15.0 * scale_factor))))


func _apply_title_layout(view_size: Vector2, scale_factor: float) -> void:
	var show_chapter := _elapsed >= CHAPTER_REVEAL_START
	if show_chapter:
		_title_label.position = Vector2(view_size.x * 0.08, view_size.y * 0.405)
		_title_label.size = Vector2(view_size.x * 0.84, view_size.y * 0.19)
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_label.add_theme_font_size_override("font_size", maxi(30, int(round(48.0 * scale_factor))))
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
	_first_texture = null
	_strike_texture = null
	_second_texture = null
	if free_self and is_inside_tree():
		queue_free()


func get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"process_enabled": is_processing(),
		"physics_process_enabled": is_physics_processing(),
		"elapsed": _elapsed,
		"first_texture_ready": _first_texture != null,
		"strike_texture_ready": _strike_texture != null,
		"second_texture_ready": _second_texture != null,
		"skip_allowed": _skip_allowed,
		"uses_fallback_font": _title_label != null and _title_label.get_theme_font("font") == ThemeDB.fallback_font,
		"speaker": _speaker_label.text if _speaker_label != null else "",
		"subtitle": _subtitle_label.text if _subtitle_label != null else "",
		"title": _title_label.text if _title_label != null else "",
		"title_centered": _title_label != null and _title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"fade_alpha": _fade_alpha,
		"size": size,
	}


func draw_prologue(canvas: CanvasItem) -> void:
	if canvas == null or not visible:
		return
	var view_size := _draw_bridge.size if _draw_bridge != null else size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var strike_blend := _smoothstep(STRIKE_SCENE_BLEND_START, STRIKE_SCENE_BLEND_END, _elapsed)
	var tablet_blend := _smoothstep(TABLET_REVEAL_BLEND_START, TABLET_REVEAL_BLEND_END, _elapsed)
	var first_motion := _smoothstep(0.0, STRIKE_SCENE_BLEND_END, _elapsed)
	var first_zoom := lerpf(1.02, 1.10, first_motion)
	var first_focus := Vector2(lerpf(0.47, 0.52, first_motion), lerpf(0.48, 0.51, first_motion))
	var strike_motion := _smoothstep(STRIKE_SCENE_BLEND_START, CHAPTER_REVEAL_START, _elapsed)
	var strike_zoom := lerpf(1.10, 1.04, strike_motion)
	var strike_focus := Vector2(lerpf(0.54, 0.50, strike_motion), lerpf(0.50, 0.48, strike_motion))
	_draw_cover_texture(canvas, _first_texture, view_size, first_zoom, first_focus, 1.0 - strike_blend)
	_draw_cover_texture(canvas, _strike_texture, view_size, strike_zoom, strike_focus, strike_blend * (1.0 - tablet_blend))
	_draw_cover_texture(canvas, _second_texture, view_size, strike_zoom, strike_focus, strike_blend * tablet_blend)
	_draw_cinematic_grade(canvas, view_size)
	_draw_missing_beat_flash(canvas, view_size)
	_draw_frame_accents(canvas, view_size)
	if _fade_alpha > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, _fade_alpha), true)


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
	_title_label.modulate = Color(0.96, 0.86, 0.61, 1.0)
	add_child(_title_label)
	_speaker_label = _new_label("HanMiryangPrologueSpeaker", HORIZONTAL_ALIGNMENT_LEFT, 3)
	_speaker_label.modulate = Color(0.58, 0.92, 0.87, 1.0)
	add_child(_speaker_label)
	_subtitle_label = _new_label("HanMiryangPrologueSubtitle", HORIZONTAL_ALIGNMENT_LEFT, 3)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_subtitle_label.modulate = Color(0.98, 0.98, 0.96, 1.0)
	add_child(_subtitle_label)
	_skip_label = _new_label("HanMiryangPrologueSkip", HORIZONTAL_ALIGNMENT_RIGHT, 3)
	_skip_label.modulate = Color(0.82, 0.84, 0.85, 0.82)
	add_child(_skip_label)
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
		canvas.draw_rect(
			Rect2(0.0, band_y, view_size.x, view_size.y * 0.075),
			Color(0.0, 0.0, 0.0, 0.035 + ratio * 0.055),
			true
		)
	var fade_in := 1.0 - _smoothstep(0.0, 1.25, _elapsed)
	if fade_in > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, fade_in), true)


func _draw_missing_beat_flash(canvas: CanvasItem, view_size: Vector2) -> void:
	var distance := absf(_elapsed - 16.05)
	if distance >= 0.34:
		return
	var envelope := 1.0 - distance / 0.34
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.68, 1.0, 0.94, envelope * 0.30), true)


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
