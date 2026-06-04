extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const GAME_WIDTH := 760.0
const GAME_HEIGHT := 750.0
const PILLAR_WIDTH := 80.0
const TUTORIAL_STAGE := 50

const DURATION_SEC := 1.8
const FADE_IN_SEC := 12.0 / 60.0
const ZOOM_HOLD_SEC := 12.0 / 60.0
const SHAKE_SEC := 14.0 / 60.0
const CAMERA_ZOOM_EXTRA := 1.8
const ARENA_START_SCALE := 0.12
const ARENA_HOLD_RATIO := 0.15
const ENCOUNTER_REVEAL_BANDS := 18
const PREWARM_TEXTURE_FALLBACK_MSEC := 8
const PREWARM_TEXTURE_FALLBACK_POLLS := 8

const STAGE_BACKGROUND_PATHS := {
	1: "res://assets/sprites/hud/stage1_landing_zoom_background_cyber_joseon_imagegen_v2_realesrgan_animev3_2x.png",
	2: "res://assets/sprites/hud/stage2_landing_zoom_background_imagegen_v1.png",
	3: "res://assets/sprites/hud/stage3_landing_zoom_background_imagegen_v1.png",
	4: "res://assets/sprites/hud/stage4_landing_zoom_background_imagegen_v1.png",
}

const STAGE_INFO := {
	1: {
		"title": "STAGE 1",
		"subtitle": "조선 골목",
		"color": Color(1.0, 0.86, 0.86, 1.0),
	},
	2: {
		"title": "STAGE 2",
		"subtitle": "정글 지진",
		"color": Color(0.58, 1.0, 0.66, 1.0),
	},
	3: {
		"title": "STAGE 3",
		"subtitle": "멘헤라 인형극장",
		"color": Color(1.0, 0.72, 0.92, 1.0),
	},
	4: {
		"title": "STAGE 4",
		"subtitle": "소림사",
		"color": Color(1.0, 0.66, 0.32, 1.0),
	},
}

const SCAN_LINES := [
	"[ DESCENT INITIATED ]",
	"[ TERRAIN SCAN... ]",
	"[ LOCAL SIGNAL LOCKING... ]",
	"[ TARGET SEARCHING... ]",
	"[ WARNING : HOSTILE DETECTED ]",
]

var active := false
var elapsed_sec := 0.0
var current_stage := 1
var background_texture: Texture2D = null
var cached_game_rect_view_size := Vector2(-1.0, -1.0)
var cached_game_rect := Rect2()


func prewarm_assets(stage: int = 1) -> void:
	while not prewarm_assets_step(stage):
		pass


func prewarm_assets_step(stage: int = 1) -> bool:
	var path: String = str(STAGE_BACKGROUND_PATHS.get(stage, ""))
	if path == "":
		return true
	var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"",
		"",
		PREWARM_TEXTURE_FALLBACK_MSEC,
		PREWARM_TEXTURE_FALLBACK_POLLS
	)
	if not bool(result.get("done", false)):
		return false
	var texture_value: Variant = result.get("texture", null)
	if texture_value is Texture2D:
		background_texture = texture_value
	return true


func begin(owner: Object, registry: Object) -> bool:
	if active:
		return true
	current_stage = int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1))
	if current_stage <= 0 or current_stage == TUTORIAL_STAGE:
		return false
	elapsed_sec = 0.0
	cached_game_rect_view_size = Vector2(-1.0, -1.0)
	cached_game_rect = Rect2()
	background_texture = _load_stage_background(current_stage)
	active = true
	_sync_serve_input(registry)
	return true


func update(delta: float, registry: Object = null) -> void:
	if not active:
		return
	elapsed_sec += max(0.0, delta)
	if elapsed_sec >= DURATION_SEC + SHAKE_SEC:
		_finish(registry)


func handle_input(event: InputEvent, registry: Object = null) -> bool:
	if not active:
		return false
	if GamepadInput.is_intro_skip_event(event):
		_finish(registry)
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			_finish(registry)
			return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			_finish(registry)
			return true
	return false


func is_active() -> bool:
	return active


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or owner == null or registry == null or not active:
		return
	if elapsed_sec < DURATION_SEC:
		_draw_descent(canvas, owner, registry, view_size)
	else:
		_draw_landing_shake(canvas, owner, registry, view_size)


func _draw_descent(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	var t: float = clamp(elapsed_sec / DURATION_SEC, 0.0, 1.0)
	var zoom_start: float = FADE_IN_SEC + ZOOM_HOLD_SEC
	var zoom_t: float = clamp((elapsed_sec - zoom_start) / max(0.001, DURATION_SEC - zoom_start), 0.0, 1.0)
	var eased_zoom: float = _ease_out_cubic(zoom_t)
	var camera_zoom: float = 1.0 + eased_zoom * CAMERA_ZOOM_EXTRA

	_draw_zoomed_background(canvas, view_size, camera_zoom)

	var final_rect: Rect2 = _get_game_rect(registry, view_size)
	var arena_scale: float = _arena_scale(t)
	if arena_scale > 0.05:
		var arena_rect := Rect2(
			final_rect.get_center() - final_rect.size * arena_scale * 0.5,
			final_rect.size * arena_scale
		)
		_draw_game_preview(canvas, owner, arena_rect)
		_draw_arena_border(canvas, arena_rect, arena_scale)

	_draw_stage_text(canvas, view_size, t)
	_draw_scan_overlay(canvas, view_size, t)
	_draw_fade_in(canvas, view_size, elapsed_sec)


func _draw_landing_shake(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	_draw_zoomed_background(canvas, view_size, 1.0 + CAMERA_ZOOM_EXTRA)
	var final_rect: Rect2 = _get_game_rect(registry, view_size)
	var shake_elapsed: float = clamp(elapsed_sec - DURATION_SEC, 0.0, SHAKE_SEC)
	var reveal_progress: float = clamp(shake_elapsed / max(0.001, SHAKE_SEC), 0.0, 1.0)
	var decay: float = 1.0 - shake_elapsed / max(0.001, SHAKE_SEC)
	@warning_ignore("shadowed_global_identifier")
	var seed: float = float(Time.get_ticks_msec()) * 0.011
	var offset := Vector2(
		sin(seed * 2.7 + float(current_stage)) * 8.0 * decay,
		cos(seed * 3.1 + float(current_stage) * 0.7) * 8.0 * decay
	)
	_draw_game_preview(canvas, owner, Rect2(final_rect.position + offset, final_rect.size))
	_draw_encounter_reveal_overlay(canvas, final_rect, reveal_progress)


func _draw_zoomed_background(canvas: CanvasItem, view_size: Vector2, camera_zoom: float) -> void:
	canvas.draw_set_transform(view_size * 0.5, 0.0, Vector2(camera_zoom, camera_zoom))
	_draw_landing_background(canvas, Rect2(-view_size * 0.5, view_size), 1.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_landing_background(canvas: CanvasItem, target: Rect2, alpha: float) -> void:
	if background_texture is Texture2D:
		_draw_texture_cover(canvas, background_texture, target, Color(0.62, 0.62, 0.62, alpha))
		canvas.draw_rect(target, Color(0.0, 0.0, 0.0, 0.35 * alpha))
		_draw_texture_fit(canvas, background_texture, target, Color(1.0, 1.0, 1.0, alpha))
		return
	_draw_fallback_space(canvas, target, alpha)


func _draw_game_preview(canvas: CanvasItem, owner: Object, target: Rect2) -> void:
	if target.size.x <= 1.0 or target.size.y <= 1.0:
		return
	canvas.draw_rect(target.grow(4.0), Color(0.0, 0.0, 0.0, 0.72))
	canvas.draw_set_transform(target.position, 0.0, Vector2(target.size.x / GAME_WIDTH, target.size.y / GAME_HEIGHT))
	_draw_playfield_snapshot(canvas, owner)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_playfield_snapshot(canvas: CanvasItem, owner: Object) -> void:
	var textures: Dictionary = BattleSceneOwnerReader.get_dictionary(owner, "battle_textures")
	var background = textures.get("stage1_center_background_texture", null)
	if background is Texture2D:
		canvas.draw_texture_rect(background, Rect2(0.0, 0.0, GAME_WIDTH, GAME_HEIGHT), false)
	else:
		_draw_fallback_playfield(canvas)

	var border = textures.get("stage1_center_border_texture", null)
	if border is Texture2D:
		canvas.draw_texture_rect(border, Rect2(0.0, 0.0, GAME_WIDTH, GAME_HEIGHT), false)
	else:
		canvas.draw_rect(Rect2(4.0, 4.0, GAME_WIDTH - 8.0, GAME_HEIGHT - 8.0), Color(0.74, 0.58, 0.24, 0.9), false, 4.0)


func _draw_fallback_playfield(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, GAME_WIDTH, GAME_HEIGHT), Color(0.25, 0.24, 0.21, 1.0))
	var center := Vector2(GAME_WIDTH * 0.5, GAME_HEIGHT * 0.5)
	canvas.draw_line(Vector2(0.0, center.y), Vector2(GAME_WIDTH, center.y), Color(0.44, 0.38, 0.27, 0.85), 3.0)
	canvas.draw_arc(center, 88.0, 0.0, TAU, 96, Color(0.58, 0.48, 0.31, 0.75), 3.0)
	for idx in range(18):
		var y := float(idx) * 42.0 + 12.0
		canvas.draw_line(Vector2(20.0, y), Vector2(GAME_WIDTH - 20.0, y + 8.0), Color(0.12, 0.10, 0.08, 0.18), 1.0)


func _draw_arena_border(canvas: CanvasItem, rect: Rect2, arena_scale: float) -> void:
	var alpha: float = clamp(0.45 + arena_scale * 0.55, 0.0, 1.0)
	var outer := Color(0.95, 0.76, 0.26, alpha)
	var inner := Color(0.14, 0.87, 0.92, alpha * 0.72)
	var red := Color(0.88, 0.18, 0.16, alpha * 0.78)
	canvas.draw_rect(rect, outer, false, max(1.0, 5.0 * arena_scale))
	canvas.draw_rect(rect.grow(-6.0 * arena_scale), red, false, max(1.0, 2.0 * arena_scale))
	canvas.draw_rect(rect.grow(3.0 * arena_scale), inner, false, max(1.0, 1.5 * arena_scale))


func _draw_encounter_reveal_overlay(canvas: CanvasItem, game_rect: Rect2, progress: float) -> void:
	var eased: float = _ease_out_cubic(progress)
	var band_h: float = max(4.0, game_rect.size.y / float(ENCOUNTER_REVEAL_BANDS))
	var center_x: float = game_rect.get_center().x
	for band_idx in range(ENCOUNTER_REVEAL_BANDS):
		var row_t: float = float(band_idx) / max(1.0, float(ENCOUNTER_REVEAL_BANDS - 1))
		var local_progress: float = clamp((progress - row_t * 0.18) / 0.82, 0.0, 1.0)
		var row_open: float = _ease_out_cubic(local_progress)
		var cover_w: float = game_rect.size.x * (1.0 - row_open)
		if cover_w <= 1.0:
			continue
		var row_y: float = game_rect.position.y + float(band_idx) * band_h
		var row_h: float = max(2.0, band_h * (0.86 + 0.08 * sin(float(band_idx) * 1.9)))
		var band_alpha: float = (0.74 - 0.42 * eased) * (1.0 - row_open * 0.35)
		var band_color := Color(0.005, 0.018, 0.035, clamp(band_alpha, 0.0, 0.74))
		var edge_color := Color(0.0, 0.88, 1.0, clamp(0.22 * (1.0 - row_open), 0.0, 0.22))
		var side_w: float = cover_w * 0.5
		var left_rect := Rect2(game_rect.position.x, row_y, side_w, row_h)
		var right_rect := Rect2(game_rect.end.x - side_w, row_y, side_w, row_h)
		canvas.draw_rect(left_rect, band_color)
		canvas.draw_rect(right_rect, band_color)
		canvas.draw_line(Vector2(center_x - side_w, row_y), Vector2(center_x - side_w, row_y + row_h), edge_color, 1.0)
		canvas.draw_line(Vector2(center_x + side_w, row_y), Vector2(center_x + side_w, row_y + row_h), edge_color, 1.0)

	var pulse_alpha: float = sin(progress * PI) * 0.32
	if pulse_alpha > 0.01:
		var center := game_rect.get_center()
		var radius: float = max(game_rect.size.x, game_rect.size.y) * (0.10 + eased * 0.62)
		canvas.draw_arc(center, radius, 0.0, TAU, 128, Color(0.0, 0.95, 1.0, pulse_alpha), 3.0)
		canvas.draw_arc(center, radius * 0.72, 0.0, TAU, 96, Color(1.0, 0.88, 0.34, pulse_alpha * 0.55), 2.0)
		for ray_idx in range(14):
			var ray_y: float = game_rect.position.y + fposmod(float(ray_idx) * 73.0 + progress * 180.0, game_rect.size.y)
			var pull: float = 1.0 - eased
			var line_alpha: float = pulse_alpha * (0.35 + 0.35 * sin(float(ray_idx) * 1.3 + progress * 6.0))
			canvas.draw_line(
				Vector2(game_rect.position.x, ray_y),
				Vector2(center.x - 60.0 * pull, center.y + (ray_y - center.y) * 0.18),
				Color(0.0, 0.85, 1.0, line_alpha),
				1.0
			)
			canvas.draw_line(
				Vector2(game_rect.end.x, ray_y),
				Vector2(center.x + 60.0 * pull, center.y + (ray_y - center.y) * 0.18),
				Color(0.0, 0.85, 1.0, line_alpha),
				1.0
			)

	if progress < 0.18:
		var flash_alpha: float = 0.20 * (1.0 - progress / 0.18)
		canvas.draw_rect(game_rect, Color(0.72, 0.92, 1.0, flash_alpha))


func _draw_stage_text(canvas: CanvasItem, view_size: Vector2, t: float) -> void:
	if t <= 0.4:
		return
	var info: Dictionary = STAGE_INFO.get(current_stage, {
		"title": "STAGE %d" % current_stage,
		"subtitle": "",
		"color": Color.WHITE,
	})
	var text_t: float = clamp((t - 0.4) / 0.3, 0.0, 1.0)
	var color: Color = info.get("color", Color.WHITE)
	color.a = text_t
	_draw_text_center(canvas, str(info.get("title", "")), Vector2(view_size.x * 0.5, view_size.y * 0.5 - 70.0), 48, color)
	var subtitle: String = str(info.get("subtitle", ""))
	if subtitle != "":
		_draw_text_center(canvas, subtitle, Vector2(view_size.x * 0.5, view_size.y * 0.5 - 12.0), 22, color)


func _draw_scan_overlay(canvas: CanvasItem, view_size: Vector2, t: float) -> void:
	if t <= 0.1:
		return
	var scan_idx: int = min(int((t - 0.1) / 0.18), SCAN_LINES.size() - 1)
	if scan_idx < 0:
		return
	var frame_idx: int = int(floor(elapsed_sec * 60.0))
	if frame_idx % 5 >= 3:
		return
	var alpha: float = min(1.0, (t - 0.1) * 5.0) * 0.78
	var font: Font = ThemeDB.fallback_font
	if font != null:
		canvas.draw_string(font, Vector2(14.0, view_size.y - 30.0), SCAN_LINES[scan_idx], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.0, 1.0, 0.70, alpha))
	var bar_w: float = 120.0 * min(1.0, t * 1.2)
	canvas.draw_rect(Rect2(14.0, view_size.y - 14.0, bar_w, 2.0), Color(0.0, 1.0, 0.70, alpha))


func _draw_fade_in(canvas: CanvasItem, view_size: Vector2, time_sec: float) -> void:
	if time_sec >= FADE_IN_SEC:
		return
	var alpha: float = 1.0 - time_sec / max(0.001, FADE_IN_SEC)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, alpha))


func _get_game_rect(registry: Object, view_size: Vector2) -> Rect2:
	if cached_game_rect_view_size == view_size and cached_game_rect.size.x > 0.0 and cached_game_rect.size.y > 0.0:
		return cached_game_rect
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		var layout: Dictionary = layout_module.build_game_layout(view_size, GAME_WIDTH, GAME_HEIGHT)
		cached_game_rect = Rect2(
			_as_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO),
			_as_vector2(layout.get("game_size", Vector2(GAME_WIDTH, GAME_HEIGHT)), Vector2(GAME_WIDTH, GAME_HEIGHT))
		)
		cached_game_rect_view_size = view_size
		return cached_game_rect
	var fallback_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	cached_game_rect = Rect2((view_size - fallback_size) * 0.5, fallback_size)
	cached_game_rect_view_size = view_size
	return cached_game_rect


func _arena_scale(t: float) -> float:
	if t < ARENA_HOLD_RATIO:
		return ARENA_START_SCALE
	var grow_t: float = clamp((t - ARENA_HOLD_RATIO) / (1.0 - ARENA_HOLD_RATIO), 0.0, 1.0)
	return ARENA_START_SCALE + (1.0 - ARENA_START_SCALE) * _ease_out_cubic(grow_t)


func _draw_fallback_space(canvas: CanvasItem, target: Rect2, alpha: float) -> void:
	canvas.draw_rect(target, Color(0.015, 0.018, 0.04, alpha))
	for idx in range(72):
		var x: float = target.position.x + fposmod(float(idx * 71 + current_stage * 29), max(1.0, target.size.x))
		var y: float = target.position.y + fposmod(float(idx * 43 + current_stage * 17), max(1.0, target.size.y))
		var twinkle: float = 0.45 + 0.35 * sin(elapsed_sec * 3.0 + float(idx) * 0.61)
		canvas.draw_circle(Vector2(x, y), 1.0 + float(idx % 3) * 0.35, Color(0.55, 0.76, 1.0, alpha * twinkle))
	var center := target.get_center()
	canvas.draw_circle(center, min(target.size.x, target.size.y) * 0.28, Color(0.09, 0.12, 0.22, alpha * 0.45))
	canvas.draw_arc(center, min(target.size.x, target.size.y) * 0.31, -0.25, PI + 0.22, 96, Color(0.1, 0.8, 0.9, alpha * 0.42), 2.0)


func _draw_texture_cover(canvas: CanvasItem, texture: Texture2D, target: Rect2, modulate: Color) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target.size.x <= 0.0 or target.size.y <= 0.0:
		return
	var scale: float = max(target.size.x / texture_size.x, target.size.y / texture_size.y)
	var source_size: Vector2 = target.size / max(0.001, scale)
	var source_pos: Vector2 = (texture_size - source_size) * 0.5
	canvas.draw_texture_rect_region(texture, target, Rect2(source_pos, source_size), modulate, false, true)


func _draw_texture_fit(canvas: CanvasItem, texture: Texture2D, target: Rect2, modulate: Color) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale: float = min(target.size.x / texture_size.x, target.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale
	var draw_rect := Rect2(target.get_center() - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect(texture, draw_rect, false, modulate)


func _draw_text_center(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(center.x - text_size.x * 0.5, center.y - text_size.y * 0.5 + font.get_ascent(font_size))
	canvas.draw_string(font, baseline + Vector2(3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, max(0.0, color.a - 0.32)))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _load_stage_background(stage: int) -> Texture2D:
	var path: String = str(STAGE_BACKGROUND_PATHS.get(stage, ""))
	if path == "":
		return null
	return ProjectResourceLoader.load_texture(path)


func _finish(registry: Object) -> void:
	if not active:
		return
	active = false
	elapsed_sec = 0.0
	_sync_serve_input(registry)


func _sync_serve_input(registry: Object) -> void:
	var serve_flow: Object = _get_instance(registry, "serve_flow_controller")
	if serve_flow != null and serve_flow.has_method("sync_current_input_state"):
		serve_flow.sync_current_input_state()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
