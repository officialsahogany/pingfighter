extends SceneTree

const LingpetCompanionSkillController := preload("res://scripts/lingpet/lingpet_companion_skill_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(320.0, 410.0)
	var ball_vel := Vector2(4.0, -18.0)
	var ball_size := 30.0


class FakeSkillState:
	extends RefCounted

	var cooldown := 0.0
	var windup_active := false
	var launch_on_advance := false

	func advance_windup(_delta: float, _duration: float) -> bool:
		return launch_on_advance

	func arm_windup() -> void:
		windup_active = true

	func cancel_windup() -> void:
		windup_active = false


class FakeRuntimeHost:
	extends RefCounted

	var update_count := 0
	var prewarm_count := 0
	var update_companion_positions: Array[Vector2] = []

	func update(_delta: float, _owner: Object, _registry: Object, _skill_id: String, params: Dictionary) -> void:
		update_count += 1
		update_companion_positions.append(params.get("companion_pos", Vector2.ZERO) as Vector2)

	func is_launch_blocked(_skill_id: String) -> bool:
		return false

	func can_arm(_skill_id: String, _params: Dictionary) -> bool:
		return true

	func prewarm(_skill_id: String) -> void:
		prewarm_count += 1

	func has_visible_effects_for_skill(_skill_id: String) -> bool:
		return false

	func skills_share_exclusive_resource(_first_skill_id: String, _second_skill_id: String) -> bool:
		return false


class FakeSkillRuntimeSurface:
	extends RefCounted

	var states: Array = []
	var override_pos := Vector2(455.0, 275.0)
	var strike_requests := 0

	func get_active_slot_count(_profile: Object, _slot_resolver: Object, _host: Object) -> int:
		return states.size()

	func get_active_skill_ids(_profile: Object, _slot_resolver: Object, _host: Object) -> Array[String]:
		var ids: Array[String] = []
		for slot in range(states.size()):
			ids.append("monkeyring_wild_roar" if slot == 1 else "maribo_hydro_sphere")
		return ids

	func get_active_surface_for_slot(
		_profile: Object,
		_slot_resolver: Object,
		_persistence: Object,
		_skill_states: Array,
		_host: Object,
		default_windup_seconds: float,
		slot: int,
		_active_slot_count: int
	) -> Dictionary:
		return {
			"skill_id": "monkeyring_wild_roar" if slot == 1 else "maribo_hydro_sphere",
			"skill_state": states[slot],
			"active_skill": {"level": slot + 1},
			"active_skill_level_fallback": slot + 1,
			"windup_seconds": default_windup_seconds,
		}

	func consume_companion_strike_request(_host: Object, _skill_id: String) -> bool:
		if strike_requests <= 0:
			return false
		strike_requests -= 1
		return true

	func get_active_position_owner_for_ids(
		_active_skill_ids: Array[String],
		_visual_resolver: Object,
		_host: Object,
		_fallback: Vector2
	) -> Dictionary:
		return {"skill_id": "maribo_hydro_sphere", "pos": override_pos}

	func has_active_position_override(_visual_resolver: Object, owner_surface: Dictionary) -> bool:
		return not owner_surface.is_empty()


class FakeRuntimeIntegration:
	extends RefCounted

	var ensure_calls := 0
	var launch_calls: Array[int] = []
	var strike_calls := 0
	var ensure_pos := Vector2(280.0, 360.0)
	var launch_pos := Vector2(330.0, 440.0)

	func ensure_companion_position_for_skill_tick(_owner: Object) -> Vector2:
		ensure_calls += 1
		return ensure_pos

	func launch_companion_skill_from_controller(_owner: Object, _registry: Object, slot: int) -> Vector2:
		launch_calls.append(slot)
		return launch_pos

	func begin_companion_skill_strike_from_controller() -> void:
		strike_calls += 1


func _init() -> void:
	_verify_controller_owns_full_slot_tick()
	_verify_runtime_keeps_a_narrow_integration_hook()

	if _failures.is_empty():
		print("lingpet_companion_skill_runtime_coordinator_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_controller_owns_full_slot_tick() -> void:
	var controller := LingpetCompanionSkillController.new()
	_expect(controller.has_method("update_active_slots"), "skill controller should own the full active-slot update tick")
	if not controller.has_method("update_active_slots"):
		return

	var ready_state := FakeSkillState.new()
	var second_ready_state := FakeSkillState.new()
	var cooldown_state := FakeSkillState.new()
	cooldown_state.cooldown = 3.0
	var states: Array = [ready_state, second_ready_state, cooldown_state]
	var surface := FakeSkillRuntimeSurface.new()
	surface.states = states
	surface.strike_requests = 1
	var host := FakeRuntimeHost.new()
	var integration := FakeRuntimeIntegration.new()
	controller.configure(
		RefCounted.new(),
		RefCounted.new(),
		RefCounted.new(),
		RefCounted.new(),
		states,
		host,
		surface,
		1.0,
		16.0
	)
	controller.reset_effect_update_counters_for_tests()

	var result: Vector2 = controller.update_active_slots(
		0.1,
		"companion",
		"companion",
		FakeOwner.new(),
		null,
		false,
		true,
		Vector2.ZERO,
		44.0,
		false,
		integration
	)

	_expect_eq(integration.ensure_calls, 1, "arming from an uninitialized position should request patrol initialization once")
	_expect(ready_state.windup_active, "ready slot should arm through the controller-owned loop")
	_expect(second_ready_state.windup_active, "later ready slots should continue through the same controller-owned loop")
	_expect_eq(host.prewarm_count, 2, "controller-owned arms should preserve per-slot skill prewarm")
	_expect_eq(integration.launch_calls.size(), 0, "arming tick should not launch early")
	_expect_eq(integration.strike_calls, 1, "controller-owned loop should consume and forward strike requests")
	_expect_eq(controller.get_effect_idle_skip_count_for_tests(), 1, "cooldown slot should retain the idle-skip performance gate")
	_expect_eq(controller.get_effect_runtime_update_count_for_tests(), 2, "ready slots should retain their runtime-host updates")
	_expect_eq(host.update_companion_positions, [Vector2.ZERO, Vector2(280.0, 360.0)], "position initialization should feed later slot contexts in the same tick")
	_expect_eq(result, surface.override_pos, "controller tick should return the resolved final active-skill position")

	ready_state.windup_active = true
	ready_state.launch_on_advance = true
	second_ready_state.cooldown = 2.0
	cooldown_state.cooldown = 4.0
	integration.launch_calls.clear()
	controller.update_active_slots(
		0.2,
		"companion",
		"companion",
		FakeOwner.new(),
		null,
		false,
		true,
		Vector2(250.0, 300.0),
		44.0,
		false,
		integration
	)
	_expect_eq(integration.launch_calls, [0], "completed windup should forward exactly its slot to the runtime launch seam")


func _verify_runtime_keeps_a_narrow_integration_hook() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
	var hook_body := _function_body(runtime_source, "func _update_companion_skill_effects")
	_expect(controller_source.find("func update_active_slots") >= 0, "skill controller source should expose the controller-owned slot tick")
	_expect(controller_source.find("LingpetCompanionSkillEffectUpdateGate") >= 0, "skill controller should compose the effect update gate")
	_expect(controller_source.find("LingpetCompanionSkillUpdateContextBuilder") >= 0, "skill controller should compose update-context assembly")
	_expect(controller_source.find("func configure") >= 0, "skill controller should retain stable dependencies outside the hot tick")
	_expect(hook_body.find("_companion_skill_controller.update_active_slots") >= 0, "egg runtime hook should delegate the complete slot tick")
	_expect(hook_body.find("for slot in range") < 0, "egg runtime hook should no longer own active-slot iteration")
	_expect(hook_body.find("BattleSceneOwnerReader.get_value") < 0, "egg runtime hook should no longer own lazy ball-context reads")
	_expect(hook_body.find("_companion_skill_update_context_builder.build") < 0, "egg runtime hook should no longer assemble per-slot controller contexts")
	_expect(hook_body.find("func(") < 0, "egg runtime hot hook should not allocate per-tick lambdas")
	_expect(hook_body.find("\"state\":") < 0, "egg runtime hot hook should not allocate a per-tick dependency dictionary")
	_expect(hook_body.find("var result: Dictionary") < 0, "egg runtime hot hook should not allocate a result dictionary")
	_expect(runtime_source.find("var _companion_skill_effect_update_gate") < 0, "egg runtime should not retain the controller's effect-gate instance")
	_expect(runtime_source.find("var _companion_skill_update_context_builder") < 0, "egg runtime should not retain the controller's context-builder instance")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
