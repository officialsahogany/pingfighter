extends SceneTree

const ActiveItemAipillRuntime := preload("res://scripts/items/active_item_aipill_runtime.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 100.0


class FakeTarget:
	extends RefCounted

	var aipill_active := false
	var aipill_phase := 0.0
	var aipill_flash_timer_frames := 0.0


func _init() -> void:
	_verify_direct_runtime_state()
	_verify_direct_runtime_update_application()
	_verify_controller_delegates_runtime_state()

	if _failures.is_empty():
		print("active_item_aipill_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_runtime_state() -> void:
	var runtime: Object = ActiveItemAipillRuntime.new()

	var started: Dictionary = runtime.start_state()
	_expect(bool(started.get("active", false)), "AI Pill runtime should start active")
	_expect(is_equal_approx(float(started.get("phase", -1.0)), 0.0), "AI Pill runtime should reset phase on start")
	_expect(is_equal_approx(float(started.get("flash_timer_frames", 0.0)), 12.0), "AI Pill runtime should start flash timer")

	var updated: Dictionary = runtime.update_state(true, 1.0, 5.0, true, 100.0, 1.0 / 60.0)
	_expect(bool(updated.get("active", false)), "AI Pill runtime should stay active with owner and gauge")
	_expect(is_equal_approx(float(updated.get("phase", 0.0)), 1.18), "AI Pill runtime should advance phase")
	_expect(is_equal_approx(float(updated.get("flash_timer_frames", 0.0)), 4.0), "AI Pill runtime should tick flash timer")

	var inactive: Dictionary = runtime.update_state(false, 2.0, 3.0, true, 100.0, 1.0 / 60.0)
	_expect(not bool(inactive.get("active", true)), "inactive AI Pill runtime should stay inactive")
	_expect(is_equal_approx(float(inactive.get("phase", -1.0)), 0.0), "inactive AI Pill runtime should reset phase")
	_expect(is_equal_approx(float(inactive.get("flash_timer_frames", -1.0)), 0.0), "inactive AI Pill runtime should reset flash")

	var lost_owner: Dictionary = runtime.update_state(true, 2.0, 3.0, false, 100.0, 1.0 / 60.0)
	_expect(not bool(lost_owner.get("active", true)), "AI Pill runtime should clear without owner")

	var depleted: Dictionary = runtime.update_state(true, 2.0, 3.0, true, 0.0, 1.0 / 60.0)
	_expect(not bool(depleted.get("active", true)), "AI Pill runtime should clear when gauge is empty")

	var flashed: Dictionary = runtime.flash_state(true, 2.5)
	_expect(bool(flashed.get("active", false)), "AI Pill flash state should preserve active flag")
	_expect(is_equal_approx(float(flashed.get("phase", 0.0)), 2.5), "AI Pill flash state should preserve phase")
	_expect(is_equal_approx(float(flashed.get("flash_timer_frames", 0.0)), 12.0), "AI Pill flash state should reset flash timer")


func _verify_direct_runtime_update_application() -> void:
	var runtime: Object = ActiveItemAipillRuntime.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var target := FakeTarget.new()
	var owner := FakeOwner.new()

	target.aipill_active = true
	target.aipill_phase = 1.0
	target.aipill_flash_timer_frames = 5.0
	runtime.apply_update(
		target,
		owner,
		target.aipill_active,
		target.aipill_phase,
		target.aipill_flash_timer_frames,
		1.0 / 60.0,
		state_applier
	)
	_expect(target.aipill_active, "AI Pill runtime should apply active update state")
	_expect(is_equal_approx(target.aipill_phase, 1.18), "AI Pill runtime should apply phase tick")
	_expect(is_equal_approx(target.aipill_flash_timer_frames, 4.0), "AI Pill runtime should apply flash tick")

	owner.special_gauge = 0.0
	target.aipill_active = true
	target.aipill_phase = 2.0
	target.aipill_flash_timer_frames = 4.0
	runtime.apply_update(
		target,
		owner,
		target.aipill_active,
		target.aipill_phase,
		target.aipill_flash_timer_frames,
		1.0 / 60.0,
		state_applier
	)
	_expect(not target.aipill_active, "AI Pill runtime should apply clear state when owner gauge is empty")
	_expect(is_equal_approx(target.aipill_phase, 0.0), "AI Pill runtime clear should reset phase")
	_expect(is_equal_approx(target.aipill_flash_timer_frames, 0.0), "AI Pill runtime clear should reset flash")


func _verify_controller_delegates_runtime_state() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	_expect(controller.activate_aipill(null, null), "controller should activate AI Pill through runtime helper")
	_expect(controller.aipill_active, "controller should apply AI Pill active state")
	_expect(is_equal_approx(controller.aipill_phase, 0.0), "controller should reset AI Pill phase on activation")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 12.0), "controller should apply AI Pill start flash")

	controller.update(owner, 1.0 / 60.0)
	_expect(controller.aipill_active, "controller should keep AI Pill active with gauge")
	_expect(is_equal_approx(controller.aipill_phase, 0.18), "controller should apply AI Pill phase tick")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 11.0), "controller should apply AI Pill flash tick")

	owner.special_gauge = 0.0
	controller.aipill_phase = 2.0
	controller.aipill_flash_timer_frames = 4.0
	controller.update(owner, 1.0 / 60.0)
	_expect(not controller.aipill_active, "controller should clear AI Pill when owner gauge is empty")
	_expect(is_equal_approx(controller.aipill_phase, 0.0), "controller should clear AI Pill phase")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 0.0), "controller should clear AI Pill flash")

	controller.aipill_active = true
	controller.aipill_phase = 2.0
	controller.aipill_flash_timer_frames = 4.0
	controller.update(null, 1.0 / 60.0)
	_expect(not controller.aipill_active, "controller should clear AI Pill when owner disappears")

	controller.aipill_active = true
	controller.aipill_phase = 3.0
	controller.aipill_flash_timer_frames = 2.0
	var gauge: float = controller.apply_aipill_guard_drain(100.0, {"selected_character_type": "smasher"}, {})
	_expect(is_equal_approx(gauge, 10.0), "controller should preserve AI Pill guard drain after runtime split")
	_expect(is_equal_approx(controller.aipill_phase, 3.0), "controller guard flash should preserve phase")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 12.0), "controller guard flash should use runtime flash state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
