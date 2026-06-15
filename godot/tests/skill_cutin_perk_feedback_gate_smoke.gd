extends SceneTree

# Seals the power-smash / drive cut-in "invisible early, only the fade-out tail at
# the end" bug: a transient runtime perk FEEDBACK notification (runtime_perk_state
# .has_feedback) was wrongly included in the cut-in draw gate
# (battle_scene_overlay_frame_controller.has_blocking_activity), so for the ~1s a
# skill activation raised the feedback the whole cut-in was suppressed. perk
# FEEDBACK must NOT block the cut-in; perk CHOICE (the real fullscreen modal) must.

const OverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const ModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []


class FakePerkState:
	extends RefCounted
	var choice := false
	var feedback := false

	func is_choice_active() -> bool:
		return choice

	func has_feedback() -> bool:
		return feedback


class FakeRegistry:
	extends RefCounted
	var modal_gate: Object
	var perk_state: Object

	func get_instance(key: String) -> Object:
		if key == "battle_scene_modal_gate_controller":
			return modal_gate
		if key == "runtime_perk_state":
			return perk_state
		return null


func _init() -> void:
	_test_perk_feedback_does_not_block_cutin()
	_test_perk_choice_still_blocks_cutin()
	_test_idle_state_does_not_block_cutin()

	if _failures.is_empty():
		print("skill_cutin_perk_feedback_gate_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _gate_blocks(choice: bool, feedback: bool) -> bool:
	var overlay := OverlayFrameController.new()
	var reg := FakeRegistry.new()
	reg.modal_gate = ModalGateController.new()
	var ps := FakePerkState.new()
	ps.choice = choice
	ps.feedback = feedback
	reg.perk_state = ps
	return bool(overlay.has_blocking_activity(Callable(reg, "get_instance")))


func _test_perk_feedback_does_not_block_cutin() -> void:
	# THE REGRESSION: feedback active, no real modal -> cut-in must still draw.
	_expect(
		not _gate_blocks(false, true),
		"runtime perk FEEDBACK must NOT block the skill/drive cut-in (transient non-modal notification)"
	)


func _test_perk_choice_still_blocks_cutin() -> void:
	# CONTRA: the real fullscreen perk-selection modal must still suppress the cut-in.
	_expect(
		_gate_blocks(true, false),
		"runtime perk CHOICE (fullscreen selection modal) must still block the cut-in"
	)


func _test_idle_state_does_not_block_cutin() -> void:
	_expect(
		not _gate_blocks(false, false),
		"with no modal and no feedback the cut-in must draw"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
