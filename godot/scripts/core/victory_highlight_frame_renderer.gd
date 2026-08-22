extends RefCounted

const VictoryHighlightFrameCaptureState := preload("res://scripts/core/victory_highlight_frame_capture_state.gd")

const CAPTURE_SIZE := VictoryHighlightFrameCaptureState.CAPTURE_SIZE
const CAPTURE_BYTE_COUNT := VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT
const FRAME_DEADLINE_USEC := 13_888
const FRAME_INDEX_EPSILON := 0.000001
const GAME_RECT := Rect2(Vector2.ZERO, Vector2(760.0, 750.0))
const TOP_COPY_SCRIM_RECT := Rect2(22.0, 22.0, 716.0, 88.0)
const BOTTOM_COPY_SCRIM_RECT := Rect2(132.0, 628.0, 496.0, 102.0)
const COPY_SCRIM_COLOR := Color(0.012, 0.008, 0.018, 0.46)
const TITLE_HOLD_SEC := 0.80
const TITLE_FADE_SEC := 0.25
const SUBTITLE_HOLD_SEC := 0.60
const SUBTITLE_FADE_SEC := 0.20

var _base_renderer: Object = null
var _image: Image = null
var _texture: ImageTexture = null
var _swap_material: ShaderMaterial = null
var _content_material: Material = null
var _prepared_clip_id := -1
var _prepared_frame_index := -1
var _upload_count := 0
var _upload_worst_usec := 0
var _upload_deadline_miss_count := 0
var _display_request_count := 0
var _unit_frame_advance_count := 0
var _repeated_frame_count := 0
var _skipped_frame_count := 0
var _non_forward_frame_count := 0
var _action_display_count := 0
var _goal_hold_display_count := 0
var _goal_hold_advance_count := 0


func configure_base_renderer(renderer: Object) -> void:
	_base_renderer = renderer


func prewarm_assets() -> void:
	if _texture != null:
		return
	var blank := PackedByteArray()
	blank.resize(CAPTURE_BYTE_COUNT)
	blank.fill(0)
	_image = Image.create_from_data(
		CAPTURE_SIZE.x,
		CAPTURE_SIZE.y,
		false,
		Image.FORMAT_RGBA8,
		blank
	)
	_texture = ImageTexture.create_from_image(_image)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); COLOR = vec4(c.b, c.g, c.r, c.a); }"
	_swap_material = ShaderMaterial.new()
	_swap_material.shader = shader


func configure_for_clips(clips: Array[Dictionary]) -> bool:
	prewarm_assets()
	if clips.is_empty():
		return false
	var frame_clip: Dictionary = {}
	for clip in clips:
		if _clip_has_frames(clip):
			frame_clip = clip
			break
	if frame_clip.is_empty():
		return false
	var format := int(frame_clip.get("frame_data_format", RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM))
	_content_material = _swap_material if format in [
		RenderingDevice.DATA_FORMAT_B8G8R8A8_UNORM,
		RenderingDevice.DATA_FORMAT_B8G8R8A8_SRGB,
	] else null
	_prepared_clip_id = -1
	_prepared_frame_index = -1
	_upload_count = 0
	_upload_worst_usec = 0
	_upload_deadline_miss_count = 0
	_display_request_count = 0
	_unit_frame_advance_count = 0
	_repeated_frame_count = 0
	_skipped_frame_count = 0
	_non_forward_frame_count = 0
	_action_display_count = 0
	_goal_hold_display_count = 0
	_goal_hold_advance_count = 0
	return true


func prepare_playback_frame(playback: Object) -> bool:
	if playback == null or _texture == null or _image == null:
		return false
	var clip: Dictionary = playback.get_current_clip()
	var frames: Array = clip.get("frame_frames", [])
	if frames.is_empty():
		# Mixed playback keeps the frame renderer installed while this clip uses
		# the shadow-state lane. The dedicated state bridge draws it in-band.
		return true
	var fps := maxf(1.0, float(clip.get("frame_fps", VictoryHighlightFrameCaptureState.CAPTURE_FPS)))
	var local_time_sec := float(playback.get_clip_local_time())
	var frame_index := clampi(
		int(floor(local_time_sec * fps + FRAME_INDEX_EPSILON)),
		0,
		frames.size() - 1
	)
	var goal_t_sec := float(clip.get("goal_t_sec", INF))
	var duration_sec := float(clip.get("duration_sec", goal_t_sec))
	var in_goal_hold := (
		is_finite(goal_t_sec)
		and duration_sec > goal_t_sec + FRAME_INDEX_EPSILON
		and local_time_sec + FRAME_INDEX_EPSILON >= goal_t_sec
	)
	var clip_id := int(clip.get("id", -1))
	_display_request_count += 1
	if in_goal_hold:
		_goal_hold_display_count += 1
	else:
		_action_display_count += 1
	if clip_id == _prepared_clip_id and frame_index == _prepared_frame_index:
		if not in_goal_hold:
			_repeated_frame_count += 1
		return true
	if clip_id != _prepared_clip_id:
		if frame_index > 0:
			if in_goal_hold:
				_goal_hold_advance_count += frame_index
			else:
				_skipped_frame_count += frame_index
	elif _prepared_frame_index >= 0:
		var frame_advance := frame_index - _prepared_frame_index
		if in_goal_hold:
			_goal_hold_advance_count += absi(frame_advance)
		elif frame_advance == 1:
			_unit_frame_advance_count += 1
		elif frame_advance > 1:
			_skipped_frame_count += frame_advance - 1
		else:
			_non_forward_frame_count += 1
	var bytes_value: Variant = frames[frame_index]
	if not (bytes_value is PackedByteArray):
		return false
	var bytes: PackedByteArray = bytes_value
	if bytes.size() != CAPTURE_BYTE_COUNT:
		return false
	var upload_start_usec := Time.get_ticks_usec()
	_image.set_data(CAPTURE_SIZE.x, CAPTURE_SIZE.y, false, Image.FORMAT_RGBA8, bytes)
	_texture.update(_image)
	var upload_usec := int(Time.get_ticks_usec() - upload_start_usec)
	_upload_count += 1
	_upload_worst_usec = maxi(_upload_worst_usec, upload_usec)
	if upload_usec > FRAME_DEADLINE_USEC:
		_upload_deadline_miss_count += 1
	_prepared_clip_id = clip_id
	_prepared_frame_index = frame_index
	return true


func get_content_material() -> Material:
	return _content_material


func get_upload_metrics() -> Dictionary:
	return {
		"upload_count": _upload_count,
		"upload_worst_usec": _upload_worst_usec,
		"upload_deadline_miss_count": _upload_deadline_miss_count,
		"display_request_count": _display_request_count,
		"unit_frame_advance_count": _unit_frame_advance_count,
		"repeated_frame_count": _repeated_frame_count,
		"skipped_frame_count": _skipped_frame_count,
		"non_forward_frame_count": _non_forward_frame_count,
		"action_display_count": _action_display_count,
		"goal_hold_display_count": _goal_hold_display_count,
		"goal_hold_advance_count": _goal_hold_advance_count,
	}


func draw(canvas: CanvasItem, playback: Object) -> void:
	draw_background(canvas, playback)
	draw_state_content(canvas, playback)
	draw_frame_content(canvas, playback)
	draw_overlay(canvas, playback)


func draw_background(canvas: CanvasItem, playback: Object) -> void:
	if _base_renderer != null and _base_renderer.has_method("draw_background"):
		_base_renderer.draw_background(canvas, playback)


func draw_content(canvas: CanvasItem, playback: Object) -> void:
	draw_state_content(canvas, playback)
	draw_frame_content(canvas, playback)


func draw_frame_content(canvas: CanvasItem, playback: Object) -> void:
	if canvas == null or playback == null or _texture == null:
		return
	var clip: Dictionary = playback.get_current_clip()
	var alpha := clampf(float(playback.get_content_alpha()), 0.0, 1.0)
	if _clip_has_frames(clip):
		canvas.draw_texture_rect(_texture, GAME_RECT, false, Color(1.0, 1.0, 1.0, alpha))
		return
	var previous_clip: Dictionary = playback.get_previous_clip()
	if _clip_has_frames(previous_clip):
		canvas.draw_texture_rect(_texture, GAME_RECT, false, Color(1.0, 1.0, 1.0, 1.0 - alpha))


func draw_state_content(canvas: CanvasItem, playback: Object) -> void:
	if (
		canvas == null
		or playback == null
		or _base_renderer == null
		or not _base_renderer.has_method("draw_clip_content_for_replay")
	):
		return
	var alpha := clampf(float(playback.get_content_alpha()), 0.0, 1.0)
	var previous_clip: Dictionary = playback.get_previous_clip()
	if not previous_clip.is_empty() and not _clip_has_frames(previous_clip):
		_base_renderer.draw_clip_content_for_replay(
			canvas,
			previous_clip,
			maxf(0.0, float(playback.get_previous_clip_time())),
			1.0 - alpha
		)
	var clip: Dictionary = playback.get_current_clip()
	if not clip.is_empty() and not _clip_has_frames(clip):
		_base_renderer.draw_clip_content_for_replay(
			canvas,
			clip,
			maxf(0.0, float(playback.get_clip_local_time())),
			alpha
		)


func draw_overlay(canvas: CanvasItem, playback: Object) -> void:
	if canvas == null or playback == null or _base_renderer == null:
		return
	var alpha := clampf(float(playback.get_content_alpha()), 0.0, 1.0)
	var current_clip: Dictionary = playback.get_current_clip()
	var previous_clip: Dictionary = playback.get_previous_clip()
	var current_alpha := alpha
	var previous_alpha := 1.0 - alpha if not previous_clip.is_empty() else 0.0
	var active_elapsed_sec := (
		maxf(0.0, float(playback.get_active_elapsed_sec()))
		if playback.has_method("get_active_elapsed_sec")
		else 0.0
	)
	var transition_elapsed_sec := (
		maxf(0.0, float(playback.get_clip_transition_elapsed_sec()))
		if playback.has_method("get_clip_transition_elapsed_sec")
		else 0.0
	)
	var title_alpha := get_title_alpha_for_tests(active_elapsed_sec)
	var current_subtitle_alpha := get_subtitle_alpha_for_tests(transition_elapsed_sec)
	var previous_subtitle_alpha := get_subtitle_alpha_for_tests(
		maxf(0.0, float(playback.get_previous_clip_time()))
	)
	var top_scrim_alpha := 0.0
	var bottom_scrim_alpha := 0.0
	if _clip_has_frames(previous_clip):
		top_scrim_alpha += previous_alpha * maxf(title_alpha, previous_subtitle_alpha)
		bottom_scrim_alpha += previous_alpha
	if _clip_has_frames(current_clip):
		top_scrim_alpha += current_alpha * maxf(title_alpha, current_subtitle_alpha)
		bottom_scrim_alpha += current_alpha
	if top_scrim_alpha > 0.001:
		var top_scrim_color := COPY_SCRIM_COLOR
		top_scrim_color.a *= clampf(top_scrim_alpha, 0.0, 1.0)
		canvas.draw_rect(TOP_COPY_SCRIM_RECT, top_scrim_color, true)
	if bottom_scrim_alpha > 0.001:
		var bottom_scrim_color := COPY_SCRIM_COLOR
		bottom_scrim_color.a *= clampf(bottom_scrim_alpha, 0.0, 1.0)
		canvas.draw_rect(BOTTOM_COPY_SCRIM_RECT, bottom_scrim_color, true)
	_draw_clip_overlay(
		canvas,
		playback,
		previous_clip,
		previous_alpha,
		title_alpha,
		previous_subtitle_alpha,
		int(playback.get_previous_clip_index())
	)
	_draw_clip_overlay(
		canvas,
		playback,
		current_clip,
		current_alpha,
		title_alpha,
		current_subtitle_alpha,
		int(playback.get_current_clip_index())
	)
	if _base_renderer.has_method("draw_skip_hold_progress_for_replay"):
		_base_renderer.draw_skip_hold_progress_for_replay(canvas, playback)


func get_title_alpha_for_tests(elapsed_sec: float) -> float:
	return _hold_then_fade_alpha(elapsed_sec, TITLE_HOLD_SEC, TITLE_FADE_SEC)


func get_subtitle_alpha_for_tests(elapsed_sec: float) -> float:
	return _hold_then_fade_alpha(elapsed_sec, SUBTITLE_HOLD_SEC, SUBTITLE_FADE_SEC)


func get_frame_content_rect_for_tests() -> Rect2:
	return GAME_RECT


func get_overlay_scrim_rects_for_tests() -> Array[Rect2]:
	return [TOP_COPY_SCRIM_RECT, BOTTOM_COPY_SCRIM_RECT]


func _draw_clip_overlay(
	canvas: CanvasItem,
	playback: Object,
	clip: Dictionary,
	alpha: float,
	title_alpha: float,
	subtitle_alpha: float,
	clip_index: int
) -> void:
	if clip.is_empty() or alpha <= 0.001:
		return
	if _clip_has_frames(clip):
		if _base_renderer.has_method("draw_frame_clip_overlay_for_replay"):
			_base_renderer.draw_frame_clip_overlay_for_replay(
				canvas,
				clip,
				alpha,
				title_alpha,
				subtitle_alpha,
				clip_index,
				int(playback.get_clip_count())
			)
		return
	if _base_renderer.has_method("draw_state_clip_overlay_for_replay"):
		_base_renderer.draw_state_clip_overlay_for_replay(
			canvas,
			clip,
			alpha,
			clip_index,
			int(playback.get_clip_count())
		)


func _hold_then_fade_alpha(elapsed_sec: float, hold_sec: float, fade_sec: float) -> float:
	var elapsed := maxf(0.0, elapsed_sec)
	if elapsed <= hold_sec:
		return 1.0
	if fade_sec <= 0.0 or elapsed >= hold_sec + fade_sec:
		return 0.0
	return 1.0 - (elapsed - hold_sec) / fade_sec


func _clip_has_frames(clip: Dictionary) -> bool:
	return not clip.is_empty() and not (clip.get("frame_frames", []) as Array).is_empty()


func reset() -> void:
	_prepared_clip_id = -1
	_prepared_frame_index = -1
	_content_material = null
