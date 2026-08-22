extends SceneTree

const VictoryHighlightFrameRenderer := preload("res://scripts/core/victory_highlight_frame_renderer.gd")
const VictoryHighlightFrameCaptureState := preload("res://scripts/core/victory_highlight_frame_capture_state.gd")
const VictoryHighlightPlaybackState := preload("res://scripts/core/victory_highlight_playback_state.gd")
const VictoryHighlightRenderer := preload("res://scripts/core/victory_highlight_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const PLAYBACK_VIEW_SIZE := Vector2i(900, 750)
const CAPTURE_SIZE := VictoryHighlightFrameCaptureState.CAPTURE_SIZE
const FIXTURE_CANVAS_SIZE := Vector2i(900, 750)
const STRETCHED_FRAMEBUFFER_SIZE := Vector2i(1800, 1500)
const RESIZED_FRAMEBUFFER_SIZE := Vector2i(1350, 1125)
const STRETCH_SCALE := 2.0
const SUSTAINED_CAPTURE_REQUEST_COUNT := 720
const PLAYBACK_CLIP_COUNT := 3
const PLAYBACK_ACTION_FRAMES_PER_CLIP := VictoryHighlightFrameCaptureState.MAX_CLIP_FRAME_COUNT
const PLAYBACK_HOLD_FRAMES_PER_CLIP := int(
	VictoryHighlightFrameCaptureState.GOAL_HOLD_SEC
	* VictoryHighlightFrameCaptureState.CAPTURE_FPS
)
const PLAYBACK_DISPLAY_FRAMES_PER_CLIP := (
	PLAYBACK_ACTION_FRAMES_PER_CLIP + PLAYBACK_HOLD_FRAMES_PER_CLIP
)
const UNIFORMITY_DISPLAY_FRAME_COUNT := PLAYBACK_CLIP_COUNT * PLAYBACK_DISPLAY_FRAMES_PER_CLIP
const COLOR_TL := Color(0.95, 0.02, 0.92, 1.0)
const COLOR_TR := Color(0.02, 0.92, 0.95, 1.0)
const COLOR_BL := Color(0.96, 0.88, 0.02, 1.0)
const COLOR_BR := Color(0.02, 0.92, 0.08, 1.0)

var _failures: Array[String] = []
var _capture_requests := 0
var _capture_produced := 0
var _capture_dropped := 0
var _capture_duration_sec := 0.0
var _capture_work_worst_usec := 0
var _capture_deadline_misses := 0
var _capture_in_flight_high_water := 0
var _playback_upload_worst_usec := 0
var _playback_deadline_misses := 0
var _playback_frame_count := 0
var _playback_repeated_frames := 0
var _playback_skipped_frames := 0
var _playback_action_frames := 0
var _playback_hold_frames := 0
var _playback_hold_advances := 0


class TestOwner:
	extends Node2D
	var victory_highlight_active := false


class TestRegistry:
	extends RefCounted
	var values: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = values.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class FakeRecorder:
	extends RefCounted

	func release_match_clips() -> void:
		pass


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		printerr("victory_highlight_frame_product_pixel_qa: headless execution is forbidden")
		quit(2)
		return
	Engine.set("max_fps", int(VictoryHighlightFrameCaptureState.MAX_CAPTURE_HZ))
	call_deferred("_run")


func _run() -> void:
	await _test_non_unit_framebuffer_crop()
	await _test_render_rate_playback_uploads()
	var viewport := SubViewport.new()
	viewport.size = PLAYBACK_VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var owner := TestOwner.new()
	viewport.add_child(owner)
	var base_renderer := VictoryHighlightRenderer.new()
	var frame_renderer := VictoryHighlightFrameRenderer.new()
	frame_renderer.configure_base_renderer(base_renderer)
	frame_renderer.prewarm_assets()
	var registry := TestRegistry.new()
	registry.values = {
		"victory_highlight_renderer": base_renderer,
		"victory_highlight_frame_renderer": frame_renderer,
		"victory_highlight_recorder": FakeRecorder.new(),
	}
	var bytes := _make_quadrant_bytes()
	var frame_clip := {
		"id": 1,
		"label_key": "victory_highlight_finisher",
		"duration_sec": 0.80,
		"goal_t_sec": 0.55,
		"samples": [{"t_sec": 0.0, "ball_pos": Vector2(380.0, 375.0)}],
		"events": [],
		"frame_frames": [bytes],
		"frame_size": CAPTURE_SIZE,
		"frame_fps": VictoryHighlightFrameCaptureState.CAPTURE_FPS,
		"frame_data_format": RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	}
	var state_clip := {
		"id": 2,
		"label_key": "victory_highlight_long_rally",
		"duration_sec": 0.80,
		"goal_t_sec": 0.55,
		"samples": [
			{
				"t_sec": 0.0,
				"ball_pos": Vector2(380.0, 375.0),
				"ball_radius": 24.0,
			}
		],
		"events": [],
	}
	var final_frame_clip: Dictionary = frame_clip.duplicate(true)
	final_frame_clip["id"] = 3
	var clips: Array[Dictionary] = [frame_clip, state_clip, final_frame_clip]
	var playback := VictoryHighlightPlaybackState.new()
	_expect(playback.start(owner, registry, clips, Callable()), "frame playback failed to start")
	_expect(str(playback.get_host_debug_snapshot().get("renderer_key", "")) == "victory_highlight_frame_renderer", "pixel path did not select the product frame renderer")
	_expect(
		str(playback.get_host_debug_snapshot().get("current_content_mode", "")) == "frame_full_canvas",
		"frame clip must start in full-canvas content mode"
	)
	playback.update(0.20)
	await _render_frames(4)
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("frame playback viewport capture failed")
	else:
		_expect(_has_expected_quadrants(image), "full-canvas playback must deliver all four asymmetric frame corners 1:1")
		_expect(
			_count_quadrant_colors(
				image,
				Rect2i(VIEW_SIZE.x, 0, PLAYBACK_VIEW_SIZE.x - VIEW_SIZE.x, PLAYBACK_VIEW_SIZE.y)
			) == 0,
			"full-canvas frame playback must leak zero recorded-frame pixels into the right letterbox fixture"
		)
		_expect(
			_color_near(image.get_pixel(100, 200), COLOR_TL),
			"frame replay must stay undimmed outside the two local copy scrims"
		)
		_expect(
			image.get_pixel(30, 40).r < COLOR_TL.r * 0.75,
			"title readability must come from a local top scrim"
		)
		_expect(
			_count_neutral_glyph(image, Rect2i(100, 24, 560, 80)) > 20
			and _count_neutral_glyph(image, Rect2i(100, 682, 560, 34)) > 5,
			"title/subtitle and skip overlay glyphs must remain visibly rendered over the recorded frame"
		)
		var hold_down := InputEventKey.new()
		hold_down.keycode = KEY_SPACE
		hold_down.pressed = true
		var hold_up := InputEventKey.new()
		hold_up.keycode = KEY_SPACE
		hold_up.pressed = false
		_expect(playback.handle_input(hold_down), "frame-lane pixel fixture must begin hold progress after the entry guard")
		playback.update(0.30)
		await _render_frames(4)
		var hold_image: Image = viewport.get_texture().get_image()
		var renderer_gauge: Rect2 = base_renderer.get_skip_hold_gauge_rect_for_tests().grow(3.0)
		var gauge_band := Rect2i(renderer_gauge)
		_expect(
			hold_image != null
			and not hold_image.is_empty()
			and _count_hold_brass(hold_image, gauge_band) > _count_hold_brass(image, gauge_band) + 20,
			"frame-lane hold progress must render a visible brass fill over the full-canvas replay"
		)
		_expect(playback.handle_input(hold_up), "frame-lane hold release must be consumed")
		_expect(is_zero_approx(playback.get_skip_hold_progress()), "frame-lane hold release must reset progress")
		playback.update(0.0)
		await _render_frames(4)
		var released_image: Image = viewport.get_texture().get_image()
		_expect(
			released_image != null
			and not released_image.is_empty()
			and _count_hold_brass(released_image, gauge_band) < _count_hold_brass(hold_image, gauge_band),
			"frame-lane hold progress pixels must disappear after release"
		)

	playback.update(0.30)
	playback.update(0.20)
	await _render_frames(3)
	var state_image: Image = viewport.get_texture().get_image()
	_expect(
		playback.get_current_clip_index() == 1
		and str(playback.get_host_debug_snapshot().get("current_content_mode", "")) == "state_band",
		"mixed playback must switch from full frame content to the state band"
	)
	if state_image != null and not state_image.is_empty():
		_expect(
			_count_quadrant_colors(state_image, Rect2i(0, 0, VIEW_SIZE.x, 117)) == 0
			and _count_quadrant_colors(state_image, Rect2i(0, 678, VIEW_SIZE.x, VIEW_SIZE.y - 678)) == 0,
			"mixed state clip must restore the original copy-safe band instead of leaving frame pixels behind"
		)
		_expect(
			_count_gold_ball(state_image, Rect2i(250, 300, 260, 200)) > 100,
			"mixed state clip must remain visibly rendered through the established band renderer"
		)

	playback.update(0.60)
	playback.update(0.20)
	await _render_frames(3)
	var return_image: Image = viewport.get_texture().get_image()
	_expect(
		playback.get_current_clip_index() == 2
		and str(playback.get_host_debug_snapshot().get("current_content_mode", "")) == "frame_full_canvas",
		"mixed playback must switch back from the state band to full-canvas frame content"
	)
	if return_image != null and not return_image.is_empty():
		_expect(_has_expected_quadrants(return_image), "frame content must regain all four full-canvas corners after a mixed transition")
	playback.reset()
	await _test_frame_overlay_timeline(viewport, owner, registry, bytes)
	viewport.free()
	print(
		"victory_highlight_resolution_metrics: capture_size=%s capture_hz=%.1f frame_bytes=%d logical_frames=%d logical_bytes=%d capture_duration_sec=%.3f capture_requests=%d capture_produced=%d capture_dropped=%d capture_work_worst_ms=%.4f capture_deadline_misses=%d in_flight_high_water=%d playback_frames=%d playback_action_frames=%d playback_hold_frames=%d playback_hold_advances=%d playback_upload_worst_ms=%.4f playback_deadline_misses=%d playback_repeats=%d playback_skips=%d" % [
			str(CAPTURE_SIZE).replace(" ", ""),
			VictoryHighlightFrameCaptureState.MAX_CAPTURE_HZ,
			VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT,
			VictoryHighlightFrameCaptureState.LOGICAL_MAX_FRAME_COUNT,
			VictoryHighlightFrameCaptureState.LOGICAL_MAX_BYTE_COUNT,
			_capture_duration_sec,
			_capture_requests,
			_capture_produced,
			_capture_dropped,
			float(_capture_work_worst_usec) / 1000.0,
			_capture_deadline_misses,
			_capture_in_flight_high_water,
			_playback_frame_count,
			_playback_action_frames,
			_playback_hold_frames,
			_playback_hold_advances,
			float(_playback_upload_worst_usec) / 1000.0,
			_playback_deadline_misses,
			_playback_repeated_frames,
			_playback_skipped_frames,
		]
	)
	if _failures.is_empty():
		print("victory_highlight_frame_product_pixel_qa: ok")
		quit(0)
		return
	for failure in _failures:
		printerr("victory_highlight_frame_product_pixel_qa: %s" % failure)
	quit(1)


func _test_frame_overlay_timeline(
	viewport: SubViewport,
	owner: TestOwner,
	registry: TestRegistry,
	bytes: PackedByteArray
) -> void:
	var first_clip := {
		"id": 101,
		"label_key": "victory_highlight_finisher",
		"duration_sec": 1.20,
		"goal_t_sec": 0.70,
		"samples": [],
		"events": [],
		"frame_frames": [bytes],
		"frame_size": CAPTURE_SIZE,
		"frame_fps": VictoryHighlightFrameCaptureState.CAPTURE_FPS,
		"frame_data_format": RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	}
	var second_clip: Dictionary = first_clip.duplicate(true)
	second_clip["id"] = 102
	second_clip["label_key"] = "victory_highlight_long_rally"
	var clips: Array[Dictionary] = [first_clip, second_clip]
	var playback := VictoryHighlightPlaybackState.new()
	_expect(playback.start(owner, registry, clips, Callable()), "frame overlay timeline fixture must start through the real playback state")
	playback.update(0.20)
	await _render_frames(4)
	var initial_image: Image = viewport.get_texture().get_image()
	if initial_image == null or initial_image.is_empty():
		_failures.append("frame overlay initial capture failed")
		playback.reset()
		return
	_expect(
		_color_near(initial_image.get_pixel(100, 18), COLOR_TL)
		and _color_near(initial_image.get_pixel(18, 200), COLOR_TL)
		and _color_near(initial_image.get_pixel(100, 118), COLOR_TL)
		and _color_near(initial_image.get_pixel(100, 678), COLOR_BL),
		"frame lane must leave every legacy brass border and y=118/678 band-line probe absent"
	)
	var title_band := Rect2i(100, 24, 560, 44)
	var subtitle_band := Rect2i(100, 72, 560, 36)
	var skip_band := Rect2i(100, 682, 560, 34)
	var dots_band := Rect2i(350, 646, 60, 20)
	_expect(_count_hold_brass(initial_image, title_band) > 20, "frame title must be visibly rendered during its initial hold")
	_expect(_count_neutral_glyph(initial_image, subtitle_band) > 20, "frame subtitle must be visibly rendered during its initial hold")

	playback.update(0.61)
	await _render_frames(4)
	var title_fade_image: Image = viewport.get_texture().get_image()
	_expect(
		title_fade_image != null
		and not title_fade_image.is_empty()
		and _count_hold_brass(title_fade_image, title_band) > 10
		and _count_neutral_glyph(title_fade_image, subtitle_band) < 5,
		"at 0.81 seconds the title must be fading while the first subtitle has finished fading"
	)

	playback.update(0.25)
	await _render_frames(4)
	var transient_gone_image: Image = viewport.get_texture().get_image()
	_expect(
		transient_gone_image != null
		and not transient_gone_image.is_empty()
		and _count_hold_brass(transient_gone_image, title_band) < 5
		and _count_neutral_glyph(transient_gone_image, subtitle_band) < 5
		and _color_near(transient_gone_image.get_pixel(30, 40), COLOR_TL),
		"after 1.05 seconds the title, subtitle, and their local top scrim must all be gone"
	)
	_expect(
		_count_neutral_glyph(transient_gone_image, skip_band) > 5
		and _count_seal_red(transient_gone_image, dots_band) > 5,
		"clip dots and hold-skip guidance must remain visible after transient copy fades"
	)

	playback.update(0.15)
	playback.update(0.10)
	await _render_frames(4)
	var next_subtitle_image: Image = viewport.get_texture().get_image()
	_expect(playback.get_current_clip_index() == 1, "overlay fixture must advance to its second frame clip")
	_expect(
		next_subtitle_image != null
		and not next_subtitle_image.is_empty()
		and _count_hold_brass(next_subtitle_image, title_band) < 5
		and _count_neutral_glyph(next_subtitle_image, subtitle_band) > 20
		and not _color_near(next_subtitle_image.get_pixel(30, 40), COLOR_TL),
		"a clip transition must restore only the subtitle and its scrim, never the global title"
	)

	playback.update(0.71)
	await _render_frames(4)
	var next_subtitle_gone_image: Image = viewport.get_texture().get_image()
	_expect(
		next_subtitle_gone_image != null
		and not next_subtitle_gone_image.is_empty()
		and _count_hold_brass(next_subtitle_gone_image, title_band) < 5
		and _count_neutral_glyph(next_subtitle_gone_image, subtitle_band) < 5
		and _color_near(next_subtitle_gone_image.get_pixel(30, 40), COLOR_TL),
		"each later subtitle and its local scrim must disappear after the 0.6+0.2-second timeline"
	)
	playback.reset()


func _test_non_unit_framebuffer_crop() -> void:
	_expect(not is_equal_approx(STRETCH_SCALE, 1.0), "crop pixel seal requires a non-unit stretch scale")
	var runner_canvas_size := root.get_visible_rect().size
	var runner_framebuffer_size := Vector2(root.get_texture().get_size())
	_expect(
		not runner_canvas_size.is_equal_approx(runner_framebuffer_size),
		"pixel QA runner window must expose different canvas and framebuffer sizes"
	)
	_expect(
		STRETCHED_FRAMEBUFFER_SIZE == Vector2i(Vector2(FIXTURE_CANVAS_SIZE) * STRETCH_SCALE),
		"crop pixel fixture framebuffer must be the declared non-unit canvas scale"
	)
	var source_viewport := SubViewport.new()
	source_viewport.size = STRETCHED_FRAMEBUFFER_SIZE
	source_viewport.size_2d_override = FIXTURE_CANVAS_SIZE
	source_viewport.size_2d_override_stretch = true
	source_viewport.transparent_bg = false
	source_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	source_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(source_viewport)
	_add_quadrant_fixture(source_viewport)
	var source_owner := TestOwner.new()
	source_viewport.add_child(source_owner)
	for _frame in range(3):
		await process_frame
		RenderingServer.force_draw(false)
	_expect(
		source_viewport.get_visible_rect().size.is_equal_approx(Vector2(FIXTURE_CANVAS_SIZE)),
		"crop fixture must expose canvas units through get_visible_rect"
	)
	_expect(
		source_viewport.get_texture().get_size().is_equal_approx(Vector2(STRETCHED_FRAMEBUFFER_SIZE)),
		"crop fixture texture must remain in framebuffer pixels"
	)
	var capture := VictoryHighlightFrameCaptureState.new()
	var prewarm_complete := capture.prewarm_step(source_owner)
	for _frame in range(12):
		if prewarm_complete:
			break
		await process_frame
		RenderingServer.force_draw(false)
		prewarm_complete = capture.prewarm_step(source_owner)
	_expect(
		prewarm_complete and capture.is_available(),
		"real product blit tree must finish RD prewarm"
	)
	var expected_uv := Rect2(Vector2(70.0 / 900.0, 0.0), Vector2(760.0 / 900.0, 1.0))
	var crop_snapshot: Dictionary = capture.get_debug_snapshot()
	_expect(
		str(crop_snapshot.get("capture_backend", "")) == "normalized_uv",
		"product crop backend must be normalized UV instead of absolute AtlasTexture pixels"
	)
	_expect(
		(crop_snapshot.get("crop_uv_rect", Rect2()) as Rect2).is_equal_approx(expected_uv),
		"normalized crop must select the centered 760x750 game rect inside the wider canvas"
	)
	var corrected: Image = await _capture_product_frame(capture, 1.0, 1)
	_expect(
		_has_expected_quadrants(corrected),
		"real product blit and async readback must preserve all four asymmetric game quadrants"
	)
	source_viewport.size = RESIZED_FRAMEBUFFER_SIZE
	for _frame in range(2):
		await process_frame
		RenderingServer.force_draw(false)
	var resized: Image = await _capture_product_frame(capture, 2.0, 2)
	_expect(
		_has_expected_quadrants(resized),
		"real product path must preserve all four quadrants after framebuffer resize"
	)
	_expect(
		(capture.get_debug_snapshot().get("crop_uv_rect", Rect2()) as Rect2).is_equal_approx(expected_uv),
		"normalized crop must remain stable across framebuffer-only resize"
	)
	await _test_sustained_render_capture(capture, 3.0)
	capture.release_all()
	var released: Dictionary = capture.get_debug_snapshot()
	_expect(
		int(released.get("ring_count", -1)) == 0
		and int(released.get("frame_clip_count", -1)) == 0
		and int(released.get("owned_rid_count", -1)) == 0,
		"760x750 capture cleanup must release every CPU frame reference and owned viewport RID"
	)
	source_viewport.free()


func _test_sustained_render_capture(
	capture: VictoryHighlightFrameCaptureState,
	start_time_sec: float
) -> void:
	var before: Dictionary = capture.get_debug_snapshot()
	var before_due := int(before.get("capture_due_count", 0))
	var before_produced := int(before.get("capture_produced_count", 0))
	var before_dropped := int(before.get("capture_dropped_count", 0))
	var before_deadline_misses := int(before.get("capture_deadline_miss_count", 0))
	var wall_start_usec := Time.get_ticks_usec()
	for index in range(SUSTAINED_CAPTURE_REQUEST_COUNT):
		_capture_requests += 1
		var logical_time_sec := start_time_sec + float(index) / VictoryHighlightFrameCaptureState.MAX_CAPTURE_HZ
		if not capture.capture_visual(logical_time_sec):
			_capture_dropped += 1
		await process_frame
		RenderingServer.force_draw(false)
	var target_produced := before_produced + SUSTAINED_CAPTURE_REQUEST_COUNT
	for _frame in range(120):
		var pending: Dictionary = capture.get_debug_snapshot()
		if (
			int(pending.get("capture_produced_count", 0)) >= target_produced
			and int(pending.get("in_flight", 0)) == 0
			and not bool(pending.get("pending_capture", true))
		):
			break
		await process_frame
		RenderingServer.force_draw(false)
	_capture_duration_sec = float(Time.get_ticks_usec() - wall_start_usec) / 1_000_000.0
	var after: Dictionary = capture.get_debug_snapshot()
	var due_delta := int(after.get("capture_due_count", 0)) - before_due
	var produced_delta := int(after.get("capture_produced_count", 0)) - before_produced
	var dropped_delta := int(after.get("capture_dropped_count", 0)) - before_dropped
	var deadline_delta := int(after.get("capture_deadline_miss_count", 0)) - before_deadline_misses
	_capture_produced += produced_delta
	_capture_work_worst_usec = int(after.get("capture_work_worst_usec", 0))
	_capture_deadline_misses = deadline_delta
	_capture_in_flight_high_water = int(after.get("in_flight_high_water", 0))
	_expect(due_delta == SUSTAINED_CAPTURE_REQUEST_COUNT, "every one of 720 stable render frames must become capture-due")
	_expect(produced_delta == SUSTAINED_CAPTURE_REQUEST_COUNT, "all 720 sustained async requests must produce complete frames")
	_expect(dropped_delta == 0 and _capture_dropped == 0, "72Hz sustained capture must drop zero due frames")
	_expect(deadline_delta == 0, "72Hz sustained capture request and callback work must miss zero frame deadlines")
	_expect(
		_capture_in_flight_high_water >= 1
		and _capture_in_flight_high_water <= VictoryHighlightFrameCaptureState.MAX_IN_FLIGHT,
		"sustained capture in-flight high-water must remain inside the declared bound"
	)


func _add_quadrant_fixture(viewport: SubViewport) -> void:
	var background := ColorRect.new()
	background.size = Vector2(FIXTURE_CANVAS_SIZE)
	background.color = Color(0.12, 0.01, 0.015, 1.0)
	viewport.add_child(background)
	var half := VIEW_SIZE / 2
	var game_offset := Vector2i((FIXTURE_CANVAS_SIZE.x - VIEW_SIZE.x) / 2, 0)
	for entry in [
		[Rect2i(game_offset.x, game_offset.y, half.x, half.y), COLOR_TL],
		[Rect2i(game_offset.x + half.x, game_offset.y, half.x, half.y), COLOR_TR],
		[Rect2i(game_offset.x, game_offset.y + half.y, half.x, half.y), COLOR_BL],
		[Rect2i(game_offset.x + half.x, game_offset.y + half.y, half.x, half.y), COLOR_BR],
	]:
		var panel := ColorRect.new()
		panel.position = Vector2(entry[0].position)
		panel.size = Vector2(entry[0].size)
		panel.color = entry[1]
		viewport.add_child(panel)


func _capture_product_frame(
	capture: VictoryHighlightFrameCaptureState,
	logical_time_sec: float,
	expected_ring_count: int
) -> Image:
	_capture_requests += 1
	var armed := capture.capture_visual(logical_time_sec)
	if not armed:
		_capture_dropped += 1
	_expect(armed, "real product capture request must arm")
	for _frame in range(30):
		await process_frame
		RenderingServer.force_draw(false)
		var snapshot: Dictionary = capture.get_debug_snapshot()
		if (
			int(snapshot.get("ring_count", 0)) >= expected_ring_count
			and int(snapshot.get("in_flight", 0)) == 0
			and not bool(snapshot.get("pending_capture", true))
		):
			break
	var bytes := capture.get_latest_frame_for_tests()
	_expect(
		bytes.size() == CAPTURE_SIZE.x * CAPTURE_SIZE.y * 4,
		"real product async readback must return one complete 760x750 RGBA frame"
	)
	if bytes.size() != CAPTURE_SIZE.x * CAPTURE_SIZE.y * 4:
		return Image.new()
	_capture_produced += 1
	return Image.create_from_data(
		CAPTURE_SIZE.x,
		CAPTURE_SIZE.y,
		false,
		Image.FORMAT_RGBA8,
		bytes
	)


func _test_render_rate_playback_uploads() -> void:
	var bytes := PackedByteArray()
	bytes.resize(VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT)
	bytes.fill(96)
	var clips: Array[Dictionary] = []
	for clip_index in range(PLAYBACK_CLIP_COUNT):
		var frames: Array[PackedByteArray] = []
		frames.resize(PLAYBACK_ACTION_FRAMES_PER_CLIP)
		for frame_index in range(frames.size()):
			frames[frame_index] = bytes
		clips.append({
			"id": 720 + clip_index,
			"label_key": "victory_highlight_finisher",
			"duration_sec": VictoryHighlightFrameCaptureState.MAX_CLIP_SEC,
			"goal_t_sec": VictoryHighlightFrameCaptureState.MAX_ACTION_SEC,
			"samples": [],
			"events": [],
			"frame_frames": frames,
			"frame_fps": VictoryHighlightFrameCaptureState.CAPTURE_FPS,
			"frame_size": CAPTURE_SIZE,
			"frame_data_format": RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
		})
	var owner := TestOwner.new()
	root.add_child(owner)
	var base_renderer := VictoryHighlightRenderer.new()
	var renderer := VictoryHighlightFrameRenderer.new()
	var registry := TestRegistry.new()
	registry.values = {
		"victory_highlight_renderer": base_renderer,
		"victory_highlight_frame_renderer": renderer,
		"victory_highlight_recorder": FakeRecorder.new(),
	}
	var playback := VictoryHighlightPlaybackState.new()
	_expect(playback.start(owner, registry, clips, Callable()), "real playback state must start the three-clip action-plus-hold fixture")
	_expect(
		is_equal_approx(float(playback.get_host_debug_snapshot().get("timeline_speed", 0.0)), 1.0),
		"real frame playback must use natural timeline speed"
	)
	_expect(
		str(playback.get_host_debug_snapshot().get("renderer_key", "")) == "victory_highlight_frame_renderer",
		"uniformity seal must traverse the real product frame renderer selection"
	)
	for _index in range(UNIFORMITY_DISPLAY_FRAME_COUNT - 1):
		playback.update(1.0 / VictoryHighlightFrameCaptureState.CAPTURE_FPS)
		await process_frame
		RenderingServer.force_draw(false)
	var metrics: Dictionary = renderer.get_upload_metrics()
	_playback_frame_count = int(metrics.get("display_request_count", 0))
	_playback_action_frames = int(metrics.get("action_display_count", 0))
	_playback_hold_frames = int(metrics.get("goal_hold_display_count", 0))
	_playback_hold_advances = int(metrics.get("goal_hold_advance_count", -1))
	_expect(_playback_frame_count == UNIFORMITY_DISPLAY_FRAME_COUNT, "real playback state must issue exactly 432 action-plus-hold display requests")
	_expect(
		int(metrics.get("upload_count", 0)) == PLAYBACK_CLIP_COUNT * PLAYBACK_ACTION_FRAMES_PER_CLIP,
		"synthetic goal holds must reuse the final action frame without extra texture uploads"
	)
	_expect(
		int(metrics.get("unit_frame_advance_count", 0)) == PLAYBACK_CLIP_COUNT * (PLAYBACK_ACTION_FRAMES_PER_CLIP - 1),
		"same-rate real-action playback must advance exactly one capture frame per displayed frame"
	)
	_expect(
		_playback_action_frames == PLAYBACK_CLIP_COUNT * PLAYBACK_ACTION_FRAMES_PER_CLIP,
		"the 1:1 uniformity gate must cover exactly 108 real-action displays per clip"
	)
	_expect(
		_playback_hold_frames == PLAYBACK_CLIP_COUNT * PLAYBACK_HOLD_FRAMES_PER_CLIP,
		"the synthetic goal hold must last exactly 0.5 seconds per clip at 72Hz"
	)
	_expect(_playback_hold_advances == 0, "the final capture frame must advance zero times throughout every goal hold")
	_playback_repeated_frames = int(metrics.get("repeated_frame_count", 0))
	_playback_skipped_frames = int(metrics.get("skipped_frame_count", 0))
	_expect(_playback_repeated_frames == 0, "same-rate real-action playback must repeat zero capture frames")
	_expect(_playback_skipped_frames == 0, "same-rate real-action playback must skip zero capture frames")
	_expect(int(metrics.get("non_forward_frame_count", 0)) == 0, "same-rate real-action playback must never move backward")
	_playback_upload_worst_usec = int(metrics.get("upload_worst_usec", 0))
	_playback_deadline_misses = int(metrics.get("upload_deadline_miss_count", 0))
	_expect(_playback_deadline_misses == 0, "72fps ImageTexture uploads must miss zero frame deadlines")
	playback.reset()
	owner.free()


func _has_expected_quadrants(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var edge := 8
	return (
		_color_near(image.get_pixel(CAPTURE_SIZE.x / 4, CAPTURE_SIZE.y / 4), COLOR_TL)
		and _color_near(image.get_pixel(CAPTURE_SIZE.x * 3 / 4, CAPTURE_SIZE.y / 4), COLOR_TR)
		and _color_near(image.get_pixel(CAPTURE_SIZE.x / 4, CAPTURE_SIZE.y * 3 / 4), COLOR_BL)
		and _color_near(image.get_pixel(CAPTURE_SIZE.x * 3 / 4, CAPTURE_SIZE.y * 3 / 4), COLOR_BR)
		and _color_near(image.get_pixel(edge, edge), COLOR_TL)
		and _color_near(image.get_pixel(CAPTURE_SIZE.x - edge - 1, edge), COLOR_TR)
		and _color_near(image.get_pixel(edge, CAPTURE_SIZE.y - edge - 1), COLOR_BL)
		and _color_near(
			image.get_pixel(CAPTURE_SIZE.x - edge - 1, CAPTURE_SIZE.y - edge - 1),
			COLOR_BR
		)
	)


func _color_near(actual: Color, expected: Color) -> bool:
	return (
		absf(actual.r - expected.r) < 0.08
		and absf(actual.g - expected.g) < 0.08
		and absf(actual.b - expected.b) < 0.08
	)


func _make_quadrant_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(CAPTURE_SIZE.x * CAPTURE_SIZE.y * 4)
	for y in range(CAPTURE_SIZE.y):
		for x in range(CAPTURE_SIZE.x):
			var color := COLOR_TL
			if x >= CAPTURE_SIZE.x / 2 and y < CAPTURE_SIZE.y / 2:
				color = COLOR_TR
			elif x < CAPTURE_SIZE.x / 2 and y >= CAPTURE_SIZE.y / 2:
				color = COLOR_BL
			elif x >= CAPTURE_SIZE.x / 2 and y >= CAPTURE_SIZE.y / 2:
				color = COLOR_BR
			var offset := (y * CAPTURE_SIZE.x + x) * 4
			bytes[offset] = int(round(color.r * 255.0))
			bytes[offset + 1] = int(round(color.g * 255.0))
			bytes[offset + 2] = int(round(color.b * 255.0))
			bytes[offset + 3] = 255
	return bytes


func _render_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
		RenderingServer.force_draw(false)


func _count_neutral_glyph(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color := image.get_pixel(x, y)
			if minf(color.r, minf(color.g, color.b)) > 0.50:
				count += 1
	return count


func _count_hold_brass(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color := image.get_pixel(x, y)
			if absf(color.r - 0.827) < 0.14 and absf(color.g - 0.674) < 0.14 and absf(color.b - 0.349) < 0.14:
				count += 1
	return count


func _count_seal_red(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color := image.get_pixel(x, y)
			if color.r > 0.38 and color.r > color.g * 1.8 and color.r > color.b * 1.8:
				count += 1
	return count


func _count_quadrant_colors(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color := image.get_pixel(x, y)
			if (
				_color_near(color, COLOR_TL)
				or _color_near(color, COLOR_TR)
				or _color_near(color, COLOR_BL)
				or _color_near(color, COLOR_BR)
			):
				count += 1
	return count


func _count_gold_ball(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color := image.get_pixel(x, y)
			if color.r > 0.75 and color.g > 0.65 and color.b > 0.45:
				count += 1
	return count


func _count_green(image: Image, rect: Rect2i) -> int:
	var count := 0
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(bounded.position.y, bounded.end.y):
		for x in range(bounded.position.x, bounded.end.x):
			var color := image.get_pixel(x, y)
			if color.r < 0.10 and color.g > 0.80 and color.b < 0.20:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
