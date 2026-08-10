extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultNavigationSceneHandler := preload("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

const EXPECTED_VIEWPORT_SIZE := Vector2i(2020, 1246)
const MIN_HOVER_CHANGED_PIXELS := 500
const MIN_NOTICE_CHANGED_PIXELS := 1000
const OUTPUT_DIR := "res://.tmp/plaza_prewarm_notice_vulkan_qa"

var _failures: Array[String] = []


class RetryablePlazaSink:
	extends RefCounted

	var calls := 0

	func enter_plaza() -> bool:
		calls += 1
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage_clear_result_plaza_prewarm_notice_vulkan_qa requires a windowed Vulkan run")
		quit(1)
		return
	var driver := RenderingServer.get_current_rendering_driver_name()
	if driver != "vulkan":
		push_error("stage_clear_result_plaza_prewarm_notice_vulkan_qa requires Vulkan, got %s" % driver)
		quit(1)
		return
	var rendering_method := RenderingServer.get_current_rendering_method()
	if rendering_method != "mobile":
		push_error("stage_clear_result_plaza_prewarm_notice_vulkan_qa requires Mobile, got %s" % rendering_method)
		quit(1)
		return

	var scene := StageClearResultScene.new()
	scene.set("_driven_by_controller", true)
	root.add_child(scene)
	await process_frame
	scene.set("_scroll_phase", StageClearResultInteractionState.PHASE_VISIBLE)
	scene.set("_scroll_timer", 0.95)
	scene.set("timer", 5.0)
	scene.set("_plaza_notice_until", -1.0)

	scene.set("_hovered_button", StageClearResultInteractionState.BUTTON_NONE)
	var no_hover := await _capture_scene(scene)
	var plaza_rect: Rect2 = scene.get("_plaza_button_rect")
	_expect(plaza_rect.has_area(), "production result draw must expose a plaza button rect")

	scene.set("_hovered_button", StageClearResultInteractionState.BUTTON_PLAZA)
	var hovered := await _capture_scene(scene)
	var hover_changed_pixels := _count_changed_pixels(no_hover, hovered, plaza_rect)
	_expect(
		hover_changed_pixels >= MIN_HOVER_CHANGED_PIXELS,
		"enabled plaza hover must change a non-vacuous button ROI (%d)" % hover_changed_pixels
	)

	var sink := RetryablePlazaSink.new()
	scene.enter_plaza_callback = Callable(sink, "enter_plaza")
	var handled := StageClearResultNavigationSceneHandler.handle_button_click(scene, plaza_rect.get_center())
	var notice := await _capture_scene(scene)
	var notice_changed_pixels := _count_changed_pixels(hovered, notice)
	_expect(handled, "production plaza button click must remain handled while readiness yields")
	_expect(sink.calls == 1, "production plaza button click must invoke the readiness callback once")
	_expect(scene.enter_plaza_callback.is_valid(), "readiness-yield click must restore the production callback")
	_expect(
		float(scene.get("_plaza_notice_until")) > float(scene.get("timer")),
		"readiness-yield click must arm preparation feedback past the current timer"
	)
	_expect(
		notice_changed_pixels >= MIN_NOTICE_CHANGED_PIXELS,
		"production click must produce a non-vacuous preparation notice delta (%d)" % notice_changed_pixels
	)
	_expect(no_hover.get_size() == EXPECTED_VIEWPORT_SIZE, "capture must use the 2020x1246 acceptance viewport")

	_save_evidence(no_hover, hovered, notice, {
		"driver": driver,
		"rendering_method": rendering_method,
		"viewport_size": no_hover.get_size(),
		"plaza_rect": plaza_rect,
		"hover_changed_pixels": hover_changed_pixels,
		"notice_changed_pixels": notice_changed_pixels,
		"production_click_handled": handled,
		"production_callback_calls": sink.calls,
		"production_callback_restored": scene.enter_plaza_callback.is_valid(),
		"production_notice_until": float(scene.get("_plaza_notice_until")),
	})

	scene.queue_free()
	if _failures.is_empty():
		print("stage_clear_result_plaza_prewarm_notice_vulkan_qa: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _capture_scene(scene: Control) -> Image:
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _count_changed_pixels(before: Image, after: Image, roi: Rect2 = Rect2()) -> int:
	if before == null or after == null or before.get_size() != after.get_size():
		return 0
	var bounds := Rect2i(Vector2i.ZERO, before.get_size())
	if roi.has_area():
		bounds = Rect2i(
			Vector2i(floor(roi.position.x), floor(roi.position.y)),
			Vector2i(ceil(roi.size.x), ceil(roi.size.y))
		).intersection(bounds)
	var changed := 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	return changed


func _save_evidence(no_hover: Image, hovered: Image, notice: Image, metrics: Dictionary) -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK:
		_failures.append("failed to create Vulkan notice evidence directory: %d" % mkdir_error)
		return
	var no_hover_path := OUTPUT_DIR + "/no_hover.png"
	var hovered_path := OUTPUT_DIR + "/hovered.png"
	var notice_path := OUTPUT_DIR + "/notice.png"
	var metrics_path := OUTPUT_DIR + "/metrics.json"
	if no_hover.save_png(no_hover_path) != OK:
		_failures.append("failed to save no-hover Vulkan evidence")
	if hovered.save_png(hovered_path) != OK:
		_failures.append("failed to save hovered Vulkan evidence")
	if notice.save_png(notice_path) != OK:
		_failures.append("failed to save notice Vulkan evidence")
	var metrics_file := FileAccess.open(metrics_path, FileAccess.WRITE)
	if metrics_file == null:
		_failures.append("failed to open Vulkan notice metrics output")
		return
	metrics_file.store_string(JSON.stringify(metrics, "  "))
	metrics_file.flush()
	metrics_file.close()
	for evidence_path in [no_hover_path, hovered_path, notice_path, metrics_path]:
		if not FileAccess.file_exists(evidence_path):
			_failures.append("missing Vulkan notice evidence: %s" % evidence_path)
	if FileAccess.get_file_as_string(metrics_path).is_empty():
		_failures.append("Vulkan notice metrics output must not be empty")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
