extends SceneTree

const BallRenderer := preload("res://scripts/ball/ball_renderer.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const GAME_SIZE := Vector2(760.0, 750.0)
const BALL_Y := 350.0
const CASE_XS := [110.0, 290.0, 470.0, 650.0]
const CASE_LABELS := ["ROUND", "IMPACT 0ms", "LAUNCH 62ms", "SETTLE 128ms"]
const EVENT_START_MSEC := 1000.0
const PHASE_TIMES := [1000.0, 1000.0, 1062.0, 1128.0]


class CaptureCanvas:
	extends Node2D

	var renderers: Array[Object] = []
	var hit_event := {
		"id": 901,
		"pos": Vector2(0.0, BALL_Y + 28.0),
		"velocity": Vector2(0.0, -26.0),
		"intensity": 0.8,
		"kind": "player_paddle",
	}

	func _ready() -> void:
		for case_index in range(CASE_XS.size()):
			var renderer := BallRenderer.new()
			renderer.prewarm_assets()
			if case_index > 0:
				renderer.contact_deformation_state.sync_event(hit_event, EVENT_START_MSEC)
			renderers.append(renderer)
		queue_redraw()

	func _draw() -> void:
		var viewport_size: Vector2 = get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.008, 0.014, 0.028), true)
		var render_scale: float = minf(viewport_size.x / GAME_SIZE.x, viewport_size.y / GAME_SIZE.y)
		var game_offset: Vector2 = (viewport_size - GAME_SIZE * render_scale) * 0.5
		draw_set_transform(game_offset, 0.0, Vector2.ONE * render_scale)
		_draw_background()
		for case_index in range(CASE_XS.size()):
			_draw_case(case_index)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_background() -> void:
		draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color(0.018, 0.036, 0.070), true)
		for line_index in range(7):
			var y: float = 80.0 + float(line_index) * 54.0
			draw_line(Vector2(22.0, y), Vector2(738.0, y - 10.0), Color(0.18, 0.52, 0.78, 0.10), 1.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(236.0, 42.0), "SPEED-BASED CONTACT DEFORMATION", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.76, 0.94, 1.0))

	func _draw_case(case_index: int) -> void:
		var center := Vector2(float(CASE_XS[case_index]), BALL_Y)
		var renderer: Object = renderers[case_index]
		var event: Dictionary = {} if case_index == 0 else hit_event
		renderer.draw_current(
			self,
			center,
			{
				"ball_visual_type": "energy",
				"ball_vel": Vector2(0.0, -26.0),
				"effect_lod_scale": 0.35,
				"ball_ground_shadow_enabled": false,
				"ball_readability_enabled": false,
				"ball_contact_deformation_enabled": case_index > 0,
				"ball_contact_deformation_now_msec": float(PHASE_TIMES[case_index]),
				"hit_pulse_event": event,
			},
			null,
			false
		)
		var paddle_rect := Rect2(center.x - 58.0, BALL_Y + 58.0, 116.0, 12.0)
		draw_rect(paddle_rect, Color(0.18, 0.46, 0.68, 0.82), true)
		draw_rect(paddle_rect, Color(0.70, 0.92, 1.0, 0.46), false, 1.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(center.x - 57.0, 472.0), str(CASE_LABELS[case_index]), HORIZONTAL_ALIGNMENT_CENTER, 114.0, 13, Color(0.76, 0.86, 0.96))


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_window: Window = get_root()
	root_window.size = VIEW_SIZE
	var canvas := CaptureCanvas.new()
	root_window.add_child(canvas)
	await process_frame
	canvas.queue_redraw()
	await process_frame
	await process_frame

	var image: Image = root_window.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("Vulkan squash/stretch capture was empty")
	else:
		_verify_capture(image)

	canvas.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ball_contact_squash_stretch_visual_qa: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_capture(image: Image) -> void:
	if image.get_size() != VIEW_SIZE:
		_failures.append("expected %s capture, got %s" % [VIEW_SIZE, image.get_size()])
	var output_dir: String = _resolve_output_dir()
	var mkdir_error: int = DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_failures.append("could not create output directory: %s" % output_dir)
		return
	var output_path: String = output_dir.path_join(
		"ball_contact_squash_stretch_phases_2020x1246.png"
	)
	var save_error: int = image.save_png(output_path)
	if save_error != OK:
		_failures.append("capture save failed (%d): %s" % [save_error, output_path])
		return

	var impact_diff: int = _count_case_difference(image, 0, 1)
	var launch_diff: int = _count_case_difference(image, 0, 2)
	var settle_diff: int = _count_case_difference(image, 0, 3)
	if impact_diff < 140:
		_failures.append("impact compression did not materialize enough changed pixels: %d" % impact_diff)
	if launch_diff < 140:
		_failures.append("launch stretch did not materialize enough changed pixels: %d" % launch_diff)
	if settle_diff < 12:
		_failures.append("elastic settle did not remain visible: %d" % settle_diff)

	var impact_size: Vector2i = _measure_bright_core_size(image, 1)
	var launch_size: Vector2i = _measure_bright_core_size(image, 2)
	var settle_size: Vector2i = _measure_bright_core_size(image, 3)
	if impact_size.x <= int(round(float(impact_size.y) * 1.35)):
		_failures.append("impact core was not wider than tall: %s" % impact_size)
	if launch_size.y <= int(round(float(launch_size.x) * 1.18)):
		_failures.append("launch core was not taller than wide: %s" % launch_size)
	if absf(float(settle_size.x - settle_size.y)) > 8.0:
		_failures.append("settle core did not return close to round: %s" % settle_size)
	print(
		"ball_contact_squash_stretch_visual_qa: capture=%s impact_diff=%d launch_diff=%d settle_diff=%d impact_size=%s launch_size=%s settle_size=%s"
		% [output_path, impact_diff, launch_diff, settle_diff, impact_size, launch_size, settle_size]
	)


func _count_case_difference(image: Image, baseline_index: int, case_index: int) -> int:
	var render_scale: float = minf(float(image.get_width()) / GAME_SIZE.x, float(image.get_height()) / GAME_SIZE.y)
	var game_offset: Vector2 = (Vector2(image.get_size()) - GAME_SIZE * render_scale) * 0.5
	var logical_size := Vector2(86.0, 86.0)
	var baseline_origin := Vector2i(game_offset + Vector2(float(CASE_XS[baseline_index]) - 43.0, BALL_Y - 43.0) * render_scale)
	var case_origin := Vector2i(game_offset + Vector2(float(CASE_XS[case_index]) - 43.0, BALL_Y - 43.0) * render_scale)
	var pixel_size := Vector2i(logical_size * render_scale)
	var changed := 0
	for y in range(pixel_size.y):
		for x in range(pixel_size.x):
			var baseline_color: Color = image.get_pixelv(baseline_origin + Vector2i(x, y))
			var case_color: Color = image.get_pixelv(case_origin + Vector2i(x, y))
			var delta: float = (
				absf(baseline_color.r - case_color.r)
				+ absf(baseline_color.g - case_color.g)
				+ absf(baseline_color.b - case_color.b)
			)
			if delta > 0.14:
				changed += 1
	return changed


func _measure_bright_core_size(image: Image, case_index: int) -> Vector2i:
	var render_scale: float = minf(float(image.get_width()) / GAME_SIZE.x, float(image.get_height()) / GAME_SIZE.y)
	var game_offset: Vector2 = (Vector2(image.get_size()) - GAME_SIZE * render_scale) * 0.5
	var center := Vector2i(game_offset + Vector2(float(CASE_XS[case_index]), BALL_Y) * render_scale)
	var radius: int = int(round(24.0 * render_scale))
	var min_point := Vector2i(radius, radius)
	var max_point := Vector2i(-radius, -radius)
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var color: Color = image.get_pixelv(center + Vector2i(x, y))
			if maxf(color.r, maxf(color.g, color.b)) < 0.48:
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)
	if max_point.x < min_point.x or max_point.y < min_point.y:
		return Vector2i.ZERO
	return max_point - min_point + Vector2i.ONE


func _resolve_output_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			return ProjectSettings.globalize_path(argument.trim_prefix("--output-dir="))
	return ProjectSettings.globalize_path(
		"res://.godot/codex_artifacts/ball_contact_squash_stretch"
	)
