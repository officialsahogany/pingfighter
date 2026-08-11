extends Control

const FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const CINEMATIC_ID := "han_miryang_araul_first_contest_v2"
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
const B2_TO_C1_FLASH_START := 26.0
const B2_TO_C1_CUT := 26.25
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
const FX_TABLET := "fx_tablet"
const FX_ORB := "fx_orb"
const FX_RAYS := "fx_rays"
const FX_SHARD := "fx_shard"

const FULL_PLATE_SIZE := Vector2(3344.0, 1882.0)
const C1_RAY_CENTER_NORMALIZED := Vector2(835.0 / 1672.0, 350.0 / 941.0)
const D_IMPACT_CENTER_NORMALIZED := Vector2(0.485, 0.385)
const FX_LAYOUT := {
	FX_TABLET: {"offset": Vector2(1463.0, 237.0), "size": Vector2(585.0, 1107.0)},
	FX_ORB: {"offset": Vector2(1530.0, 274.0), "size": Vector2(652.0, 619.0)},
	FX_RAYS: {"offset": Vector2(33.0, 0.0), "size": Vector2(3288.0, 1361.0)},
	FX_SHARD: {"offset": Vector2(661.0, 237.0), "size": Vector2(1447.0, 823.0)},
}
const SPARK_COUNT := 40
const MOTION_SEED_SALT := 0x41A0_6A11


class PrologueDrawBridge:
	extends Control

	var presentation_host: Object = null

	func _draw() -> void:
		if presentation_host != null:
			presentation_host.call("draw_prologue", self)


class PrologueAdditiveDrawBridge:
	extends Control

	var presentation_host: Object = null

	func _draw() -> void:
		if presentation_host != null:
			presentation_host.call("draw_additive_fx", self)


var _elapsed := 0.0
var _fade_alpha := 0.0
var _plate_textures: Dictionary = {}
var _copy: Dictionary = {}
var _skip_allowed := false
var _applied_font_locale := ""
var _elapsed_card_visible := false
var _motion_enabled := false
var _flash_alpha := 0.0
var _ray_growth := 0.0
var _ray_additive_alpha := 0.0
var _shard_progress := 0.0
var _shard_alpha := 0.0
var _shake_magnitude := 0.0
var _base_plate_key := PLATE_A1
var _sparks: Array[Dictionary] = []
var _shake_samples: Array[Vector2] = []

var _screen_black: ColorRect = null
var _draw_bridge: PrologueDrawBridge = null
var _additive_bridge: PrologueAdditiveDrawBridge = null
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
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


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
	_motion_enabled = true
	_build_motion_samples()
	_update_motion_state()
	visible = true
	_screen_black.visible = true
	_draw_bridge.visible = true
	_additive_bridge.visible = true
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
	skip_allowed: bool = true,
	motion_enabled: bool = true
) -> void:
	_elapsed = maxf(0.0, elapsed)
	_fade_alpha = clampf(fade_alpha, 0.0, 1.0)
	_skip_allowed = skip_allowed
	_motion_enabled = motion_enabled
	_update_motion_state()
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
	_additive_bridge.position = Vector2.ZERO
	_additive_bridge.size = view_size
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
	_motion_enabled = false
	_reset_motion_state()
	visible = false
	if _screen_black != null:
		_screen_black.visible = false
	if _draw_bridge != null:
		_draw_bridge.visible = false
	if _additive_bridge != null:
		_additive_bridge.visible = false
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
	_sparks.clear()
	_shake_samples.clear()
	if free_self and is_inside_tree():
		queue_free()


func get_snapshot() -> Dictionary:
	var readiness: Dictionary = {}
	for plate_key in [PLATE_A1, PLATE_A2, PLATE_A3, PLATE_B1, PLATE_B2, PLATE_C1, PLATE_D1, PLATE_D2, FX_TABLET, FX_ORB, FX_RAYS, FX_SHARD]:
		readiness[plate_key] = _plate_textures.get(plate_key, null) is Texture2D
	var camera_state := _get_camera_state(_base_plate_key)
	var source_rect := _get_cover_source_rect(FULL_PLATE_SIZE, size if size.x > 1.0 and size.y > 1.0 else REFERENCE_SIZE, float(camera_state.get("zoom", 1.0)), camera_state.get("focus", Vector2(0.5, 0.5)), Vector2.ZERO)
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
		"flash_alpha": _flash_alpha,
		"ray_growth": _ray_growth,
		"ray_additive_alpha": _ray_additive_alpha,
		"shard_progress": _shard_progress,
		"shard_alpha": _shard_alpha,
		"shake_magnitude": _shake_magnitude,
		"base_plate_key": _base_plate_key,
		"subtitle_position": _subtitle_label.position if _subtitle_label != null else Vector2.ZERO,
		"camera_zoom": float(camera_state.get("zoom", 1.0)),
		"camera_source_width_ratio": source_rect.size.x / FULL_PLATE_SIZE.x,
		"additive_blend_mode": int((_additive_bridge.material as CanvasItemMaterial).blend_mode) if _additive_bridge != null and _additive_bridge.material is CanvasItemMaterial else -1,
		"additive_interpolation_off": _additive_bridge != null and _additive_bridge.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
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
	_draw_motion_mix_fx(canvas, view_size)
	_draw_frame_accents(canvas, view_size)


func draw_additive_fx(canvas: CanvasItem) -> void:
	if canvas == null or not visible or not _motion_enabled:
		return
	var view_size := _additive_bridge.size if _additive_bridge != null else size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	_draw_ray_fx(canvas, view_size)
	_draw_sparks(canvas, view_size)
	_draw_impact_fx(canvas, view_size)


func _draw_timeline_plate(canvas: CanvasItem, view_size: Vector2) -> void:
	if _elapsed < A1_TO_A2_START:
		_draw_single_plate(canvas, view_size, PLATE_A1)
	elif _elapsed < A1_TO_A2_END:
		_draw_single_plate(canvas, view_size, PLATE_A1)
		var reveal := _ease_out_cubic(_inverse_lerp_clamped(A1_TO_A2_START, A1_TO_A2_END, _elapsed))
		_draw_cropped_fx(canvas, view_size, FX_TABLET, PLATE_A1, 1.0, reveal, "bottom", 1.0, Vector2.ZERO)
	elif _elapsed < A2_TO_A3_START:
		_draw_single_plate(canvas, view_size, PLATE_A2)
	elif _elapsed < A2_TO_A3_END:
		_draw_plate_blend(canvas, view_size, PLATE_A2, PLATE_A3, A2_TO_A3_START, A2_TO_A3_END)
	elif _elapsed < A3_TO_B1_START:
		_draw_single_plate(canvas, view_size, PLATE_A3)
	elif _elapsed < A3_TO_B1_END:
		_draw_plate_blend(canvas, view_size, PLATE_A3, PLATE_B1, A3_TO_B1_START, A3_TO_B1_END)
	elif _elapsed < B1_TO_B2_START:
		_draw_single_plate(canvas, view_size, PLATE_B1)
	elif _elapsed < B1_TO_B2_END:
		_draw_plate_blend(canvas, view_size, PLATE_B1, PLATE_B2, B1_TO_B2_START, B1_TO_B2_END)
	elif _elapsed < B2_TO_C1_CUT:
		_draw_single_plate(canvas, view_size, PLATE_B2)
	elif _elapsed < C1_TO_D1_START:
		_draw_single_plate(canvas, view_size, PLATE_C1)
	elif _elapsed < C1_TO_D1_END:
		_draw_plate_blend(canvas, view_size, PLATE_C1, PLATE_D1, C1_TO_D1_START, C1_TO_D1_END)
	elif _elapsed < D1_TO_D2_START:
		_draw_single_plate(canvas, view_size, PLATE_D1)
	elif _elapsed < D1_TO_D2_END:
		_draw_plate_blend(canvas, view_size, PLATE_D1, PLATE_D2, D1_TO_D2_START, D1_TO_D2_END)
	else:
		_draw_single_plate(canvas, view_size, PLATE_D2)


func _draw_single_plate(canvas: CanvasItem, view_size: Vector2, plate_key: String) -> void:
	var texture := _get_plate_texture(plate_key)
	if texture == null:
		texture = _get_latest_available_plate(plate_key)
	var camera_state := _get_camera_state(plate_key)
	_draw_cover_texture(
		canvas,
		texture,
		view_size,
		float(camera_state.get("zoom", 1.0)),
		camera_state.get("focus", Vector2(0.5, 0.5)),
		1.0,
		_get_shake_offset_source()
	)


func _draw_plate_blend(
	canvas: CanvasItem,
	view_size: Vector2,
	from_key: String,
	to_key: String,
	start_time: float,
	end_time: float
) -> void:
	var from_texture := _get_plate_texture(from_key)
	if from_texture == null:
		from_texture = _get_latest_available_plate(from_key)
	var to_texture := _get_plate_texture(to_key)
	var camera_state := _get_camera_state(to_key)
	var zoom := float(camera_state.get("zoom", 1.0))
	var focus: Vector2 = camera_state.get("focus", Vector2(0.5, 0.5))
	var shake_offset := _get_shake_offset_source()
	if to_texture == null:
		_draw_cover_texture(canvas, from_texture, view_size, zoom, focus, 1.0, shake_offset)
		return
	var blend := _smoothstep(start_time, end_time, _elapsed)
	# Standard MIX alpha is source-over, not arithmetic addition. Keep the
	# predecessor opaque and fade the successor over it; fading both sides would
	# darken every midpoint to roughly 75 percent luminance.
	_draw_cover_texture(canvas, from_texture, view_size, zoom, focus, 1.0, shake_offset)
	_draw_cover_texture(canvas, to_texture, view_size, zoom, focus, blend, shake_offset)


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
	_draw_bridge.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_draw_bridge)

	_additive_bridge = PrologueAdditiveDrawBridge.new()
	_additive_bridge.name = "HanMiryangPrologueAdditiveFx"
	_additive_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_additive_bridge.presentation_host = self
	_additive_bridge.z_index = 2
	_additive_bridge.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_additive_bridge.material = additive_material
	add_child(_additive_bridge)

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
	alpha: float,
	source_jitter: Vector2 = Vector2.ZERO
) -> void:
	if texture == null or alpha <= 0.001:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var source_rect := _get_cover_source_rect(texture_size, view_size, zoom, focus, source_jitter)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(Vector2.ZERO, view_size),
		source_rect,
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	)


func _get_cover_source_rect(
	texture_size: Vector2,
	view_size: Vector2,
	zoom: float,
	focus: Vector2,
	source_jitter: Vector2
) -> Rect2:
	var source_size := texture_size
	var source_aspect := texture_size.x / texture_size.y
	var target_aspect := view_size.x / view_size.y
	if source_aspect > target_aspect:
		source_size.x = texture_size.y * target_aspect
	else:
		source_size.y = texture_size.x / target_aspect
	source_size /= maxf(1.0, zoom)
	var max_origin := texture_size - source_size
	var source_origin := Vector2(
		max_origin.x * clampf(focus.x, 0.0, 1.0),
		max_origin.y * clampf(focus.y, 0.0, 1.0)
	)
	source_origin += source_jitter
	source_origin.x = clampf(source_origin.x, 0.0, max_origin.x)
	source_origin.y = clampf(source_origin.y, 0.0, max_origin.y)
	return Rect2(source_origin, source_size)


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


func _draw_motion_mix_fx(canvas: CanvasItem, view_size: Vector2) -> void:
	if not _motion_enabled:
		return
	var vignette_alpha := _get_silence_vignette_alpha()
	if vignette_alpha > 0.001:
		_draw_vignette(canvas, view_size, vignette_alpha)
	if _elapsed >= B1_TO_B2_END and _elapsed < B2_TO_C1_CUT:
		var orb_phase := TAU * (_elapsed - B1_TO_B2_END) / 0.9
		var orb_scale := 1.0 + 0.012 * (0.5 + 0.5 * sin(orb_phase))
		var orb_offset := Vector2(sin(orb_phase * 0.73), cos(orb_phase * 0.61)) * 4.0
		_draw_cropped_fx(canvas, view_size, FX_ORB, PLATE_B2, 0.16, 1.0, "all", orb_scale, orb_offset)
	if _flash_alpha > 0.001:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.91, 1.0, 0.973, _flash_alpha), true)


func _draw_vignette(canvas: CanvasItem, view_size: Vector2, alpha: float) -> void:
	var band_count := 10
	for index in range(band_count):
		var ratio := float(index) / float(band_count)
		var inset := Vector2(view_size.x * 0.035 * ratio, view_size.y * 0.035 * ratio)
		var rect := Rect2(inset, view_size - inset * 2.0)
		canvas.draw_rect(rect, Color(0.0, 0.01, 0.025, alpha * (1.0 - ratio) * 0.22), false, maxf(2.0, view_size.y * 0.012))


func _draw_ray_fx(canvas: CanvasItem, view_size: Vector2) -> void:
	if _ray_additive_alpha <= 0.001:
		return
	var growth_scale := lerpf(0.2, 1.0, _ease_out_cubic(_ray_growth))
	_draw_cropped_fx(
		canvas,
		view_size,
		FX_RAYS,
		PLATE_C1,
		_ray_additive_alpha,
		1.0,
		"all",
		growth_scale,
		Vector2.ZERO,
		C1_RAY_CENTER_NORMALIZED
	)


func _draw_sparks(canvas: CanvasItem, view_size: Vector2) -> void:
	if _elapsed < 26.3 or _elapsed >= 29.6:
		return
	var camera_state := _get_camera_state(PLATE_C1)
	var center := _source_point_to_view(
		C1_RAY_CENTER_NORMALIZED * FULL_PLATE_SIZE,
		view_size,
		float(camera_state.get("zoom", 1.0)),
		camera_state.get("focus", Vector2(0.5, 0.5))
	)
	var scale_factor := minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y)
	for spark in _sparks:
		var spawn_time := 26.3 + float(spark.get("delay", 0.0))
		var life := float(spark.get("life", 1.0))
		var age := (_elapsed - spawn_time) / life
		if age < 0.0 or age >= 1.0:
			continue
		var direction: Vector2 = spark.get("direction", Vector2.RIGHT)
		var distance := float(spark.get("speed", 100.0)) * age * scale_factor
		var position := center + direction * distance
		var spark_alpha := (1.0 - age) * sin(PI * minf(1.0, age * 1.6))
		var radius := float(spark.get("radius", 2.0)) * scale_factor
		canvas.draw_circle(position, radius, Color(0.58, 1.0, 0.93, spark_alpha))
		canvas.draw_line(position - direction * radius * 4.0, position, Color(0.35, 0.95, 0.88, spark_alpha * 0.72), maxf(1.0, radius * 0.55))


func _draw_impact_fx(canvas: CanvasItem, view_size: Vector2) -> void:
	if _elapsed >= 33.0 and _elapsed < 33.45:
		var ring_t := _inverse_lerp_clamped(33.0, 33.45, _elapsed)
		var camera_state := _get_camera_state(PLATE_D2)
		var center := _source_point_to_view(
			D_IMPACT_CENTER_NORMALIZED * FULL_PLATE_SIZE,
			view_size,
			float(camera_state.get("zoom", 1.0)),
			camera_state.get("focus", Vector2(0.5, 0.5))
		)
		var radius := lerpf(18.0, 145.0, _ease_out_cubic(ring_t)) * minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y)
		canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(0.58, 1.0, 0.94, (1.0 - ring_t) * 0.8), maxf(2.0, 6.0 * (1.0 - ring_t)))
	if _shard_alpha > 0.001:
		_draw_cropped_fx(canvas, view_size, FX_SHARD, PLATE_D2, _shard_alpha, _shard_progress, "left", 1.0, Vector2.ZERO)


func _draw_cropped_fx(
	canvas: CanvasItem,
	view_size: Vector2,
	fx_key: String,
	camera_plate_key: String,
	alpha: float,
	reveal_progress: float,
	reveal_mode: String,
	scale: float,
	view_offset: Vector2,
	scale_anchor_normalized: Vector2 = Vector2(-1.0, -1.0)
) -> void:
	var texture := _get_plate_texture(fx_key)
	if texture == null or alpha <= 0.001 or not FX_LAYOUT.has(fx_key):
		return
	var layout: Dictionary = FX_LAYOUT[fx_key]
	var crop_rect := Rect2(layout.get("offset", Vector2.ZERO), layout.get("size", texture.get_size()))
	var reveal := clampf(reveal_progress, 0.0, 1.0)
	if reveal_mode == "bottom":
		var hidden_height := crop_rect.size.y * (1.0 - reveal)
		crop_rect.position.y += hidden_height
		crop_rect.size.y -= hidden_height
	elif reveal_mode == "left":
		crop_rect.size.x *= reveal
	if crop_rect.size.x <= 0.5 or crop_rect.size.y <= 0.5:
		return
	var camera_state := _get_camera_state(camera_plate_key)
	var zoom := float(camera_state.get("zoom", 1.0))
	var focus: Vector2 = camera_state.get("focus", Vector2(0.5, 0.5))
	var full_source_rect := _get_cover_source_rect(FULL_PLATE_SIZE, view_size, zoom, focus, Vector2.ZERO)
	var visible_full_rect := crop_rect.intersection(full_source_rect)
	if visible_full_rect.size.x <= 0.5 or visible_full_rect.size.y <= 0.5:
		return
	var source_region := Rect2(visible_full_rect.position - Vector2(layout.get("offset", Vector2.ZERO)), visible_full_rect.size)
	var dest_position := (visible_full_rect.position - full_source_rect.position) / full_source_rect.size * view_size
	var dest_size := visible_full_rect.size / full_source_rect.size * view_size
	var dest_rect := Rect2(dest_position + view_offset, dest_size)
	if not is_equal_approx(scale, 1.0):
		var anchor_source := crop_rect.get_center()
		if scale_anchor_normalized.x >= 0.0:
			anchor_source = scale_anchor_normalized * FULL_PLATE_SIZE
		var anchor_view := (anchor_source - full_source_rect.position) / full_source_rect.size * view_size
		canvas.draw_set_transform((Vector2.ONE - Vector2(scale, scale)) * anchor_view, 0.0, Vector2(scale, scale))
	canvas.draw_texture_rect_region(texture, dest_rect, source_region, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	if not is_equal_approx(scale, 1.0):
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _update_motion_state() -> void:
	if not _motion_enabled:
		_reset_motion_state()
		return
	_base_plate_key = _get_base_plate_key(_elapsed)
	_flash_alpha = _get_flash_alpha()
	_ray_growth = _smoothstep(26.25, 27.4, _elapsed) if _elapsed >= 26.25 else 0.0
	if _elapsed >= 26.25 and _elapsed < 27.4:
		_ray_additive_alpha = 0.82
	elif _elapsed >= 27.4 and _elapsed < 28.6:
		_ray_additive_alpha = 0.82 * (1.0 - _smoothstep(27.4, 28.6, _elapsed))
	else:
		_ray_additive_alpha = 0.0
	if _elapsed >= 33.10 and _elapsed < 34.0:
		_shard_progress = _ease_in_cubic(_inverse_lerp_clamped(33.10, 33.80, _elapsed))
		_shard_alpha = 1.0 - _smoothstep(33.72, 34.0, _elapsed)
	else:
		_shard_progress = 0.0
		_shard_alpha = 0.0
	if _elapsed >= 33.0 and _elapsed < 33.35:
		var shake_t := _inverse_lerp_clamped(33.0, 33.35, _elapsed)
		_shake_magnitude = 6.0 * exp(-4.2 * shake_t) * (1.0 - shake_t)
	else:
		_shake_magnitude = 0.0


func _reset_motion_state() -> void:
	_flash_alpha = 0.0
	_ray_growth = 0.0
	_ray_additive_alpha = 0.0
	_shard_progress = 0.0
	_shard_alpha = 0.0
	_shake_magnitude = 0.0
	_base_plate_key = PLATE_A1


func _get_flash_alpha() -> float:
	var ray_flash := 0.0
	if _elapsed >= B2_TO_C1_FLASH_START and _elapsed < 26.15:
		ray_flash = 0.92 * _smoothstep(B2_TO_C1_FLASH_START, 26.15, _elapsed)
	elif _elapsed >= 26.15 and _elapsed < 26.35:
		ray_flash = 0.92
	elif _elapsed >= 26.35 and _elapsed < 26.90:
		ray_flash = 0.92 * (1.0 - _smoothstep(26.35, 26.90, _elapsed))
	var impact_flash := 0.0
	if _elapsed >= 33.0 and _elapsed < 33.22:
		impact_flash = 0.5 * (1.0 - _smoothstep(33.0, 33.22, _elapsed))
	return maxf(ray_flash, impact_flash)


func _get_silence_vignette_alpha() -> float:
	if _elapsed < 20.8 or _elapsed >= 23.4:
		return 0.0
	var envelope := 1.0
	if _elapsed < 21.6:
		envelope = _smoothstep(20.8, 21.6, _elapsed)
	elif _elapsed > 22.8:
		envelope = 1.0 - _smoothstep(22.8, 23.4, _elapsed)
	var pulse := 0.82 + 0.18 * sin(TAU * 2.0 * _inverse_lerp_clamped(21.6, 23.4, _elapsed))
	return 0.22 * envelope * pulse


func _get_base_plate_key(elapsed: float) -> String:
	if elapsed < A1_TO_A2_END:
		return PLATE_A1
	if elapsed < A2_TO_A3_END:
		return PLATE_A2
	if elapsed < A3_TO_B1_END:
		return PLATE_A3
	if elapsed < B1_TO_B2_END:
		return PLATE_B1
	if elapsed < B2_TO_C1_CUT:
		return PLATE_B2
	if elapsed < C1_TO_D1_END:
		return PLATE_C1
	if elapsed < D1_TO_D2_END:
		return PLATE_D1
	return PLATE_D2


func _get_camera_state(plate_key: String) -> Dictionary:
	if plate_key in [PLATE_A1, PLATE_A2, PLATE_A3]:
		var a_t := _smoothstep(0.8, 18.4, _elapsed)
		return {"zoom": lerpf(1.02, 1.11, a_t), "focus": Vector2(lerpf(0.47, 0.52, a_t), lerpf(0.47, 0.50, a_t))}
	if plate_key in [PLATE_B1, PLATE_B2]:
		var b_t := _smoothstep(19.6, B2_TO_C1_CUT, _elapsed)
		return {"zoom": lerpf(1.04, 1.12, b_t), "focus": Vector2(0.50, lerpf(0.52, 0.43, b_t))}
	if plate_key == PLATE_C1:
		var c_t := _smoothstep(B2_TO_C1_CUT, C1_TO_D1_START, _elapsed)
		return {"zoom": lerpf(1.10, 1.02, c_t), "focus": Vector2(0.50, lerpf(0.47, 0.50, c_t))}
	var d_t := _smoothstep(C1_TO_D1_END, D1_TO_D2_END, _elapsed)
	return {"zoom": lerpf(1.03, 1.12, d_t), "focus": Vector2(lerpf(0.46, 0.54, d_t), 0.48)}


func _get_shake_offset_source() -> Vector2:
	if _shake_magnitude <= 0.001 or _shake_samples.is_empty():
		return Vector2.ZERO
	var sample_index := int(floor((_elapsed - 33.0) * 60.0))
	sample_index = posmod(sample_index, _shake_samples.size())
	return _shake_samples[sample_index] * _shake_magnitude


func _source_point_to_view(source_point: Vector2, view_size: Vector2, zoom: float, focus: Vector2) -> Vector2:
	var source_rect := _get_cover_source_rect(FULL_PLATE_SIZE, view_size, zoom, focus, Vector2.ZERO)
	return (source_point - source_rect.position) / source_rect.size * view_size


func _build_motion_samples() -> void:
	if not _sparks.is_empty() and not _shake_samples.is_empty():
		return
	_sparks.clear()
	_shake_samples.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(CINEMATIC_ID)) ^ MOTION_SEED_SALT
	for index in range(SPARK_COUNT):
		var angle := rng.randf_range(-PI, PI)
		_sparks.append({
			"delay": rng.randf_range(0.0, 1.05),
			"life": rng.randf_range(0.75, 1.65),
			"direction": Vector2(cos(angle), sin(angle)),
			"speed": rng.randf_range(90.0, 330.0),
			"radius": rng.randf_range(1.2, 3.1),
		})
	for index in range(32):
		var direction := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		_shake_samples.append(direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT)


func _inverse_lerp_clamped(from_value: float, to_value: float, value: float) -> float:
	if to_value <= from_value:
		return 1.0 if value >= to_value else 0.0
	return clampf((value - from_value) / (to_value - from_value), 0.0, 1.0)


func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse


func _ease_in_cubic(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * clamped


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
	if _additive_bridge != null:
		_additive_bridge.queue_redraw()
