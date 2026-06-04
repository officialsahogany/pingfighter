extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_scroll_button_layout()
	_verify_button_hit_state()
	_verify_box_hit_state()
	_verify_box_state_counts()
	_verify_scene_delegates_interaction_state()

	if _failures.is_empty():
		print("stage_clear_result_interaction_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scroll_button_layout() -> void:
	var layout: Dictionary = StageClearResultInteractionState.get_scroll_button_layout(
		Rect2(Vector2(100.0, 200.0), Vector2(700.0, 400.0)),
		1.0
	)
	var next_rect: Rect2 = layout.get("next_stage_rect", Rect2())
	var exit_rect: Rect2 = layout.get("exit_rect", Rect2())
	_expect(next_rect == Rect2(Vector2(156.0, 510.0), Vector2(280.0, 64.0)), "button layout should center the next-stage button")
	_expect(exit_rect == Rect2(Vector2(464.0, 510.0), Vector2(280.0, 64.0)), "button layout should place the exit button after the gap")

	var scaled_layout: Dictionary = StageClearResultInteractionState.get_scroll_button_layout(
		Rect2(Vector2.ZERO, Vector2(900.0, 600.0)),
		0.5
	)
	var scaled_next: Rect2 = scaled_layout.get("next_stage_rect", Rect2())
	_expect(scaled_next.size == Vector2(140.0, 32.0), "button layout should scale button size")


func _verify_button_hit_state() -> void:
	var next_rect := Rect2(Vector2(10.0, 10.0), Vector2(100.0, 40.0))
	var exit_rect := Rect2(Vector2(130.0, 10.0), Vector2(100.0, 40.0))
	_expect(
		StageClearResultInteractionState.get_hovered_button(Vector2(30.0, 20.0), next_rect, exit_rect) == StageClearResultInteractionState.BUTTON_NEXT_STAGE,
		"hover state should identify the next-stage button"
	)
	_expect(
		StageClearResultInteractionState.get_hovered_button(Vector2(150.0, 20.0), next_rect, exit_rect) == StageClearResultInteractionState.BUTTON_EXIT,
		"hover state should identify the exit button"
	)
	_expect(
		StageClearResultInteractionState.get_hovered_button(Vector2(300.0, 20.0), next_rect, exit_rect) == StageClearResultInteractionState.BUTTON_NONE,
		"hover state should ignore misses"
	)
	_expect(
		StageClearResultInteractionState.get_clicked_button(Vector2(30.0, 20.0), next_rect, exit_rect, "hidden") == StageClearResultInteractionState.BUTTON_NONE,
		"click state should ignore buttons before the scroll is visible"
	)
	_expect(
		StageClearResultInteractionState.get_clicked_button(Vector2(150.0, 20.0), next_rect, exit_rect, "visible") == StageClearResultInteractionState.BUTTON_EXIT,
		"click state should report visible-scroll button hits"
	)


func _verify_box_hit_state() -> void:
	var boxes := [
		{"state": "idle", "base_pos": Vector2(100.0, 100.0), "amplitude": 0.0, "speed": 0.0},
		{"state": "opened", "base_pos": Vector2(160.0, 100.0), "amplitude": 0.0, "speed": 0.0},
		{"state": "idle", "base_pos": Vector2(220.0, 100.0), "amplitude": 0.0, "speed": 0.0},
	]
	_expect(
		StageClearResultInteractionState.get_hovered_box_index(
			boxes, Vector2(220.0, 100.0), 1.0, 0.0, StageClearResultScene.BOX_BASE_SIZE, StageClearResultScene.BOX_HOVER_GROW, 0.0, 0.0
		) == 2,
		"hovered box hit-test should prefer the topmost matching box"
	)
	_expect(
		StageClearResultInteractionState.get_clicked_idle_box_index(
			boxes, Vector2(160.0, 100.0), 1.0, 0.0, StageClearResultScene.BOX_BASE_SIZE, StageClearResultScene.BOX_HOVER_GROW, 0.0, 0.0
		) == -1,
		"clicked idle box hit-test should ignore opened boxes"
	)
	_expect(
		StageClearResultInteractionState.get_clicked_idle_box_index(
			boxes, Vector2(100.0, 100.0), 1.0, 0.0, StageClearResultScene.BOX_BASE_SIZE, StageClearResultScene.BOX_HOVER_GROW, 0.0, 0.0
		) == 0,
		"clicked idle box hit-test should report idle box hits"
	)


func _verify_box_state_counts() -> void:
	var boxes := [
		{"state": "opened"},
		{"state": "opening"},
		{"state": "idle"},
		"bad",
	]
	var counts: Dictionary = StageClearResultInteractionState.get_box_state_counts(boxes)
	_expect(int(counts.get("opened_count", -1)) == 1, "box counts should count opened boxes")
	_expect(int(counts.get("opening_count", -1)) == 1, "box counts should count opening boxes")
	_expect(not StageClearResultInteractionState.all_boxes_opened([]), "empty boxes should not count as all opened")
	_expect(not StageClearResultInteractionState.all_boxes_opened(boxes), "mixed boxes should not count as all opened")
	_expect(StageClearResultInteractionState.all_boxes_opened([{"state": "opened"}, {"state": "opened"}]), "opened boxes should count as all opened")


func _verify_scene_delegates_interaction_state() -> void:
	var scene := StageClearResultScene.new()
	scene.size = Vector2(1920.0, 1080.0)
	scene._scroll_phase = StageClearResultInteractionState.PHASE_VISIBLE
	scene._scroll_timer = StageClearResultScene.SCROLL_UNFURL_DURATION
	scene._refresh_scroll_button_rects()
	scene._update_hovered_button(scene._exit_button_rect.get_center())
	_expect(str(scene.get_interaction_status().get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_EXIT, "scene hovered-button wrapper should delegate")

	scene._boxes = [{"state": "opened"}, {"state": "opening"}]
	var status: Dictionary = scene.get_interaction_status()
	_expect(int(status.get("opened_count", -1)) == 1, "scene interaction status should use delegated opened count")
	_expect(int(status.get("opening_count", -1)) == 1, "scene interaction status should use delegated opening count")
	_expect(not StageClearResultInteractionState.all_boxes_opened(scene._boxes), "scene boxes should remain compatible with all-open helper")
	scene._boxes = [{"state": "opened"}, {"state": "opened"}]
	_expect(StageClearResultInteractionState.all_boxes_opened(scene._boxes), "scene boxes should report opened state through helper")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("StageClearResultInteractionState.all_boxes_opened") >= 0,
		"result scene should call all-boxes-open helper directly"
	)
	_expect(
		source.find("StageClearResultInteractionState.get_hovered_box_index") >= 0
			and source.find("StageClearResultInteractionState.get_clicked_idle_box_index") >= 0,
		"result scene should delegate box hover and click hit-tests"
	)
	_expect(
		source.find("func _all_boxes_opened") < 0,
		"result scene should not keep all-boxes-open pass-through wrapper"
	)
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
