extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const CONTENT_TOP := 118.0
const CONTENT_BOTTOM := 678.0
const CONTENT_SCALE := (CONTENT_BOTTOM - CONTENT_TOP) / GAME_SIZE.y
const CONTENT_OFFSET := Vector2(
	(GAME_SIZE.x - GAME_SIZE.x * CONTENT_SCALE) * 0.5,
	CONTENT_TOP
)
const TITLE_KEY := "victory_highlight_title"
const SKIP_HINT_KEY := "victory_highlight_skip_hint"
const BALL_COLOR := Color(1.0, 0.93, 0.68, 1.0)
const SILHOUETTE_COLOR := Color(0.34, 0.28, 0.24, 1.0)
const SKIP_HOLD_GAUGE_RECT := Rect2(270.0, GAME_SIZE.y - 27.0, 220.0, 7.0)


func draw(canvas: CanvasItem, playback: Object) -> void:
	if canvas == null or playback == null:
		return
	draw_background(canvas, playback)
	draw_content(canvas, playback)
	draw_overlay(canvas, playback)


func draw_background(canvas: CanvasItem, _playback: Object) -> void:
	if canvas == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), TraditionalChrome.LACQUER_BLACK, true)


func draw_content(canvas: CanvasItem, playback: Object) -> void:
	if canvas == null or playback == null:
		return
	var clip: Dictionary = playback.get_current_clip()
	if clip.is_empty():
		return
	var alpha: float = clampf(float(playback.get_content_alpha()), 0.0, 1.0)
	var local_time: float = maxf(0.0, float(playback.get_clip_local_time()))
	var previous_clip: Dictionary = playback.get_previous_clip()
	if not previous_clip.is_empty():
		_draw_clip_content(
			canvas,
			previous_clip,
			maxf(0.0, float(playback.get_previous_clip_time())),
			1.0 - alpha
		)
	_draw_clip_content(canvas, clip, local_time, alpha)


func draw_overlay(canvas: CanvasItem, playback: Object) -> void:
	if canvas == null or playback == null:
		return
	var clip: Dictionary = playback.get_current_clip()
	if clip.is_empty():
		return
	var alpha: float = clampf(float(playback.get_content_alpha()), 0.0, 1.0)
	var previous_clip: Dictionary = playback.get_previous_clip()
	if not previous_clip.is_empty():
		draw_state_clip_overlay_for_replay(
			canvas,
			previous_clip,
			1.0 - alpha,
			int(playback.get_previous_clip_index()),
			int(playback.get_clip_count())
		)
	draw_state_clip_overlay_for_replay(
		canvas,
		clip,
		alpha,
		int(playback.get_current_clip_index()),
		int(playback.get_clip_count())
	)
	_draw_skip_hold_progress(canvas, playback)


func draw_clip_content_for_replay(
	canvas: CanvasItem,
	clip: Dictionary,
	local_time: float,
	alpha: float
) -> void:
	_draw_clip_content(canvas, clip, local_time, alpha)


func draw_state_clip_overlay_for_replay(
	canvas: CanvasItem,
	clip: Dictionary,
	alpha: float,
	clip_index: int,
	clip_count: int
) -> void:
	_draw_clip_overlay(canvas, clip, alpha, clip_index, clip_count)


func draw_frame_clip_overlay_for_replay(
	canvas: CanvasItem,
	clip: Dictionary,
	alpha: float,
	title_alpha: float,
	subtitle_alpha: float,
	clip_index: int,
	clip_count: int
) -> void:
	if alpha <= 0.001:
		return
	_draw_title(canvas, alpha * clampf(title_alpha, 0.0, 1.0))
	_draw_subtitle(canvas, clip, alpha * clampf(subtitle_alpha, 0.0, 1.0))
	_draw_persistent_copy(canvas, alpha, clip_index, clip_count)


func draw_skip_hold_progress_for_replay(canvas: CanvasItem, playback: Object) -> void:
	_draw_skip_hold_progress(canvas, playback)


func _draw_clip(
	canvas: CanvasItem,
	playback: Object,
	clip: Dictionary,
	local_time: float,
	alpha: float,
	clip_index: int
) -> void:
	if alpha <= 0.001:
		return
	_draw_clip_content(canvas, clip, local_time, alpha)
	_draw_clip_overlay(canvas, clip, alpha, clip_index, int(playback.get_clip_count()))


func _draw_clip_content(
	canvas: CanvasItem,
	clip: Dictionary,
	local_time: float,
	alpha: float
) -> void:
	if alpha <= 0.001:
		return
	# The entire recorded 760x750 coordinate space shares one draw transform.
	# Do not clamp actors or remap primitives independently: that would change
	# the rally's relative geometry and turn the replay into a different shot.
	# The production host clips this whole layer to CONTENT_TOP..CONTENT_BOTTOM,
	# including out-of-bounds goal samples, rather than clipping primitives.
	_apply_content_transform(canvas)
	_draw_trail(canvas, clip, local_time, alpha)
	var sample: Dictionary = _sample_at_time(clip, local_time)
	if not sample.is_empty():
		_draw_actor(canvas, sample, "boss", alpha)
		_draw_actor(canvas, sample, "player", alpha)
		_draw_ball(canvas, sample, alpha)
	_draw_event_marks(canvas, clip, local_time, alpha)
	_clear_content_transform(canvas)


func _draw_clip_overlay(
	canvas: CanvasItem,
	clip: Dictionary,
	alpha: float,
	clip_index: int,
	clip_count: int
) -> void:
	if alpha <= 0.001:
		return
	_draw_frame(canvas, alpha)
	_draw_copy(canvas, clip, alpha, clip_index, clip_count)


func _draw_frame(canvas: CanvasItem, alpha: float) -> void:
	var frame := Rect2(18.0, 18.0, GAME_SIZE.x - 36.0, GAME_SIZE.y - 36.0)
	canvas.draw_rect(frame, _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.58 * alpha), false, 2.0)
	canvas.draw_rect(frame.grow(-7.0), _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.18 * alpha), false, 1.0)
	canvas.draw_line(Vector2(34.0, CONTENT_TOP), Vector2(GAME_SIZE.x - 34.0, CONTENT_TOP), _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.26 * alpha), 1.0)
	canvas.draw_line(Vector2(34.0, CONTENT_BOTTOM), Vector2(GAME_SIZE.x - 34.0, CONTENT_BOTTOM), _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.22 * alpha), 1.0)


func _draw_trail(canvas: CanvasItem, clip: Dictionary, local_time: float, alpha: float) -> void:
	var samples: Array = clip.get("samples", [])
	if samples.size() < 2:
		return
	var previous := Vector2.ZERO
	var has_previous := false
	var first_time: float = maxf(0.0, local_time - 0.42)
	for value in samples:
		if not (value is Dictionary):
			continue
		var sample: Dictionary = value
		var sample_time: float = float(sample.get("t_sec", 0.0))
		if sample_time < first_time:
			continue
		if sample_time > local_time + 0.0001:
			break
		var point: Vector2 = sample.get("ball_pos", Vector2.ZERO)
		if has_previous:
			var age_alpha: float = clampf(1.0 - (local_time - sample_time) / 0.42, 0.0, 1.0)
			canvas.draw_line(previous, point, _with_alpha(TraditionalChrome.SEAL_RED, 0.82 * age_alpha * alpha), 4.0)
		previous = point
		has_previous = true


func _draw_actor(canvas: CanvasItem, sample: Dictionary, prefix: String, alpha: float) -> void:
	var dest_value: Variant = sample.get("%s_dest" % prefix, Rect2())
	if not (dest_value is Rect2):
		return
	var dest: Rect2 = dest_value
	if dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	var texture_value: Variant = sample.get("%s_texture" % prefix, null)
	var modulate_value: Variant = sample.get("%s_modulate" % prefix, Color.WHITE)
	var modulate: Color = modulate_value if modulate_value is Color else Color.WHITE
	modulate.a *= alpha
	if texture_value is Texture2D:
		var texture: Texture2D = texture_value
		var src_value: Variant = sample.get("%s_src" % prefix, Rect2())
		var src: Rect2 = src_value if src_value is Rect2 else Rect2(Vector2.ZERO, texture.get_size())
		if src.size.x <= 0.0 or src.size.y <= 0.0:
			src = Rect2(Vector2.ZERO, texture.get_size())
		if bool(sample.get("%s_flip" % prefix, false)):
			var center_x: float = dest.get_center().x
			canvas.draw_set_transform(
				CONTENT_OFFSET + Vector2(center_x * 2.0 * CONTENT_SCALE, 0.0),
				0.0,
				Vector2(-CONTENT_SCALE, CONTENT_SCALE)
			)
			canvas.draw_texture_rect_region(texture, dest, src, modulate)
			_apply_content_transform(canvas)
		else:
			canvas.draw_texture_rect_region(texture, dest, src, modulate)
		return
	var silhouette := dest.grow(-minf(dest.size.x, dest.size.y) * 0.18)
	canvas.draw_rect(silhouette, _with_alpha(SILHOUETTE_COLOR, 0.78 * alpha), true)
	canvas.draw_rect(silhouette, _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.38 * alpha), false, 2.0)


func _draw_ball(canvas: CanvasItem, sample: Dictionary, alpha: float) -> void:
	var ball_pos_value: Variant = sample.get("ball_pos", Vector2.ZERO)
	if not (ball_pos_value is Vector2):
		return
	var ball_pos: Vector2 = ball_pos_value
	var radius: float = clampf(float(sample.get("ball_radius", 18.0)), 6.0, 34.0)
	canvas.draw_circle(ball_pos, radius * 1.55, _with_alpha(TraditionalChrome.SEAL_RED, 0.18 * alpha))
	canvas.draw_circle(ball_pos, radius, _with_alpha(BALL_COLOR, alpha))
	canvas.draw_arc(ball_pos, radius + 3.0, 0.0, TAU, 28, _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.84 * alpha), 2.0)


func _draw_event_marks(canvas: CanvasItem, clip: Dictionary, local_time: float, alpha: float) -> void:
	var events: Array = clip.get("events", [])
	for value in events:
		if not (value is Dictionary):
			continue
		var event: Dictionary = value
		var age: float = local_time - float(event.get("t_sec", 0.0))
		if age < 0.0 or age > 0.18:
			continue
		var pos_value: Variant = event.get("pos", Vector2.ZERO)
		if not (pos_value is Vector2):
			continue
		var pos: Vector2 = pos_value
		var pulse: float = 1.0 - age / 0.18
		var radius: float = lerpf(42.0, 12.0, pulse)
		var kind: int = int(event.get("kind", 0))
		var color: Color = TraditionalChrome.SEAL_RED if kind == 4 else TraditionalChrome.BRASS_LIGHT
		canvas.draw_arc(pos, radius, 0.0, TAU, 24, _with_alpha(color, pulse * alpha), 3.0)


func _draw_copy(
	canvas: CanvasItem,
	clip: Dictionary,
	alpha: float,
	clip_index: int,
	clip_count: int
) -> void:
	_draw_title(canvas, alpha)
	_draw_subtitle(canvas, clip, alpha)
	_draw_persistent_copy(canvas, alpha, clip_index, clip_count)


func _draw_title(canvas: CanvasItem, alpha: float) -> void:
	if alpha <= 0.001:
		return
	var font: Font = ThemeDB.fallback_font
	var title := LanguageSettings.translate(TITLE_KEY, "승리의 순간")
	_draw_centered_text(canvas, font, title, 54.0, 28, _with_alpha(TraditionalChrome.BRASS_LIGHT, alpha))


func _draw_subtitle(canvas: CanvasItem, clip: Dictionary, alpha: float) -> void:
	if alpha <= 0.001:
		return
	var font: Font = ThemeDB.fallback_font
	var label_key: String = str(clip.get("label_key", "victory_highlight_finisher"))
	var label := LanguageSettings.translate(label_key, "결정타")
	_draw_centered_text(canvas, font, label, 96.0, 18, _with_alpha(Color.WHITE, 0.90 * alpha))


func _draw_persistent_copy(
	canvas: CanvasItem,
	alpha: float,
	clip_index: int,
	clip_count: int
) -> void:
	if alpha <= 0.001:
		return
	var font: Font = ThemeDB.fallback_font
	clip_count = maxi(1, clip_count)
	var dot_y := GAME_SIZE.y - 94.0
	var dot_start := GAME_SIZE.x * 0.5 - float(clip_count - 1) * 10.0
	for index in range(clip_count):
		var dot_color := TraditionalChrome.SEAL_RED if index == clip_index else TraditionalChrome.BRASS_LIGHT
		var dot_alpha := 0.95 if index == clip_index else 0.34
		canvas.draw_circle(Vector2(dot_start + float(index) * 20.0, dot_y), 4.0, _with_alpha(dot_color, dot_alpha * alpha))
	var hint := LanguageSettings.translate(SKIP_HINT_KEY, "길게 눌러 건너뛰기")
	_draw_centered_text(canvas, font, hint, GAME_SIZE.y - 42.0, 14, _with_alpha(Color.WHITE, 0.64 * alpha))


func _draw_skip_hold_progress(canvas: CanvasItem, playback: Object) -> void:
	if playback == null or not playback.has_method("get_skip_hold_progress"):
		return
	var progress: float = clampf(float(playback.get_skip_hold_progress()), 0.0, 1.0)
	if progress <= 0.001:
		return
	var fill_rect := get_skip_hold_fill_rect_for_tests(progress)
	canvas.draw_rect(SKIP_HOLD_GAUGE_RECT.grow(3.0), _with_alpha(TraditionalChrome.LACQUER_BLACK, 0.72), true)
	canvas.draw_rect(fill_rect.grow(2.0), _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.22), true)
	canvas.draw_rect(fill_rect, _with_alpha(TraditionalChrome.BRASS_LIGHT, 0.92), true)


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, baseline_y: float, size: int, color: Color) -> void:
	canvas.draw_string(font, Vector2(34.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, GAME_SIZE.x - 68.0, size, color)


func get_content_transform_for_tests() -> Dictionary:
	return {
		"scale": CONTENT_SCALE,
		"offset": CONTENT_OFFSET,
		"source_rect": Rect2(Vector2.ZERO, GAME_SIZE),
		"content_rect": Rect2(CONTENT_OFFSET, GAME_SIZE * CONTENT_SCALE),
	}


func get_skip_hold_gauge_rect_for_tests() -> Rect2:
	return SKIP_HOLD_GAUGE_RECT


func get_skip_hold_fill_rect_for_tests(progress: float) -> Rect2:
	return Rect2(
		SKIP_HOLD_GAUGE_RECT.position,
		Vector2(SKIP_HOLD_GAUGE_RECT.size.x * clampf(progress, 0.0, 1.0), SKIP_HOLD_GAUGE_RECT.size.y)
	)


func transform_content_point_for_tests(point: Vector2) -> Vector2:
	return _transform_content_point(point)


func transform_content_rect_for_tests(rect: Rect2) -> Rect2:
	return Rect2(_transform_content_point(rect.position), rect.size * CONTENT_SCALE)


func _apply_content_transform(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(CONTENT_OFFSET, 0.0, Vector2(CONTENT_SCALE, CONTENT_SCALE))


func _clear_content_transform(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _transform_content_point(point: Vector2) -> Vector2:
	return CONTENT_OFFSET + point * CONTENT_SCALE


func _sample_at_time(clip: Dictionary, local_time: float) -> Dictionary:
	var samples: Array = clip.get("samples", [])
	if samples.is_empty():
		return {}
	var previous: Dictionary = samples[0] if samples[0] is Dictionary else {}
	for index in range(1, samples.size()):
		if not (samples[index] is Dictionary):
			continue
		var next_sample: Dictionary = samples[index]
		var next_time: float = float(next_sample.get("t_sec", 0.0))
		if next_time >= local_time:
			var previous_time: float = float(previous.get("t_sec", 0.0))
			var span: float = maxf(0.0001, next_time - previous_time)
			var weight: float = clampf((local_time - previous_time) / span, 0.0, 1.0)
			var blended: Dictionary = previous.duplicate()
			blended["ball_pos"] = _lerp_vector2(previous.get("ball_pos", Vector2.ZERO), next_sample.get("ball_pos", Vector2.ZERO), weight)
			blended["ball_radius"] = lerpf(float(previous.get("ball_radius", 18.0)), float(next_sample.get("ball_radius", 18.0)), weight)
			return blended
		previous = next_sample
	return previous


func _lerp_vector2(from_value: Variant, to_value: Variant, weight: float) -> Vector2:
	var from_vec: Vector2 = from_value if from_value is Vector2 else Vector2.ZERO
	var to_vec: Vector2 = to_value if to_value is Vector2 else from_vec
	return from_vec.lerp(to_vec, weight)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
