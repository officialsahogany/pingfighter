extends Control

const GAME_SIZE := Vector2(760.0, 750.0)
const FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")


class IntroDrawBridge:
	extends Control

	var presentation_host: Object = null

	func _draw() -> void:
		if presentation_host != null:
			presentation_host.call("draw_intro_overlay", self)


var _elapsed := 0.0
var _fade_alpha := 0.0
var _video_finished := false

var _screen_black: ColorRect = null
var _playfield_clip: Control = null
var _video_player: VideoStreamPlayer = null
var _draw_bridge: IntroDrawBridge = null


func _init() -> void:
	name = "Stage7AkamuPrebattleOverlayHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	top_level = true
	z_as_relative = false
	z_index = 3120
	visible = false
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	_build_nodes()


func begin_video(stream: VideoStream, muted: bool = false) -> bool:
	_build_nodes()
	if _video_player == null or stream == null:
		return false
	_elapsed = 0.0
	_fade_alpha = 0.0
	_video_finished = false
	visible = true
	_screen_black.visible = true
	_playfield_clip.visible = true
	_video_player.visible = true
	_video_player.stream = stream
	_video_player.volume_db = -80.0 if muted else 0.0
	_video_player.paused = false
	_video_player.play()
	_queue_visual_redraw()
	return true


func sync_video(elapsed: float, fade_alpha: float, muted: bool) -> void:
	_elapsed = maxf(0.0, elapsed)
	_fade_alpha = clampf(fade_alpha, 0.0, 1.0)
	if _video_player != null:
		var audible_linear := maxf(0.0001, 1.0 - _fade_alpha)
		_video_player.volume_db = -80.0 if muted else linear_to_db(audible_linear)
	_queue_visual_redraw()


func sync_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	_build_nodes()
	position = Vector2.ZERO
	size = view_size
	_screen_black.position = Vector2.ZERO
	_screen_black.size = view_size
	_playfield_clip.position = game_offset
	_playfield_clip.size = game_size
	_video_player.position = Vector2.ZERO
	_video_player.size = game_size
	_draw_bridge.position = Vector2.ZERO
	_draw_bridge.size = game_size


func is_video_finished() -> bool:
	return _video_finished


func is_video_playing() -> bool:
	return _video_player != null and _video_player.is_playing()


func stop_video() -> void:
	if _video_player != null:
		_video_player.stop()
		_video_player.paused = false


func set_inactive() -> void:
	stop_video()
	visible = false
	if _screen_black != null:
		_screen_black.visible = false
	if _playfield_clip != null:
		_playfield_clip.visible = false
	if _video_player != null:
		_video_player.visible = false


func tear_down(free_self: bool = false) -> void:
	set_inactive()
	if _video_player != null:
		_video_player.stream = null
	if free_self and is_inside_tree():
		queue_free()


func get_clip_snapshot() -> Dictionary:
	return {
		"host_visible": visible,
		"host_process_enabled": is_processing(),
		"clip_position": _playfield_clip.position if _playfield_clip != null else Vector2.ZERO,
		"clip_size": _playfield_clip.size if _playfield_clip != null else Vector2.ZERO,
		"clip_contents": _playfield_clip.clip_contents if _playfield_clip != null else false,
		"clip_children": _playfield_clip.clip_children if _playfield_clip != null else CanvasItem.CLIP_CHILDREN_DISABLED,
		"video_position": _video_player.position if _video_player != null else Vector2.ZERO,
		"video_size": _video_player.size if _video_player != null else Vector2.ZERO,
		"video_parent_is_clip": _video_player != null and _video_player.get_parent() == _playfield_clip,
		"video_playing": _video_player.is_playing() if _video_player != null else false,
		"video_volume_db": _video_player.volume_db if _video_player != null else 0.0,
	}


func draw_intro_overlay(canvas: CanvasItem) -> void:
	if canvas == null or not visible:
		return
	var local_size := _draw_bridge.size if _draw_bridge != null else GAME_SIZE
	canvas.draw_rect(Rect2(Vector2.ZERO, local_size), Color(0.0, 0.0, 0.0, 90.0 / 255.0), true)
	var title_alpha := 1.0
	if _elapsed > 1.5:
		title_alpha = clampf((2.0 - _elapsed) / 0.5, 0.0, 1.0)
	if title_alpha > 0.0:
		var scale_factor := minf(local_size.x / GAME_SIZE.x, local_size.y / GAME_SIZE.y)
		_draw_centered_text(canvas, "STAGE 7", Vector2(local_size.x * 0.5, local_size.y * 0.20), maxi(18, int(round(34.0 * scale_factor))), Color(0.92, 0.96, 1.0, title_alpha))
		_draw_centered_text(canvas, "아카무 리고", Vector2(local_size.x * 0.5, local_size.y * 0.27), maxi(16, int(round(26.0 * scale_factor))), Color(1.0, 0.36, 0.30, title_alpha))
		_draw_centered_text(canvas, "SPACE / 클릭으로 건너뛰기", Vector2(local_size.x * 0.5, local_size.y * 0.94), maxi(10, int(round(14.0 * scale_factor))), Color(0.88, 0.90, 0.96, title_alpha * 0.78))
	if _fade_alpha > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, local_size), Color(0.0, 0.0, 0.0, _fade_alpha), true)


func _build_nodes() -> void:
	if _playfield_clip != null:
		return

	_screen_black = ColorRect.new()
	_screen_black.name = "Stage7IntroScreenBlack"
	_screen_black.color = Color.BLACK
	_screen_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_black.z_index = 0
	add_child(_screen_black)

	_playfield_clip = Control.new()
	_playfield_clip.name = "Stage7AkamuPlayfieldClip"
	_playfield_clip.position = Vector2.ZERO
	_playfield_clip.size = GAME_SIZE
	_playfield_clip.clip_contents = true
	_playfield_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_clip.z_index = 1
	add_child(_playfield_clip)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "Stage7AkamuIntroVideo"
	_video_player.position = Vector2.ZERO
	_video_player.size = GAME_SIZE
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_player.expand = true
	_video_player.loop = false
	_video_player.bus = "BGM"
	_video_player.z_index = 0
	_video_player.finished.connect(Callable(self, "_on_video_finished"))
	_playfield_clip.add_child(_video_player)

	_draw_bridge = IntroDrawBridge.new()
	_draw_bridge.name = "Stage7AkamuIntroDraw"
	_draw_bridge.position = Vector2.ZERO
	_draw_bridge.size = GAME_SIZE
	_draw_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_bridge.presentation_host = self
	_draw_bridge.z_index = 1
	_playfield_clip.add_child(_draw_bridge)

	_screen_black.visible = false
	_playfield_clip.visible = false
	_video_player.visible = false


func _draw_centered_text(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if FONT == null or text == "":
		return
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center - Vector2(text_size.x * 0.5, -text_size.y * 0.34)
	canvas.draw_string(FONT, baseline + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.82))
	canvas.draw_string_outline(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, maxi(2, int(round(float(font_size) * 0.12))), Color(0.0, 0.0, 0.0, color.a * 0.88))
	canvas.draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _queue_visual_redraw() -> void:
	if _draw_bridge != null:
		_draw_bridge.queue_redraw()


func _on_video_finished() -> void:
	_video_finished = true
