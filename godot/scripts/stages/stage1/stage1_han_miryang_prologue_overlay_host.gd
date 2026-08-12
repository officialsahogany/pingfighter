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
const ORB_PEAK_START := 25.60
const ORB_PEAK_SECONDS := 26.15
const RAY_STAGGER_STEP_SECONDS := 0.04
const RAY_GROW_DURATION_SECONDS := 0.80
const SPARK_START_SECONDS := 27.40
const LAST_EMBER_START := 29.08
const LAST_EMBER_END := 29.58
const GUARD_BLADE_GLINT_START := 30.08
const GUARD_BLADE_GLINT_PEAK := 30.17
const GUARD_BLADE_GLINT_END := 30.30
const IMPACT_HITSTOP_END := 33.12
const HOST_RECOVERY_END := 33.52
const D2_PULLBACK_START := 36.20
const D2_TAIL_DIM_START := 39.90
const D2_TAIL_DIM_END := 45.00
const D2_TAIL_DIM_MAX_ALPHA := 0.35

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
const C1_OFFICIANT_TARGET_NORMALIZED := Vector2(0.625, 0.585)
const D_IMPACT_CENTER_NORMALIZED := Vector2(0.485, 0.385)
const RAY_ANGLES_DEGREES := [35.5, 75.5, 121.5, 158.5, 199.5, 247.5, 305.5, 356.0]
const RAY_REVEAL_ORDER := [0, 4, 2, 6, 1, 5, 3, 7]
const GUARD_BLADE_GLINT_POINTS_NORMALIZED := [Vector2(0.856, 0.323), Vector2(0.925, 0.472)]
const GUARD_BLADE_GLINT_DIRECTIONS := [Vector2(0.72, 0.69), Vector2(0.64, 0.77)]
const FX_LAYOUT := {
	FX_TABLET: {"offset": Vector2(1463.0, 237.0), "size": Vector2(585.0, 1107.0)},
	FX_ORB: {"offset": Vector2(1530.0, 274.0), "size": Vector2(652.0, 619.0)},
	FX_RAYS: {"offset": Vector2(33.0, 0.0), "size": Vector2(3288.0, 1361.0)},
	FX_SHARD: {"offset": Vector2(661.0, 237.0), "size": Vector2(1447.0, 823.0)},
}
const SPARK_COUNT := 40
const MOTION_SEED_SALT := 0x41A0_6A11
const DUST_COUNT := 28
const DUST_C1_ACTIVE_COUNT := 14
const SPATIAL_SEED_SALT := 0x65A0_5A11
const SPATIAL_FOREGROUND_MULTIPLIER := 1.55
const SPATIAL_INITIAL_MIN_RATIO := 0.0035
const SPATIAL_INITIAL_MAX_RATIO := 0.006
const SPATIAL_HARD_MAX_RATIO := 0.015
const SPATIAL_MARGIN_EPSILON := 0.0005
const DUST_COLOR := Color(0.74, 0.64, 0.49, 1.0)
const CANDLE_ANCHORS_A := [
	Vector2(0.455, 0.470),
	Vector2(0.475, 0.462),
	Vector2(0.495, 0.482),
	Vector2(0.515, 0.466),
	Vector2(0.535, 0.483),
]
const CANDLE_ANCHORS_C := [
	Vector2(0.444, 0.485),
	Vector2(0.470, 0.460),
	Vector2(0.495, 0.478),
	Vector2(0.522, 0.470),
	Vector2(0.548, 0.490),
]
const CANDLE_ANCHORS_D := [
	Vector2(0.386, 0.477),
	Vector2(0.414, 0.495),
	Vector2(0.548, 0.475),
	Vector2(0.632, 0.489),
]
const CANDLE_ANCHORS_NONE := []


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
var _ray_progresses: Array[float] = []
var _ray_additive_alpha := 0.0
var _shard_progress := 0.0
var _shard_alpha := 0.0
var _shake_magnitude := 0.0
var _orb_peak_progress := 0.0
var _last_ember_progress := 0.0
var _guard_glint_alpha := 0.0
var _impact_hitstop_active := false
var _host_recovery_progress := 0.0
var _tail_vignette_alpha := 0.0
var _base_plate_key := PLATE_A1
var _sparks: Array[Dictionary] = []
var _shake_samples: Array[Vector2] = []
var _dust_samples: Array[Dictionary] = []
var _spatial_offset_normalized := Vector2.ZERO
var _spatial_offset_ratio := 0.0
var _spatial_margin_ratio := 0.0
var _dust_active_count := 0

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
	_build_spatial_samples()
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
	_dust_samples.clear()
	if free_self and is_inside_tree():
		queue_free()


func get_snapshot() -> Dictionary:
	var readiness: Dictionary = {}
	for plate_key in [PLATE_A1, PLATE_A2, PLATE_A3, PLATE_B1, PLATE_B2, PLATE_C1, PLATE_D1, PLATE_D2, FX_TABLET, FX_ORB, FX_RAYS, FX_SHARD]:
		readiness[plate_key] = _plate_textures.get(plate_key, null) is Texture2D
	var camera_state := _get_camera_state(_base_plate_key)
	var source_rect := _get_cover_source_rect(FULL_PLATE_SIZE, size if size.x > 1.0 and size.y > 1.0 else REFERENCE_SIZE, float(camera_state.get("zoom", 1.0)), camera_state.get("focus", Vector2(0.5, 0.5)), Vector2.ZERO)
	var snapshot_size := size if size.x > 1.0 and size.y > 1.0 else REFERENCE_SIZE
	var shake_ratio := _get_shake_offset_source().length() / maxf(source_rect.size.x, 1.0)
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
		"ray_progresses": _ray_progresses.duplicate(),
		"ray_revealed_count": _get_ray_revealed_count(),
		"ray_additive_alpha": _ray_additive_alpha,
		"shard_progress": _shard_progress,
		"shard_alpha": _shard_alpha,
		"shake_magnitude": _shake_magnitude,
		"orb_peak_progress": _orb_peak_progress,
		"spark_active_count": _get_active_spark_count(),
		"last_ember_progress": _last_ember_progress,
		"last_ember_distance_to_target_ratio": _get_last_ember_distance_to_target_ratio(snapshot_size),
		"guard_glint_alpha": _guard_glint_alpha,
		"impact_hitstop_active": _impact_hitstop_active,
		"host_recovery_progress": _host_recovery_progress,
		"tail_vignette_alpha": _tail_vignette_alpha,
		"base_plate_key": _base_plate_key,
		"spatial_offset_ratio": _spatial_offset_ratio,
		"spatial_combined_offset_ratio": _spatial_offset_ratio + shake_ratio,
		"spatial_margin_ratio": _spatial_margin_ratio,
		"fx_spatial_offset_ratio": _get_active_fx_spatial_offset_ratio(snapshot_size),
		"fx_tablet_offset_ratio": _get_fx_spatial_offset(snapshot_size, FX_TABLET).length() / maxf(snapshot_size.x, 1.0),
		"fx_orb_offset_ratio": _get_fx_spatial_offset(snapshot_size, FX_ORB).length() / maxf(snapshot_size.x, 1.0),
		"fx_rays_offset_ratio": _get_fx_spatial_offset(snapshot_size, FX_RAYS).length() / maxf(snapshot_size.x, 1.0),
		"fx_shard_offset_ratio": _get_fx_spatial_offset(snapshot_size, FX_SHARD).length() / maxf(snapshot_size.x, 1.0),
		"spatial_foreground_multiplier": SPATIAL_FOREGROUND_MULTIPLIER,
		"spatial_initial_min_ratio": SPATIAL_INITIAL_MIN_RATIO,
		"spatial_initial_max_ratio": SPATIAL_INITIAL_MAX_RATIO,
		"spatial_hard_max_ratio": SPATIAL_HARD_MAX_RATIO,
		"dust_active_count": _dust_active_count,
		"dust_cluster_mean_offset_ratio": _spatial_offset_ratio,
		"procedural_draw_shape_count": _dust_active_count + _get_candle_anchors(_base_plate_key).size() * 2,
		"subtitle_position": _subtitle_label.position if _subtitle_label != null else Vector2.ZERO,
		"speaker_position": _speaker_label.position if _speaker_label != null else Vector2.ZERO,
		"skip_position": _skip_label.position if _skip_label != null else Vector2.ZERO,
		"title_position": _title_label.position if _title_label != null else Vector2.ZERO,
		"camera_zoom": float(camera_state.get("zoom", 1.0)),
		"camera_source_width_ratio": source_rect.size.x / FULL_PLATE_SIZE.x,
		"additive_blend_mode": int((_additive_bridge.material as CanvasItemMaterial).blend_mode) if _additive_bridge != null and _additive_bridge.material is CanvasItemMaterial else -1,
		"additive_interpolation_off": _additive_bridge != null and _additive_bridge.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
		"size": snapshot_size,
	}


func draw_prologue(canvas: CanvasItem) -> void:
	if canvas == null or not visible:
		return
	var view_size := _draw_bridge.size if _draw_bridge != null else size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	_draw_timeline_plate(canvas, view_size)
	_draw_cinematic_grade(canvas, view_size)
	_draw_spatial_layers(canvas, view_size)
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
	_draw_guard_blade_glint(canvas, view_size)
	_draw_impact_fx(canvas, view_size)


func _draw_timeline_plate(canvas: CanvasItem, view_size: Vector2) -> void:
	if _elapsed < A1_TO_A2_START:
		_draw_single_plate(canvas, view_size, PLATE_A1)
	elif _elapsed < A1_TO_A2_END:
		_draw_single_plate(canvas, view_size, PLATE_A1)
		var reveal := _ease_out_cubic(_inverse_lerp_clamped(A1_TO_A2_START, A1_TO_A2_END, _elapsed))
		_draw_cropped_fx(canvas, view_size, FX_TABLET, PLATE_A1, 1.0, reveal, "bottom", 1.0, _get_fx_spatial_offset(view_size, FX_TABLET))
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
		_draw_plate_blend_progress(canvas, view_size, PLATE_D1, PLATE_D2, _host_recovery_progress)
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


func _draw_plate_blend_progress(canvas: CanvasItem, view_size: Vector2, from_key: String, to_key: String, progress: float) -> void:
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
	_draw_cover_texture(canvas, from_texture, view_size, zoom, focus, 1.0, shake_offset)
	_draw_cover_texture(canvas, to_texture, view_size, zoom, focus, clampf(progress, 0.0, 1.0), shake_offset)


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
	if _tail_vignette_alpha > 0.001:
		_draw_tail_vignette(canvas, view_size, _tail_vignette_alpha)
	if _elapsed >= B1_TO_B2_END and _elapsed < B2_TO_C1_CUT:
		var orb_phase := TAU * (_elapsed - B1_TO_B2_END) / 0.9
		var orb_scale := 1.0 + 0.012 * (0.5 + 0.5 * sin(orb_phase)) + 0.045 * _orb_peak_progress
		var orb_alpha := lerpf(0.16, 0.52, _orb_peak_progress)
		var orb_offset := Vector2(sin(orb_phase * 0.73), cos(orb_phase * 0.61)) * 4.0
		orb_offset += _get_fx_spatial_offset(view_size, FX_ORB)
		_draw_cropped_fx(canvas, view_size, FX_ORB, PLATE_B2, orb_alpha, 1.0, "all", orb_scale, orb_offset)
	if _flash_alpha > 0.001:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.91, 1.0, 0.973, _flash_alpha), true)


func _draw_vignette(canvas: CanvasItem, view_size: Vector2, alpha: float) -> void:
	var band_count := 10
	for index in range(band_count):
		var ratio := float(index) / float(band_count)
		var inset := Vector2(view_size.x * 0.035 * ratio, view_size.y * 0.035 * ratio)
		var rect := Rect2(inset, view_size - inset * 2.0)
		canvas.draw_rect(rect, Color(0.0, 0.01, 0.025, alpha * (1.0 - ratio) * 0.22), false, maxf(2.0, view_size.y * 0.012))


func _draw_tail_vignette(canvas: CanvasItem, view_size: Vector2, alpha: float) -> void:
	# Keep the central officiant-ball-Miryang axis and subtitle band untouched.
	# The plate is flat, so this is a peripheral rhythm cue rather than a false
	# claim that the background has its own mask.
	var clamped_alpha := clampf(alpha, 0.0, D2_TAIL_DIM_MAX_ALPHA)
	var side_width := view_size.x * 0.22
	var top_height := view_size.y * 0.18
	# Normalize the seven nested bands in optical-density space so the darkest
	# untouched edge reaches, but never exceeds, the authored alpha cap.
	var optical_density := -log(maxf(0.001, 1.0 - clamped_alpha)) / 4.12
	for index in range(7):
		var ratio := float(index + 1) / 7.0
		var band_alpha := 1.0 - exp(-optical_density * (1.0 - ratio * 0.72))
		var inset_x := side_width * ratio
		var inset_y := top_height * ratio
		canvas.draw_rect(Rect2(0.0, 0.0, inset_x, view_size.y * 0.72), Color(0.0, 0.0, 0.0, band_alpha), true)
		canvas.draw_rect(Rect2(view_size.x - inset_x, 0.0, inset_x, view_size.y * 0.72), Color(0.0, 0.0, 0.0, band_alpha), true)
		canvas.draw_rect(Rect2(inset_x, 0.0, view_size.x - inset_x * 2.0, inset_y), Color(0.0, 0.0, 0.0, band_alpha * 0.82), true)


func _draw_spatial_layers(canvas: CanvasItem, view_size: Vector2) -> void:
	if not _motion_enabled or _dust_active_count <= 0:
		return
	var scale_factor := minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y)
	var spatial_offset := Vector2(
		_spatial_offset_normalized.x * view_size.x,
		_spatial_offset_normalized.y * view_size.y
	)
	var candle_anchors := _get_candle_anchors(_base_plate_key)
	for anchor_index in range(candle_anchors.size()):
		var anchor: Vector2 = candle_anchors[anchor_index]
		var phase := TAU * (_elapsed / 2.8 + float(anchor_index) * 0.173)
		var pulse := 0.5 + 0.5 * sin(phase)
		var anchor_position := anchor * view_size + spatial_offset
		var halo_radius := lerpf(11.0, 17.0, pulse) * scale_factor
		var halo_alpha := lerpf(0.038, 0.078, pulse)
		canvas.draw_circle(anchor_position, halo_radius, Color(0.88, 0.67, 0.34, halo_alpha))
		var shimmer_height := lerpf(7.0, 13.0, pulse) * scale_factor
		canvas.draw_line(
			anchor_position - Vector2(0.0, shimmer_height),
			anchor_position + Vector2(0.0, shimmer_height * 0.18),
			Color(0.93, 0.72, 0.40, halo_alpha * 0.46),
			maxf(1.0, 1.35 * scale_factor)
		)
	var active_count := mini(_dust_active_count, _dust_samples.size())
	var mean_horizontal_drift := _get_dust_horizontal_mean_drift(active_count)
	for dust_index in range(active_count):
		var dust: Dictionary = _dust_samples[dust_index]
		var anchor_slot := int(dust.get("anchor_slot", 0))
		var base_position: Vector2 = dust.get("base", Vector2(0.5, 0.65))
		if not candle_anchors.is_empty():
			base_position = candle_anchors[anchor_slot % candle_anchors.size()] + Vector2(dust.get("jitter_x", 0.0), dust.get("jitter_y", 0.0))
		var phase_time := _elapsed * float(dust.get("phase_speed", 0.5)) + float(dust.get("phase", 0.0))
		var drift := Vector2(
			sin(phase_time) * float(dust.get("drift_x", 0.01)) - mean_horizontal_drift,
			-fmod(_elapsed * float(dust.get("rise_speed", 0.003)) + float(dust.get("rise_seed", 0.0)), 0.22)
		)
		var normalized_position := base_position + drift
		normalized_position.x = fposmod(normalized_position.x, 1.0)
		normalized_position.y = fposmod(normalized_position.y, 1.0)
		var dust_position := normalized_position * view_size + spatial_offset
		var visibility := 0.72 + 0.28 * (0.5 + 0.5 * sin(phase_time * 0.83))
		var dust_alpha := float(dust.get("alpha", 0.10)) * visibility
		var dust_radius := float(dust.get("radius", 3.0)) * scale_factor
		# Warm low-saturation amber is deliberate. Cyan is reserved for spirit FX.
		canvas.draw_circle(dust_position, dust_radius, Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, dust_alpha))


func _get_dust_horizontal_mean_drift(active_count: int) -> float:
	if active_count <= 0:
		return 0.0
	var drift_sum := 0.0
	for dust_index in range(active_count):
		var dust: Dictionary = _dust_samples[dust_index]
		var phase_time := _elapsed * float(dust.get("phase_speed", 0.5)) + float(dust.get("phase", 0.0))
		drift_sum += sin(phase_time) * float(dust.get("drift_x", 0.01))
	return drift_sum / float(active_count)


func _draw_ray_fx(canvas: CanvasItem, view_size: Vector2) -> void:
	if _ray_progresses.is_empty() and _ray_additive_alpha <= 0.001:
		return
	var camera_state := _get_camera_state(PLATE_C1)
	var camera_zoom := float(camera_state.get("zoom", 1.0))
	var camera_focus: Vector2 = camera_state.get("focus", Vector2(0.5, 0.5))
	var center_source := C1_RAY_CENTER_NORMALIZED * FULL_PLATE_SIZE
	var center := _source_point_to_view(center_source, view_size, camera_zoom, camera_focus)
	var spatial_offset := _get_fx_spatial_offset(view_size, FX_RAYS)
	center += spatial_offset
	var scale_factor := minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y)
	for ray_index in range(mini(_ray_progresses.size(), RAY_ANGLES_DEGREES.size())):
		var progress := float(_ray_progresses[ray_index])
		if progress <= 0.001 or progress >= 0.999:
			continue
		var radians := deg_to_rad(float(RAY_ANGLES_DEGREES[ray_index]))
		var direction_source := Vector2(cos(radians), -sin(radians))
		var endpoint_source := center_source + direction_source * 2200.0
		var endpoint := _source_point_to_view(endpoint_source, view_size, camera_zoom, camera_focus) + spatial_offset
		var revealed_endpoint := center.lerp(endpoint, _ease_out_cubic(progress))
		var pulse_alpha := 0.70 * sin(PI * progress)
		canvas.draw_line(center, revealed_endpoint, Color(0.30, 0.94, 0.88, pulse_alpha * 0.22), maxf(7.0, 20.0 * scale_factor))
		canvas.draw_line(center, revealed_endpoint, Color(0.72, 1.0, 0.97, pulse_alpha), maxf(2.0, 5.0 * scale_factor))
	if _ray_additive_alpha > 0.001:
		_draw_cropped_fx(
			canvas,
			view_size,
			FX_RAYS,
			PLATE_C1,
			_ray_additive_alpha,
			1.0,
			"all",
			1.0,
			spatial_offset,
			C1_RAY_CENTER_NORMALIZED
		)


func _draw_sparks(canvas: CanvasItem, view_size: Vector2) -> void:
	if _elapsed < SPARK_START_SECONDS or _elapsed >= C1_TO_D1_START:
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
		var spawn_time := SPARK_START_SECONDS + float(spark.get("delay", 0.0))
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
	_draw_last_ember(canvas, view_size, camera_state, center, scale_factor)


func _draw_last_ember(canvas: CanvasItem, view_size: Vector2, camera_state: Dictionary, start: Vector2, scale_factor: float) -> void:
	if _last_ember_progress <= 0.001:
		return
	var target := _get_last_ember_target(view_size, camera_state)
	var control := _get_last_ember_control(start, target, view_size)
	var eased := _smoothstep(0.0, 1.0, _last_ember_progress)
	var head := _quadratic_bezier(start, control, target, eased)
	for trail_index in range(6):
		var trail_t := maxf(0.0, eased - float(trail_index) * 0.045)
		var trail_position := _quadratic_bezier(start, control, target, trail_t)
		var trail_alpha := (1.0 - float(trail_index) / 6.0) * sin(PI * eased)
		canvas.draw_circle(trail_position, maxf(1.5, (5.5 - float(trail_index) * 0.55) * scale_factor), Color(0.48, 1.0, 0.92, trail_alpha * 0.72))
	canvas.draw_circle(head, maxf(3.0, 8.0 * scale_factor), Color(0.82, 1.0, 0.97, sin(PI * eased)))


func _get_last_ember_target(view_size: Vector2, camera_state: Dictionary) -> Vector2:
	return _source_point_to_view(
		C1_OFFICIANT_TARGET_NORMALIZED * FULL_PLATE_SIZE,
		view_size,
		float(camera_state.get("zoom", 1.0)),
		camera_state.get("focus", Vector2(0.5, 0.5))
	)


func _get_last_ember_control(start: Vector2, target: Vector2, view_size: Vector2) -> Vector2:
	return start.lerp(target, 0.46) + Vector2(view_size.x * 0.045, -view_size.y * 0.085)


func _get_last_ember_distance_to_target_ratio(view_size: Vector2) -> float:
	if _last_ember_progress <= 0.001 or view_size.x <= 1.0:
		return 0.0
	var camera_state := _get_camera_state(PLATE_C1)
	var start := _source_point_to_view(
		C1_RAY_CENTER_NORMALIZED * FULL_PLATE_SIZE,
		view_size,
		float(camera_state.get("zoom", 1.0)),
		camera_state.get("focus", Vector2(0.5, 0.5))
	)
	var target := _get_last_ember_target(view_size, camera_state)
	var control := _get_last_ember_control(start, target, view_size)
	var head := _quadratic_bezier(start, control, target, _smoothstep(0.0, 1.0, _last_ember_progress))
	return head.distance_to(target) / view_size.x


func _draw_guard_blade_glint(canvas: CanvasItem, view_size: Vector2) -> void:
	if _guard_glint_alpha <= 0.001:
		return
	var camera_state := _get_camera_state(PLATE_D1)
	var zoom := float(camera_state.get("zoom", 1.0))
	var focus: Vector2 = camera_state.get("focus", Vector2(0.5, 0.5))
	var scale_factor := minf(view_size.x / REFERENCE_SIZE.x, view_size.y / REFERENCE_SIZE.y)
	for index in range(GUARD_BLADE_GLINT_POINTS_NORMALIZED.size()):
		var point := _source_point_to_view(GUARD_BLADE_GLINT_POINTS_NORMALIZED[index] * FULL_PLATE_SIZE, view_size, zoom, focus)
		var direction: Vector2 = GUARD_BLADE_GLINT_DIRECTIONS[index]
		var tangent := Vector2(-direction.y, direction.x)
		var long_radius := 22.0 * scale_factor
		var short_radius := 8.0 * scale_factor
		canvas.draw_line(point - direction * long_radius, point + direction * long_radius, Color(1.0, 0.91, 0.66, _guard_glint_alpha), maxf(1.2, 2.4 * scale_factor))
		canvas.draw_line(point - tangent * short_radius, point + tangent * short_radius, Color(1.0, 0.98, 0.88, _guard_glint_alpha * 0.92), maxf(1.0, 1.8 * scale_factor))


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
		_draw_cropped_fx(canvas, view_size, FX_SHARD, PLATE_D2, _shard_alpha, _shard_progress, "left", 1.0, _get_fx_spatial_offset(view_size, FX_SHARD))


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
	_orb_peak_progress = _smoothstep(ORB_PEAK_START, ORB_PEAK_SECONDS, _elapsed) if _elapsed >= ORB_PEAK_START and _elapsed < B2_TO_C1_CUT else 0.0
	_update_ray_progresses()
	if _elapsed >= 27.05 and _elapsed < 27.4:
		_ray_additive_alpha = 0.82 * _smoothstep(27.05, 27.4, _elapsed)
	elif _elapsed >= 27.4 and _elapsed < 28.6:
		_ray_additive_alpha = 0.82 * (1.0 - _smoothstep(27.4, 28.6, _elapsed))
	else:
		_ray_additive_alpha = 0.0
	_last_ember_progress = _smoothstep(LAST_EMBER_START, LAST_EMBER_END, _elapsed) if _elapsed >= LAST_EMBER_START and _elapsed < LAST_EMBER_END else 0.0
	_guard_glint_alpha = _get_guard_glint_alpha()
	_impact_hitstop_active = _elapsed >= D1_TO_D2_START and _elapsed < IMPACT_HITSTOP_END
	_host_recovery_progress = _smoothstep(IMPACT_HITSTOP_END, HOST_RECOVERY_END, _elapsed) if _elapsed >= IMPACT_HITSTOP_END else 0.0
	_tail_vignette_alpha = D2_TAIL_DIM_MAX_ALPHA * _smoothstep(D2_TAIL_DIM_START, D2_TAIL_DIM_END, _elapsed) if _elapsed >= D2_TAIL_DIM_START and _elapsed < D2_TAIL_DIM_END else 0.0
	if _elapsed >= IMPACT_HITSTOP_END and _elapsed < D1_TO_D2_END:
		_shard_progress = _ease_in_cubic(_inverse_lerp_clamped(IMPACT_HITSTOP_END, 33.82, _elapsed))
		_shard_alpha = 1.0 - _smoothstep(33.72, 34.0, _elapsed)
	else:
		_shard_progress = 0.0
		_shard_alpha = 0.0
	if _elapsed >= 33.0 and _elapsed < 33.35:
		var shake_t := _inverse_lerp_clamped(33.0, 33.35, _elapsed)
		_shake_magnitude = 6.0 * exp(-4.2 * shake_t) * (1.0 - shake_t)
	else:
		_shake_magnitude = 0.0
	_update_spatial_state()


func _reset_motion_state() -> void:
	_flash_alpha = 0.0
	_ray_growth = 0.0
	_ray_progresses.clear()
	_ray_additive_alpha = 0.0
	_shard_progress = 0.0
	_shard_alpha = 0.0
	_shake_magnitude = 0.0
	_orb_peak_progress = 0.0
	_last_ember_progress = 0.0
	_guard_glint_alpha = 0.0
	_impact_hitstop_active = false
	_host_recovery_progress = 0.0
	_tail_vignette_alpha = 0.0
	_base_plate_key = PLATE_A1
	_spatial_offset_normalized = Vector2.ZERO
	_spatial_offset_ratio = 0.0
	_spatial_margin_ratio = 0.0
	_dust_active_count = 0


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


func _update_ray_progresses() -> void:
	_ray_progresses.resize(RAY_ANGLES_DEGREES.size())
	for ray_index in range(_ray_progresses.size()):
		_ray_progresses[ray_index] = 0.0
	var progress_sum := 0.0
	for reveal_rank in range(RAY_REVEAL_ORDER.size()):
		var ray_index := int(RAY_REVEAL_ORDER[reveal_rank])
		var start_time := B2_TO_C1_CUT + float(reveal_rank) * RAY_STAGGER_STEP_SECONDS
		var progress := _smoothstep(start_time, start_time + RAY_GROW_DURATION_SECONDS, _elapsed)
		_ray_progresses[ray_index] = progress
		progress_sum += progress
	_ray_growth = progress_sum / maxf(1.0, float(_ray_progresses.size()))


func _get_ray_revealed_count() -> int:
	var count := 0
	for progress in _ray_progresses:
		if progress > 0.001:
			count += 1
	return count


func _get_active_spark_count() -> int:
	if _elapsed < SPARK_START_SECONDS or _elapsed >= C1_TO_D1_START:
		return 0
	var count := 0
	for spark in _sparks:
		var spawn_time := SPARK_START_SECONDS + float(spark.get("delay", 0.0))
		var life := float(spark.get("life", 1.0))
		if _elapsed >= spawn_time and _elapsed < spawn_time + life:
			count += 1
	return count


func _get_guard_glint_alpha() -> float:
	if _elapsed < GUARD_BLADE_GLINT_START or _elapsed >= GUARD_BLADE_GLINT_END:
		return 0.0
	if _elapsed < GUARD_BLADE_GLINT_PEAK:
		return _smoothstep(GUARD_BLADE_GLINT_START, GUARD_BLADE_GLINT_PEAK, _elapsed)
	return 1.0 - _smoothstep(GUARD_BLADE_GLINT_PEAK, GUARD_BLADE_GLINT_END, _elapsed)


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
	var visual_elapsed := _get_impact_visual_elapsed()
	var d_t := _smoothstep(C1_TO_D1_END, D1_TO_D2_END, visual_elapsed)
	var zoom := lerpf(1.03, 1.12, d_t)
	var focus := Vector2(lerpf(0.46, 0.54, d_t), 0.48)
	if _elapsed >= D2_PULLBACK_START:
		var tail_t := _smoothstep(D2_PULLBACK_START, D2_TAIL_DIM_END, _elapsed)
		zoom = lerpf(1.12, 1.04, tail_t)
		focus = focus.lerp(Vector2(0.50, 0.49), tail_t)
	return {"zoom": zoom, "focus": focus}


func _get_impact_visual_elapsed() -> float:
	if _elapsed < D1_TO_D2_START:
		return _elapsed
	if _elapsed < IMPACT_HITSTOP_END:
		return D1_TO_D2_START
	if _elapsed < D1_TO_D2_END:
		return lerpf(D1_TO_D2_START, D1_TO_D2_END, _inverse_lerp_clamped(IMPACT_HITSTOP_END, D1_TO_D2_END, _elapsed))
	return _elapsed


func _get_shake_offset_source() -> Vector2:
	if _shake_magnitude <= 0.001 or _shake_samples.is_empty():
		return Vector2.ZERO
	var sample_index := int(floor((_elapsed - 33.0) * 60.0))
	sample_index = posmod(sample_index, _shake_samples.size())
	return _shake_samples[sample_index] * _shake_magnitude


func _update_spatial_state() -> void:
	var view_size := size if size.x > 1.0 and size.y > 1.0 else REFERENCE_SIZE
	var camera_state := _get_camera_state(_base_plate_key)
	var source_rect := _get_cover_source_rect(
		FULL_PLATE_SIZE,
		view_size,
		float(camera_state.get("zoom", 1.0)),
		camera_state.get("focus", Vector2(0.5, 0.5)),
		Vector2.ZERO
	)
	_spatial_margin_ratio = minf(
		(FULL_PLATE_SIZE.x - source_rect.size.x) / (FULL_PLATE_SIZE.x * 2.0),
		(FULL_PLATE_SIZE.y - source_rect.size.y) / (FULL_PLATE_SIZE.y * 2.0)
	)
	var requested := _get_spatial_camera_offset_normalized() * SPATIAL_FOREGROUND_MULTIPLIER
	var requested_ratio := _normalized_offset_to_view_width_ratio(requested, view_size)
	var allowed_ratio := minf(SPATIAL_HARD_MAX_RATIO, maxf(0.0, _spatial_margin_ratio - SPATIAL_MARGIN_EPSILON))
	if requested_ratio > allowed_ratio and requested_ratio > 0.000001:
		requested *= allowed_ratio / requested_ratio
	_spatial_offset_normalized = requested
	_spatial_offset_ratio = _normalized_offset_to_view_width_ratio(_spatial_offset_normalized, view_size)
	_dust_active_count = DUST_C1_ACTIVE_COUNT if _elapsed >= B2_TO_C1_CUT and _elapsed < C1_TO_D1_START else DUST_COUNT


func _get_spatial_camera_offset_normalized() -> Vector2:
	# The authored keys are the foreground result. Divide here, then apply the
	# locked 1.55 multiplier in _update_spatial_state so the speed relationship
	# remains explicit instead of becoming an untraceable magic curve.
	var target := Vector2(-0.0042, 0.0010)
	if _elapsed < 8.0:
		target = Vector2(-0.0042, 0.0010).lerp(Vector2(-0.0054, -0.0011), _smoothstep(0.0, 8.0, _elapsed))
	elif _elapsed < 19.6:
		target = Vector2(-0.0054, -0.0011).lerp(Vector2(-0.0058, 0.0012), _smoothstep(8.0, 19.6, _elapsed))
	elif _elapsed < B2_TO_C1_CUT:
		target = Vector2(-0.0084, 0.0018).lerp(Vector2(-0.0102, -0.0020), _smoothstep(19.6, B2_TO_C1_CUT, _elapsed))
	elif _elapsed < C1_TO_D1_START:
		target = Vector2(0.0102, -0.0020).lerp(Vector2(0.0088, 0.0018), _smoothstep(B2_TO_C1_CUT, C1_TO_D1_START, _elapsed))
	elif _elapsed < 33.0:
		target = Vector2(-0.0088, 0.0018).lerp(Vector2(-0.0100, -0.0018), _smoothstep(C1_TO_D1_START, 33.0, _elapsed))
	elif _elapsed < D1_TO_D2_END:
		target = Vector2(-0.0100, -0.0018).lerp(Vector2(-0.0086, 0.0016), _smoothstep(33.0, D1_TO_D2_END, _elapsed))
	else:
		target = Vector2(0.0055, -0.0011).lerp(Vector2(0.0040, 0.0008), _smoothstep(D1_TO_D2_END, 48.0, _elapsed))
	return target / SPATIAL_FOREGROUND_MULTIPLIER


func _get_fx_spatial_offset(view_size: Vector2, fx_key: String) -> Vector2:
	var start_time := 0.0
	var end_time := 0.0
	var amplitude_ratio := 0.0
	if fx_key == FX_TABLET:
		start_time = A1_TO_A2_START
		end_time = A1_TO_A2_END
		amplitude_ratio = 0.0024
	elif fx_key == FX_ORB:
		start_time = B1_TO_B2_END
		end_time = B2_TO_C1_CUT
		amplitude_ratio = 0.0028
	elif fx_key == FX_RAYS:
		start_time = B2_TO_C1_CUT
		end_time = 28.6
		amplitude_ratio = 0.0032
	elif fx_key == FX_SHARD:
		start_time = 33.10
		end_time = D1_TO_D2_END
		amplitude_ratio = 0.0026
	else:
		return Vector2.ZERO
	if _elapsed <= start_time or _elapsed >= end_time:
		return Vector2.ZERO
	var envelope := sin(PI * _inverse_lerp_clamped(start_time, end_time, _elapsed))
	var foreground_offset := Vector2(
		_spatial_offset_normalized.x * view_size.x,
		_spatial_offset_normalized.y * view_size.y
	)
	var direction := foreground_offset.normalized() if foreground_offset.length_squared() > 0.000001 else Vector2.RIGHT
	return direction * view_size.x * amplitude_ratio * envelope


func _normalized_offset_to_view_width_ratio(normalized_offset: Vector2, view_size: Vector2) -> float:
	var view_offset := Vector2(normalized_offset.x * view_size.x, normalized_offset.y * view_size.y)
	return view_offset.length() / maxf(view_size.x, 1.0)


func _get_active_fx_spatial_offset_ratio(view_size: Vector2) -> float:
	var max_ratio := 0.0
	for fx_key in [FX_TABLET, FX_ORB, FX_RAYS, FX_SHARD]:
		max_ratio = maxf(max_ratio, _get_fx_spatial_offset(view_size, fx_key).length() / maxf(view_size.x, 1.0))
	return max_ratio


func _get_candle_anchors(plate_key: String) -> Array:
	if plate_key == PLATE_A1 or plate_key == PLATE_A2 or plate_key == PLATE_A3:
		return CANDLE_ANCHORS_A
	if plate_key == PLATE_C1:
		return CANDLE_ANCHORS_C
	if plate_key == PLATE_D1 or plate_key == PLATE_D2:
		return CANDLE_ANCHORS_D
	return CANDLE_ANCHORS_NONE


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


func _build_spatial_samples() -> void:
	if not _dust_samples.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(CINEMATIC_ID)) ^ SPATIAL_SEED_SALT
	for index in range(DUST_COUNT):
		_dust_samples.append({
			"anchor_slot": rng.randi_range(0, CANDLE_ANCHORS_A.size() - 1),
			"base": Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.20, 0.82)),
			"jitter_x": rng.randf_range(-0.11, 0.11),
			"jitter_y": rng.randf_range(-0.10, 0.15),
			"phase": rng.randf_range(0.0, TAU),
			"phase_speed": rng.randf_range(0.22, 0.52),
			"drift_x": rng.randf_range(0.004, 0.013),
			"rise_speed": rng.randf_range(0.0018, 0.0048),
			"rise_seed": rng.randf_range(0.0, 0.22),
			"radius": rng.randf_range(2.0, 5.0),
			"alpha": rng.randf_range(0.08, 0.15),
		})


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


func _quadratic_bezier(start: Vector2, control: Vector2, target: Vector2, progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * start + 2.0 * inverse * t * control + t * t * target


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
