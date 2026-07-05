extends RefCounted

const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetDecoder := preload("res://scripts/lingpet/lingpet_decoder.gd")
const LingpetLanguageCatalog := preload("res://scripts/lingpet/lingpet_language_catalog.gd")
const LingpetLanguageRichText := preload("res://scripts/lingpet/lingpet_language_rich_text.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LINE_SECONDS := 4.8
# Ambient pet-style wander: the companion strolls to a random spot, pauses, then
# picks a new one - NOT a constant left/right ping-pong. Speeds/dwell are in
# normalized-band units per second. Ground pets move along the floor line (x only);
# flight pets drift in 2D within the glass. motion_speed_ratio is derived from the
# ACTUAL per-frame displacement so a paused pet reads idle (treadmill trap).
const WANDER_GROUND_SPEED := 0.24
const WANDER_FLIGHT_SPEED := 0.17
const WANDER_DWELL_MIN := 0.7
const WANDER_DWELL_MAX := 2.4
const WANDER_MIN_STEP := 0.28
const WANDER_ARRIVE_EPS := 0.02
const DEFAULT_COMPANION_DRAW_SIZE := 70.0
const WALK_BAND_SPRITE_MARGIN := 3.0
const FLIGHT_ROAM_TOP_RATIO := 0.42
const SHELL_TEXTURE_PATH := "res://assets/ui/hud/lingpet_pendulum_shell_imagegen_v1.png"
const SHELL_ASPECT_RATIO := 747.0 / 1076.0
const MODAL_MAX_HEIGHT := 620.0
const MODAL_MIN_HEIGHT := 440.0
const MODAL_SIDE_MARGIN := 40.0
const MODAL_VERTICAL_MARGIN := 80.0
const SHELL_SCREEN_RECT_NORM := Rect2(Vector2(98.0 / 747.0, 310.0 / 1076.0), Vector2(551.0 / 747.0, 475.0 / 1076.0))
const SHELL_WALK_BAND_NORM := Rect2(Vector2(130.0 / 747.0, 655.0 / 1076.0), Vector2(490.0 / 747.0, 140.0 / 1076.0))
const WALK_BAND_HORIZONTAL_INSET_RATIO := 0.11
const COMPANION_RADIUS := 13.0
const SPEECH_FONT_SIZE := 17
const CAPTION_FONT_SIZE := 12
const SPEECH_HEIGHT := 104.0
const SPEECH_SCREEN_INSET := 14.0
const SPEECH_TOP_OFFSET := 16.0
const SPEECH_FILL_COLOR := Color(0.04, 0.09, 0.12, 0.92)
const SPEECH_BORDER_COLOR := Color(0.40, 0.82, 0.85, 0.55)
const SPEECH_HEADER_COLOR := Color(0.62, 0.88, 1.0, 0.85)
const SPEECH_CAPTION_COLOR := Color(0.70, 0.92, 1.0, 0.72)
# Dialogue body is drawn in ONE unified color for both the decoded Korean and the
# undecoded Lingpet glyphs (per design-owner request). The emotion seal keeps its
# gold accent. Shared build_runs() still differentiates glyph vs decoded for the
# other decoder screens; the pendulum only overrides its own per-run draw color.
const SPEECH_TEXT_COLOR := Color(0.92, 0.97, 1.0, 1.0)
const CLOSE_ANCHOR_NORM := Vector2(0.79, 0.278)
const CLOSE_RADIUS := 13.0
const CLOSE_FILL_COLOR := Color(0.02, 0.05, 0.07, 0.94)
const CLOSE_GOLD_COLOR := Color(1.0, 0.86, 0.60, 0.96)
const CLOSE_HOVER_FILL_COLOR := Color(0.08, 0.18, 0.20, 0.98)
const CLOSE_HOVER_GOLD_COLOR := Color(1.0, 0.95, 0.76, 1.0)
const MAX_RING_CORE_TIER_DISPLAY := 6
var active := false
var pet_id := ""
var ring_core_tier := 0
var decoder_level := 0
var elapsed := 0.0
var _is_flight := false
var _walk_draw_size := 0.0
var _wander_x := 0.5
var _wander_y := 1.0
var _target_x := 0.5
var _target_y := 1.0
var _dwell_timer := 0.0
var _moving := false
var _facing_left := false
var _motion_speed_ratio := 0.0
var _line_elapsed := 0.0
var _line_index := 0
var _line_pool: Array[Dictionary] = []
var _line_runs: Array[Dictionary] = []
var _line_plain_text := ""
var _close_rect := Rect2()
var _speech_rect := Rect2()
var _companion_center := Vector2.ZERO
var _profile: Object = LingpetCurrentProfile.new()
var _animator: Object = LingpetCompanionSpriteAnimator.new()
var _renderer: Object = LingpetCompanionRenderer.new()
var _context_builder: Object = LingpetCompanionDrawContextBuilder.new()
var _shell_texture: Texture2D = null


static func can_open_snapshot(snapshot: Dictionary) -> bool:
	return str(snapshot.get("state", "")) == "companion" and str(snapshot.get("pet_id", "")).strip_edges() != "" and int(snapshot.get("ring_core_tier", 0)) > 0


func is_active() -> bool:
	return active


func reset() -> void:
	active = false
	pet_id = ""
	ring_core_tier = 0
	decoder_level = 0
	elapsed = 0.0
	_is_flight = false
	_walk_draw_size = 0.0
	_wander_x = 0.5
	_wander_y = 1.0
	_target_x = 0.5
	_target_y = 1.0
	_dwell_timer = 0.0
	_moving = false
	_facing_left = false
	_motion_speed_ratio = 0.0
	_line_elapsed = 0.0
	_line_index = 0
	_line_pool.clear()
	_line_runs.clear()
	_line_plain_text = ""
	_close_rect = Rect2()
	_speech_rect = Rect2()
	_companion_center = Vector2.ZERO
	if _animator != null and _animator.has_method("reset_all"):
		_animator.reset_all()


func prewarm_for_snapshot(snapshot: Dictionary, _registry: Object = null) -> void:
	_prewarm_shell_texture()
	var snapshot_pet_id := str(snapshot.get("pet_id", "")).strip_edges().to_lower()
	if snapshot_pet_id != "":
		_profile.set_pet_id(snapshot_pet_id)
		_profile.prewarm_visual_keys([
			"companion_idle",
			"companion_walk",
			"companion_move_left",
			"companion_move_right",
		])
	if _renderer != null and _renderer.has_method("prewarm_assets"):
		_renderer.prewarm_assets()
	LingpetLanguageRichText.prewarm_fonts()


func open(snapshot: Dictionary, _owner: Object, registry: Object) -> bool:
	if not can_open_snapshot(snapshot):
		return false
	reset()
	active = true
	pet_id = str(snapshot.get("pet_id", "")).strip_edges().to_lower()
	ring_core_tier = clampi(int(snapshot.get("ring_core_tier", 0)), 0, MAX_RING_CORE_TIER_DISPLAY)
	decoder_level = decoder_level_for_ring_core_tier(ring_core_tier)
	prewarm_for_snapshot(snapshot, registry)
	_profile.set_pet_id(pet_id)
	var motion_style := LingpetCatalog.get_motion_style(pet_id)
	_is_flight = motion_style == "sortie_flight" or motion_style == "free_flight"
	_walk_draw_size = _profile.get_visual_layout_value("companion_walk_draw_size", 0.0)
	_init_wander()
	_line_pool = LingpetLanguageCatalog.get_generic_lines("")
	if _line_pool.is_empty():
		_line_pool = LingpetLanguageCatalog.get_lines_for_speaker(pet_id)
	if not _line_pool.is_empty():
		_line_index = int(abs(hash([pet_id, ring_core_tier, decoder_level, Time.get_ticks_msec()]))) % _line_pool.size()
	_rebuild_line_runs()
	return true


func advance(delta: float) -> void:
	if not active:
		return
	var safe_delta := maxf(0.0, delta)
	elapsed += safe_delta
	_line_elapsed += safe_delta
	if safe_delta <= 0.0:
		_motion_speed_ratio = 0.0
		if _animator != null:
			_animator.advance(0.0)
			_animator.advance_walk_phase(0.0, 0.0)
		return
	var speed := WANDER_FLIGHT_SPEED if _is_flight else WANDER_GROUND_SPEED
	var prev_x := _wander_x
	var prev_y := _wander_y
	if _moving:
		var step := speed * safe_delta
		_wander_x = _step_toward(_wander_x, _target_x, step)
		if _is_flight:
			_wander_y = _step_toward(_wander_y, _target_y, step)
		var arrived_x := absf(_wander_x - _target_x) <= WANDER_ARRIVE_EPS
		var arrived_y := (not _is_flight) or absf(_wander_y - _target_y) <= WANDER_ARRIVE_EPS
		if arrived_x and arrived_y:
			_moving = false
			_dwell_timer = randf_range(WANDER_DWELL_MIN, WANDER_DWELL_MAX)
	else:
		_dwell_timer -= safe_delta
		if _dwell_timer <= 0.0:
			_pick_new_target()
			_moving = true
	var moved := absf(_wander_x - prev_x)
	if _is_flight:
		moved = maxf(moved, absf(_wander_y - prev_y))
	_motion_speed_ratio = clampf(moved / maxf(0.0001, speed * safe_delta), 0.0, 1.0)
	if _animator != null:
		_animator.advance(safe_delta)
		_animator.advance_walk_phase(safe_delta, _motion_speed_ratio)
	if _line_elapsed >= LINE_SECONDS:
		_line_elapsed = 0.0
		advance_line()


func advance_line() -> void:
	if _line_pool.is_empty():
		return
	_line_index = (_line_index + 1) % _line_pool.size()
	_rebuild_line_runs()


func _init_wander() -> void:
	# Start already moving toward the far side so the first visible frames read as a
	# walk (and so a single advance() tick reports real motion). Subsequent targets
	# are random via _pick_new_target().
	_wander_x = 0.18
	_target_x = 0.82
	_wander_y = 0.5 if _is_flight else 1.0
	_target_y = 0.2 if _is_flight else 1.0
	_dwell_timer = 0.0
	_moving = true
	_facing_left = false


func _pick_new_target() -> void:
	var new_x := _wander_x
	for _i in range(6):
		new_x = randf()
		if absf(new_x - _wander_x) >= WANDER_MIN_STEP:
			break
	_target_x = clampf(new_x, 0.0, 1.0)
	_facing_left = _target_x < _wander_x
	if _is_flight:
		_target_y = clampf(randf(), 0.0, 1.0)


func _step_toward(current: float, target: float, max_step: float) -> float:
	var diff := target - current
	if absf(diff) <= max_step:
		return target
	return current + signf(diff) * max_step


func _effective_walk_draw_size() -> float:
	return _walk_draw_size if _walk_draw_size > 0.0 else DEFAULT_COMPANION_DRAW_SIZE


func handle_mouse_button(mouse_pos: Vector2, button_index: int) -> StringName:
	if not active or button_index != MOUSE_BUTTON_LEFT:
		return &""
	if _close_rect.has_point(mouse_pos):
		reset()
		return &"closed"
	if _speech_rect.has_point(mouse_pos):
		advance_line()
		return &"line"
	return &""


func draw(canvas: CanvasItem, font: Font, panel_rect: Rect2, view_size: Vector2, mouse_pos: Vector2 = Vector2.INF) -> void:
	if not active or canvas == null:
		return
	var modal_rect := build_modal_rect(panel_rect, view_size)
	canvas.draw_rect(panel_rect.grow(-4.0), Color(0.0, 0.0, 0.0, 0.48))
	var shell_texture := _shell_texture
	var screen_rect := _screen_rect(modal_rect)
	var walk_band_rect := _walk_band_rect(modal_rect)
	if shell_texture != null:
		_draw_shell_texture(canvas, shell_texture, modal_rect)
		_draw_close_button(canvas, font, modal_rect, mouse_pos)
	else:
		_draw_shell(canvas, font, modal_rect, mouse_pos)
		_draw_screen(canvas, screen_rect)
		walk_band_rect = Rect2()
	_draw_companion(canvas, screen_rect, walk_band_rect)
	_draw_speech_bubble(canvas, font, modal_rect, screen_rect)
	_draw_footer(canvas, font, modal_rect)


static func build_modal_rect(panel_rect: Rect2, view_size: Vector2 = Vector2.ZERO) -> Rect2:
	var available_width := maxf(120.0, panel_rect.size.x - 48.0)
	var available_height := maxf(180.0, panel_rect.size.y - 56.0)
	if view_size.x > 0.0 and view_size.y > 0.0:
		available_width = minf(available_width, maxf(120.0, view_size.x - MODAL_SIDE_MARGIN))
		available_height = minf(available_height, maxf(180.0, view_size.y - MODAL_VERTICAL_MARGIN))
	var modal_height := minf(MODAL_MAX_HEIGHT, available_height)
	var modal_width := modal_height * SHELL_ASPECT_RATIO
	if modal_width > available_width:
		modal_width = available_width
		modal_height = modal_width / SHELL_ASPECT_RATIO
	if modal_height < MODAL_MIN_HEIGHT:
		var fitted_min_height := minf(MODAL_MIN_HEIGHT, minf(available_height, available_width / SHELL_ASPECT_RATIO))
		modal_height = maxf(modal_height, fitted_min_height)
		modal_width = modal_height * SHELL_ASPECT_RATIO
	var modal_size := Vector2(modal_width, modal_height)
	return Rect2(panel_rect.get_center() - modal_size * 0.5, modal_size)


static func decoder_level_for_ring_core_tier(tier: int) -> int:
	return clampi(tier, 0, LingpetDecoder.MAX_DECODER_LEVEL)


func get_motion_speed_ratio_for_tests() -> float:
	return _motion_speed_ratio


func get_walk_phase_for_tests() -> float:
	return float(_animator.walk_phase) if _animator != null else 0.0


func get_current_plain_text_for_tests() -> String:
	return _line_plain_text


func get_decoder_level_for_tests() -> int:
	return decoder_level


func get_ring_core_tier_for_tests() -> int:
	return ring_core_tier


func is_flight_for_tests() -> bool:
	return _is_flight


func get_decoder_caption_for_tests() -> String:
	return _build_decoder_caption()


func get_close_rect_for_tests() -> Rect2:
	return _close_rect


func get_speech_rect_for_tests() -> Rect2:
	return _speech_rect


func get_companion_center_for_tests() -> Vector2:
	return _companion_center


func has_shell_texture_for_tests() -> bool:
	return _shell_texture != null


static func get_shell_texture_path_for_tests() -> String:
	return SHELL_TEXTURE_PATH


static func get_shell_aspect_ratio_for_tests() -> float:
	return SHELL_ASPECT_RATIO


static func screen_rect_for_tests(modal_rect: Rect2) -> Rect2:
	return _anchor_rect(modal_rect, SHELL_SCREEN_RECT_NORM)


static func walk_band_rect_for_tests(modal_rect: Rect2) -> Rect2:
	return _anchor_rect(modal_rect, SHELL_WALK_BAND_NORM)


static func close_rect_for_tests(modal_rect: Rect2) -> Rect2:
	return _build_close_rect(modal_rect)


static func speech_rect_for_tests(screen_rect: Rect2, companion_center: Vector2) -> Rect2:
	return _build_speech_rect(screen_rect, companion_center)


static func speech_tail_for_tests(speech_rect: Rect2, screen_rect: Rect2, companion_center: Vector2) -> PackedVector2Array:
	return _build_speech_tail(speech_rect, screen_rect, companion_center)


func _rebuild_line_runs() -> void:
	_line_runs.clear()
	_line_plain_text = ""
	if _line_pool.is_empty():
		return
	var line: Dictionary = _line_pool[clampi(_line_index, 0, _line_pool.size() - 1)] as Dictionary
	_line_runs = LingpetLanguageRichText.build_runs(line, decoder_level, Callable(self, "_translate_token"))
	_line_plain_text = LingpetLanguageRichText.runs_to_plain_text(_line_runs)


func _translate_token(key: String, fallback: String = "") -> String:
	return _tr(key, fallback if fallback != "" else key)


func _tr(key: String, fallback: String = "") -> String:
	return LanguageSettings.translate(key, fallback if fallback != "" else key)


func _screen_rect(modal_rect: Rect2) -> Rect2:
	return _anchor_rect(modal_rect, SHELL_SCREEN_RECT_NORM)


func _walk_band_rect(modal_rect: Rect2) -> Rect2:
	return _anchor_rect(modal_rect, SHELL_WALK_BAND_NORM)


static func _anchor_rect(modal_rect: Rect2, anchor: Rect2) -> Rect2:
	return Rect2(
		modal_rect.position + Vector2(modal_rect.size.x * anchor.position.x, modal_rect.size.y * anchor.position.y),
		Vector2(modal_rect.size.x * anchor.size.x, modal_rect.size.y * anchor.size.y)
	)


# Maps the normalized wander position to a draw center whose FULL sprite footprint
# (half = draw_size * 0.5) stays inside the glass. Ground pets travel along the floor
# line inside the walk band (x only); flight pets roam a 2D band of the glass screen.
static func resolve_companion_center(is_flight: bool, wander_x: float, wander_y: float, walk_bounds: Rect2, screen_rect: Rect2, draw_size: float) -> Vector2:
	var half := maxf(6.0, draw_size * 0.5)
	if is_flight:
		var fx := _contain_range(screen_rect.position.x, screen_rect.end.x, half + WALK_BAND_SPRITE_MARGIN, screen_rect.get_center().x)
		var roam_top := screen_rect.position.y + screen_rect.size.y * FLIGHT_ROAM_TOP_RATIO
		var fy := _contain_range(roam_top, screen_rect.end.y, half + WALK_BAND_SPRITE_MARGIN, (roam_top + screen_rect.end.y) * 0.5)
		return Vector2(
			lerpf(fx.x, fx.y, clampf(wander_x, 0.0, 1.0)),
			lerpf(fy.x, fy.y, clampf(wander_y, 0.0, 1.0))
		)
	var existing_inset := minf(46.0, walk_bounds.size.x * WALK_BAND_HORIZONTAL_INSET_RATIO)
	var inset := maxf(existing_inset, half + WALK_BAND_SPRITE_MARGIN)
	var bx := _contain_range(walk_bounds.position.x, walk_bounds.end.x, inset, walk_bounds.get_center().x)
	return Vector2(
		lerpf(bx.x, bx.y, clampf(wander_x, 0.0, 1.0)),
		walk_bounds.position.y + walk_bounds.size.y * 0.62
	)


static func _contain_range(lo: float, hi: float, inset: float, fallback: float) -> Vector2:
	var left := lo + inset
	var right := hi - inset
	if right < left:
		return Vector2(fallback, fallback)
	return Vector2(left, right)


func _prewarm_shell_texture() -> Texture2D:
	if _shell_texture != null:
		return _shell_texture
	_shell_texture = ProjectResourceLoader.load_imported_texture(
		SHELL_TEXTURE_PATH,
		"Missing Lingpet pendulum shell texture at %s",
		"Failed to load Lingpet pendulum shell texture at %s"
	)
	return _shell_texture


func _draw_shell_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	canvas.draw_texture_rect(texture, rect, false, Color.WHITE)


func _draw_shell(canvas: CanvasItem, font: Font, rect: Rect2, mouse_pos: Vector2) -> void:
	var shell_fill := Color(13.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 0.98)
	var shell_border := Color(215.0 / 255.0, 170.0 / 255.0, 92.0 / 255.0, 0.94)
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, shell_fill, shell_border, 3.0)
	var top_center := Vector2(rect.get_center().x, rect.position.y + 18.0)
	canvas.draw_line(top_center, top_center + Vector2(0.0, 34.0), Color(0.90, 0.76, 0.46, 0.70), 2.0)
	canvas.draw_circle(top_center, 8.0, Color(0.12, 0.18, 0.26, 1.0))
	canvas.draw_circle(top_center, 4.5, Color(0.08, 0.82, 0.94, 0.82))
	canvas.draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.44, -PI * 0.86, -PI * 0.14, 42, Color(0.0, 0.82, 1.0, 0.24), 1.5, true)
	canvas.draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.49, -PI * 0.83, -PI * 0.17, 42, Color(1.0, 0.56, 0.78, 0.18), 1.2, true)
	_draw_text(canvas, font, _tr("lingpet.pendulum.title"), rect.position + Vector2(24.0, 35.0), 16, Color(1.0, 0.94, 0.78, 0.96))
	_draw_close_button(canvas, font, rect, mouse_pos)


func _draw_close_button(canvas: CanvasItem, _font: Font, rect: Rect2, mouse_pos: Vector2) -> void:
	_close_rect = _build_close_rect(rect)
	var center := _close_rect.get_center()
	var hovered := _close_rect.has_point(mouse_pos)
	var fill_color := CLOSE_HOVER_FILL_COLOR if hovered else CLOSE_FILL_COLOR
	var gold_color := CLOSE_HOVER_GOLD_COLOR if hovered else CLOSE_GOLD_COLOR
	canvas.draw_circle(center, CLOSE_RADIUS, fill_color)
	canvas.draw_arc(center, CLOSE_RADIUS - 0.8, 0.0, TAU, 28, gold_color, 2.1 if hovered else 1.7, true)
	var cross_half_extent := 4.8
	canvas.draw_line(center - Vector2.ONE * cross_half_extent, center + Vector2.ONE * cross_half_extent, gold_color, 2.2 if hovered else 2.0, true)
	canvas.draw_line(center + Vector2(-cross_half_extent, cross_half_extent), center + Vector2(cross_half_extent, -cross_half_extent), gold_color, 2.2 if hovered else 2.0, true)


func _draw_screen(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect.grow(6.0), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(rect, Color(5.0 / 255.0, 18.0 / 255.0, 24.0 / 255.0, 0.98))
	canvas.draw_rect(rect, Color(60.0 / 255.0, 225.0 / 255.0, 220.0 / 255.0, 0.72), false, 2.0)
	var horizon_y := rect.end.y - 44.0
	canvas.draw_rect(Rect2(rect.position.x + 8.0, horizon_y, rect.size.x - 16.0, 2.0), Color(0.60, 0.84, 0.78, 0.28))
	for i in range(5):
		var x := rect.position.x + 18.0 + float(i) * maxf(24.0, rect.size.x / 5.4)
		var pulse := 0.5 + 0.5 * sin(elapsed * 1.7 + float(i))
		canvas.draw_circle(Vector2(x, rect.position.y + 28.0 + pulse * 9.0), 1.6 + pulse, Color(0.74, 0.92, 1.0, 0.22 + pulse * 0.22))


func _draw_companion(canvas: CanvasItem, screen_rect: Rect2, walk_band_rect: Rect2 = Rect2()) -> void:
	if _renderer == null or _context_builder == null:
		return
	var walk_bounds := walk_band_rect
	if walk_bounds.size.x <= 0.0 or walk_bounds.size.y <= 0.0:
		walk_bounds = screen_rect.grow(-56.0)
	var center := resolve_companion_center(_is_flight, _wander_x, _wander_y, walk_bounds, screen_rect, _effective_walk_draw_size())
	_companion_center = center
	var config: Dictionary = _context_builder.build_config({
		"companion_active": true,
		"current_profile": _profile,
		"animator": _animator,
		"radius": COMPANION_RADIUS,
		"face_left": _facing_left,
		"motion_speed_ratio": _motion_speed_ratio,
		"companion_visible": true,
	})
	_renderer.draw_companion(canvas, center, config)


func _draw_speech_bubble(canvas: CanvasItem, font: Font, modal_rect: Rect2, screen_rect: Rect2) -> void:
	_speech_rect = _build_speech_rect(screen_rect, _companion_center)
	var tail := _build_speech_tail(_speech_rect, screen_rect, _companion_center)
	canvas.draw_colored_polygon(tail, SPEECH_FILL_COLOR)
	canvas.draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), SPEECH_BORDER_COLOR, 1.2, true)
	canvas.draw_rect(_speech_rect, SPEECH_FILL_COLOR)
	canvas.draw_rect(_speech_rect, SPEECH_BORDER_COLOR, false, 1.6)
	_draw_text(canvas, font, _tr("lingpet.pendulum.language_label"), _speech_rect.position + Vector2(12.0, 20.0), 10, SPEECH_HEADER_COLOR)
	var decoder_text := _build_decoder_caption()
	var decoder_size := font.get_string_size(decoder_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, CAPTION_FONT_SIZE)
	_draw_text(canvas, font, decoder_text, Vector2(_speech_rect.end.x - decoder_size.x - 12.0, _speech_rect.position.y + 20.0), 10, SPEECH_CAPTION_COLOR)
	_draw_runs(canvas, Rect2(_speech_rect.position + Vector2(12.0, 35.0), _speech_rect.size - Vector2(24.0, 45.0)))
	if _line_pool.size() > 1:
		_draw_text(canvas, font, _tr("lingpet.pendulum.next_hint"), modal_rect.position + Vector2(modal_rect.size.x - 138.0, modal_rect.end.y - 24.0), 9, Color(0.78, 0.86, 0.92, 0.58))


static func _build_close_rect(modal_rect: Rect2) -> Rect2:
	var center := modal_rect.position + Vector2(
		modal_rect.size.x * CLOSE_ANCHOR_NORM.x,
		modal_rect.size.y * CLOSE_ANCHOR_NORM.y
	)
	return Rect2(center - Vector2.ONE * CLOSE_RADIUS, Vector2.ONE * CLOSE_RADIUS * 2.0)


static func _build_speech_rect(screen_rect: Rect2, companion_center: Vector2) -> Rect2:
	var bubble_width := clampf(screen_rect.size.x * 0.58, 178.0, 320.0)
	var min_x := screen_rect.position.x + SPEECH_SCREEN_INSET
	var max_x := screen_rect.end.x - SPEECH_SCREEN_INSET - bubble_width
	var centered_x := companion_center.x - bubble_width * 0.5
	var bubble_x := clampf(centered_x, min_x, maxf(min_x, max_x))
	var min_y := screen_rect.position.y + SPEECH_TOP_OFFSET
	var max_y := screen_rect.end.y - SPEECH_SCREEN_INSET - SPEECH_HEIGHT
	var bubble_y := minf(min_y, maxf(min_y, max_y))
	return Rect2(Vector2(bubble_x, bubble_y), Vector2(bubble_width, SPEECH_HEIGHT))


static func _build_speech_tail(speech_rect: Rect2, screen_rect: Rect2, companion_center: Vector2) -> PackedVector2Array:
	var tip_x := clampf(companion_center.x, screen_rect.position.x + SPEECH_SCREEN_INSET, screen_rect.end.x - SPEECH_SCREEN_INSET)
	var tip_min_y := speech_rect.end.y + 8.0
	var tip_max_y := maxf(tip_min_y, screen_rect.end.y - SPEECH_SCREEN_INSET)
	var tip_y := clampf(companion_center.y - COMPANION_RADIUS - 4.0, tip_min_y, tip_max_y)
	var base_center_x := clampf(tip_x, speech_rect.position.x + 18.0, speech_rect.end.x - 18.0)
	var base_y := speech_rect.end.y - 1.0
	return PackedVector2Array([
		Vector2(base_center_x - 9.0, base_y),
		Vector2(base_center_x + 9.0, base_y),
		Vector2(tip_x, tip_y),
	])


func _build_decoder_caption() -> String:
	return _tr("lingpet.pendulum.decoder_caption") % [
		ring_core_tier,
		LingpetDecoder.decode_pct_for_level(decoder_level),
	]


# Both decoded Korean (kind "ko") and undecoded Lingpet glyphs (kind "glyph") render
# in ONE unified color inside the speech bubble. The emotion seal keeps its own accent.
static func _resolve_speech_run_color(run: Dictionary) -> Color:
	var kind := str(run.get("kind", ""))
	if kind == "glyph" or kind == "ko":
		return SPEECH_TEXT_COLOR
	var color_value: Variant = run.get("color", SPEECH_TEXT_COLOR)
	return color_value if color_value is Color else SPEECH_TEXT_COLOR


static func resolve_speech_run_color_for_tests(run: Dictionary) -> Color:
	return _resolve_speech_run_color(run)


func _draw_runs(canvas: CanvasItem, rect: Rect2) -> void:
	var lingpet_font := LingpetLanguageRichText.get_lingpet_font()
	var body_font := LingpetLanguageRichText.get_body_font()
	if lingpet_font == null:
		lingpet_font = ThemeDB.fallback_font
	if body_font == null:
		body_font = ThemeDB.fallback_font
	if lingpet_font == null or body_font == null:
		return
	var cursor := rect.position + Vector2(0.0, float(SPEECH_FONT_SIZE))
	var max_x := rect.end.x
	var line_step := float(SPEECH_FONT_SIZE) + 8.0
	var space_width := body_font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, SPEECH_FONT_SIZE).x
	for run_value in _line_runs:
		var run: Dictionary = run_value as Dictionary
		if not bool(run.get("visible", true)):
			continue
		var text := str(run.get("text", ""))
		if text == "":
			continue
		var run_font := lingpet_font if str(run.get("font_path", "")) == LingpetLanguageRichText.LINGPET_FONT_PATH else body_font
		var text_size := run_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SPEECH_FONT_SIZE)
		if cursor.x > rect.position.x and cursor.x + text_size.x > max_x:
			cursor.x = rect.position.x
			cursor.y += line_step
		if cursor.y > rect.end.y:
			return
		var color := _resolve_speech_run_color(run)
		canvas.draw_string(run_font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SPEECH_FONT_SIZE, color)
		cursor.x += text_size.x + space_width


func _draw_footer(canvas: CanvasItem, font: Font, rect: Rect2) -> void:
	var pet_label := pet_id if pet_id != "" else "lingpet"
	_draw_text(canvas, font, _tr("lingpet.pendulum.esc_hint"), rect.position + Vector2(24.0, rect.size.y - 24.0), 10, Color(0.78, 0.90, 0.94, 0.76))
	_draw_text(canvas, font, pet_label, rect.position + Vector2(24.0, rect.size.y - 43.0), 9, Color(0.86, 0.72, 1.0, 0.58))


func _draw_text(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center_baseline: Vector2, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var visible_text := text
	var text_size := font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	canvas.draw_string(font, center_baseline - Vector2(text_size.x * 0.5, 0.0), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
