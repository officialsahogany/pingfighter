extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultScrollInputHandler := preload("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_button_click_and_hover()
	_verify_drag_lifecycle()
	_verify_apply_payloads()
	_verify_scene_delegates_scroll_input()

	if _failures.is_empty():
		print("stage_clear_result_scroll_input_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_button_click_and_hover() -> void:
	var layout: Dictionary = StageClearResultScrollInputHandler.get_button_layout(
		StageClearResultInteractionState.PHASE_VISIBLE,
		1.0,
		Vector2.ZERO
	)
	var next_rect: Rect2 = layout.get("next_stage_rect", Rect2())
	var plaza_rect: Rect2 = layout.get("plaza_rect", Rect2())
	var exit_rect: Rect2 = layout.get("exit_rect", Rect2())
	_expect(next_rect.size.x > 0.0 and plaza_rect.size.x > 0.0 and exit_rect.size.x > 0.0, "visible scroll should expose button rects")

	var click_result: Dictionary = StageClearResultScrollInputHandler.get_button_click_result(
		exit_rect.get_center(),
		StageClearResultInteractionState.PHASE_VISIBLE,
		1.0,
		Vector2.ZERO
	)
	_expect(str(click_result.get("clicked_button", "")) == StageClearResultInteractionState.BUTTON_EXIT, "button click helper should report exit hits")

	var plaza_click: Dictionary = StageClearResultScrollInputHandler.get_button_click_result(
		plaza_rect.get_center(),
		StageClearResultInteractionState.PHASE_VISIBLE,
		1.0,
		Vector2.ZERO
	)
	_expect(str(plaza_click.get("clicked_button", "")) == StageClearResultInteractionState.BUTTON_PLAZA, "button click helper should report plaza hits")

	var hidden_click: Dictionary = StageClearResultScrollInputHandler.get_button_click_result(
		exit_rect.get_center(),
		"hidden",
		1.0,
		Vector2.ZERO
	)
	_expect(str(hidden_click.get("clicked_button", "")) == StageClearResultInteractionState.BUTTON_NONE, "button click helper should ignore hidden scroll")

	var hover_result: Dictionary = StageClearResultScrollInputHandler.get_hovered_button_result(
		next_rect.get_center(),
		StageClearResultInteractionState.BUTTON_NONE,
		StageClearResultInteractionState.PHASE_VISIBLE,
		1.0,
		Vector2.ZERO
	)
	_expect(str(hover_result.get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_NEXT_STAGE, "hover helper should report next-stage hits")
	_expect(bool(hover_result.get("changed", false)), "hover helper should report changed hover state")


func _verify_drag_lifecycle() -> void:
	var scroll_rect: Rect2 = StageClearResultScrollState.get_region_full_rect(1.0, Vector2.ZERO)
	var start_pos: Vector2 = scroll_rect.position + Vector2(150.0, 135.0)
	var start_result: Dictionary = StageClearResultScrollInputHandler.get_drag_start_result(
		start_pos,
		StageClearResultInteractionState.PHASE_VISIBLE,
		false,
		1.0,
		Vector2.ZERO
	)
	_expect(bool(start_result.get("started", false)), "drag start helper should start on visible scroll body")
	_expect(start_result.get("grab_offset", Vector2.ZERO) == Vector2(150.0, 135.0), "drag start helper should preserve grab offset")

	var update_result: Dictionary = StageClearResultScrollInputHandler.get_drag_update_result(
		start_pos + Vector2(90.0, 35.0),
		start_result.get("grab_offset", Vector2.ZERO),
		StageClearResultInteractionState.PHASE_VISIBLE,
		1.0,
		Vector2(1920.0, 1080.0)
	)
	var offset: Vector2 = update_result.get("position_offset", Vector2.ZERO)
	_expect(offset.distance_to(Vector2(90.0, 35.0)) < 0.1, "drag update helper should move scroll by the mouse delta")
	_expect(update_result.get("next_stage_rect", Rect2()) is Rect2, "drag update helper should refresh button rects")

	var finish_result: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_result(
		start_pos + Vector2(90.0, 35.0),
		start_result.get("grab_offset", Vector2.ZERO),
		StageClearResultInteractionState.PHASE_VISIBLE,
		StageClearResultInteractionState.BUTTON_NONE,
		1.0,
		Vector2(1920.0, 1080.0)
	)
	_expect(finish_result.get("position_offset", Vector2.ZERO) == offset, "drag finish helper should reuse drag-update offset math")
	_expect(finish_result.has("hovered_button"), "drag finish helper should refresh hover state for visible scroll")


func _verify_apply_payloads() -> void:
	var next_rect := Rect2(Vector2(12.0, 24.0), Vector2(120.0, 48.0))
	var plaza_rect := Rect2(Vector2(150.0, 24.0), Vector2(120.0, 48.0))
	var exit_rect := Rect2(Vector2(288.0, 24.0), Vector2(120.0, 48.0))
	var hover_apply: Dictionary = StageClearResultScrollInputHandler.get_hovered_button_apply_result(
		{
			"next_stage_rect": next_rect,
			"plaza_rect": plaza_rect,
			"exit_rect": exit_rect,
			"hovered_button": StageClearResultInteractionState.BUTTON_NEXT_STAGE,
			"changed": true,
		},
		StageClearResultInteractionState.BUTTON_NONE
	)
	_expect(hover_apply.get("next_stage_rect", Rect2()) == next_rect, "hover apply helper should preserve next-stage layout")
	_expect(hover_apply.get("plaza_rect", Rect2()) == plaza_rect, "hover apply helper should preserve plaza layout")
	_expect(hover_apply.get("exit_rect", Rect2()) == exit_rect, "hover apply helper should preserve exit layout")
	_expect(str(hover_apply.get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_NEXT_STAGE, "hover apply helper should apply hovered button")
	_expect(bool(hover_apply.get("redraw", false)), "hover apply helper should redraw when hover changes")

	var missed_start_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_start_apply_result(
		{
			"started": false,
			"button_layout": {
				"next_stage_rect": next_rect,
				"plaza_rect": plaza_rect,
				"exit_rect": exit_rect,
			},
			"grab_offset": Vector2.ZERO,
			"hovered_button": StageClearResultInteractionState.BUTTON_NONE,
		},
		false,
		Vector2(3.0, 4.0),
		StageClearResultInteractionState.BUTTON_EXIT
	)
	_expect(not bool(missed_start_apply.get("started", true)), "drag-start apply helper should preserve missed starts")
	_expect(not bool(missed_start_apply.get("scroll_dragging", true)), "drag-start apply helper should not activate drag for misses")
	_expect(missed_start_apply.get("scroll_drag_grab_offset", Vector2.ZERO) == Vector2(3.0, 4.0), "drag-start apply helper should keep grab offset for misses")
	_expect(str(missed_start_apply.get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_EXIT, "drag-start apply helper should keep hover for misses")
	_expect(not bool(missed_start_apply.get("redraw", true)), "drag-start apply helper should not redraw for misses")

	var started_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_start_apply_result(
		{
			"started": true,
			"button_layout": {
				"next_stage_rect": next_rect,
				"plaza_rect": plaza_rect,
				"exit_rect": exit_rect,
			},
			"grab_offset": Vector2(22.0, 33.0),
			"hovered_button": StageClearResultInteractionState.BUTTON_NONE,
		},
		false,
		Vector2.ZERO,
		StageClearResultInteractionState.BUTTON_EXIT
	)
	_expect(bool(started_apply.get("scroll_dragging", false)), "drag-start apply helper should activate drag when started")
	_expect(started_apply.get("scroll_drag_grab_offset", Vector2.ZERO) == Vector2(22.0, 33.0), "drag-start apply helper should apply grab offset when started")
	_expect(str(started_apply.get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_NONE, "drag-start apply helper should clear hover when started")
	_expect(bool(started_apply.get("redraw", false)), "drag-start apply helper should redraw when started")

	var update_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_update_apply_result(
		{
			"next_stage_rect": next_rect,
			"plaza_rect": plaza_rect,
			"exit_rect": exit_rect,
			"position_offset": Vector2(44.0, 55.0),
		},
		Vector2.ZERO
	)
	_expect(update_apply.get("scroll_position_offset", Vector2.ZERO) == Vector2(44.0, 55.0), "drag-update apply helper should apply drag offset")
	_expect(bool(update_apply.get("redraw", false)), "drag-update apply helper should redraw drag movement")

	var finish_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_apply_result(
		{
			"next_stage_rect": next_rect,
			"plaza_rect": plaza_rect,
			"exit_rect": exit_rect,
			"position_offset": Vector2(66.0, 77.0),
			"hovered_button": StageClearResultInteractionState.BUTTON_EXIT,
		},
		StageClearResultInteractionState.PHASE_VISIBLE,
		Vector2.ZERO,
		StageClearResultInteractionState.BUTTON_NONE
	)
	_expect(finish_apply.get("scroll_position_offset", Vector2.ZERO) == Vector2(66.0, 77.0), "drag-finish apply helper should apply final offset")
	_expect(not bool(finish_apply.get("scroll_dragging", true)), "drag-finish apply helper should clear dragging")
	_expect(str(finish_apply.get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_EXIT, "drag-finish apply helper should refresh visible hover")
	_expect(bool(finish_apply.get("redraw", false)), "drag-finish apply helper should redraw final drag state")

	var hidden_finish_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_apply_result(
		{"position_offset": Vector2(5.0, 6.0)},
		"hidden",
		Vector2.ZERO,
		StageClearResultInteractionState.BUTTON_EXIT
	)
	_expect(not hidden_finish_apply.has("hovered_button"), "hidden drag-finish apply helper should not refresh hover")

	var cancel_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_cancel_apply_result(true)
	_expect(not bool(cancel_apply.get("scroll_dragging", true)), "drag-cancel apply helper should clear active drag")
	_expect(bool(cancel_apply.get("redraw", false)), "drag-cancel apply helper should redraw when drag was active")

	var idle_cancel_apply: Dictionary = StageClearResultScrollInputHandler.get_drag_cancel_apply_result(false)
	_expect(not bool(idle_cancel_apply.get("scroll_dragging", true)), "idle drag-cancel apply helper should keep drag inactive")
	_expect(not bool(idle_cancel_apply.get("redraw", true)), "idle drag-cancel apply helper should not redraw")

	var current_state := {
		"next_stage_rect": next_rect,
		"plaza_rect": plaza_rect,
		"exit_rect": exit_rect,
		"scroll_position_offset": Vector2(4.0, 5.0),
		"scroll_dragging": true,
		"scroll_drag_grab_offset": Vector2(6.0, 7.0),
		"hovered_button": StageClearResultInteractionState.BUTTON_EXIT,
	}
	var scene_apply: Dictionary = StageClearResultScrollInputHandler.get_scroll_state_apply_result(
		{
			"next_stage_rect": Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0)),
			"plaza_rect": Rect2(Vector2(2.0, 3.0), Vector2(4.0, 5.0)),
			"exit_rect": "invalid",
			"scroll_position_offset": Vector2(8.0, 9.0),
			"scroll_dragging": false,
			"scroll_drag_grab_offset": "invalid",
			"hovered_button": StageClearResultInteractionState.BUTTON_NEXT_STAGE,
		},
		current_state
	)
	_expect(scene_apply.get("next_stage_rect", Rect2()).position == Vector2(1.0, 2.0), "scene scroll apply should apply next rect")
	_expect(scene_apply.get("plaza_rect", Rect2()).position == Vector2(2.0, 3.0), "scene scroll apply should apply plaza rect")
	_expect(scene_apply.get("exit_rect", Rect2()) == exit_rect, "invalid exit rect should keep current rect")
	_expect(scene_apply.get("scroll_position_offset", Vector2.ZERO) == Vector2(8.0, 9.0), "scene scroll apply should apply offset")
	_expect(not bool(scene_apply.get("scroll_dragging", true)), "scene scroll apply should apply dragging flag")
	_expect(scene_apply.get("scroll_drag_grab_offset", Vector2.ZERO) == Vector2(6.0, 7.0), "invalid grab offset should keep current grab offset")
	_expect(str(scene_apply.get("hovered_button", "")) == StageClearResultInteractionState.BUTTON_NEXT_STAGE, "scene scroll apply should apply hover")

	var scene_field_apply: Dictionary = StageClearResultScrollInputHandler.get_scroll_state_scene_apply_result(
		{
			"next_stage_rect": Rect2(Vector2(31.0, 32.0), Vector2(33.0, 34.0)),
			"plaza_rect": Rect2(Vector2(32.0, 33.0), Vector2(34.0, 35.0)),
			"exit_rect": "invalid",
			"scroll_position_offset": Vector2(35.0, 36.0),
			"scroll_dragging": false,
			"scroll_drag_grab_offset": "invalid",
			"hovered_button": StageClearResultInteractionState.BUTTON_NEXT_STAGE,
		},
		current_state
	)
	var field_payload_value: Variant = scene_field_apply.get("field_payload", {})
	_expect(field_payload_value is Dictionary, "scene scroll apply helper should wrap scene fields in a field payload")
	var field_payload: Dictionary = field_payload_value if field_payload_value is Dictionary else {}
	_expect((field_payload.get("_next_stage_button_rect", Rect2()) as Rect2).position == Vector2(31.0, 32.0), "scene scroll field payload should write next button rect")
	_expect((field_payload.get("_plaza_button_rect", Rect2()) as Rect2).position == Vector2(32.0, 33.0), "scene scroll field payload should write plaza button rect")
	_expect(field_payload.get("_exit_button_rect", Rect2()) == exit_rect, "scene scroll field payload should keep current exit rect for invalid values")
	_expect(field_payload.get("_scroll_position_offset", Vector2.ZERO) == Vector2(35.0, 36.0), "scene scroll field payload should write offset")
	_expect(not bool(field_payload.get("_scroll_dragging", true)), "scene scroll field payload should write dragging flag")
	_expect(field_payload.get("_scroll_drag_grab_offset", Vector2.ZERO) == Vector2(6.0, 7.0), "scene scroll field payload should keep current grab offset for invalid values")
	_expect(str(field_payload.get("_hovered_button", "")) == StageClearResultInteractionState.BUTTON_NEXT_STAGE, "scene scroll field payload should write hover")

	var scene := StageClearResultScene.new()
	scene.set("_next_stage_button_rect", next_rect)
	scene.set("_plaza_button_rect", plaza_rect)
	scene.set("_exit_button_rect", exit_rect)
	scene.set("_scroll_position_offset", Vector2(4.0, 5.0))
	scene.set("_scroll_dragging", true)
	scene.set("_scroll_drag_grab_offset", Vector2(6.0, 7.0))
	scene.set("_hovered_button", StageClearResultInteractionState.BUTTON_EXIT)
	scene._apply_scroll_state_result({
		"next_stage_rect": Rect2(Vector2(11.0, 12.0), Vector2(13.0, 14.0)),
		"plaza_rect": Rect2(Vector2(12.0, 13.0), Vector2(14.0, 15.0)),
		"scroll_position_offset": Vector2(15.0, 16.0),
		"scroll_dragging": false,
		"hovered_button": StageClearResultInteractionState.BUTTON_NEXT_STAGE,
	})
	_expect((scene.get("_next_stage_button_rect") as Rect2).position == Vector2(11.0, 12.0), "scene should apply scroll next rect through helper")
	_expect((scene.get("_plaza_button_rect") as Rect2).position == Vector2(12.0, 13.0), "scene should apply scroll plaza rect through helper")
	_expect(scene.get("_exit_button_rect") == exit_rect, "scene should keep missing exit rect through helper")
	_expect(scene.get("_scroll_position_offset") == Vector2(15.0, 16.0), "scene should apply scroll offset through helper")
	_expect(not bool(scene.get("_scroll_dragging")), "scene should apply dragging through helper")
	_expect(scene.get("_scroll_drag_grab_offset") == Vector2(6.0, 7.0), "scene should keep missing grab offset through helper")
	_expect(str(scene.get("_hovered_button")) == StageClearResultInteractionState.BUTTON_NEXT_STAGE, "scene should apply hover through helper")
	scene.free()


func _verify_scene_delegates_scroll_input() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
	_expect(source.find("StageClearResultScrollInputHandler.get_button_click_result") >= 0, "result scene should delegate scroll button click state")
	_expect(source.find("StageClearResultScrollInputHandler.get_hovered_button_result") >= 0, "result scene should delegate scroll button hover state")
	_expect(source.find("StageClearResultScrollInputHandler.get_hovered_button_apply_result") >= 0, "result scene should delegate scroll button hover apply payloads")
	_expect(source.find("StageClearResultScrollInputHandler.get_drag_start_result") >= 0, "result scene should delegate scroll drag starts")
	_expect(source.find("StageClearResultScrollInputHandler.get_drag_start_apply_result") >= 0, "result scene should delegate scroll drag-start apply payloads")
	_expect(source.find("StageClearResultScrollInputHandler.get_drag_update_result") >= 0, "result scene should delegate scroll drag updates")
	_expect(source.find("StageClearResultScrollInputHandler.get_drag_update_apply_result") >= 0, "result scene should delegate scroll drag-update apply payloads")
	_expect(source.find("StageClearResultScrollInputHandler.get_drag_finish_apply_result") >= 0, "result scene should delegate scroll drag-finish apply payloads")
	_expect(source.find("StageClearResultScrollInputHandler.get_drag_cancel_apply_result") >= 0, "result scene should delegate scroll drag-cancel apply payloads")
	_expect(source.find("StageClearResultScrollInputHandler.get_scroll_state_scene_apply_result") >= 0, "result scene should delegate common scroll-state scene field payloads")
	_expect(helper_source.find("static func get_scroll_state_apply_result") >= 0, "scroll input helper should expose common scroll-state apply payloads")
	_expect(helper_source.find("static func get_scroll_state_scene_apply_result") >= 0, "scroll input helper should expose scene field payloads")
	_expect(source.find("StageClearResultInteractionState.get_scroll_drag_start_state") < 0, "result scene should not build scroll drag starts directly")
	_expect(source.find("StageClearResultInteractionState.get_visible_scroll_button_layout") < 0, "result scene should not build scroll button layout directly")
	_expect(source.find("drag_state.get(\"started\"") < 0, "result scene should not inspect drag-start success directly")
	_expect(source.find("result.get(\"position_offset\"") < 0, "result scene should not inspect drag offset directly")
	_expect(source.find("_next_stage_button_rect = result.get") < 0, "result scene should not inspect next button rect directly")
	_expect(source.find("_exit_button_rect = result.get") < 0, "result scene should not inspect exit button rect directly")
	_expect(source.find("_scroll_position_offset = result.get") < 0, "result scene should not inspect scroll offset directly")
	_expect(source.find("_scroll_drag_grab_offset = result.get") < 0, "result scene should not inspect drag grab offset directly")
	_expect(source.find("_hovered_button = str(result.get") < 0, "result scene should not inspect hovered button directly")
	_expect(source.find("_scroll_dragging = true") < 0, "result scene should not directly activate scroll dragging")
	_expect(source.find("_scroll_dragging = false") < 0, "result scene should not directly cancel scroll dragging")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
