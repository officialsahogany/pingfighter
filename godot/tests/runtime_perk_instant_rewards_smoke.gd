extends SceneTree

const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")
const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 0.0
	var selected_character_type := "smasher"


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
		return 2


class FakeMonkeyBlessingDelivery:
	extends RefCounted

	var start_calls := 0

	func start(_owner: Object, _registry: Object) -> bool:
		start_calls += 1
		return true


class FakeTreasureRuntime:
	extends RefCounted

	var start_calls := 0

	func start(_owner: Object, _registry: Object) -> Dictionary:
		start_calls += 1
		return {"ok": true, "feedback_text": "treasure-ok"}


func _init() -> void:
	_run()


func _run() -> void:
	_verify_bookkeeping_instant_choices()
	_verify_debug_instant_choice_update()
	_verify_full_gauge_reward()
	_verify_dimension_gate_reward()
	_verify_monkey_blessing_delivery_and_fallback()
	_verify_treasure_hunt_reward()

	if _failures.is_empty():
		print("runtime_perk_instant_rewards_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bookkeeping_instant_choices() -> void:
	var helper := RuntimePerkInstantRewards.new()

	var refresh_result: Dictionary = helper.apply_bookkeeping_choice({"id": "common_refresh"}, 0, 0, 1)
	_expect(bool(refresh_result.get("handled", false)), "common_refresh should be handled as bookkeeping instant")
	_expect(bool(refresh_result.get("accepted", false)), "common_refresh bookkeeping should be accepted")
	_expect(int(refresh_result.get("pending_skill_choices", 0)) == 1, "common_refresh should add one pending choice")
	_expect(str(refresh_result.get("feedback_key", "")) == "common_refresh", "common_refresh should return a feedback key")
	_expect(str(refresh_result.get("feedback_text", "")) == "\uc120\ud0dd\uc9c0 \uc0c8\ub85c\uace0\uce68", "common_refresh should own its visible feedback text")
	var refresh_update: Dictionary = helper.build_bookkeeping_state_update(refresh_result, 0, 0)
	_expect(bool(refresh_update.get("handled", false)), "common_refresh update should preserve handled state")
	_expect(int(refresh_update.get("next_pending_skill_choices", 0)) == 1, "common_refresh update should expose next pending choices")
	_expect(int(refresh_update.get("next_starpoint_for_skills", -1)) == 0, "common_refresh update should expose next starpoint remainder")

	var star_result: Dictionary = helper.apply_bookkeeping_choice({"id": "star_change"}, 0, 0, 1)
	_expect(bool(star_result.get("handled", false)), "star_change should be handled as bookkeeping instant")
	_expect(int(star_result.get("pending_skill_choices", 0)) == 3, "star_change should convert three starpoints into choices")
	_expect(int(star_result.get("starpoint_for_skills", -1)) == 0, "star_change should leave no remainder at one starpoint per choice")
	_expect(str(star_result.get("feedback_key", "")) == "star_change", "star_change should return a feedback key")
	_expect(str(star_result.get("feedback_text", "")) == "\uc2a4\ud0c0\ud3ec\uc778\ud2b8 +3", "star_change should own its visible feedback text")
	var star_update: Dictionary = helper.build_bookkeeping_state_update(star_result, 0, 0)
	_expect(int(star_update.get("next_pending_skill_choices", 0)) == 3, "star_change update should expose converted pending choices")
	_expect(int(star_update.get("next_starpoint_for_skills", -1)) == 0, "star_change update should expose converted starpoint remainder")

	var generic_result: Dictionary = helper.apply_bookkeeping_choice(
		{"id": "instant_debug", "is_instant": true, "name": "Instant Debug"},
		2,
		1,
		2
	)
	_expect(bool(generic_result.get("handled", false)), "generic instant choice should be handled")
	_expect(int(generic_result.get("pending_skill_choices", 0)) == 2, "generic instant should not change pending choices")
	_expect(int(generic_result.get("starpoint_for_skills", 0)) == 1, "generic instant should preserve starpoint remainder")
	_expect(str(generic_result.get("feedback_text", "")) == "Instant Debug", "generic instant should surface choice name feedback")
	var generic_update: Dictionary = helper.build_bookkeeping_state_update(generic_result, 2, 1)
	_expect(int(generic_update.get("next_pending_skill_choices", 0)) == 2, "generic update should preserve pending choices")
	_expect(int(generic_update.get("next_starpoint_for_skills", 0)) == 1, "generic update should preserve starpoint remainder")

	var ordinary_result: Dictionary = helper.apply_bookkeeping_choice({"id": "common_swiftness"}, 0, 0, 1)
	_expect(not bool(ordinary_result.get("handled", false)), "ordinary level-up perks should not be handled as instant bookkeeping")
	var ordinary_update: Dictionary = helper.build_bookkeeping_state_update(ordinary_result, 4, 2)
	_expect(not bool(ordinary_update.get("handled", false)), "ordinary update should preserve unhandled state")
	_expect(int(ordinary_update.get("next_pending_skill_choices", 0)) == 4, "ordinary update should preserve current pending choices")
	_expect(int(ordinary_update.get("next_starpoint_for_skills", 0)) == 2, "ordinary update should preserve current starpoint remainder")


func _verify_debug_instant_choice_update() -> void:
	var helper := RuntimePerkInstantRewards.new()
	var update: Dictionary = helper.build_debug_instant_choice_update(
		"instant_debug",
		{"name": "Instant Debug", "is_instant": true}
	)
	_expect(bool(update.get("accepted", false)), "debug instant update should accept valid perk data")
	_expect(str(update.get("choice_id", "")) == "instant_debug", "debug instant update should expose the choice id")
	_expect(int(update.get("current_level", -1)) == 0, "debug instant update should expose zero current level")
	_expect(int(update.get("next_level", -1)) == 0, "debug instant update should expose zero next level")
	_expect(not bool(helper.build_debug_instant_choice_update("", {"name": "Instant"}).get("accepted", false)), "debug instant update should reject blank ids")
	_expect(not bool(helper.build_debug_instant_choice_update("instant_debug", {}).get("accepted", false)), "debug instant update should reject empty perk data")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var debug_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_debug_grants.gd")
	_expect(state_source.find("_debug_grants.apply_debug_grant") >= 0, "state should route debug instant grants through debug-grant orchestration")
	_expect(debug_source.find("build_debug_instant_choice_update") >= 0, "debug-grant helper should call helper-owned debug instant updates")
	_expect(state_source.find("build_debug_instant_choice_update") < 0, "state should not call debug instant update builders directly")
	var instant_branch := state_source.find("if bool(data.get(\"is_instant\", false))")
	var unlock_branch := state_source.find("if str(data.get(\"unlocks_skill\", \"\"))", instant_branch)
	var inline_current_level := state_source.find("data[\"current_level\"] = 0", instant_branch)
	var inline_next_level := state_source.find("data[\"next_level\"] = 0", instant_branch)
	_expect(inline_current_level < 0 or inline_current_level > unlock_branch, "state should not own debug instant current-level payload")
	_expect(inline_next_level < 0 or inline_next_level > unlock_branch, "state should not own debug instant next-level payload")


func _verify_full_gauge_reward() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var dash := FakeDashState.new()
	var skill := FakeSkillState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"smasher_dash_state": dash,
		"smasher_skill_state": skill,
	}

	var applied: bool = state.apply_choice({"id": "instant_gauge_full", "name": "Gauge"}, owner, registry)
	_expect(applied, "instant gauge should apply")
	_expect(is_equal_approx(owner.special_gauge, RuntimePerkState.SPECIAL_GAUGE_MAX), "instant gauge should fill the owner gauge")
	_expect(dash.refill_calls == 1, "instant gauge should refill dash tokens")
	_expect(skill.reset_calls == 1, "instant gauge should reset character skill cooldowns")
	_expect(str(state.feedback_text) == RuntimePerkInstantRewards.FULL_GAUGE_FEEDBACK_TEXT, "instant gauge should apply helper-owned feedback text")
	_expect(is_equal_approx(float(state.feedback_timer), RuntimePerkInstantRewards.IMMEDIATE_FEEDBACK_TIMER), "instant gauge should apply helper-owned feedback timer")

	var helper := RuntimePerkInstantRewards.new()
	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	var viper_skill := FakeSkillState.new()
	var direct_registry := FakeRegistry.new()
	direct_registry.instances = {
		"smasher_dash_state": FakeDashState.new(),
		"viper_skill_state": viper_skill,
	}
	var direct_result: Dictionary = helper.apply_owner_full_gauge_choice(
		viper_owner,
		direct_registry,
		RuntimePerkCharacterContext.new(),
		RuntimePerkState.SPECIAL_GAUGE_MAX,
		Callable(self, "_get_instance")
	)
	_expect(bool(direct_result.get("accepted", false)), "owner full-gauge helper should accept valid owner context")
	_expect(viper_skill.reset_calls == 1, "owner full-gauge helper should resolve the owner skill-state key")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var instant_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
	_expect(state_source.find("_instant_choice_flow.apply_full_gauge_choice") >= 0, "state should route owner full-gauge choice through instant choice flow")
	_expect(state_source.find("_instant_choice_flow.apply_full_gauge") >= 0, "state should route owner full-gauge apply through instant choice flow")
	_expect(instant_flow_source.find("apply_owner_full_gauge_choice") >= 0, "instant choice flow should use helper-owned owner full-gauge choice wrapper")
	_expect(instant_flow_source.find("apply_owner_full_gauge(") >= 0, "instant choice flow should use helper-owned owner full-gauge apply wrapper")
	_expect(state_source.find("var character_type: String = _get_character_type(owner)") < 0, "state should not resolve full-gauge character type inline")


func _verify_dimension_gate_reward() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {"active_item_runtime": active_runtime}

	var applied: bool = state.apply_choice({"id": "instant_dimension_gate", "name": "Gate"}, owner, registry)
	_expect(applied, "dimension gate should apply when active item runtime accepts")
	_expect(active_runtime.dimension_calls == 1, "dimension gate should route through active_item_runtime.activate_dimension_gate")
	_expect(str(state.feedback_text) == RuntimePerkInstantRewards.DIMENSION_GATE_FEEDBACK_TEXT, "dimension gate should apply helper-owned feedback text")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var apply_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var instant_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
	_expect(state_source.find("func _apply_choice_feedback_result") >= 0, "state should centralize helper feedback result application")
	_expect(apply_flow_source.find("build_bookkeeping_state_update") >= 0, "apply-flow helper should apply bookkeeping updates through instant helper")
	_expect(state_source.find("_choice_apply_flow.apply_choice") >= 0, "state should route standard bookkeeping choices through apply-flow orchestration")
	_expect(state_source.find("bookkeeping_instant.get(\"pending_skill_choices\"") < 0, "state should not read bookkeeping pending choices from raw helper result")
	_expect(state_source.find("bookkeeping_instant.get(\"starpoint_for_skills\"") < 0, "state should not read bookkeeping starpoints from raw helper result")
	_expect(state_source.find(RuntimePerkInstantRewards.FULL_GAUGE_FEEDBACK_TEXT) < 0, "state should not own full-gauge success feedback text")
	_expect(state_source.find(RuntimePerkInstantRewards.DIMENSION_GATE_FEEDBACK_TEXT) < 0, "state should not own Dimension Gate success feedback text")
	_expect(state_source.find("feedback_text = str(full_gauge_result") < 0, "state should not inline full-gauge helper feedback application")
	_expect(state_source.find("feedback_text = str(dimension_gate_result") < 0, "state should not inline Dimension Gate helper feedback application")
	_expect(instant_flow_source.find("apply_dimension_gate_choice") >= 0, "instant choice flow should route Dimension Gate choice payloads")
	var reward_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_rewards.gd")
	_expect(reward_source.find("func apply_full_gauge_choice") >= 0, "instant reward helper should own full-gauge choice payloads")
	_expect(reward_source.find("func apply_dimension_gate_choice") >= 0, "instant reward helper should own Dimension Gate choice payloads")
	_expect(reward_source.find("func apply_monkey_blessing_choice") >= 0, "instant reward helper should own Monkey Blessing choice payloads")
	_expect(reward_source.find("func apply_treasure_hunt_choice") >= 0, "instant reward helper should own Treasure Hunt choice payloads")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
	_expect(flow_source.find("func apply_monkey_blessing_choice_from_runtime_state") >= 0, "instant choice flow should own runtime-state Monkey Blessing assembly")
	_expect(flow_source.find("func apply_treasure_hunt_choice_from_runtime_state") >= 0, "instant choice flow should own runtime-state Treasure Hunt assembly")


func _verify_monkey_blessing_delivery_and_fallback() -> void:
	var owner := FakeOwner.new()

	var delivery_state := RuntimePerkState.new()
	var delivery := FakeMonkeyBlessingDelivery.new()
	var delivery_registry := FakeRegistry.new()
	delivery_registry.instances = {"monkey_blessing_delivery_state": delivery}
	_expect(delivery_state.apply_choice({"id": "instant_monkey_blessing", "name": "Monkey"}, owner, delivery_registry), "monkey blessing should apply through delivery state")
	_expect(delivery.start_calls == 1, "monkey blessing should prefer delivery_state.start")
	_expect(str(delivery_state.feedback_text) == "Monkey", "monkey blessing should surface helper-owned choice-name feedback text")
	_expect(is_equal_approx(float(delivery_state.feedback_timer), RuntimePerkInstantRewards.MONKEY_BLESSING_FEEDBACK_TIMER), "monkey blessing should apply helper-owned feedback timer")

	var fallback_state := RuntimePerkState.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var fallback_registry := FakeRegistry.new()
	fallback_registry.instances = {"active_item_runtime": active_runtime}
	_expect(fallback_state.apply_choice({"id": "instant_monkey_blessing", "name": "Monkey"}, owner, fallback_registry), "monkey blessing should apply through banana fallback")
	_expect(active_runtime.fill_calls == 1, "monkey blessing fallback should fill active item slots")
	_expect(active_runtime.last_fill_item == "banana", "monkey blessing fallback should request banana")
	_expect(is_equal_approx(float(fallback_state.feedback_timer), RuntimePerkInstantRewards.MONKEY_BLESSING_FEEDBACK_TIMER), "monkey blessing fallback should apply helper-owned feedback timer")


func _verify_treasure_hunt_reward() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var treasure := FakeTreasureRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {"treasure_hunt_runtime": treasure}

	var applied: bool = state.apply_choice({"id": "instant_treasure_hunt", "name": "Treasure"}, owner, registry)
	_expect(applied, "treasure hunt should apply when runtime starts")
	_expect(treasure.start_calls == 1, "treasure hunt should route through treasure_hunt_runtime.start")
	_expect(state.feedback_text == "treasure-ok", "treasure hunt should surface runtime feedback text")
	_expect(is_equal_approx(float(state.feedback_timer), RuntimePerkInstantRewards.TREASURE_HUNT_FEEDBACK_TIMER), "treasure hunt should apply helper-owned feedback timer")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(state_source.find("_apply_monkey_blessing(owner, registry)") < 0, "state should apply Monkey Blessing through helper-owned choice payloads")
	_expect(state_source.find("_apply_treasure_hunt(owner, registry)") < 0, "state should apply Treasure Hunt through helper-owned choice payloads")
	var monkey_body := _function_body(state_source, "func _apply_monkey_blessing_choice(")
	_expect(monkey_body.find("_instant_choice_flow.apply_monkey_blessing_choice_from_runtime_state") >= 0, "state Monkey Blessing wrapper should delegate to instant choice flow runtime-state API")
	_expect(monkey_body.find("Callable(self, \"_get_instance\")") < 0, "state Monkey Blessing wrapper should not build get-instance callbacks directly")
	var treasure_body := _function_body(state_source, "func _apply_treasure_hunt_choice(")
	_expect(treasure_body.find("_instant_choice_flow.apply_treasure_hunt_choice_from_runtime_state") >= 0, "state Treasure Hunt wrapper should delegate to instant choice flow runtime-state API")
	_expect(treasure_body.find("Callable(self, \"_get_instance\")") < 0, "state Treasure Hunt wrapper should not build get-instance callbacks directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
