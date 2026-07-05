extends SceneTree

# Regression seal for the Horn Strawberry Mask firearm-fire bug: the mask's
# command listener samples the shared stateful input reader during
# update_mythic_items, which runs BEFORE update_player_control in
# battle_frame_flow_controller. If get_snapshot() recomputes the just-pressed
# edges on every call, the first (mask) call consumes the edge and the player
# controller never sees action_just_pressed, so edge-gated commando firearms
# stop firing while the mask is merely equipped. Same-frame calls must return
# the same snapshot.

var _failures: Array[String] = []


class FrameLockedCommandoReader:
	extends "res://scripts/characters/commando_input_reader.gd"

	var fake_frame := 0

	func _get_snapshot_frame_key() -> int:
		return fake_frame


class FrameLockedBlacksmithReader:
	extends "res://scripts/characters/blacksmith_input_reader.gd"

	var fake_frame := 0

	func _get_snapshot_frame_key() -> int:
		return fake_frame


func _init() -> void:
	_verify_second_same_frame_consumer_keeps_action_edge()
	_verify_edge_stays_one_shot_across_frames()
	_verify_first_consumer_mutation_does_not_leak()
	_verify_blacksmith_reader_mirrors_same_frame_guard()
	Input.action_release("ui_accept")

	if _failures.is_empty():
		print("player_input_reader_same_frame_edge_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_second_same_frame_consumer_keeps_action_edge() -> void:
	var reader := FrameLockedCommandoReader.new()
	Input.action_release("ui_accept")
	reader.fake_frame = 0
	var idle_snapshot: Dictionary = reader.get_snapshot()
	_expect(not bool(idle_snapshot.get("action_pressed", true)), "idle frame should read action released")

	Input.action_press("ui_accept")
	reader.fake_frame = 1
	var mask_snapshot: Dictionary = reader.get_snapshot()
	_expect(bool(mask_snapshot.get("action_just_pressed", false)), "first same-frame consumer should see the press edge")
	var controller_snapshot: Dictionary = reader.get_snapshot()
	_expect(
		bool(controller_snapshot.get("action_just_pressed", false)),
		"second same-frame consumer (player controller) must still see action_just_pressed"
	)
	_expect(
		bool(controller_snapshot.get("action_pressed", false)),
		"second same-frame consumer should read action held"
	)
	Input.action_release("ui_accept")


func _verify_edge_stays_one_shot_across_frames() -> void:
	var reader := FrameLockedCommandoReader.new()
	Input.action_release("ui_accept")
	reader.fake_frame = 0
	reader.get_snapshot()

	Input.action_press("ui_accept")
	reader.fake_frame = 1
	reader.get_snapshot()
	reader.get_snapshot()

	reader.fake_frame = 2
	var held_snapshot: Dictionary = reader.get_snapshot()
	_expect(bool(held_snapshot.get("action_pressed", false)), "held frame should read action pressed")
	_expect(
		not bool(held_snapshot.get("action_just_pressed", true)),
		"held frame must not re-report action_just_pressed after the edge frame"
	)

	Input.action_release("ui_accept")
	reader.fake_frame = 3
	var released_snapshot: Dictionary = reader.get_snapshot()
	_expect(
		bool(released_snapshot.get("action_just_released", false)),
		"release frame should report action_just_released"
	)
	var released_second: Dictionary = reader.get_snapshot()
	_expect(
		bool(released_second.get("action_just_released", false)),
		"second same-frame consumer should also see action_just_released"
	)

	reader.fake_frame = 4
	var settled_snapshot: Dictionary = reader.get_snapshot()
	_expect(
		not bool(settled_snapshot.get("action_just_released", true)),
		"settled frame must not re-report action_just_released"
	)


func _verify_first_consumer_mutation_does_not_leak() -> void:
	var reader := FrameLockedCommandoReader.new()
	Input.action_release("ui_accept")
	reader.fake_frame = 0
	reader.get_snapshot()

	Input.action_press("ui_accept")
	reader.fake_frame = 1
	var first_snapshot: Dictionary = reader.get_snapshot()
	first_snapshot["action_just_pressed"] = false
	first_snapshot["action_pressed"] = false
	var second_snapshot: Dictionary = reader.get_snapshot()
	_expect(
		bool(second_snapshot.get("action_just_pressed", false)),
		"a consumer mutating its snapshot copy must not corrupt later same-frame consumers"
	)
	Input.action_release("ui_accept")


func _verify_blacksmith_reader_mirrors_same_frame_guard() -> void:
	var reader := FrameLockedBlacksmithReader.new()
	Input.action_release("ui_accept")
	reader.fake_frame = 0
	reader.get_snapshot()

	Input.action_press("ui_accept")
	reader.fake_frame = 1
	reader.get_snapshot()
	var second_snapshot: Dictionary = reader.get_snapshot()
	_expect(
		bool(second_snapshot.get("action_just_pressed", false)),
		"blacksmith reader second same-frame consumer must still see action_just_pressed"
	)
	reader.fake_frame = 2
	var held_snapshot: Dictionary = reader.get_snapshot()
	_expect(
		not bool(held_snapshot.get("action_just_pressed", true)),
		"blacksmith reader held frame must not re-report action_just_pressed"
	)
	Input.action_release("ui_accept")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
