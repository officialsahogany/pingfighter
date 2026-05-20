extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LOGO_SHEET_PATH := "res://assets/ui/intro/penguin_logo_wave.png"
const LOGO_SOUND_PATH := "res://assets/sounds/logo.wav"
const TEXT_FONT_PATHS := [
	"res://assets/fonts/PFStardust.ttf",
	"res://assets/fonts/NanumSquareB.ttf",
	"res://assets/fonts/NeoDunggeunmoPro.ttf",
]
const BG_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const RING_COLOR := Color(245.0 / 255.0, 238.0 / 255.0, 225.0 / 255.0, 1.0)
const RING_HIGHLIGHT := Color(250.0 / 255.0, 248.0 / 255.0, 243.0 / 255.0, 110.0 / 255.0)
const RED_COLOR := Color(208.0 / 255.0, 42.0 / 255.0, 34.0 / 255.0, 1.0)
const GLOW_COLOR := Color(1.0, 210.0 / 255.0, 160.0 / 255.0, 1.0)
const GLINT_COLOR := Color(1.0, 245.0 / 255.0, 220.0 / 255.0, 1.0)
const TEXT := "동네게임즈"

const FRAME_COUNT := 24
const COLS := 6
const CELL_W := 965.0
const CELL_H := 961.0
const FPS := 15.0
const BOOTSTRAP_HOLD_SECONDS := 0.0
const LOGO_SOUND_SECONDS := 2.69025
const LOGO_DIAMETER_SCALE := 0.80
const LOGO_MIN_DIAMETER := 128.0
const SCALE_IN_SECONDS := 0.30
const SCALE_IN_START := 0.82
const FADE_OUT_SECONDS := 0.30
const TEXT_REVEAL_SECONDS := 0.50
const TEXT_GLINT_DELAY_SECONDS := 0.55
const TEXT_GLINT_SECONDS := 0.60
const TEXT_SIZE_RATIO := 0.17
const TEXT_GAP_MIN := 16.0
const TEXT_GAP_RATIO := 0.06
const TEXT_LIFT_MIN := 18.0
const TEXT_LIFT_RATIO := 0.045
const TEXT_TRACKING_STEPS := 18
const TEXT_TRACKING_START_RATIO := 0.055
const TEXT_DRIFT_RATIO := 0.015
const TEXT_DRIFT_MIN := 3.0
const GLINT_PEAK_ALPHA := 170.0 / 255.0
const GLINT_BRUSH_HEIGHT_MULT := 2.0
const GLINT_CORE_WIDTH_RATIO := 0.18
const GLINT_BROAD_WIDTH_RATIO := 0.50
const GLINT_TRAIL_WIDTH_RATIO := 0.88
const GLINT_BAND_ALPHA := 0.34
const GLINT_CORE_ALPHA := 0.95
const GLINT_FLARE_ALPHA := 0.90

var active: bool = false
var elapsed_seconds: float = 0.0
var start_msec: int = 0
var sheet_texture: Texture2D
var logo_sound: AudioStreamPlayer
var sheet_load_attempted: bool = false
var studio_text_font: Font
var studio_text_font_path: String = ""


func begin(owner: Node) -> bool:
	if active:
		return true
	_load_sheet()
	_get_studio_text_font()
	if sheet_texture == null:
		return false
	elapsed_seconds = 0.0
	sheet_load_attempted = true
	_play_sound(owner)
	start_msec = Time.get_ticks_msec()
	active = true
	return true


func prewarm_assets() -> void:
	_load_sheet()
	if not _is_headless_run():
		ProjectResourceLoader.load_audio_stream(
			LOGO_SOUND_PATH,
			"Missing penguin logo intro sound: %s",
			"Failed to load penguin logo intro sound: %s"
		)
	_get_studio_text_font()


func is_active() -> bool:
	return active


func is_audio_playing() -> bool:
	return logo_sound != null and is_instance_valid(logo_sound) and logo_sound.playing


func cleanup() -> void:
	active = false
	start_msec = 0
	if logo_sound != null and is_instance_valid(logo_sound):
		if logo_sound.playing:
			logo_sound.stop()
		logo_sound.stream = null
		logo_sound.free()
	logo_sound = null
	sheet_texture = null
	studio_text_font = null
	studio_text_font_path = ""


func update(_delta: float) -> void:
	if not active:
		return
	_refresh_elapsed_seconds()
	if elapsed_seconds >= _total_seconds():
		active = false


func draw(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), BG_COLOR)
	if _is_bootstrap_phase() or sheet_texture == null:
		_draw_bootstrap_logo(canvas, view_size)
		return
	if sheet_texture == null:
		return

	var layout: Dictionary = _build_layout(view_size)
	var scale: float = _logo_scale()
	var alpha: float = _logo_alpha()
	var center: Vector2 = layout.get("center", view_size * 0.5)
	var diameter: float = float(layout["diameter"]) * scale
	var source_frame_size: Vector2 = layout.get("frame_size", Vector2.ZERO)
	var frame_size: Vector2 = source_frame_size * scale
	var frame_index: int = _frame_index()

	var local_size: Vector2 = layout.get("local_size", Vector2.ZERO)
	_draw_glow(canvas, center, local_size.x * 0.5 * scale, alpha)
	_draw_logo_backdrop(canvas, center, diameter, alpha)
	_draw_wave_frame(canvas, center, frame_size, frame_index, alpha)
	_draw_studio_text(canvas, view_size, layout, alpha)


func _load_sheet() -> void:
	if sheet_texture != null:
		return
	sheet_texture = ProjectResourceLoader.load_texture(
		LOGO_SHEET_PATH,
		"Missing penguin logo intro sheet: %s",
		"Failed to load penguin logo intro sheet: %s"
	)


func _play_sound(owner: Node) -> void:
	if owner == null:
		return
	if _is_headless_run():
		return
	if logo_sound == null:
		logo_sound = AudioStreamPlayer.new()
		logo_sound.name = "PenguinLogoIntroSfx"
		logo_sound.bus = "Master"
		logo_sound.volume_db = 0.0
		logo_sound.stream = ProjectResourceLoader.load_audio_stream(
			LOGO_SOUND_PATH,
			"Missing penguin logo intro sound: %s",
			"Failed to load penguin logo intro sound: %s"
		)
		owner.add_child(logo_sound)
	if logo_sound.stream == null:
		return
	if logo_sound.playing:
		logo_sound.stop()
	logo_sound.pitch_scale = 1.0
	logo_sound.play()


func _is_headless_run() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _get_studio_text_font() -> Font:
	if studio_text_font != null:
		return studio_text_font
	for path_value in TEXT_FONT_PATHS:
		var path: String = str(path_value)
		var font: Font = ProjectResourceLoader.load_font(path)
		if font != null:
			studio_text_font = font
			studio_text_font_path = path
			return studio_text_font
	studio_text_font = ThemeDB.fallback_font
	studio_text_font_path = ""
	return studio_text_font


func _get_studio_text_font_size(diameter: float) -> int:
	var base_size: int = max(14, int(diameter * TEXT_SIZE_RATIO))
	if studio_text_font_path.ends_with("PFStardust.ttf"):
		return int(base_size * 1.1)
	return base_size


func _draw_bootstrap_logo(canvas: CanvasItem, view_size: Vector2) -> void:
	var layout: Dictionary = _build_layout(view_size)
	var center: Vector2 = layout.get("center", view_size * 0.5)
	var diameter: float = float(layout["diameter"]) * SCALE_IN_START
	var local_size: Vector2 = layout.get("local_size", Vector2.ZERO)
	_draw_glow(canvas, center, local_size.x * 0.5 * SCALE_IN_START, 1.0)
	_draw_logo_backdrop(canvas, center, diameter, 1.0)


func _build_layout(view_size: Vector2) -> Dictionary:
	var base_diameter: float = min(view_size.x * 0.44, view_size.y * 0.60)
	var diameter: float = max(LOGO_MIN_DIAMETER, round(base_diameter * LOGO_DIAMETER_SCALE))
	var pad_x: float = max(24.0, diameter / 12.0)
	var pad_y: float = max(24.0, diameter / 12.0)
	var logo_local: Vector2 = Vector2(diameter + pad_x * 2.0, diameter + pad_y * 2.0)
	var frame_scale: float = min((diameter * 0.94) / CELL_W, (diameter * 0.94) / CELL_H)
	var frame_size: Vector2 = Vector2(CELL_W, CELL_H) * max(0.1, frame_scale)
	var local_size: Vector2 = Vector2(
		max(logo_local.x, frame_size.x + max(24.0, diameter / 6.0)),
		max(logo_local.y, frame_size.y + max(24.0, diameter / 6.0))
	)
	return {
		"center": view_size * 0.5,
		"diameter": diameter,
		"frame_size": frame_size,
		"local_size": local_size,
	}


func _draw_glow(canvas: CanvasItem, center: Vector2, max_radius: float, alpha: float) -> void:
	var layers: int = 10
	for idx in range(layers):
		var radius: float = max(10.0, max_radius - float(idx) * max(6.0, max_radius / 8.0))
		var layer_alpha: float = min(90.0, 10.0 + float(idx) * 10.0) / 255.0
		canvas.draw_circle(center, radius, _with_alpha(GLOW_COLOR, layer_alpha * alpha))


func _draw_logo_backdrop(canvas: CanvasItem, center: Vector2, diameter: float, alpha: float) -> void:
	var outer_radius: float = max(1.0, diameter * 0.5 - 2.0)
	var ring_thickness: float = max(12.0, diameter * 0.072)
	var inner_radius: float = max(1.0, outer_radius - ring_thickness)
	canvas.draw_circle(center, outer_radius, _with_alpha(RING_COLOR, alpha))
	canvas.draw_circle(center, inner_radius, _with_alpha(RED_COLOR, alpha))
	canvas.draw_circle(
		center + Vector2(0.0, -diameter * 0.22),
		max(8.0, diameter * 0.18),
		_with_alpha(RING_HIGHLIGHT, alpha * RING_HIGHLIGHT.a)
	)


func _draw_wave_frame(
	canvas: CanvasItem,
	center: Vector2,
	frame_size: Vector2,
	frame_index: int,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var col: int = frame_index % COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / COLS)
	var source: Rect2 = Rect2(Vector2(float(col) * CELL_W, float(row) * CELL_H), Vector2(CELL_W, CELL_H))
	var dest: Rect2 = Rect2(center - frame_size * 0.5, frame_size)
	canvas.draw_texture_rect_region(
		sheet_texture,
		dest,
		source,
		Color(1.0, 1.0, 1.0, alpha),
		false,
		true
	)


func _draw_studio_text(canvas: CanvasItem, view_size: Vector2, layout: Dictionary, alpha: float) -> void:
	var anim_elapsed: float = _animation_elapsed()
	if anim_elapsed < SCALE_IN_SECONDS:
		return
	var font: Font = _get_studio_text_font()
	if font == null:
		return

	var diameter: float = float(layout["diameter"])
	var reveal_t: float = clamp((anim_elapsed - SCALE_IN_SECONDS) / TEXT_REVEAL_SECONDS, 0.0, 1.0)
	var eased_reveal: float = _smoothstep(reveal_t)
	var text_alpha: float = min(alpha, eased_reveal)
	if text_alpha <= 0.0:
		return

	var font_size: int = _get_studio_text_font_size(diameter)
	var tracking: float = _tracking_for_reveal(diameter, eased_reveal)
	var text_size: Vector2 = _tracked_text_size(font, TEXT, font_size, tracking)
	var gap: float = max(TEXT_GAP_MIN, diameter * TEXT_GAP_RATIO)
	var center: Vector2 = layout.get("center", view_size * 0.5)
	var local_size: Vector2 = layout.get("local_size", Vector2.ZERO)
	var text_lift: float = max(TEXT_LIFT_MIN, diameter * TEXT_LIFT_RATIO)
	var text_top: float = min(
		center.y + local_size.y * 0.5 + gap - text_lift,
		view_size.y - text_size.y - 8.0
	)
	text_top = max(8.0, text_top)
	var drift: int = int((1.0 - eased_reveal) * max(TEXT_DRIFT_MIN, diameter * TEXT_DRIFT_RATIO))
	var baseline: Vector2 = Vector2(view_size.x * 0.5 - text_size.x * 0.5, text_top + float(font.get_ascent(font_size)) + drift)

	_draw_tracked_text(canvas, font, TEXT, baseline, font_size, tracking, _with_alpha(GLOW_COLOR, text_alpha))
	_draw_text_glint(canvas, font, TEXT, baseline, font_size, tracking, text_alpha)


func _draw_text_glint(
	canvas: CanvasItem,
	font: Font,
	text: String,
	baseline: Vector2,
	font_size: int,
	tracking: float,
	text_alpha: float
) -> void:
	var anim_elapsed: float = _animation_elapsed()
	var glint_start: float = SCALE_IN_SECONDS + TEXT_GLINT_DELAY_SECONDS
	if anim_elapsed < glint_start or anim_elapsed >= glint_start + TEXT_GLINT_SECONDS:
		return
	var glint_t: float = (anim_elapsed - glint_start) / TEXT_GLINT_SECONDS
	var total_width: float = _tracked_text_size(font, text, font_size, tracking).x
	var text_height: float = float(font.get_height(font_size))
	var brush_width: float = max(1.0, text_height * GLINT_BRUSH_HEIGHT_MULT)
	var sweep_x: float = -brush_width + glint_t * (total_width + brush_width)
	var band_center: float = sweep_x + brush_width * 0.5
	_draw_glint_sweep_band(canvas, baseline, total_width, text_height, band_center, text_alpha)
	var x: float = baseline.x
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		var ch_size: Vector2 = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var center_x: float = x + ch_size.x * 0.5
		var local_center: float = center_x - baseline.x
		var dist: float = abs(local_center - band_center)
		var trail_alpha: float = _glint_profile(dist, brush_width * GLINT_TRAIL_WIDTH_RATIO)
		var broad_alpha: float = _glint_profile(dist, brush_width * GLINT_BROAD_WIDTH_RATIO)
		var core_alpha: float = _glint_profile(dist, brush_width * GLINT_CORE_WIDTH_RATIO)
		_draw_glint_glyph(canvas, font, ch, Vector2(x, baseline.y), font_size, text_alpha, trail_alpha, broad_alpha, core_alpha)
		x += ch_size.x + tracking
	_draw_glint_spark(canvas, baseline, total_width, text_height, band_center, text_alpha)


func _draw_glint_glyph(
	canvas: CanvasItem,
	font: Font,
	ch: String,
	pos: Vector2,
	font_size: int,
	text_alpha: float,
	trail_alpha: float,
	broad_alpha: float,
	core_alpha: float
) -> void:
	if trail_alpha > 0.0:
		canvas.draw_string(
			font,
			pos + Vector2(-1.0, 0.0),
			ch,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			_with_alpha(GLINT_COLOR, text_alpha * trail_alpha * GLINT_PEAK_ALPHA * 0.52)
		)
	if broad_alpha > 0.0:
		canvas.draw_string(
			font,
			pos,
			ch,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			_with_alpha(GLINT_COLOR, text_alpha * broad_alpha * GLINT_CORE_ALPHA)
		)
	if core_alpha > 0.0:
		canvas.draw_string(
			font,
			pos + Vector2(0.0, -1.0),
			ch,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			_with_alpha(Color.WHITE, text_alpha * core_alpha * GLINT_CORE_ALPHA)
		)


func _draw_glint_sweep_band(
	canvas: CanvasItem,
	baseline: Vector2,
	total_width: float,
	text_height: float,
	band_center: float,
	text_alpha: float
) -> void:
	if band_center < -text_height or band_center > total_width + text_height:
		return
	var top_y: float = baseline.y - text_height * 0.92
	var bottom_y: float = baseline.y + text_height * 0.18
	var slant: float = text_height * 0.42
	var broad_half: float = text_height * 0.32
	var core_half: float = max(2.0, text_height * 0.040)
	var x_center: float = baseline.x + band_center
	var broad_points := PackedVector2Array([
		Vector2(x_center - broad_half + slant, top_y),
		Vector2(x_center + broad_half + slant, top_y),
		Vector2(x_center + broad_half - slant, bottom_y),
		Vector2(x_center - broad_half - slant, bottom_y),
	])
	canvas.draw_colored_polygon(
		broad_points,
		_with_alpha(GLINT_COLOR, text_alpha * GLINT_BAND_ALPHA)
	)
	canvas.draw_line(
		Vector2(x_center + slant * 0.72, top_y),
		Vector2(x_center - slant * 0.72, bottom_y),
		_with_alpha(Color.WHITE, text_alpha * GLINT_CORE_ALPHA),
		max(1.0, core_half)
	)
	canvas.draw_line(
		Vector2(x_center - broad_half - slant * 0.80, bottom_y - text_height * 0.10),
		Vector2(x_center + broad_half + slant * 0.80, top_y + text_height * 0.10),
		_with_alpha(GLINT_COLOR, text_alpha * GLINT_BAND_ALPHA * 0.72),
		max(1.0, text_height * 0.020)
	)


func _draw_glint_spark(
	canvas: CanvasItem,
	baseline: Vector2,
	total_width: float,
	text_height: float,
	band_center: float,
	text_alpha: float
) -> void:
	if band_center < 0.0 or band_center > total_width:
		return
	var spark_alpha: float = text_alpha * GLINT_FLARE_ALPHA
	var spark_center := Vector2(
		baseline.x + band_center,
		baseline.y - text_height * 0.58
	)
	var flare_size: float = max(6.0, text_height * 0.11)
	canvas.draw_line(
		spark_center + Vector2(-flare_size, 0.0),
		spark_center + Vector2(flare_size, 0.0),
		_with_alpha(GLINT_COLOR, spark_alpha * 0.88),
		max(1.0, text_height * 0.020)
	)
	canvas.draw_line(
		spark_center + Vector2(0.0, -flare_size * 0.72),
		spark_center + Vector2(0.0, flare_size * 0.72),
		_with_alpha(Color.WHITE, spark_alpha * 0.58),
		max(1.0, text_height * 0.016)
	)
	canvas.draw_line(
		spark_center + Vector2(-text_height * 0.10, text_height * 0.10),
		spark_center + Vector2(text_height * 0.12, -text_height * 0.12),
		_with_alpha(GLINT_COLOR, spark_alpha),
		max(1.0, text_height * 0.018)
	)
	canvas.draw_circle(spark_center, max(2.0, text_height * 0.030), _with_alpha(Color.WHITE, spark_alpha * 0.9))


func _draw_tracked_text(
	canvas: CanvasItem,
	font: Font,
	text: String,
	baseline: Vector2,
	font_size: int,
	tracking: float,
	color: Color
) -> void:
	var x: float = baseline.x
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		canvas.draw_string(
			font,
			Vector2(x, baseline.y),
			ch,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			color
		)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + tracking


func _tracked_text_size(font: Font, text: String, font_size: int, tracking: float) -> Vector2:
	var width: float = 0.0
	for i in range(text.length()):
		width += font.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if text.length() > 1:
		width += tracking * float(text.length() - 1)
	return Vector2(width, float(font.get_height(font_size)))


func _glint_profile(distance: float, half_width: float) -> float:
	if half_width <= 0.0:
		return 0.0
	var t: float = clamp(1.0 - distance / half_width, 0.0, 1.0)
	return _smoothstep(t)


func _tracking_for_reveal(diameter: float, eased_reveal: float) -> float:
	var max_tracking: int = max(6, int(diameter * TEXT_TRACKING_START_RATIO))
	var steps: int = max(2, TEXT_TRACKING_STEPS)
	var variant_index: int = min(
		steps - 1,
		max(0, int(round(eased_reveal * float(steps - 1))))
	)
	var t: float = float(variant_index) / float(steps - 1)
	var eased: float = _smoothstep(t)
	return float(int(round(float(max_tracking) * (1.0 - eased))))


func _frame_index() -> int:
	return min(FRAME_COUNT - 1, int(_animation_elapsed() * FPS))


func _logo_scale() -> float:
	var anim_elapsed: float = _animation_elapsed()
	if anim_elapsed >= SCALE_IN_SECONDS:
		return 1.0
	var t: float = clamp(anim_elapsed / SCALE_IN_SECONDS, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	return SCALE_IN_START + (1.0 - SCALE_IN_START) * eased


func _logo_alpha() -> float:
	var anim_elapsed: float = _animation_elapsed()
	var fade_start: float = _animation_seconds() + _hold_after_animation_seconds()
	if anim_elapsed < fade_start:
		return 1.0
	var fade_t: float = clamp((anim_elapsed - fade_start) / FADE_OUT_SECONDS, 0.0, 1.0)
	return 1.0 - _smoothstep(fade_t)


func _animation_elapsed() -> float:
	return max(0.0, elapsed_seconds - BOOTSTRAP_HOLD_SECONDS)


func _refresh_elapsed_seconds() -> void:
	if start_msec <= 0:
		return
	elapsed_seconds = max(0.0, float(Time.get_ticks_msec() - start_msec) / 1000.0)


func _is_bootstrap_phase() -> bool:
	return elapsed_seconds < BOOTSTRAP_HOLD_SECONDS


func _animation_seconds() -> float:
	return FRAME_COUNT / FPS


func _hold_after_animation_seconds() -> float:
	return max(0.0, LOGO_SOUND_SECONDS - _animation_seconds() - FADE_OUT_SECONDS)


func _total_seconds() -> float:
	return BOOTSTRAP_HOLD_SECONDS + _animation_seconds() + _hold_after_animation_seconds() + FADE_OUT_SECONDS


func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
