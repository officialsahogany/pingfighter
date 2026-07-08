extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkUnlockSwapLayout := preload("res://scripts/characters/runtime_perk_unlock_swap_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_layout_contract()
	_verify_state_wrapper_contract()

	if _failures.is_empty():
		print("runtime_perk_unlock_swap_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_layout_contract() -> void:
	var helper := RuntimePerkUnlockSwapLayout.new()
	var swap := _make_swap(5)
	var wide_view := Vector2(1280.0, 720.0)
	var layout: Dictionary = helper.build_layout(swap, wide_view)
	var rects: Array = helper.get_option_rects(swap, wide_view)
	_expect(rects.size() == 5, "helper should create one option rect per candidate")
	_expect(_get_rect2(layout.get("panel_rect", Rect2())).size.y == 292.0, "panel height should keep the established swap dialog height")
	if rects.size() == 5:
		_expect(helper.get_index_at(swap, _get_rect2(rects[2]).get_center(), wide_view) == 2, "center of third rect should hit index 2")
		_expect(helper.get_index_at(swap, _get_rect2(rects[0]).position - Vector2(4.0, 4.0), wide_view) == -1, "outside point should miss all rects")
	var narrow_layout: Dictionary = helper.build_layout(swap, Vector2(420.0, 720.0))
	var narrow_card_size: Vector2 = _get_vector2(narrow_layout.get("card_size", Vector2.ZERO))
	_expect(narrow_card_size.x < RuntimePerkUnlockSwapLayout.DEFAULT_CARD_SIZE.x, "narrow views should scale swap cards down")

	var runtime_state := FakeRuntimeState.new()
	runtime_state.pending_unlock_swap = swap.duplicate(true)
	var state_layout: Dictionary = helper.build_layout_from_runtime_state(runtime_state, wide_view)
	var state_rects: Array = helper.get_option_rects_from_runtime_state(runtime_state, wide_view)
	_expect(_get_rect2(state_layout.get("panel_rect", Rect2())).size.y == 292.0, "runtime-state layout should preserve panel geometry")
	_expect(state_rects.size() == 5, "runtime-state rect facade should read pending swap candidates")
	if state_rects.size() == 5:
		_expect(
			helper.get_index_at_from_runtime_state(runtime_state, _get_rect2(state_rects[2]).get_center(), wide_view) == 2,
			"runtime-state hit facade should resolve option index"
		)
	_expect(helper.get_option_rects_from_runtime_state(null, wide_view).is_empty(), "runtime-state rect facade should reject missing state")
	_expect(helper.get_index_at_from_runtime_state(null, Vector2.ZERO, wide_view) == -1, "runtime-state hit facade should reject missing state")


func _verify_state_wrapper_contract() -> void:
	var state := RuntimePerkState.new()
	state.pending_unlock_swap = _make_swap(3)
	var view_size := Vector2(760.0, 720.0)
	var rects: Array = state.get_unlock_swap_option_rects(view_size)
	_expect(rects.size() == 3, "state wrapper should delegate candidate rect creation")
	if rects.size() == 3:
		var center: Vector2 = _get_rect2(rects[1]).get_center()
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.position = center
		state.handle_input(mouse_motion, null, null, view_size)
		_expect(state.unlock_swap_selected_index == 1, "mouse hover should still select the delegated swap rect")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var layout_body: String = _function_body(state_source, "func build_unlock_swap_layout(")
	var rects_body: String = _function_body(state_source, "func get_unlock_swap_option_rects(")
	var hit_body: String = _function_body(state_source, "func _get_unlock_swap_index_at(")
	_expect(layout_body.find("build_layout_from_runtime_state") >= 0, "state should delegate runtime-state swap layout build")
	_expect(rects_body.find("get_option_rects_from_runtime_state") >= 0, "state should delegate runtime-state swap rect lookup")
	_expect(hit_body.find("get_index_at_from_runtime_state") >= 0, "state should delegate runtime-state swap hit lookup")
	_expect(layout_body.find("pending_unlock_swap") < 0, "state swap layout wrapper should not pass pending swap inline")
	_expect(rects_body.find("pending_unlock_swap") < 0, "state swap rect wrapper should not pass pending swap inline")
	_expect(hit_body.find("pending_unlock_swap") < 0, "state swap hit wrapper should not pass pending swap inline")


func _make_swap(count: int) -> Dictionary:
	var candidates: Array = []
	for index in range(count):
		candidates.append({"skill_id": "skill_%d" % index, "name": "Skill %d" % index})
	return {
		"choice_id": "soldier_unlock_test",
		"unlocks_skill": "test_skill",
		"new_name": "Test Skill",
		"candidates": candidates,
	}


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


class FakeRuntimeState:
	var pending_unlock_swap: Dictionary = {}
