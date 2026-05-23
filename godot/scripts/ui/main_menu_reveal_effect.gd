extends Control

signal reveal_finished

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

# "Memory panorama" reveal that plays once when the main menu opens after the
# loading sequence. The scene does not snap in; instead a cream/warm haze
# holds for a beat, then slowly thins out as the background emerges from a
# washed-out, slightly zoomed-and-panned state into its final crisp clarity.
# A single soft horizontal light band passes through the middle of the
# emergence to evoke a panoramic memory coming into focus.
#
# Timeline (default constants, total ~2.5 sec):
#   0.00 - 0.30   HAZE HOLD: full cream haze; image whispers underneath
#                 (modulate over-bright + low alpha, ~1.075x zoom + slight pan)
#   0.30 - 2.50   REVEAL:    haze fades out while image, zoom, and pan travel
#                            on one continuous curve toward the final menu.
#
# Once finished the layer hides itself and releases input (mouse_filter back
# to IGNORE). It always sits on top of the menu tree so that during the
# reveal it masks the Background TextureRect, AmbientLayer, and ButtonStack.

const TEXTURE_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_logo.png"
const HAZE_HOLD_SEC := 0.30
const EMERGE_DURATION_SEC := 1.45
const SETTLE_DURATION_SEC := 0.75
const TOTAL_DURATION_SEC := HAZE_HOLD_SEC + EMERGE_DURATION_SEC + SETTLE_DURATION_SEC

const HAZE_COLOR := Color(0.96, 0.92, 0.84, 1.0)
const HAZE_ALPHA_START := 0.96
const HAZE_ALPHA_HOLD_END := 0.92
const HAZE_ALPHA_SETTLE_END := 0.0

const IMAGE_MODULATE_START := Color(1.55, 1.45, 1.35, 0.30)
const IMAGE_MODULATE_SETTLE_END := Color(1.0, 1.0, 1.0, 1.0)

const ZOOM_START := 1.075
const ZOOM_SETTLE_END := 1.0
const PAN_START := Vector2(-22.0, -4.0)
const PAN_SETTLE_END := Vector2.ZERO

const BAND_PEAK_TIME_SEC := 1.45
const BAND_HALF_WINDOW_SEC := 1.00
const BAND_HEIGHT_RATIO := 0.50
const BAND_PEAK_ALPHA := 0.13
const BAND_STRIP_COUNT := 16

const FALLBACK_VIEW_SIZE := Vector2(2020.0, 1246.0)

var texture: Texture2D = null
var elapsed: float = 0.0
var animation_done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture = ProjectResourceLoader.load_texture(
		TEXTURE_PATH,
		"Missing main-menu reveal texture: %s",
		"Failed to load main-menu reveal texture: %s"
	)
	if texture == null:
		# Without the texture the reveal cannot show anything meaningful; let
		# the underlying Background show immediately rather than block input.
		_finish_reveal()
		return
	set_process(true)


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	queue_redraw()
	if not animation_done and elapsed >= TOTAL_DURATION_SEC:
		_finish_reveal()


func _draw() -> void:
	if animation_done or texture == null:
		return
	var view_size := _view_size()
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	_draw_image_layer(view_size)
	_draw_haze(view_size)
	_draw_memory_band(view_size)


# --- Phase math -----------------------------------------------------------


func _hold_progress() -> float:
	if HAZE_HOLD_SEC <= 0.0:
		return 1.0
	return clampf(elapsed / HAZE_HOLD_SEC, 0.0, 1.0)


func _reveal_progress() -> float:
	if elapsed <= HAZE_HOLD_SEC:
		return 0.0
	var reveal_duration: float = EMERGE_DURATION_SEC + SETTLE_DURATION_SEC
	if reveal_duration <= 0.0:
		return 1.0
	return clampf((elapsed - HAZE_HOLD_SEC) / reveal_duration, 0.0, 1.0)


func _ease_in_out(t: float) -> float:
	var clamped: float = clampf(t, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _ease_out_cubic(t: float) -> float:
	var clamped: float = clampf(t, 0.0, 1.0)
	var inverse: float = 1.0 - clamped
	return 1.0 - inverse * inverse * inverse


# --- Image layer ---------------------------------------------------------


func _draw_image_layer(view_size: Vector2) -> void:
	var reveal_t: float = _reveal_progress()
	var k: float = _ease_out_cubic(reveal_t)
	var zoom: float = lerpf(ZOOM_START, ZOOM_SETTLE_END, k)
	var pan: Vector2 = PAN_START.lerp(PAN_SETTLE_END, k)
	var base_rect := _background_image_rect(view_size)
	var dst_size := base_rect.size * zoom
	var dst_position := base_rect.get_center() - dst_size * 0.5 + pan
	var dst_rect := Rect2(dst_position, dst_size)
	var src_rect := Rect2(Vector2.ZERO, texture.get_size())
	var tint: Color = _image_modulate(reveal_t)
	draw_texture_rect_region(texture, dst_rect, src_rect, tint)


func _image_modulate(reveal_t: float) -> Color:
	return IMAGE_MODULATE_START.lerp(IMAGE_MODULATE_SETTLE_END, _ease_out_cubic(reveal_t))


# --- Haze layer ----------------------------------------------------------


func _draw_haze(view_size: Vector2) -> void:
	var reveal_t: float = _reveal_progress()
	var haze_alpha: float
	if elapsed <= HAZE_HOLD_SEC:
		haze_alpha = lerpf(HAZE_ALPHA_START, HAZE_ALPHA_HOLD_END, _hold_progress())
	else:
		haze_alpha = lerpf(HAZE_ALPHA_HOLD_END, HAZE_ALPHA_SETTLE_END, _ease_in_out(reveal_t))
	if haze_alpha <= 0.005:
		return
	var fill := Color(HAZE_COLOR.r, HAZE_COLOR.g, HAZE_COLOR.b, haze_alpha)
	draw_rect(Rect2(Vector2.ZERO, view_size), fill)


# --- Memory band (single soft horizontal pass) ---------------------------


func _draw_memory_band(view_size: Vector2) -> void:
	var dist: float = elapsed - BAND_PEAK_TIME_SEC
	if absf(dist) > BAND_HALF_WINDOW_SEC:
		return
	var profile: float = 1.0 - absf(dist) / BAND_HALF_WINDOW_SEC
	profile = profile * profile * (3.0 - 2.0 * profile)
	var band_alpha: float = profile * BAND_PEAK_ALPHA
	if band_alpha < 0.004:
		return
	var band_h: float = view_size.y * BAND_HEIGHT_RATIO
	var band_top: float = view_size.y * 0.5 - band_h * 0.5
	var strip_thickness: float = band_h / float(BAND_STRIP_COUNT) + 1.0
	for i in BAND_STRIP_COUNT:
		var ti: float = (float(i) / float(BAND_STRIP_COUNT - 1) - 0.5) * 2.0
		var falloff: float = pow(1.0 - absf(ti), 1.5)
		var alpha: float = band_alpha * falloff
		if alpha < 0.003:
			continue
		var strip_y: float = band_top + (ti * 0.5 + 0.5) * band_h
		var stripe_color := Color(1.0, 0.96, 0.88, alpha)
		draw_line(
			Vector2(0.0, strip_y),
			Vector2(view_size.x, strip_y),
			stripe_color,
			strip_thickness
		)


# --- Lifecycle / helpers --------------------------------------------------


func _finish_reveal() -> void:
	if animation_done:
		return
	animation_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	reveal_finished.emit()


func is_reveal_active() -> bool:
	return not animation_done


func _view_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	return FALLBACK_VIEW_SIZE


func _background_image_rect(view_size: Vector2) -> Rect2:
	# Match the scene's full-viewport Background TextureRect stretch.
	# The reveal's final frame must land on the same rect, otherwise hiding this
	# layer creates a visible snap between the animation and static menu.
	return Rect2(Vector2.ZERO, view_size)
