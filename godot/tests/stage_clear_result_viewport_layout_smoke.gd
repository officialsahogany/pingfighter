extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultViewportLayout := preload("res://scripts/ui/stage_clear_result_viewport_layout.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_scale_and_fallbacks()
	_verify_control_sync()
	_verify_scene_delegates_viewport_layout()

	if _failures.is_empty():
		print("stage_clear_result_viewport_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scale_and_fallbacks() -> void:
	_expect(StageClearResultViewportLayout.get_layout_scale(Vector2.ZERO) == 1.0, "zero view size should keep scale 1")
	_expect(is_equal_approx(StageClearResultViewportLayout.get_layout_scale(Vector2(960.0, 540.0)), 0.5), "half 16:9 viewport should scale to 0.5")
	_expect(is_equal_approx(StageClearResultViewportLayout.get_layout_scale(Vector2(1920.0, 540.0)), 0.5), "height should constrain wide viewport scale")
	_expect(StageClearResultViewportLayout.get_view_size(null) == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "null control should use default view size")
	_expect(StageClearResultViewportLayout.get_current_view_size(null) == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "null current size should use default view size")


func _verify_control_sync() -> void:
	var control := Control.new()
	control.size = Vector2(320.0, 240.0)
	control.anchor_left = 0.2
	control.anchor_top = 0.3
	control.anchor_right = 0.8
	control.anchor_bottom = 0.9
	control.position = Vector2(44.0, 55.0)
	var synced_size: Vector2 = StageClearResultViewportLayout.sync_control_to_viewport(control)
	_expect(synced_size == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "detached control sync should use default viewport size")
	_expect(control.anchor_left == 0.0 and control.anchor_top == 0.0, "sync should reset top-left anchors")
	_expect(control.anchor_right == 0.0 and control.anchor_bottom == 0.0, "sync should reset bottom-right anchors")
	_expect(control.position == Vector2.ZERO, "sync should reset position")
	_expect(control.size == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "sync should apply view size")
	control.free()


func _verify_scene_delegates_viewport_layout() -> void:
	var scene := StageClearResultScene.new()
	_expect(StageClearResultViewportSceneHandler.get_view_size(scene) == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "viewport scene handler should use layout helper fallback")
	_expect(StageClearResultViewportSceneHandler.get_current_view_size(scene) == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "viewport scene handler current-size lookup should use layout helper fallback")
	_expect(is_equal_approx(StageClearResultViewportSceneHandler.get_layout_scale(Vector2(960.0, 540.0)), 0.5), "viewport scene handler scale lookup should use layout helper math")
	StageClearResultViewportSceneHandler.sync_control_to_viewport(scene)
	_expect(scene.size == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "viewport scene handler sync should apply layout helper size")
	scene.free()

	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var viewport_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")
	var scene_handler_paths: Array[String] = [
		"res://scripts/ui/stage_clear_result_actor_click_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_box_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_draw_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_navigation_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_scroll_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_update_scene_handler.gd",
	]
	_expect(viewport_scene_handler_source.find("static func get_current_view_size") >= 0, "viewport scene handler should expose current view-size scene glue")
	_expect(viewport_scene_handler_source.find("static func sync_control_to_viewport") >= 0, "viewport scene handler should expose viewport sync scene glue")
	_expect(viewport_scene_handler_source.find("static func get_layout_scale") >= 0, "viewport scene handler should expose layout scale scene glue")
	_expect(source.find("StageClearResultViewportSceneHandler.get_current_view_size") < 0, "result scene should not keep current view-size pass-through glue")
	_expect(source.find("StageClearResultViewportSceneHandler.sync_control_to_viewport") < 0, "result scene should not keep viewport sync pass-through glue")
	_expect(source.find("StageClearResultViewportSceneHandler.get_layout_scale") < 0, "result scene should not keep layout scale pass-through glue")
	_expect(source.find("StageClearResultViewportLayout.") < 0, "result scene should not call viewport layout directly")
	_expect(config_scene_handler_source.find("StageClearResultViewportSceneHandler.sync_control_to_viewport") >= 0, "config scene handler should delegate viewport sync through viewport scene glue")
	_expect(config_scene_handler_source.find("StageClearResultViewportLayout.") < 0, "config scene handler should not call viewport layout directly")
	for scene_handler_path in scene_handler_paths:
		var scene_handler_source: String = FileAccess.get_file_as_string(scene_handler_path)
		_expect(
			scene_handler_source.find("StageClearResultViewportSceneHandler.") >= 0,
			"%s should use viewport scene glue" % scene_handler_path
		)
		_expect(
			scene_handler_source.find("StageClearResultViewportLayout.") < 0,
			"%s should not call viewport layout directly" % scene_handler_path
		)
	_expect(viewport_scene_handler_source.find("StageClearResultViewportLayout.get_current_view_size") >= 0, "viewport scene handler should delegate current view-size lookup to layout helper")
	_expect(viewport_scene_handler_source.find("StageClearResultViewportLayout.sync_control_to_viewport") >= 0, "viewport scene handler should delegate viewport sync to layout helper")
	_expect(viewport_scene_handler_source.find("StageClearResultViewportLayout.get_layout_scale") >= 0, "viewport scene handler should delegate scale math to layout helper")
	_expect(source.find("view_size.x / 1920.0") < 0, "result scene should not keep 1920 layout scale math inline")
	_expect(source.find("get_visible_rect().size") < 0, "result scene should not read viewport size inline")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
