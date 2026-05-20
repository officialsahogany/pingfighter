extends SceneTree

const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


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


func _verify_runtime_delegates_input_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect_vec(
		runtime._get_suicide_drone_input_vector({"right_pressed": true, "down_pressed": true}),
		Vector2(1.0, 1.0).normalized(),
		"runtime suicide-drone input wrapper should delegate"
	)
	_expect(runtime._input_action_just_pressed({"action_just_pressed": true}), "runtime just-pressed wrapper should delegate explicit true")
	_expect(not runtime._input_action_just_pressed({"action_just_pressed": false, "action_pressed": true}), "runtime just-pressed wrapper should delegate explicit false")


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
