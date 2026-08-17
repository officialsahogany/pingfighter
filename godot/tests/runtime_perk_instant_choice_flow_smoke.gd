extends SceneTree

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkDeferredInstants := preload("res://scripts/characters/runtime_perk_deferred_instants.gd")
const RuntimePerkInstantChoiceFlow := preload("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []
var _sync_owner_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 0
	var selected_character_type := "smasher"
	var special_gauge := 0.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false
	var runtime_perk_gold := 0
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeDashState:
	extends RefCounted

	var refill_calls := 0

	func refill_tokens() -> void:
		refill_calls += 1


class FakeSkillState:
	extends RefCounted

	var reset_calls := 0

	func reset_cooldowns() -> void:
		reset_calls += 1


class FakeActiveItemRuntime:
	extends RefCounted

	var dimension_calls := 0
	var fill_calls := 0
	var last_fill_item := ""

	func activate_dimension_gate(_registry: Object = null) -> bool:
		dimension_calls += 1
		return true

	func fill_empty_slots_with_item(item_name: String, _owner: Object, _registry: Object) -> int:
		fill_calls += 1
		last_fill_item = item_name
		return 1




func _init() -> void:
	_verify_flow_applies_immediate_rewards()
	_verify_flow_state_facing_wrappers()
	_verify_flow_resolves_spawn_intro_deferrals()
	_verify_state_wrappers_delegate_to_flow()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_instant_choice_flow_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_flow_applies_immediate_rewards() -> void:
	var flow: Object = RuntimePerkInstantChoiceFlow.new()
	var rewards: Object = RuntimePerkInstantRewards.new()
	var owner := FakeOwner.new()
	var dash := FakeDashState.new()
	var skill := FakeSkillState.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"smasher_dash_state": dash,
		"smasher_skill_state": skill,
		"active_item_runtime": active_runtime,
	}

	var full_result: Dictionary = flow.apply_full_gauge_choice(
		rewards,
		RuntimePerkCharacterContext.new(),
		owner,
		registry,
		RuntimePerkState.SPECIAL_GAUGE_MAX,
		Callable(self, "_get_instance")
	)
	_expect(bool(full_result.get("accepted", false)), "instant flow should apply full-gauge choice payloads")
	_expect(is_equal_approx(owner.special_gauge, RuntimePerkState.SPECIAL_GAUGE_MAX), "instant flow should fill owner gauge")
	_expect(dash.refill_calls == 1, "instant flow should route full-gauge dash refill")
	_expect(skill.reset_calls == 1, "instant flow should route full-gauge cooldown reset")

	var gate_result: Dictionary = flow.apply_dimension_gate_choice(rewards, registry, Callable(self, "_get_instance"))
	_expect(bool(gate_result.get("accepted", false)), "instant flow should apply Dimension Gate choice payloads")
	_expect(active_runtime.dimension_calls == 1, "instant flow should route Dimension Gate activation")


func _verify_flow_state_facing_wrappers() -> void:
	var flow: Object = RuntimePerkInstantChoiceFlow.new()
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var dash := FakeDashState.new()
	var skill := FakeSkillState.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"smasher_dash_state": dash,
		"smasher_skill_state": skill,
		"active_item_runtime": active_runtime,
	}

	var full_result: Dictionary = flow.apply_full_gauge_choice_from_runtime_state(
		state,
		owner,
		registry,
		RuntimePerkState.SPECIAL_GAUGE_MAX
	)
	_expect(bool(full_result.get("accepted", false)), "state-facing full-gauge wrapper should accept valid runtime state")
	_expect(is_equal_approx(owner.special_gauge, RuntimePerkState.SPECIAL_GAUGE_MAX), "state-facing full-gauge wrapper should fill owner gauge")
	_expect(dash.refill_calls == 1 and skill.reset_calls == 1, "state-facing full-gauge wrapper should route get_instance through runtime state")
	var gate_result: Dictionary = flow.apply_dimension_gate_choice_from_runtime_state(state, registry)
	_expect(bool(gate_result.get("accepted", false)), "state-facing Dimension Gate wrapper should accept valid runtime state")
	_expect(active_runtime.dimension_calls == 1, "state-facing Dimension Gate wrapper should route activation through runtime state")
	var monkey_result: Dictionary = flow.apply_monkey_blessing_choice_from_runtime_state(state, owner, registry, "Monkey")
	_expect(bool(monkey_result.get("accepted", false)), "state-facing Monkey Blessing wrapper should accept valid runtime state")
	_expect(active_runtime.fill_calls == 1 and active_runtime.last_fill_item == "banana", "state-facing Monkey Blessing wrapper should route get_instance through runtime state")

	state.current_choice_context = {
		RuntimePerkDeferredInstants.DEFER_FULL_GAUGE_CONTEXT_KEY: true,
		RuntimePerkDeferredInstants.DEFER_DIMENSION_GATE_CONTEXT_KEY: true,
	}
	_expect(flow.should_defer_full_gauge_from_runtime_state(state), "state-facing full-gauge defer query should read runtime choice context")
	_expect(flow.should_defer_dimension_gate_from_runtime_state(state), "state-facing Dimension Gate defer query should read runtime choice context")
	var gauge_queue: Dictionary = flow.queue_full_gauge_choice_from_runtime_state(state, owner, "Gauge")
	var gate_queue: Dictionary = flow.queue_dimension_gate_choice_from_runtime_state(state, owner, "Gate")
	_expect(bool(gauge_queue.get("accepted", false)), "state-facing full-gauge queue should accept valid runtime state")
	_expect(bool(gate_queue.get("accepted", false)), "state-facing Dimension Gate queue should accept valid runtime state")
	_expect(flow.has_pending_full_gauge_from_runtime_state(state), "state-facing full-gauge pending query should read deferred helper")
	_expect(flow.has_pending_dimension_gate_from_runtime_state(state), "state-facing Dimension Gate pending query should read deferred helper")


func _verify_flow_resolves_spawn_intro_deferrals() -> void:
	_sync_owner_calls = 0
	var flow: Object = RuntimePerkInstantChoiceFlow.new()
	var deferred := RuntimePerkDeferredInstants.new()
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	owner.current_stage = 5
	var registry := FakeRegistry.new()
	registry.instances = {"active_item_runtime": FakeActiveItemRuntime.new()}
	flow.queue_dimension_gate(deferred, owner, "Gate")
	owner.current_stage = 6

	var result: Dictionary = flow.on_ball_spawn_intro_finished(
		deferred,
		state,
		owner,
		registry,
		state._choice_feedback,
		Callable(state, "_apply_dimension_gate"),
		Callable(state, "_apply_full_gauge"),
		Callable(self, "_sync_owner")
	)
	_expect(bool(result.get("dimension_gate_activated", false)), "instant flow should expose ready Dimension Gate activation")
	_expect(str(state.feedback_text) == "Gate", "instant flow should apply deferred feedback through choice feedback helper")
	_expect(_sync_owner_calls == 1, "instant flow should call owner sync when deferred actions request it")
	_expect(not result.has("_feedback_text"), "instant flow should strip helper-only feedback keys from public result")
	_expect(not result.has("_sync_owner"), "instant flow should strip helper-only sync keys from public result")


func _verify_state_wrappers_delegate_to_flow() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var dash := FakeDashState.new()
	var skill := FakeSkillState.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"smasher_dash_state": dash,
		"smasher_skill_state": skill,
		"active_item_runtime": active_runtime,
	}

	_expect(state.apply_choice({"id": "instant_gauge_full", "name": "Gauge"}, owner, registry), "state full-gauge wrapper should still apply through action flow")
	_expect(dash.refill_calls == 1 and skill.reset_calls == 1, "state full-gauge wrapper should delegate to instant choice flow")
	_expect(state.apply_choice({"id": "instant_dimension_gate", "name": "Gate"}, owner, registry), "state Dimension Gate wrapper should still apply through action flow")
	_expect(active_runtime.dimension_calls == 1, "state Dimension Gate wrapper should delegate to instant choice flow")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
	_expect(state_source.find("RuntimePerkInstantChoiceFlow") >= 0, "state should preload the instant choice flow helper")
	_expect(flow_source.find("apply_owner_full_gauge_choice") >= 0, "instant flow should own full-gauge reward helper invocation")
	_expect(flow_source.find("apply_dimension_gate_choice") >= 0, "instant flow should own Dimension Gate reward helper invocation")
	_expect(flow_source.find("func apply_full_gauge_choice_from_runtime_state") >= 0, "instant flow should own runtime-state full-gauge assembly")
	_expect(flow_source.find("func apply_dimension_gate_choice_from_runtime_state") >= 0, "instant flow should own runtime-state Dimension Gate assembly")
	_expect(flow_source.find("func apply_monkey_blessing_choice_from_runtime_state") >= 0, "instant flow should own runtime-state Monkey Blessing assembly")
	_expect(flow_source.find("func on_ball_spawn_intro_finished_from_runtime_state") >= 0, "instant flow should own runtime-state spawn-intro assembly")
	_expect(flow_source.find("collect_spawn_intro_actions") >= 0, "instant flow should own deferred spawn-intro action collection")
	_expect(flow_source.find("resolve_spawn_intro_actions") >= 0, "instant flow should own deferred spawn-intro action resolution")
	_expect(flow_source.find("apply_spawn_intro_state_update") >= 0, "instant flow should own deferred spawn-intro feedback application")
	var intro_body: String = _function_body(state_source, "func on_ball_spawn_intro_finished(")
	_expect(intro_body.find("_instant_choice_flow.on_ball_spawn_intro_finished_from_runtime_state") >= 0, "state spawn-intro wrapper should delegate to instant choice flow runtime-state API")
	_expect(intro_body.find("collect_spawn_intro_actions") < 0, "state should not collect deferred spawn-intro actions inline")
	_expect(intro_body.find("resolve_spawn_intro_actions") < 0, "state should not resolve deferred spawn-intro actions inline")
	_expect(intro_body.find("apply_spawn_intro_state_update") < 0, "state should not apply deferred spawn-intro feedback inline")
	var full_body: String = _function_body(state_source, "func _apply_full_gauge_choice(")
	_expect(full_body.find("_instant_choice_flow.apply_full_gauge_choice_from_runtime_state") >= 0, "state full-gauge wrapper should delegate to instant choice flow runtime-state API")
	_expect(full_body.find("_instant_rewards") < 0, "state full-gauge wrapper should not pass instant rewards directly")
	_expect(full_body.find("_character_context") < 0, "state full-gauge wrapper should not pass character context directly")
	_expect(full_body.find("Callable(self, \"_get_instance\")") < 0, "state full-gauge wrapper should not build get-instance callbacks directly")
	_expect(full_body.find("_instant_rewards.apply_owner_full_gauge_choice") < 0, "state should not call full-gauge reward helper inline")
	var gate_body: String = _function_body(state_source, "func _apply_dimension_gate_choice(")
	_expect(gate_body.find("_instant_choice_flow.apply_dimension_gate_choice_from_runtime_state") >= 0, "state Dimension Gate wrapper should delegate to instant choice flow runtime-state API")
	_expect(gate_body.find("_instant_rewards") < 0, "state Dimension Gate wrapper should not pass instant rewards directly")
	_expect(gate_body.find("Callable(self, \"_get_instance\")") < 0, "state Dimension Gate wrapper should not build get-instance callbacks directly")
	_expect(gate_body.find("_instant_rewards.apply_dimension_gate_choice") < 0, "state should not call Dimension Gate reward helper inline")
	var monkey_body: String = _function_body(state_source, "func _apply_monkey_blessing_choice(")
	_expect(monkey_body.find("_instant_choice_flow.apply_monkey_blessing_choice_from_runtime_state") >= 0, "state Monkey Blessing wrapper should delegate to instant choice flow runtime-state API")
	_expect(monkey_body.find("_instant_rewards") < 0, "state Monkey Blessing wrapper should not pass instant rewards directly")
	_expect(monkey_body.find("Callable(self, \"_get_instance\")") < 0, "state Monkey Blessing wrapper should not build get-instance callbacks directly")
	var defer_body: String = _function_body(state_source, "func _should_defer_full_gauge_until_spawn_intro_end(")
	_expect(defer_body.find("current_choice_context") < 0, "state defer wrapper should not pass current choice context directly")
	_expect(defer_body.find("_deferred_instants") < 0, "state defer wrapper should not pass deferred helper directly")


func _get_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null


func _sync_owner(_owner: Object) -> void:
	_sync_owner_calls += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
