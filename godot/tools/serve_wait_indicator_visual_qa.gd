extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ServeWaitIndicatorRenderer := preload("res://scripts/hud/serve_wait_indicator_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const PANEL_RECT := Rect2i(180, 18, 400, 132)
const BAR_RECT := Rect2i(225, 84, 310, 24)
const TITLE_RECT := Rect2i(210, 35, 340, 46)
const STATUS_RECT := Rect2i(210, 108, 340, 30)
const OUTPUT_DIR := "res://.godot/codex_captures/serve_wait_indicator"
const EARLY_PATH := OUTPUT_DIR + "/01_korean_gathering_025.png"
const LATE_PATH := OUTPUT_DIR + "/02_korean_gathering_070.png"
const READY_PATH := OUTPUT_DIR + "/03_korean_ready.png"
const STRIP_PATH := OUTPUT_DIR + "/boss_serve_wait_korean_vulkan_strip.png"

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var serve_timer := 0.0
	var serve_delay := 1.0

	func is_waiting_for_serve() -> bool:
		return true

	func does_player_serve() -> bool:
		return false

	func get_snapshot() -> Dictionary:
		return {
			"serve_timer": serve_timer,
			"serve_delay": serve_delay,
		}

	func is_round_restart_notice_active() -> bool:
		return false

	func is_serve_banner_active() -> bool:
		return false


class ServeCanvas:
	extends Node2D

	var renderer: Object
	var round_state: Object

	func _draw() -> void:
		for band in range(15):
			var shade := 0.035 + float(band) * 0.002
			draw_rect(
				Rect2(0.0, float(band) * 50.0, float(VIEW_SIZE.x), 51.0),
				Color(shade, shade * 1.08, shade * 0.91),
				true
			)
		renderer.draw(
			self,
			float(VIEW_SIZE.x),
			float(VIEW_SIZE.y),
			{"current_stage": 1},
			{"round_state": round_state}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("serve-wait visual QA requires a real window")
	if RenderingServer.get_rendering_device() == null:
		_fail("serve-wait visual QA requires a Vulkan rendering device")
	if not _failures.is_empty():
		_finish()
		return

	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var renderer := ServeWaitIndicatorRenderer.new()
	var early := await _capture(renderer, 0.25)
	var late := await _capture(renderer, 0.70)
	var ready := await _capture(renderer, 1.0)
	for image_value in [early, late, ready]:
		(image_value as Image).convert(Image.FORMAT_RGBA8)

	var early_gold := _count_gold_pixels(early, BAR_RECT)
	var late_gold := _count_gold_pixels(late, BAR_RECT)
	var ready_gold := _count_gold_pixels(ready, BAR_RECT)
	var changed_pixels := _count_changed_pixels(late, ready, PANEL_RECT)
	var title_light_pixels := _count_light_pixels(early, TITLE_RECT)
	var status_light_pixels := _count_light_pixels(early, STATUS_RECT)
	_expect(early_gold > 180, "early gathering frame should show a readable gold charge segment")
	_expect(late_gold > early_gold + 500, "gold charge pixels should grow substantially before ready")
	_expect(ready_gold > late_gold + 350, "ready frame should complete the layered charge fill")
	_expect(changed_pixels > 900, "gathering and ready frames should be visibly distinct")
	_expect(title_light_pixels > 150, "localized boss serve title should remain immediately readable")
	_expect(status_light_pixels > 70, "localized gathering status should remain immediately readable")

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create serve-wait capture directory")
	else:
		_expect(early.save_png(ProjectSettings.globalize_path(EARLY_PATH)) == OK, "early capture should save")
		_expect(late.save_png(ProjectSettings.globalize_path(LATE_PATH)) == OK, "late capture should save")
		_expect(ready.save_png(ProjectSettings.globalize_path(READY_PATH)) == OK, "ready capture should save")
		var strip := Image.create(VIEW_SIZE.x * 3, VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
		strip.fill(Color.BLACK)
		strip.blit_rect(early, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i.ZERO)
		strip.blit_rect(late, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i(VIEW_SIZE.x, 0))
		strip.blit_rect(ready, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i(VIEW_SIZE.x * 2, 0))
		_expect(strip.save_png(ProjectSettings.globalize_path(STRIP_PATH)) == OK, "three-frame strip should save")

	print(
		"[ServeWaitIndicatorQA] DEVICE=%s EARLY_GOLD=%d LATE_GOLD=%d READY_GOLD=%d PREP_READY_CHANGED=%d TITLE_LIGHT=%d STATUS_LIGHT=%d VULKAN=true"
		% [
			RenderingServer.get_video_adapter_name(),
			early_gold,
			late_gold,
			ready_gold,
			changed_pixels,
			title_light_pixels,
			status_light_pixels,
		]
	)
	print("[ServeWaitIndicatorQA] evidence=%s" % STRIP_PATH)
	_finish()


func _capture(renderer: Object, serve_timer: float) -> Image:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var state := FakeRoundState.new()
	state.serve_timer = serve_timer
	var canvas := ServeCanvas.new()
	canvas.renderer = renderer
	canvas.round_state = state
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


func _count_gold_pixels(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y_value in range(rect.position.y, rect.end.y):
		for x_value in range(rect.position.x, rect.end.x):
			var color := image.get_pixel(x_value, y_value)
			if color.r >= 0.42 and color.g >= 0.21 and color.g > color.b * 1.32:
				count += 1
	return count


func _count_light_pixels(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y_value in range(rect.position.y, rect.end.y):
		for x_value in range(rect.position.x, rect.end.x):
			var color := image.get_pixel(x_value, y_value)
			if maxf(color.r, maxf(color.g, color.b)) >= 0.58:
				count += 1
	return count


func _count_changed_pixels(first: Image, second: Image, rect: Rect2i) -> int:
	var count := 0
	for y_value in range(rect.position.y, rect.end.y):
		for x_value in range(rect.position.x, rect.end.x):
			var a := first.get_pixel(x_value, y_value)
			var b := second.get_pixel(x_value, y_value)
			var delta := maxf(
				absf(a.r - b.r),
				maxf(absf(a.g - b.g), absf(a.b - b.b))
			)
			if delta > 3.0 / 255.0:
				count += 1
	return count


func _finish() -> void:
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("serve_wait_indicator_visual_qa: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
