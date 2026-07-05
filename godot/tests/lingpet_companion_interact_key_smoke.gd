extends SceneTree

# Non-mouse bond interact (E key + gamepad RT trigger) routing seal.
#
# The space_arrows / gamepad grips cannot mouse-click the companion, so the
# battle input controller routes LINGPET_INTERACT_KEY and the RT trigger axis
# through the runtime's self-targeting wrapper. This smoke seals the ROUTING
# contract only:
# - E (keycode or physical keycode) reaches try_begin_companion_interact_reaction
#   with the registry, and consumes the input (redraw + handled) on success.
# - RT is an axis: a pull past the press threshold fires exactly ONE interact
#   (latched); it re-arms only after the value drops below the release
#   threshold. LT and mid-band jitter never fire.
# - A refused interact (no companion / not ready) does NOT consume the input,
#   so E stays a live key for downstream handlers.
# - Echo / release / other keys / mouse events never reach the wrapper.
# Reaction/affinity SEMANTICS (grant, replay, round cap, hidden gate) are
# sealed runtime-side in lingpet_egg_runtime_smoke._verify_companion_interact_key_reaction.

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

var _failures: Array[String] = []
var _active_modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeReadinessController:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


class FakeLingpetRuntime:
	extends RefCounted

	var accept := true
	var interact_calls := 0
	var last_registry: Object = null

	func try_begin_companion_interact_reaction(registry: Object = null) -> bool:
		interact_calls += 1
		last_registry = registry
		return accept


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_interact_key_routes_via_module_getter()
	_verify_interact_key_routes_via_registry_fallback()
	_verify_refused_interact_falls_through()
	_verify_non_interact_events_never_reach_the_wrapper()
	_verify_trigger_pull_fires_once_and_rearms_on_release()
	_verify_trigger_noise_never_fires()

	if _failures.is_empty():
		print("lingpet_companion_interact_key_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_interact_key_routes_via_module_getter() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new({})
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
		"lingpet_egg_runtime": runtime,
	}

	input.handle_unhandled_input(_interact_key_event(), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 1, "E should route to the runtime interact wrapper via the module getter")
	_expect(runtime.last_registry == registry, "interact routing should hand the registry through for the per-pet voice")
	_expect(owner.redraw_count == 1, "consumed interact should request a redraw")

	var physical_only := InputEventKey.new()
	physical_only.pressed = true
	physical_only.keycode = KEY_NONE
	physical_only.physical_keycode = KEY_E
	input.handle_unhandled_input(physical_only, owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 2, "physical-keycode-only E should also route to the interact wrapper")
	_active_modules.clear()


func _verify_interact_key_routes_via_registry_fallback() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
	}

	input.handle_unhandled_input(_interact_key_event(), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 1, "E should fall back to the registry lingpet runtime when the module getter misses")
	_expect(owner.redraw_count == 1, "registry-fallback interact should still request a redraw")
	_active_modules.clear()


func _verify_refused_interact_falls_through() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	runtime.accept = false
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
	}

	input.handle_unhandled_input(_interact_key_event(), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 1, "refused interact should still have consulted the runtime once")
	_expect(owner.redraw_count == 0, "refused interact must NOT consume the input (no redraw, E stays live downstream)")
	_active_modules.clear()


func _verify_non_interact_events_never_reach_the_wrapper() -> void:
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
	}

	var echo_event := _interact_key_event()
	echo_event.echo = true
	input.handle_unhandled_input(echo_event, owner, registry, Callable(self, "_get_module"), {})

	var release_event := _interact_key_event()
	release_event.pressed = false
	input.handle_unhandled_input(release_event, owner, registry, Callable(self, "_get_module"), {})

	var other_key := InputEventKey.new()
	other_key.pressed = true
	other_key.keycode = KEY_F
	other_key.physical_keycode = KEY_F
	input.handle_unhandled_input(other_key, owner, registry, Callable(self, "_get_module"), {})

	var cycle_key := InputEventKey.new()
	cycle_key.pressed = true
	cycle_key.keycode = KEY_L
	cycle_key.physical_keycode = KEY_L
	input.handle_unhandled_input(cycle_key, owner, registry, Callable(self, "_get_module"), {})

	var mouse_motion := InputEventMouseMotion.new()
	input.handle_unhandled_input(mouse_motion, owner, registry, Callable(self, "_get_module"), {})

	_expect(runtime.interact_calls == 0, "echo / release / other keys / L cycle / mouse events must never reach the interact wrapper")
	_expect(owner.redraw_count == 0, "ignored events should not request redraws through the interact path")
	_active_modules.clear()


func _verify_trigger_pull_fires_once_and_rearms_on_release() -> void:
	GamepadInput.clear_primary_action_trigger_suppression_for_tests()
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
	}

	input.handle_unhandled_input(_trigger_event(0.9), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 1, "RT pull past the press threshold should fire one interact")
	_expect(owner.redraw_count == 1, "consumed RT interact should request a redraw")
	_expect(GamepadInput.is_primary_action_trigger_suppressed_for_tests(), "accepted RT interact should mask RT from primary-action polling until release")

	input.handle_unhandled_input(_trigger_event(0.95), owner, registry, Callable(self, "_get_module"), {})
	input.handle_unhandled_input(_trigger_event(0.7), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 1, "held RT (latched) must not re-fire on further analog motion")
	_expect(GamepadInput.is_primary_action_trigger_suppressed_for_tests(), "held RT should stay masked from primary-action polling")

	input.handle_unhandled_input(_trigger_event(0.5), owner, registry, Callable(self, "_get_module"), {})
	input.handle_unhandled_input(_trigger_event(0.9), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 1, "dropping only into the mid band (release < value < press) must not re-arm the latch")
	_expect(GamepadInput.is_primary_action_trigger_suppressed_for_tests(), "mid-band RT jitter should not unmask primary-action polling")

	input.handle_unhandled_input(_trigger_event(0.1), owner, registry, Callable(self, "_get_module"), {})
	_expect(not GamepadInput.is_primary_action_trigger_suppressed_for_tests(), "full RT release should unmask primary-action polling")
	input.handle_unhandled_input(_trigger_event(0.9), owner, registry, Callable(self, "_get_module"), {})
	_expect(runtime.interact_calls == 2, "a full release below the release threshold should re-arm the next pull")
	_expect(GamepadInput.is_primary_action_trigger_suppressed_for_tests(), "second accepted RT pull should mask primary-action polling again")
	_active_modules.clear()
	GamepadInput.clear_primary_action_trigger_suppression_for_tests()


func _verify_trigger_noise_never_fires() -> void:
	GamepadInput.clear_primary_action_trigger_suppression_for_tests()
	var input := BattleSceneInputController.new()
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_active_modules = {
		"battle_scene_readiness_controller": FakeReadinessController.new(),
	}

	var left_trigger := InputEventJoypadMotion.new()
	left_trigger.axis = JOY_AXIS_TRIGGER_LEFT
	left_trigger.axis_value = 1.0
	input.handle_unhandled_input(left_trigger, owner, registry, Callable(self, "_get_module"), {})

	input.handle_unhandled_input(_trigger_event(0.5), owner, registry, Callable(self, "_get_module"), {})
	input.handle_unhandled_input(_trigger_event(0.0), owner, registry, Callable(self, "_get_module"), {})

	var left_stick := InputEventJoypadMotion.new()
	left_stick.axis = JOY_AXIS_LEFT_X
	left_stick.axis_value = 1.0
	input.handle_unhandled_input(left_stick, owner, registry, Callable(self, "_get_module"), {})

	_expect(runtime.interact_calls == 0, "LT / mid-band RT / stick axes must never reach the interact wrapper")
	_expect(owner.redraw_count == 0, "trigger noise should not request redraws through the interact path")
	_expect(not GamepadInput.is_primary_action_trigger_suppressed_for_tests(), "ignored trigger noise should not mask primary-action polling")
	_active_modules.clear()


func _get_module(key: String) -> Object:
	return _active_modules.get(key, null)


func _trigger_event(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


func _interact_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
