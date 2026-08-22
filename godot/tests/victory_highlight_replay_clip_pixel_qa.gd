extends SceneTree

const VictoryHighlightPlaybackState := preload("res://scripts/core/victory_highlight_playback_state.gd")
const VictoryHighlightRecorder := preload("res://scripts/core/victory_highlight_recorder.gd")
const VictoryHighlightRenderer := preload("res://scripts/core/victory_highlight_renderer.gd")

const VIEW_SIZE := Vector2i(1000, 820)
const GAME_SIZE := Vector2(760.0, 750.0)
const GAME_OFFSET := Vector2(170.0, 85.0)
const RENDER_SCALE := 0.82
const FIXTURE_GOAL_T_SEC := 0.20
const FLIPPED_PLAYER_SOURCE_DEST := Rect2(290.0, 612.0, 160.0, 160.0)

var _failures: Array[String] = []


class TestRegistry:
	extends RefCounted
	var values: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = values.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class LeakProbe:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(-140.0, -60.0, 1040.0, 870.0), Color(1.0, 0.0, 0.0, 1.0), true)


class PixelOwner:
	extends Node2D
	var victory_highlight_active := false


class SideBandProbe:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(8.0, 260.0, 32.0, 180.0), Color.WHITE, true)
		draw_rect(Rect2(720.0, 260.0, 32.0, 180.0), Color.WHITE, true)


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		printerr("victory_highlight_replay_clip_pixel_qa: headless execution is forbidden")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	_expect(GAME_OFFSET != Vector2.ZERO, "game_offset must be non-zero")
	_expect(not is_equal_approx(RENDER_SCALE, 1.0), "render_scale must be non-unit")
	var viewport := SubViewport.new()
	viewport.name = "VictoryHighlightPixelViewport"
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(viewport)

	var owner := PixelOwner.new()
	owner.name = "ReplayOwner"
	viewport.add_child(owner)
	var registry := TestRegistry.new()
	var playback := VictoryHighlightPlaybackState.new()
	registry.values = {
		"victory_highlight_renderer": VictoryHighlightRenderer.new(),
		"victory_highlight_recorder": VictoryHighlightRecorder.new(),
	}
	var clips: Array[Dictionary] = [_fixture_clip()]
	if not playback.start(owner, registry, clips, Callable()):
		_failures.append("playback host failed to start")
		_cleanup(viewport, playback)
		_finish_later()
		return
	playback.sync_host_layout({"game_offset": GAME_OFFSET, "render_scale": RENDER_SCALE})
	var clip_path := NodePath("VictoryHighlightReplayFxHost/VictoryHighlightPlayfieldClip")
	var clip: Control = owner.get_node_or_null(clip_path) as Control
	if clip == null:
		_failures.append("playback clip Control was not attached")
		_cleanup(viewport, playback)
		_finish_later()
		return
	var content_clip: Control = clip.get_node_or_null(NodePath("VictoryHighlightContentClip")) as Control
	_expect(content_clip != null, "shared replay content clip must be attached")
	if content_clip != null:
		_expect(content_clip.clip_contents, "shared replay content clip must enable clip_contents")
		_expect(content_clip.position == Vector2(0.0, 118.0), "shared replay content clip must begin below the copy band")
		_expect(content_clip.size == Vector2(760.0, 560.0), "shared replay content clip must end above the skip band")

	var probe := LeakProbe.new()
	probe.name = "LetterboxLeakProbe"
	probe.position = Vector2.ZERO
	probe.size = GAME_SIZE
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	probe.z_index = 100
	clip.add_child(probe)
	clip.clip_contents = false
	clip.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	probe.queue_redraw()
	await _wait_render_frames(4)
	var off_image: Image = _capture(viewport, "clip OFF control")

	clip.clip_contents = true
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	probe.queue_redraw()
	await _wait_render_frames(4)
	var on_image: Image = _capture(viewport, "clip ON")

	probe.free()
	var playback_debug: Dictionary = playback.get_host_debug_snapshot()
	var timeline_speed: float = maxf(0.001, float(playback_debug.get("timeline_speed", 1.0)))
	# Capture after the entry fade and at the fixture's goal sample even when
	# the presentation-length normalizer slows this single-clip fixture down.
	var capture_delta: float = maxf(0.20, (FIXTURE_GOAL_T_SEC + 0.001) / timeline_speed)
	playback.update(capture_delta)
	var draw_bridge: Control = clip.get_node_or_null(NodePath("VictoryHighlightDrawBridge")) as Control
	if draw_bridge != null:
		draw_bridge.queue_redraw()
	await _wait_render_frames(4)
	var replay_image: Image = _capture(viewport, "replay interior")
	var hold_down := InputEventMouseButton.new()
	hold_down.button_index = MOUSE_BUTTON_LEFT
	hold_down.pressed = true
	var hold_up := InputEventMouseButton.new()
	hold_up.button_index = MOUSE_BUTTON_LEFT
	hold_up.pressed = false
	_expect(playback.handle_input(hold_down), "state-lane pixel fixture must begin hold progress after the entry guard")
	playback.update(0.30)
	await _wait_render_frames(4)
	var hold_image: Image = _capture(viewport, "state-lane hold progress")
	_expect(playback.handle_input(hold_up), "state-lane hold release must be consumed")
	_expect(is_zero_approx(playback.get_skip_hold_progress()), "state-lane hold release must reset progress")
	playback.update(0.0)
	await _wait_render_frames(4)
	var released_image: Image = _capture(viewport, "state-lane released progress")
	var band_probe := SideBandProbe.new()
	band_probe.position = Vector2.ZERO
	band_probe.size = GAME_SIZE
	band_probe.z_index = 100
	band_probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(band_probe)
	band_probe.queue_redraw()
	await _wait_render_frames(4)
	var band_image: Image = _capture(viewport, "full-playfield side bands")
	if off_image != null and on_image != null and replay_image != null and hold_image != null and released_image != null and band_image != null:
		var game_rect := _screen_game_rect()
		var left_letterbox := Rect2i(0, 0, int(game_rect.position.x), VIEW_SIZE.y)
		var right_start := int(ceil(game_rect.end.x))
		var right_letterbox := Rect2i(right_start, 0, VIEW_SIZE.x - right_start, VIEW_SIZE.y)
		var off_left: int = _count_red(off_image, left_letterbox)
		var off_right: int = _count_red(off_image, right_letterbox)
		var on_left: int = _count_red(on_image, left_letterbox)
		var on_right: int = _count_red(on_image, right_letterbox)
		_expect(off_left > 0 and off_right > 0, "clip OFF control must visibly leak into both letterboxes")
		_expect(on_left == 0 and on_right == 0, "clip ON must remove every red leak pixel from both letterboxes")

		var interior := _game_sample_rect(90.0, 90.0, 580.0, 570.0)
		_expect(_count_lit(replay_image, interior) > 0, "actual replay interior must contain lit highlight pixels")
		var top_copy_band := _game_sample_rect(0.0, 0.0, 760.0, 102.0)
		var content_actor_band := _game_sample_rect(0.0, 102.0, 760.0, 594.0)
		var bottom_copy_band := _game_sample_rect(0.0, 696.0, 760.0, 54.0)
		_expect(_count_actor_probe(replay_image, content_actor_band) > 0, "cyan/green replay actor probes must render inside the shared content band")
		_expect(_count_actor_probe(replay_image, top_copy_band) == 0, "replay actors must not enter the title/subtitle copy band")
		_expect(_count_actor_probe(replay_image, bottom_copy_band) == 0, "replay actors must not enter the skip-hint copy band")
		var renderer := VictoryHighlightRenderer.new()
		var hold_gauge: Rect2 = renderer.get_skip_hold_gauge_rect_for_tests().grow(3.0)
		var hold_gauge_band := _game_sample_rect(hold_gauge.position.x, hold_gauge.position.y, hold_gauge.size.x, hold_gauge.size.y)
		var idle_brass: int = _count_hold_brass(replay_image, hold_gauge_band)
		var active_brass: int = _count_hold_brass(hold_image, hold_gauge_band)
		var released_brass: int = _count_hold_brass(released_image, hold_gauge_band)
		_expect(active_brass > idle_brass + 20, "state-lane hold progress must render a visible brass fill near the skip hint")
		_expect(released_brass < active_brass, "state-lane hold progress pixels must disappear after release")
		var flipped_player_rect: Rect2 = renderer.transform_content_rect_for_tests(FLIPPED_PLAYER_SOURCE_DEST)
		var half_width: float = flipped_player_rect.size.x * 0.5
		var flip_probe_height: float = minf(48.0, flipped_player_rect.size.y - 18.0)
		var flipped_left_band := _game_sample_rect(
			flipped_player_rect.position.x + 9.0,
			flipped_player_rect.position.y + 9.0,
			half_width - 18.0,
			flip_probe_height
		)
		var flipped_right_band := _game_sample_rect(
			flipped_player_rect.position.x + half_width + 9.0,
			flipped_player_rect.position.y + 9.0,
			half_width - 18.0,
			flip_probe_height
		)
		_expect(_count_cyan_probe(replay_image, flipped_left_band) > 0, "flipped commando actor must mirror the cyan source half into the transformed left half")
		_expect(_count_magenta_probe(replay_image, flipped_right_band) > 0, "flipped commando actor must mirror the magenta source half into the transformed right half")
		_expect(_count_magenta_probe(replay_image, flipped_left_band) == 0, "flipped commando actor must not leave the magenta source half unmirrored on the left")
		_expect(_count_cyan_probe(replay_image, flipped_right_band) == 0, "flipped commando actor must not leave the cyan source half unmirrored on the right")
		var negative_goal_ball_band := _game_sample_rect(125.0, 70.0, 70.0, 48.0)
		_expect(_count_ball_probe(replay_image, negative_goal_ball_band) == 0, "negative-y goal ball must be clipped before the title/subtitle copy band")
		var left_full_playfield_band := _game_sample_rect(0.0, 0.0, 80.0, 750.0)
		var right_full_playfield_band := _game_sample_rect(680.0, 0.0, 80.0, 750.0)
		_expect(_count_lit(band_image, left_full_playfield_band) > 0, "game x=0..80 must remain rendered inside the full playfield clip")
		_expect(_count_lit(band_image, right_full_playfield_band) > 0, "game x=680..760 must remain rendered inside the full playfield clip")

	band_probe.free()
	off_image = null
	on_image = null
	replay_image = null
	hold_image = null
	released_image = null
	band_image = null
	_cleanup(viewport, playback)
	_finish_later()


func _fixture_clip() -> Dictionary:
	var boss_probe := _make_probe_texture(Color(0.0, 1.0, 0.0, 1.0))
	var player_probe := _make_split_probe_texture(Color(1.0, 0.0, 1.0, 1.0), Color(0.0, 1.0, 1.0, 1.0))
	return {
		"label_key": VictoryHighlightRecorder.LABEL_FINISHER,
		"duration_sec": 2.0,
		"goal_t_sec": FIXTURE_GOAL_T_SEC,
		"samples": [
			{
				"t_sec": 0.0,
				"ball_pos": Vector2(180.0, 570.0),
				"ball_radius": 20.0,
				"player_texture": player_probe,
				"player_src": Rect2(0.0, 0.0, 16.0, 4.0),
				"player_dest": FLIPPED_PLAYER_SOURCE_DEST,
				"player_flip": true,
				"boss_texture": boss_probe,
				"boss_src": Rect2(0.0, 0.0, 2.0, 2.0),
				"boss_dest": Rect2(300.0, -10.0, 160.0, 160.0),
			},
			{
				"t_sec": FIXTURE_GOAL_T_SEC,
				"ball_pos": Vector2(80.0, -32.0),
				"ball_radius": 20.0,
				"player_texture": player_probe,
				"player_src": Rect2(0.0, 0.0, 16.0, 4.0),
				"player_dest": FLIPPED_PLAYER_SOURCE_DEST,
				"player_flip": true,
				"boss_texture": boss_probe,
				"boss_src": Rect2(0.0, 0.0, 2.0, 2.0),
				"boss_dest": Rect2(300.0, -10.0, 160.0, 160.0),
			},
		],
		"events": [{"t_sec": FIXTURE_GOAL_T_SEC, "kind": VictoryHighlightRecorder.EVENT_GOAL, "pos": Vector2(80.0, -32.0)}],
	}


func _make_probe_texture(color: Color) -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _make_split_probe_texture(left_color: Color, right_color: Color) -> ImageTexture:
	var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			image.set_pixel(x, y, left_color if x < image.get_width() / 2 else right_color)
	return ImageTexture.create_from_image(image)


func _wait_render_frames(count: int) -> void:
	for _index in range(count):
		await process_frame
		RenderingServer.force_draw(false)


func _capture(viewport: SubViewport, label: String) -> Image:
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		_failures.append("%s viewport texture is unavailable" % label)
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("%s viewport image capture failed" % label)
		return null
	return image


func _screen_game_rect() -> Rect2:
	return Rect2(GAME_OFFSET, GAME_SIZE * RENDER_SCALE)


func _game_sample_rect(x: float, y: float, width: float, height: float) -> Rect2i:
	var screen_pos := GAME_OFFSET + Vector2(x, y) * RENDER_SCALE
	var screen_size := Vector2(width, height) * RENDER_SCALE
	return Rect2i(
		int(floor(screen_pos.x)),
		int(floor(screen_pos.y)),
		maxi(1, int(ceil(screen_size.x))),
		maxi(1, int(ceil(screen_size.y)))
	)


func _count_red(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.r > 0.85 and color.g < 0.18 and color.b < 0.18:
				count += 1
	return count


func _count_lit(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.32:
				count += 1
	return count


func _count_actor_probe(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			# Capture occurs after the 0.12s entry fade, so a dimmed actor
			# regression cannot pass on a merely-present low threshold.
			var is_green := color.r < 0.12 and color.g > 0.58 and color.b < 0.12
			var is_cyan := color.r < 0.12 and color.g > 0.58 and color.b > 0.58
			if is_green or is_cyan:
				count += 1
	return count


func _count_cyan_probe(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.r < 0.12 and color.g > 0.58 and color.b > 0.58:
				count += 1
	return count


func _count_magenta_probe(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.r > 0.58 and color.g < 0.12 and color.b > 0.58:
				count += 1
	return count


func _count_ball_probe(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.r > 0.82 and color.g > 0.74 and color.b > 0.48 and color.b < 0.82:
				count += 1
	return count


func _count_hold_brass(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color: Color = image.get_pixel(x, y)
			if absf(color.r - 0.827) < 0.14 and absf(color.g - 0.674) < 0.14 and absf(color.b - 0.349) < 0.14:
				count += 1
	return count


func _cleanup(viewport: SubViewport, playback: Object) -> void:
	if playback != null and playback.has_method("reset"):
		playback.reset()
	if viewport != null and is_instance_valid(viewport):
		viewport.free()


func _finish_later() -> void:
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("victory_highlight_replay_clip_pixel_qa: ok")
		quit(0)
		return
	for failure in _failures:
		printerr("victory_highlight_replay_clip_pixel_qa: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
