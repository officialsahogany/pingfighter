extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemGaugeRuntime := preload("res://scripts/items/active_item_gauge_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 200.0
	var player_paddle_height := 40.0


class FakeMythicRuntime:
	extends RefCounted

	var calls: Array[float] = []

	func apply_gold_digger_gauge_bonus(gauge_gain: float) -> float:
		calls.append(gauge_gain)
		return gauge_gain * 2.0


class FakeRegistry:
	extends RefCounted

	var mythic_item_runtime: Object = null

	func _init(mythic_runtime: Object = null) -> void:
		mythic_item_runtime = mythic_runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


func _init() -> void:
	_verify_direct_gauge_runtime()
	_verify_controller_delegates_gauge_runtime()

	if _failures.is_empty():
		print("active_item_gauge_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_gauge_runtime() -> void:
	var runtime: Object = ActiveItemGaugeRuntime.new()

	var normal: Dictionary = runtime.build_gauge_charge_result({"gauge_gain": 10.0}, 100.0, 500.0)
	_expect(is_equal_approx(float(normal.get("special_gauge", 0.0)), 110.0), "gauge runtime should add requested gauge")
	_expect(is_equal_approx(float(normal.get("gauge_gain", 0.0)), 10.0), "gauge runtime should expose applied gain")
	_expect(is_equal_approx(float(normal.get("gauge_max", 0.0)), 500.0), "gauge runtime should expose effective max")

	var capped: Dictionary = runtime.build_gauge_charge_result({"gauge_gain": 50.0}, 480.0, 500.0)
	_expect(is_equal_approx(float(capped.get("special_gauge", 0.0)), 500.0), "gauge runtime should cap at owner max")
	_expect(is_equal_approx(float(capped.get("applied_gain", 0.0)), 20.0), "gauge runtime should expose capped actual gain")

	var min_max: Dictionary = runtime.build_gauge_charge_result({"gauge_gain": 10.0}, 0.0, 0.0)
	_expect(is_equal_approx(float(min_max.get("special_gauge", 0.0)), 1.0), "gauge runtime should keep max at least one")

	var mythic := FakeMythicRuntime.new()
	var boosted: Dictionary = runtime.build_gauge_charge_result({"gauge_gain": 15.0}, 100.0, 500.0, mythic)
	_expect(mythic.calls == [15.0], "gauge runtime should delegate Gold Digger bonus")
	_expect(is_equal_approx(float(boosted.get("special_gauge", 0.0)), 130.0), "gauge runtime should apply mythic-adjusted gain")

	var life_defaults: Dictionary = runtime.build_life_elixir_item_data({})
	_expect(is_equal_approx(float(life_defaults.get("gauge_gain", 0.0)), 500.0), "life elixir data should default to full gauge gain")
	_expect(is_equal_approx(float(life_defaults.get("gauge_max", 0.0)), 500.0), "life elixir data should default max")

	var life_custom: Dictionary = runtime.build_life_elixir_item_data({"gauge_gain": 250.0, "gauge_max": 700.0})
	_expect(is_equal_approx(float(life_custom.get("gauge_gain", 0.0)), 250.0), "life elixir data should preserve custom gain")
	_expect(is_equal_approx(float(life_custom.get("gauge_max", 0.0)), 700.0), "life elixir data should preserve custom max")


func _verify_controller_delegates_gauge_runtime() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	_expect(controller.apply_gauge_charge({"gauge_gain": 10.0}, owner, null), "controller should apply gauge charge")
	_expect(is_equal_approx(owner.special_gauge, 110.0), "controller should apply runtime gauge result to owner")

	var mythic := FakeMythicRuntime.new()
	var registry := FakeRegistry.new(mythic)
	_expect(controller.apply_gauge_charge({"gauge_gain": 20.0}, owner, registry), "controller should apply mythic gauge charge")
	_expect(mythic.calls == [20.0], "controller should pass mythic runtime into gauge helper")
	_expect(is_equal_approx(owner.special_gauge, 150.0), "controller should apply boosted gauge result")

	owner.special_gauge = 200.0
	owner.special_gauge_max = 650.0
	_expect(controller.apply_life_elixir({}, owner, null), "controller should apply life elixir through gauge helper")
	_expect(is_equal_approx(owner.special_gauge, 650.0), "life elixir should respect owner gauge max")
	_expect(controller.pickup_particles.size() == 22, "life elixir should still spawn burst particles")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
