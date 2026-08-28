extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ServeWaitIndicatorRenderer := preload("res://scripts/hud/serve_wait_indicator_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const FULL_RECT := Rect2i(Vector2i.ZERO, VIEW_SIZE)
const TITLE_RECT := Rect2i(230, 58, 300, 50)
const STATUS_RECT := Rect2i(260, 98, 240, 42)
const CENTER_BANNER_RECT := Rect2i(180, 320, 400, 110)
const BOSS_SOURCE_RECT := Rect2i(0, 0, 256, 256)
const BOSS_DRAW_RECT := Rect2(87.0, 3.0, 96.0, 112.0)
const PLAYER_DRAW_RECT := Rect2(255.0, 626.0, 250.0, 120.0)
const BOSS_SOURCE_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_idle_8f_autosprite_v1_pro.png"
const PLAYER_SOURCE_PATH := "res://assets/sprites/smasher_current_idle.png"
const OUTPUT_DIR := "res://.godot/codex_captures/serve_wait_indicator"
const PREPARING_PATH := OUTPUT_DIR + "/01_gaksital_korean_preparing.png"
const READY_PATH := OUTPUT_DIR + "/02_gaksital_korean_ready.png"
const BANNER_PATH := OUTPUT_DIR + "/03_gaksital_korean_serve_banner.png"
const STRIP_PATH := OUTPUT_DIR + "/gaksital_serve_wait_variant_vulkan.png"
const PIXEL_DELTA := 3.0 / 255.0

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var serve_timer := 0.0
	var serve_delay := 1.0
	var serve_banner_active := false

	func is_waiting_for_serve() -> bool:
		return true

	func does_player_serve() -> bool:
		return false

	func get_snapshot() -> Dictionary:
		return {
			"serve_timer": serve_timer,
			"serve_delay": serve_delay,
			"serve_banner_timer": 0.5,
			"serve_banner_duration": 0.85,
		}

	func is_round_restart_notice_active() -> bool:
		return false

	func is_serve_banner_active() -> bool:
		return serve_banner_active


class ServeCanvas:
	extends Node2D

	var renderer: Object
	var round_state: Object
	var boss_texture: Texture2D
	var player_texture: Texture2D
	var draw_actors := false
	var draw_overlay := false

	func _draw() -> void:
		for band in range(15):
			var shade := 0.035 + float(band) * 0.002
			draw_rect(
				Rect2(0.0, float(band) * 50.0, float(VIEW_SIZE.x), 51.0),
				Color(shade, shade * 1.08, shade * 0.91),
				true
			)
		if draw_actors:
			draw_texture_rect_region(boss_texture, BOSS_DRAW_RECT, BOSS_SOURCE_RECT)
			draw_texture_rect(player_texture, PLAYER_DRAW_RECT, false)
		if draw_overlay:
			renderer.draw(
				self,
				float(VIEW_SIZE.x),
				float(VIEW_SIZE.y),
				{
					"current_stage": 1,
					"stage1_boss_variant": "gaksi",
					"stage_boss_variant": "alice",
				},
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

	var boss_texture := _load_source_texture(BOSS_SOURCE_PATH)
	var player_texture := _load_source_texture(PLAYER_SOURCE_PATH)
	if boss_texture == null or player_texture == null:
		_finish()
		return

	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var renderer := ServeWaitIndicatorRenderer.new()
	var variant_context := {
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
		"stage_boss_variant": "alice",
	}
	_expect(renderer._get_serve_label(false, variant_context) == "각시탈 차례", "the visual fixture should use the separate Stage 1 Gaksital authority")
	var background := await _capture(renderer, 0.25, false, false, false, boss_texture, player_texture)
	var actors := await _capture(renderer, 0.25, true, false, false, boss_texture, player_texture)
	var preparing := await _capture(renderer, 0.25, true, true, false, boss_texture, player_texture)
	var ready := await _capture(renderer, 1.0, true, true, false, boss_texture, player_texture)
	var banner := await _capture(renderer, 0.25, true, true, true, boss_texture, player_texture)
	for image_value in [background, actors, preparing, ready, banner]:
		(image_value as Image).convert(Image.FORMAT_RGBA8)

	var actor_pixels := _count_changed_pixels(background, actors, FULL_RECT)
	var overlay_pixels := _count_changed_pixels(actors, preparing, FULL_RECT)
	var actor_overlap := _count_change_overlap(background, actors, preparing, FULL_RECT)
	var prep_ready_changed := _count_changed_pixels(preparing, ready, STATUS_RECT)
	var banner_changed := _count_changed_pixels(preparing, banner, FULL_RECT)
	var title_light_pixels := _count_light_pixels(preparing, TITLE_RECT)
	var status_light_pixels := _count_light_pixels(preparing, STATUS_RECT)
	var center_light_pixels := _count_light_pixels(banner, CENTER_BANNER_RECT)
	_expect(actor_pixels > 3500, "the production Gaksital and Smasher sources should be visibly rendered")
	_expect(overlay_pixels > 300, "the reverted title, accent line, and status should be visible")
	_expect(overlay_pixels < 6500, "the reverted overlay should remain compact without a broad panel")
	_expect(actor_overlap == 0, "the reverted boss wait overlay should not cover either character")
	_expect(prep_ready_changed > 80, "preparing and ready status rows should be visibly distinct")
	_expect(title_light_pixels > 150, "the Korean boss-turn title should remain readable")
	_expect(status_light_pixels > 45, "the Korean preparing status should remain readable")
	_expect(banner_changed > 100000, "the central serve banner should visibly dim the full playfield")
	_expect(center_light_pixels > 450, "the central Korean Gaksital turn label should remain readable")

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create serve-wait capture directory")
	else:
		_expect(preparing.save_png(ProjectSettings.globalize_path(PREPARING_PATH)) == OK, "preparing capture should save")
		_expect(ready.save_png(ProjectSettings.globalize_path(READY_PATH)) == OK, "ready capture should save")
		_expect(banner.save_png(ProjectSettings.globalize_path(BANNER_PATH)) == OK, "central banner capture should save")
		var strip := Image.create(VIEW_SIZE.x * 3, VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
		strip.fill(Color.BLACK)
		strip.blit_rect(preparing, FULL_RECT, Vector2i.ZERO)
		strip.blit_rect(ready, FULL_RECT, Vector2i(VIEW_SIZE.x, 0))
		strip.blit_rect(banner, FULL_RECT, Vector2i(VIEW_SIZE.x * 2, 0))
		_expect(strip.save_png(ProjectSettings.globalize_path(STRIP_PATH)) == OK, "three-frame Gaksital strip should save")

	print(
		"[ServeWaitIndicatorQA] DEVICE=%s GAKSITAL_LABEL=true ACTOR_PIXELS=%d OVERLAY_PIXELS=%d ACTOR_OVERLAP=%d PREP_READY_CHANGED=%d BANNER_CHANGED=%d TITLE_LIGHT=%d STATUS_LIGHT=%d CENTER_LIGHT=%d VULKAN=true"
		% [
			RenderingServer.get_video_adapter_name(),
			actor_pixels,
			overlay_pixels,
			actor_overlap,
			prep_ready_changed,
			banner_changed,
			title_light_pixels,
			status_light_pixels,
			center_light_pixels,
		]
	)
	print("[ServeWaitIndicatorQA] evidence=%s" % STRIP_PATH)
	_finish()


func _load_source_texture(resource_path: String) -> ImageTexture:
	var source_path := ProjectSettings.globalize_path(resource_path)
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		_fail("could not load source image directly: %s" % resource_path)
		return null
	return ImageTexture.create_from_image(image)


func _capture(
	renderer: Object,
	serve_timer: float,
	draw_actors: bool,
	draw_overlay: bool,
	serve_banner_active: bool,
	boss_texture: Texture2D,
	player_texture: Texture2D
) -> Image:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var state := FakeRoundState.new()
	state.serve_timer = serve_timer
	state.serve_banner_active = serve_banner_active
	var canvas := ServeCanvas.new()
	canvas.renderer = renderer
	canvas.round_state = state
	canvas.boss_texture = boss_texture
	canvas.player_texture = player_texture
	canvas.draw_actors = draw_actors
	canvas.draw_overlay = draw_overlay
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


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
			if _pixel_delta(first.get_pixel(x_value, y_value), second.get_pixel(x_value, y_value)) > PIXEL_DELTA:
				count += 1
	return count


func _count_change_overlap(background: Image, actors: Image, combined: Image, rect: Rect2i) -> int:
	var count := 0
	for y_value in range(rect.position.y, rect.end.y):
		for x_value in range(rect.position.x, rect.end.x):
			var actor_changed := _pixel_delta(background.get_pixel(x_value, y_value), actors.get_pixel(x_value, y_value)) > PIXEL_DELTA
			var overlay_changed := _pixel_delta(actors.get_pixel(x_value, y_value), combined.get_pixel(x_value, y_value)) > PIXEL_DELTA
			if actor_changed and overlay_changed:
				count += 1
	return count


func _pixel_delta(first: Color, second: Color) -> float:
	return maxf(
		absf(first.r - second.r),
		maxf(absf(first.g - second.g), absf(first.b - second.b))
	)


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
