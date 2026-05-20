extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_support_call_resolver()
	_verify_runtime_delegates_support_call_resolver()

	if _failures.is_empty():
		print("commando_firearm_support_call_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_support_call_resolver() -> void:
	var target := Vector2(320.0, 180.0)
	_expect(
		CommandoFirearmSupportCallResolver.support_call_seed(4, target) == 4414083065,
		"support call seed should preserve the deterministic legacy formula"
	)
	_expect(
		is_equal_approx(CommandoFirearmSupportCallResolver.get_delay_frames(4, target, 120.0, 180.0), 148.0),
		"support call delay should stay inside the legacy deterministic range"
	)
	_expect(
		CommandoFirearmSupportCallResolver.get_bomb_count(4, target, 5, 7) == 7,
		"support bomb count should stay inside the legacy deterministic range"
	)
	_expect(
		is_equal_approx(CommandoFirearmSupportCallResolver.get_delay_frames(1, target, 30.0, 30.0), 30.0),
		"single-value delay ranges should not divide by zero"
	)
	_expect(
		CommandoFirearmSupportCallResolver.get_bomb_count(1, target, 2, 2) == 2,
		"single-value bomb-count ranges should not divide by zero"
	)


func _verify_runtime_delegates_support_call_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var target := Vector2(320.0, 180.0)
	_expect(runtime._support_call_seed(4, target) == 4414083065, "runtime seed wrapper should delegate")
	_expect(is_equal_approx(runtime._get_support_call_delay_frames(4, target), 148.0), "runtime delay wrapper should delegate")
	_expect(runtime._get_support_bomb_count(4, target) == 7, "runtime bomb-count wrapper should delegate")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
