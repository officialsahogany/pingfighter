extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultViewportLayout := preload("res://scripts/ui/stage_clear_result_viewport_layout.gd")

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
	_expect(scene._get_view_size() == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "scene view-size wrapper should use layout helper fallback")
	_expect(scene._get_current_view_size() == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "scene current-size wrapper should use layout helper fallback")
	_expect(is_equal_approx(scene._get_layout_scale(Vector2(960.0, 540.0)), 0.5), "scene scale wrapper should use layout helper math")
	scene._sync_viewport_size()
	_expect(scene.size == StageClearResultViewportLayout.DEFAULT_VIEW_SIZE, "scene sync wrapper should apply layout helper size")
	scene.free()

	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultViewportLayout.get_current_view_size") >= 0, "result scene should delegate current view-size lookup")
	_expect(source.find("StageClearResultViewportLayout.sync_control_to_viewport") >= 0, "result scene should delegate viewport sync")
	_expect(source.find("StageClearResultViewportLayout.get_layout_scale") >= 0, "result scene should delegate layout scale math")
	_expect(source.find("view_size.x / 1920.0") < 0, "result scene should not keep 1920 layout scale math inline")
	_expect(source.find("get_visible_rect().size") < 0, "result scene should not read viewport size inline")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
