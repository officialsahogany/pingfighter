extends SceneTree

const BattleLingpetInteractionInputRouter := preload(
	"res://scripts/core/battle_lingpet_interaction_input_router.gd"
)
const BattleSystemShortcutInputRouter := preload(
	"res://scripts/core/battle_system_shortcut_input_router.gd"
)
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeToggleRuntime:
	extends RefCounted

	var toggle_count := 0
	var consume_toggle := true

	func try_toggle_guardian_stow(_owner: Object, _registry: Object) -> bool:
		toggle_count += 1
		return consume_toggle


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_project_action_contract()
	_verify_ctrl_and_r3_edges_are_idempotent()
	_verify_battle_r3_carveout_keeps_menu_policy()
	_verify_runtime_minimum_hold_and_transition_feedback()

	if _failures.is_empty():
		print("guardian_toggle_input_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_project_action_contract() -> void:
	_expect(InputMap.has_action("guardian_toggle"), "project input map should declare guardian_toggle")
	var has_ctrl := false
	var has_r3 := false
	for event in InputMap.action_get_events("guardian_toggle"):
		if event is InputEventKey:
			var key_event: InputEventKey = event
			has_ctrl = has_ctrl or key_event.keycode == KEY_CTRL or key_event.physical_keycode == KEY_CTRL
		elif event is InputEventJoypadButton:
			has_r3 = has_r3 or (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK
	_expect(has_ctrl, "guardian_toggle should map Ctrl")
	_expect(has_r3, "guardian_toggle should map R3")


func _verify_ctrl_and_r3_edges_are_idempotent() -> void:
	var runtime := FakeToggleRuntime.new()
	var holder := ModuleHolder.new()
	holder.modules["lingpet_egg_runtime"] = runtime
	var owner := FakeOwner.new()
	var router := BattleLingpetInteractionInputRouter.new()
	var getter := Callable(holder, "get_module")

	_expect(router.handle_companion_input(_key_event(KEY_CTRL), owner, null, getter), "Ctrl press should toggle")
	var ctrl_echo := _key_event(KEY_CTRL)
	ctrl_echo.echo = true
	_expect(not router.handle_companion_input(ctrl_echo, owner, null, getter), "Ctrl key echo should not repeat")
	_expect(router.handle_companion_input(_button_event(true), owner, null, getter), "first R3 press should toggle")
	_expect(not router.handle_companion_input(_button_event(true), owner, null, getter), "same-frame/repeated R3 press should stay latched")
	_expect(not router.handle_companion_input(_button_event(false), owner, null, getter), "R3 release should only rearm")
	_expect(router.handle_companion_input(_button_event(true), owner, null, getter), "R3 should toggle again after release")
	_expect_eq(runtime.toggle_count, 3, "Ctrl plus two physical R3 presses should yield exactly three edges")
	_expect_eq(owner.redraw_count, 3, "each consumed toggle should request one redraw")
	holder.modules.clear()


func _verify_battle_r3_carveout_keeps_menu_policy() -> void:
	var router := BattleSystemShortcutInputRouter.new()
	var holder := ModuleHolder.new()
	var getter := Callable(holder, "get_module")
	_expect(not router.handle_input(_button_event(true), FakeOwner.new(), getter), "battle system router should pass R3 to guardian_toggle")
	_expect(router.handle_input(_axis_event(JOY_AXIS_RIGHT_X, 0.9), FakeOwner.new(), getter), "battle router should still suppress right-stick axes")
	_expect(GamepadInput.should_suppress_right_stick_event(_button_event(true)), "shared/menu suppression policy should still classify R3 as suppressed")


func _verify_runtime_minimum_hold_and_transition_feedback() -> void:
	var owner := _make_runtime_owner()
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "runtime fixture should activate a guardian")
	runtime.set_duration_pool_for_tests(60.0, 60.0)
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "toggle inside hold should still be consumed")
	_expect(not runtime.is_guardian_stowed(), "toggle before six seconds should be ignored")
	runtime.update(5.99, owner, registry)
	runtime.try_toggle_guardian_stow(owner, registry)
	_expect(not runtime.is_guardian_stowed(), "toggle just below six seconds should remain ignored")
	runtime.update(0.02, owner, registry)
	runtime.try_toggle_guardian_stow(owner, registry)
	_expect(runtime.is_guardian_stowed(), "toggle after six seconds should stow")
	_expect(not runtime.is_companion_active(), "stowed guardian should publish companion_active false")
	var stow_snapshot: Dictionary = runtime.get_snapshot()
	_expect(float(stow_snapshot.get("companion_switch_transition", 0.0)) > 0.0, "stow should reuse the 0.62s switch transition")
	var ghost_vfx: Object = runtime.get("_ghost_blink_vfx")
	_expect(ghost_vfx != null and bool(ghost_vfx.is_active_for_tests()), "stow should reuse ghost blink feedback")

	runtime.try_toggle_guardian_stow(owner, registry)
	_expect(not runtime.is_guardian_stowed(), "healthy shared pool should allow immediate resummon")
	_expect(runtime.is_companion_active(), "resummoned guardian should publish active")
	_cleanup_runtime(runtime)


func _make_runtime_owner() -> Object:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _button_event(pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_RIGHT_STICK
	event.pressed = pressed
	return event


func _axis_event(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])
