extends SceneTree

const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


class FakeWeaponController:
	extends RefCounted

	var last_switch_msec: int

	func _init(initial_last_switch_msec: int) -> void:
		last_switch_msec = initial_last_switch_msec

	func get_last_switch_msec() -> int:
		return last_switch_msec


func _init() -> void:
	_verify_direct_input_resolver()
	_verify_runtime_delegates_input_resolver()

	if _failures.is_empty():
		print("commando_firearm_input_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_input_resolver() -> void:
	_expect_vec(
		CommandoFirearmInputResolver.get_suicide_drone_input_vector({"left_pressed": true}),
		Vector2.LEFT,
		"left input should steer suicide drone left"
	)
	_expect_vec(
		CommandoFirearmInputResolver.get_suicide_drone_input_vector({"right_pressed": true, "up_pressed": true}),
		Vector2(1.0, -1.0).normalized(),
		"diagonal input should be normalized"
	)
	_expect_vec(
		CommandoFirearmInputResolver.get_suicide_drone_input_vector({"left_pressed": true, "right_pressed": true, "up_pressed": true, "down_pressed": true}),
		Vector2.ZERO,
		"opposing inputs should cancel"
	)
	_expect_vec(
		CommandoFirearmInputResolver.get_suicide_drone_input_vector({}),
		Vector2.ZERO,
		"empty input should not steer suicide drone"
	)

	_expect(CommandoFirearmInputResolver.input_action_just_pressed({"action_just_pressed": true, "action_pressed": false}), "explicit action_just_pressed should win")
	_expect(not CommandoFirearmInputResolver.input_action_just_pressed({"action_just_pressed": false, "action_pressed": true}), "explicit false action_just_pressed should block held action")
	_expect(CommandoFirearmInputResolver.input_action_just_pressed({"action_pressed": true}), "legacy snapshots should fall back to action_pressed")
	_expect(not CommandoFirearmInputResolver.input_action_just_pressed({}), "empty snapshots should not count as just pressed")
	_expect(
		CommandoFirearmInputResolver.is_fire_suppressed_after_switch(FakeWeaponController.new(1000), 1030, 70),
		"switch suppression should block fire inside the suppression window"
	)
	_expect(
		not CommandoFirearmInputResolver.is_fire_suppressed_after_switch(FakeWeaponController.new(1000), 1070, 70),
		"switch suppression should allow fire at the suppression boundary"
	)
	_expect(
		not CommandoFirearmInputResolver.is_fire_suppressed_after_switch(RefCounted.new(), 1030, 70),
		"switch suppression should ignore objects without switch timestamps"
	)


func _verify_runtime_delegates_input_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect_vec(
		runtime._get_suicide_drone_input_vector({"right_pressed": true, "down_pressed": true}),
		Vector2(1.0, 1.0).normalized(),
		"runtime suicide-drone input wrapper should delegate"
	)
	_expect(runtime._input_action_just_pressed({"action_just_pressed": true}), "runtime just-pressed wrapper should delegate explicit true")
	_expect(not runtime._input_action_just_pressed({"action_just_pressed": false, "action_pressed": true}), "runtime just-pressed wrapper should delegate explicit false")
	_expect(runtime._is_fire_suppressed_after_switch(FakeWeaponController.new(1000), 1030), "runtime switch suppression wrapper should delegate active suppression")
	_expect(not runtime._is_fire_suppressed_after_switch(FakeWeaponController.new(1000), 1070), "runtime switch suppression wrapper should delegate boundary release")


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
