extends SceneTree

# 결과화면 순차 상자 오픈 회귀 씰.
# 마우스 클릭 또는 스페이스/엔터 한 번으로 모든 상자가 0.2초 간격으로 순차적으로 열리는지,
# 그리고 보상 모달(스타포인트 게이트 등) 동안 순차 오픈이 일시정지·재개되는지 검증한다.
# 수정 전 코드(한 입력 = 한 상자)에서는 _verify_single_* 가 실패하도록 설계되어 있다.

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultInputSceneHandler := preload("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
const StageClearResultUpdateSceneHandler := preload("res://scripts/ui/stage_clear_result_update_scene_handler.gd")

var _failures: Array[String] = []


class Roller:
	extends RefCounted

	var calls := 0

	func roll_reward(_kind: String) -> Dictionary:
		calls += 1
		# 비-차단 보상(액티브 아이템)만 굴려 게이트 없이 순차 오픈이 끝까지 흐르게 한다.
		return {"type": "active", "label": "x"}


func _init() -> void:
	_verify_single_space_opens_all_boxes()
	_verify_single_click_opens_all_boxes()
	_verify_cascade_opens_one_at_a_time()
	_verify_no_trigger_leaves_boxes_idle()
	_verify_blocked_gate_pauses_then_resumes_cascade()

	if _failures.is_empty():
		print("stage_clear_result_sequential_box_open_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_scene(box_count: int, roller: Roller) -> Control:
	var scene := StageClearResultScene.new()
	scene.size = Vector2(1920.0, 1080.0)
	root.add_child(scene)
	var boxes: Array = []
	for i in range(box_count):
		boxes.append({
			"state": "idle",
			"kind": "normal",
			"base_pos": Vector2(200.0 + i * 90.0, 400.0),
			"amplitude": 0.0,
			"speed": 0.0,
		})
	scene.set("_boxes", boxes)
	scene.set("_scroll_phase", "hidden")
	scene.reward_roll_callback = Callable(roller, "roll_reward")
	return scene


func _idle_count(scene: Control) -> int:
	var count := 0
	for box_value in (scene.get("_boxes") as Array):
		if str((box_value as Dictionary).get("state", "idle")) == "idle":
			count += 1
	return count


func _opened_count(scene: Control) -> int:
	var count := 0
	for box_value in (scene.get("_boxes") as Array):
		if str((box_value as Dictionary).get("state", "idle")) == "opened":
			count += 1
	return count


func _space_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	return event


func _click_event(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _step(scene: Control, frames: int, delta: float) -> void:
	for _i in range(frames):
		StageClearResultUpdateSceneHandler.update_result_scene(scene, delta)


func _verify_single_space_opens_all_boxes() -> void:
	var roller := Roller.new()
	var scene := _make_scene(4, roller)
	StageClearResultInputSceneHandler.handle_result_input(scene, _space_event(), 1.55)
	_step(scene, 240, 0.05)
	_expect(_opened_count(scene) == 4, "single Space press should sequentially open all 4 boxes, got %d opened" % _opened_count(scene))
	_expect(roller.calls == 4, "each box should roll exactly once with no phantom rolls, got %d" % roller.calls)
	_expect(not bool(scene.get("_auto_open_active")), "cascade should deactivate after every box opens")
	scene.free()


func _verify_single_click_opens_all_boxes() -> void:
	var roller := Roller.new()
	var scene := _make_scene(3, roller)
	# 상자를 빗맞은 빈 곳 클릭이라도 결과화면 상자 페이즈면 전체 순차 오픈을 무장해야 한다.
	StageClearResultInputSceneHandler.handle_result_input(scene, _click_event(Vector2(960.0, 540.0)), 1.55)
	_step(scene, 240, 0.05)
	_expect(_opened_count(scene) == 3, "single mouse click should sequentially open all 3 boxes, got %d opened" % _opened_count(scene))
	_expect(roller.calls == 3, "each box should roll exactly once with no phantom rolls, got %d" % roller.calls)
	scene.free()


func _verify_cascade_opens_one_at_a_time() -> void:
	var roller := Roller.new()
	var scene := _make_scene(4, roller)
	StageClearResultInputSceneHandler.handle_result_input(scene, _space_event(), 1.55)
	# 0.5초 시점: 첫 상자만 열리는 중이어야 하고 나머지 3개는 아직 유휴여야 한다(동시 오픈이 아님).
	_step(scene, 10, 0.05)
	_expect(_idle_count(scene) == 3, "cascade should open boxes one at a time, not all at once (idle=%d)" % _idle_count(scene))
	_expect(_opened_count(scene) == 0, "the first box should still be opening at 0.5s, none fully opened yet")
	scene.free()


func _verify_no_trigger_leaves_boxes_idle() -> void:
	var roller := Roller.new()
	var scene := _make_scene(3, roller)
	# 아무 입력도 주지 않으면 상자는 저절로 열리면 안 된다.
	_step(scene, 120, 0.05)
	_expect(_idle_count(scene) == 3, "boxes should stay idle without a trigger, got %d idle" % _idle_count(scene))
	_expect(roller.calls == 0, "no reward should roll without a trigger, got %d" % roller.calls)
	scene.free()


func _verify_blocked_gate_pauses_then_resumes_cascade() -> void:
	var roller := Roller.new()
	var scene := _make_scene(3, roller)
	StageClearResultInputSceneHandler.handle_result_input(scene, _space_event(), 1.55)
	# 첫 상자가 열리는 순간을 흉내내 스타포인트 선택 게이트를 세운다: 순차 오픈이 멈춰야 한다.
	scene.set("_starpoint_choice_gate_active", true)
	_step(scene, 100, 0.05)
	_expect(_opened_count(scene) == 1, "the first box should finish opening but the cascade should pause under the gate (opened=%d)" % _opened_count(scene))
	_expect(_idle_count(scene) == 2, "remaining boxes should stay idle while the reward gate blocks the cascade (idle=%d)" % _idle_count(scene))
	# 게이트가 풀리면 남은 상자를 이어서 연다.
	scene.set("_starpoint_choice_gate_active", false)
	_step(scene, 200, 0.05)
	_expect(_opened_count(scene) == 3, "cascade should resume and open the remaining boxes after the gate clears (opened=%d)" % _opened_count(scene))
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
