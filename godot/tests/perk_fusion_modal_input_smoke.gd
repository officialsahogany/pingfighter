extends SceneTree

const PerkFusionModalInput := preload("res://scripts/characters/perk_fusion_modal_input.gd")
const PerkFusionModalLayout := preload("res://scripts/characters/perk_fusion_modal_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	var helper := PerkFusionModalInput.new()
	var layout_helper := PerkFusionModalLayout.new()
	var snapshot := {"phase": "materials", "candidate_ids": ["a", "b", "c"], "highlight_index": 0}
	var view_size := Vector2(760.0, 750.0)
	var layout: Dictionary = layout_helper.build_layout(snapshot, view_size)
	var candidate_rects: Array = layout.get("candidate_rects", []) as Array

	var motion := InputEventMouseMotion.new()
	motion.position = (candidate_rects[1] as Rect2).get_center()
	_expect(int(helper.resolve(motion, snapshot, view_size).get("highlight_index", -1)) == 1, "mouse motion should resolve the hovered material")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (candidate_rects[2] as Rect2).get_center()
	_expect(int(helper.resolve(click, snapshot, view_size).get("select_index", -1)) == 2, "mouse click should select the hit material")
	for later_phase in ["confirm", "animation", "reveal"]:
		var later_snapshot := snapshot.duplicate(true)
		later_snapshot["phase"] = later_phase
		var later_action := helper.resolve(click, later_snapshot, view_size)
		_expect(
			int(later_action.get("select_index", -1)) < 0,
			"%s phase must not expose stale material cells as click targets" % later_phase
		)
	click.position = (layout.get("confirm_rect", Rect2()) as Rect2).get_center()
	_expect(bool(helper.resolve(click, snapshot, view_size).get("confirm", false)), "confirm button should resolve confirm")
	click.position = (layout.get("back_rect", Rect2()) as Rect2).get_center()
	_expect(bool(helper.resolve(click, snapshot, view_size).get("cancel", false)), "back button should resolve cancel")

	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	_expect(int(helper.resolve(key, snapshot, view_size).get("move", 0)) == 1, "right key should move material highlight")
	key.keycode = KEY_ENTER
	_expect(bool(helper.resolve(key, snapshot, view_size).get("confirm", false)), "enter should confirm")
	key.keycode = KEY_ESCAPE
	_expect(bool(helper.resolve(key, snapshot, view_size).get("cancel", false)), "escape should cancel")

	helper.suppress_confirm_until_release()
	_expect(not bool(helper.resolve(_rt_axis(0.60), snapshot, view_size).get("confirm", false)), "held RT from the parent modal should not enter the first fusion phase")
	helper.resolve(_rt_axis(0.10), snapshot, view_size)
	_expect(bool(helper.resolve(_rt_axis(0.60), snapshot, view_size).get("confirm", false)), "released then pressed RT should emit one confirm edge")
	_expect(not bool(helper.resolve(_rt_axis(0.80), snapshot, view_size).get("confirm", false)), "held RT must not emit a second confirm at a higher axis sample")
	_expect(not bool(helper.resolve(_rt_axis(1.00), snapshot, view_size).get("confirm", false)), "held RT must stay latched until full release")

	if _failures.is_empty():
		print("perk_fusion_modal_input_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
		quit(1)


func _rt_axis(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
