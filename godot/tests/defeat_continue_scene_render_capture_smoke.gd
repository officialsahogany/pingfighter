extends SceneTree

const DefeatChanceGemsContinueScreen := preload("res://scripts/core/defeat_chance_gems_continue_screen.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(1280.0, 720.0)
const CAPTURE_DIR := "res://../.tmp/defeat_continue_scene_capture"

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var current_stage: int = 1
	var chance_gems_count: int = 3
	var chance_gems_max: int = 3


class FakeResources:
	extends RefCounted

	var _cache: Dictionary = {}

	func _init() -> void:
		var real_boss := ProjectResourceLoader.load_imported_texture(
			"res://assets/sprites/stage1/dalji/dalji_boss_victory.png",
			"Missing Dalji victory capture texture at %s",
			"Failed to load Dalji victory capture texture at %s"
		)
		if real_boss != null:
			_cache["boss_victory_sheet"] = real_boss
			return
		var image := Image.create(400, 200, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.10, 0.28, 0.58, 1.0))
		for row in range(2):
			for col in range(4):
				var tint := Color(0.22 + float(col) * 0.08, 0.52 + float(row) * 0.12, 0.92, 1.0)
				image.fill_rect(Rect2i(col * 100 + 12, row * 100 + 10, 76, 80), tint)
		_cache["boss_victory_sheet"] = ImageTexture.create_from_image(image)

	func get_resource_cache() -> Dictionary:
		return _cache


class FakeRegistry:
	extends RefCounted

	var resources := FakeResources.new()

	func get_instance(key: String) -> Object:
		if key == "battle_resources":
			return resources
		return null


class DrawProbe:
	extends Control

	var screen: Object = null
	var battle_owner: Object = null
	var registry: Object = null

	func _draw() -> void:
		screen.draw(self, battle_owner, registry, VIEW_SIZE)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("defeat_continue_scene_render_capture_smoke: capture skipped under headless display server")
		print("defeat_continue_scene_render_capture_smoke: ok")
		quit(0)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var screen := DefeatChanceGemsContinueScreen.new()
	screen.prewarm_assets()
	screen.active = true
	screen.remaining_gems = 3
	screen.max_gems = 3
	screen.elapsed_sec = 0.80
	screen.reveal_elapsed = 0.55
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var probe := DrawProbe.new()
	probe.size = VIEW_SIZE
	probe.screen = screen
	probe.battle_owner = owner
	probe.registry = registry
	viewport.add_child(owner)
	viewport.add_child(probe)
	var present_image := await _capture(viewport, probe)
	_expect(present_image != null and not present_image.is_empty(), "present-state capture must produce a viewport image")
	if present_image != null and not present_image.is_empty():
		_verify_visible_pixels(present_image)
		_save_evidence(present_image, "present")

	screen.remaining_gems = 2
	screen._cinematic_state.reset(2)
	var spent_image := await _capture(viewport, probe)
	_expect(spent_image != null and not spent_image.is_empty(), "spent-state capture must produce a viewport image")
	if spent_image != null and not spent_image.is_empty():
		_save_evidence(spent_image, "spent")
	if present_image != null and spent_image != null:
		_verify_spent_gem_delta(present_image, spent_image)

	screen.remaining_gems = 3
	screen._cinematic_state.reset(3)
	screen._cinematic_state.begin_consuming()
	screen._cinematic_state.set_post_consume_remaining(2, 3)
	screen._cinematic_state.confirm_elapsed = 2.12
	var shatter_image := await _capture(viewport, probe)
	_expect(shatter_image != null and not shatter_image.is_empty(), "shatter-state capture must produce a viewport image")
	if shatter_image != null and not shatter_image.is_empty():
		_verify_visible_pixels(shatter_image)
		_save_evidence(shatter_image, "shatter")
	if present_image != null and shatter_image != null:
		_verify_shatter_delta(present_image, shatter_image)

	screen._cinematic_state.confirm_elapsed = 2.60
	var whiteout_image := await _capture(viewport, probe)
	_expect(whiteout_image != null and not whiteout_image.is_empty(), "whiteout-state capture must produce a viewport image")
	if whiteout_image != null and not whiteout_image.is_empty():
		_save_evidence(whiteout_image, "whiteout")
	if shatter_image != null and whiteout_image != null:
		_verify_whiteout_delta(shatter_image, whiteout_image)

	viewport.queue_free()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("defeat_continue_scene_render_capture_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture(viewport: SubViewport, probe: Control) -> Image:
	probe.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _verify_visible_pixels(image: Image) -> void:
	var visible_samples := 0
	var cool_highlight_samples := 0
	var total_samples := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			total_samples += 1
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.90 and pixel.r + pixel.g + pixel.b > 0.06:
				visible_samples += 1
			if pixel.a > 0.70 and pixel.b > 0.42 and pixel.b > pixel.r * 1.12:
				cool_highlight_samples += 1
	_expect(visible_samples > int(float(total_samples) * 0.72), "full-screen defeat backdrop must cover most captured pixels")
	_expect(cool_highlight_samples > 900, "portal/reveal/ambient layers must leave a visible cool-highlight footprint")


func _verify_shatter_delta(present_image: Image, shatter_image: Image) -> void:
	var changed_pixels := 0
	var roi := Rect2i(420, 430, 220, 220)
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var present := present_image.get_pixel(x, y)
			var shatter := shatter_image.get_pixel(x, y)
			var delta := absf(present.r - shatter.r) + absf(present.g - shatter.g) + absf(present.b - shatter.b)
			if delta > 0.12:
				changed_pixels += 1
	_expect(changed_pixels > 1800, "shatter state must materially change the first-gem impact region")


func _verify_spent_gem_delta(present_image: Image, spent_image: Image) -> void:
	var changed_pixels := 0
	var roi := Rect2i(480, 485, 76, 88)
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var present := present_image.get_pixel(x, y)
			var spent := spent_image.get_pixel(x, y)
			var delta := absf(present.r - spent.r) + absf(present.g - spent.g) + absf(present.b - spent.b)
			if delta > 0.10:
				changed_pixels += 1
	_expect(changed_pixels > 420, "spent capture must visibly replace the first intact jade ward with its broken authored state")


func _verify_whiteout_delta(shatter_image: Image, whiteout_image: Image) -> void:
	var brighter_samples := 0
	var total_samples := 0
	for y in range(0, whiteout_image.get_height(), 4):
		for x in range(0, whiteout_image.get_width(), 4):
			total_samples += 1
			var before := shatter_image.get_pixel(x, y)
			var after := whiteout_image.get_pixel(x, y)
			var brightness_gain := (after.r + after.g + after.b) - (before.r + before.g + before.b)
			if brightness_gain > 0.24:
				brighter_samples += 1
	_expect(
		brighter_samples > int(float(total_samples) * 0.60),
		"whiteout overlay must brighten most of the visible frame"
	)


func _save_evidence(image: Image, slug: String) -> void:
	var output_path := ProjectSettings.globalize_path(
		"%s/defeat_continue_scene_%s_%d.png" % [CAPTURE_DIR, slug, OS.get_process_id()]
	)
	var dir_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if dir_error != OK:
		_failures.append("capture evidence directory creation failed (%d)" % dir_error)
		return
	var save_error := image.save_png(output_path)
	if save_error != OK:
		_failures.append("capture evidence save failed (%d)" % save_error)
		return
	if not FileAccess.file_exists(output_path):
		_failures.append("capture evidence file is missing after save")
		return
	print("defeat_continue_scene_render_capture_smoke: evidence %s" % output_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
