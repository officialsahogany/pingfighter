extends SceneTree

const AngelBlessingCooldownCapability := preload("res://scripts/characters/runtime_perk_angel_blessing_cooldown_capability.gd")
const AngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkOwnerEffectSync := preload("res://scripts/characters/runtime_perk_owner_effect_sync.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_character_context_routes_blacksmith_without_smasher_fallback()
	_verify_current_character_capability_matrix()
	_verify_future_hammer_shock_requires_a_declared_live_timer()
	_verify_runtime_roll_facade_consumes_the_capability_gate()
	_verify_blacksmith_config_accepts_shared_multiplier_inputs_without_fake_cooldown()

	if _failures.is_empty():
		print("angel_blessing_blacksmith_cooldown_capability_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_character_context_routes_blacksmith_without_smasher_fallback() -> void:
	var context: Object = RuntimePerkCharacterContext.new()
	for alias: String in ["blacksmith", "baltor", "kohaku"]:
		_expect(context.normalize_character_type(alias) == "blacksmith", "%s should normalize to Blacksmith" % alias)
		_expect(context.get_skill_config_key(alias) == "blacksmith_skill_config", "%s should route to the Blacksmith config" % alias)
		_expect(context.get_skill_state_key(alias) == "blacksmith_skill_state", "%s should route to the Blacksmith timer state" % alias)
		_expect(
			context.get_owner_character_type(FakeOwner.new({"selected_character_type": alias})) == "blacksmith",
			"owner alias %s should not fall back to Smasher" % alias
		)


func _verify_current_character_capability_matrix() -> void:
	var resolver: Object = AngelBlessingCooldownCapability.new()
	var angel_state: Object = AngelBlessingState.new()
	var registry := FakeRegistry.new({
		"smasher_skill_config": SmasherSkillConfig.new(),
		"smasher_skill_state": SmasherSkillState.new(),
		"viper_skill_config": ViperSkillConfig.new(),
		"viper_skill_state": SmasherSkillState.new(),
		"commando_skill_config": CommandoSkillConfig.new(),
		"commando_skill_state": SmasherSkillState.new(),
		"blacksmith_skill_config": BlacksmithSkillConfig.new(),
		"blacksmith_skill_state": SmasherSkillState.new(),
	})

	for character_type: String in ["smasher", "viper", "soldier", "commando"]:
		_expect(
			resolver.has_live_player_skill_cooldown(character_type, registry),
			"%s should retain Angel's live player-skill cooldown candidate" % character_type
		)
		_expect(
			"active_cooldown" in resolver.get_eligible_buff_ids(angel_state, character_type, registry),
			"%s eligible buffs should include active_cooldown" % character_type
		)

	for character_type: String in ["optimus", "io", "blacksmith", "baltor", "kohaku"]:
		_expect(
			not resolver.has_live_player_skill_cooldown(character_type, registry),
			"%s should exclude a dead player-skill cooldown candidate" % character_type
		)
		_expect(
			"active_cooldown" not in resolver.get_eligible_buff_ids(angel_state, character_type, registry),
			"%s eligible buffs should exclude active_cooldown" % character_type
		)

	var blacksmith_capability: Dictionary = resolver.get_capability("baltor", registry)
	_expect(str(blacksmith_capability.get("reason", "")) == "cooldown_contract_not_live", "current Baltor reason should expose the intentionally disabled cooldown contract")
	_expect((blacksmith_capability.get("configured_skill_ids", []) as Array).is_empty(), "current Baltor should expose no fake configured cooldown ids")

	var undeclared_config := UndeclaredCooldownConfig.new()
	var undeclared_registry := FakeRegistry.new({
		"blacksmith_skill_config": undeclared_config,
		"blacksmith_skill_state": SmasherSkillState.new(),
	})
	_expect(
		not resolver.has_live_player_skill_cooldown("blacksmith", undeclared_registry),
		"a positive cooldown without an explicit live declaration must fail closed"
	)

	var zero_multiplier_config: Object = SmasherSkillConfig.new()
	zero_multiplier_config.set_runtime_cooldown_multiplier(0.0)
	var zero_multiplier_registry := FakeRegistry.new({
		"smasher_skill_config": zero_multiplier_config,
		"smasher_skill_state": SmasherSkillState.new(),
	})
	_expect(
		resolver.has_live_player_skill_cooldown("smasher", zero_multiplier_registry),
		"structural cooldown capability must stay live when the current effective multiplier is zero"
	)


func _verify_future_hammer_shock_requires_a_declared_live_timer() -> void:
	var resolver: Object = AngelBlessingCooldownCapability.new()
	var timer_state: Object = SmasherSkillState.new()
	var incomplete_registry := FakeRegistry.new({
		"blacksmith_skill_config": FutureHammerConfig.new(false),
		"blacksmith_skill_state": timer_state,
	})
	_expect(
		not resolver.has_live_player_skill_cooldown("blacksmith", incomplete_registry),
		"a cooldown number alone must not expose Angel before Hammer Shock declares its live activation contract"
	)
	var snapshot_only_registry := FakeRegistry.new({
		"blacksmith_skill_config": SnapshotOnlyLiveConfig.new(),
		"blacksmith_skill_state": timer_state,
	})
	_expect(
		not resolver.has_live_player_skill_cooldown("blacksmith", snapshot_only_registry),
		"live-looking snapshot metadata without multiplier/getter APIs must fail closed"
	)

	var live_config := FutureHammerConfig.new(true)
	var live_registry := FakeRegistry.new({
		"blacksmith_skill_config": live_config,
		"blacksmith_skill_state": timer_state,
	})
	_expect(
		resolver.has_live_player_skill_cooldown("blacksmith", live_registry),
		"a future declared Hammer Shock config plus the real timer owner should open Angel automatically"
	)
	var capability: Dictionary = resolver.get_capability("blacksmith", live_registry)
	_expect(capability.get("configured_skill_ids", []) == ["hammer_shock"], "future capability should name Hammer Shock as its live cooldown")
	live_config.set_runtime_cooldown_multiplier(0.70)
	live_config.set_item_cooldown_multiplier(0.80)
	timer_state.trigger_configured_cooldown("hammer_shock", 1000, live_config)
	_expect_close(timer_state.get_cooldown_total_seconds("hammer_shock"), 3.92, "future live config should store the composed cooldown total in the actual timer")
	_expect_close(timer_state.get_configured_cooldown_remaining("hammer_shock", 1000, live_config), 1.0, "future live config should feed the actual remaining-ratio path")

	var missing_timer_registry := FakeRegistry.new({
		"blacksmith_skill_config": FutureHammerConfig.new(true),
		"blacksmith_skill_state": RefCounted.new(),
	})
	_expect(
		not resolver.has_live_player_skill_cooldown("blacksmith", missing_timer_registry),
		"declared Hammer Shock still needs a state that can store the actual cooldown"
	)
	var raw_timer_registry := FakeRegistry.new({
		"blacksmith_skill_config": live_config,
		"blacksmith_skill_state": RawOnlyCooldownState.new(),
	})
	_expect(
		not resolver.has_live_player_skill_cooldown("blacksmith", raw_timer_registry),
		"a raw hardcoded timer path must not bypass the configured multiplier contract"
	)


func _verify_runtime_roll_facade_consumes_the_capability_gate() -> void:
	var runtime: Object = RuntimePerkState.new()
	var registry := FakeRegistry.new({
		"blacksmith_skill_config": BlacksmithSkillConfig.new(),
		"blacksmith_skill_state": SmasherSkillState.new(),
	})
	_expect(
		"active_cooldown" not in runtime.get_angel_blessing_eligible_buff_ids("baltor", registry),
		"runtime facade should publish Baltor's current five-candidate pool"
	)
	var result: Dictionary = runtime.roll_angel_blessing_for_character_stage(
		1,
		"baltor",
		registry,
		1,
		["active_cooldown", "paddle_size"]
	)
	_expect(bool(result.get("rolled", false)), "runtime facade should still roll for current Baltor")
	_expect(result.get("active_buff_ids", []) == ["paddle_size"], "runtime roll must skip the dead active_cooldown candidate")


func _verify_blacksmith_config_accepts_shared_multiplier_inputs_without_fake_cooldown() -> void:
	var blacksmith_config: Object = BlacksmithSkillConfig.new()
	var registry := FakeRegistry.new({"blacksmith_skill_config": blacksmith_config})
	var perk_sync: Object = RuntimePerkOwnerEffectSync.new()
	perk_sync.apply_training_to_skill_configs(registry, 0.70, Callable(self, "_get_instance"))
	var after_perk: Dictionary = blacksmith_config.get_snapshot()
	_expect_close(float(after_perk.get("runtime_cooldown_multiplier", -1.0)), 0.70, "Angel/training input should reach the Blacksmith compatibility config")

	var item_sync: Object = MythicItemOwnerSyncer.new()
	item_sync.sync_skill_cooldown_to_configs(FakeMythicRuntime.new(0.80), registry)
	var after_item: Dictionary = blacksmith_config.get_snapshot()
	_expect_close(float(after_item.get("item_cooldown_multiplier", -1.0)), 0.80, "Timer Belt/Cape input should reach the Blacksmith compatibility config")
	_expect_close(float(after_item.get("cooldown_multiplier", -1.0)), 0.56, "Blacksmith compatibility config should compose the two shared inputs once")
	_expect((after_item.get("cooldown_seconds", {}) as Dictionary).is_empty(), "shared inputs must not invent a Thor Shield or Hammer Shock cooldown")
	_expect(not bool(after_item.get("cooldown_reduction_eligible", true)), "empty Blacksmith compatibility config must remain cooldown-ineligible")


func _get_instance(registry: Object, key: String) -> Object:
	return registry.get_instance(key) if registry != null and registry.has_method("get_instance") else null


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.6f, got %.6f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRegistry:
	var instances: Dictionary

	func _init(values: Dictionary) -> void:
		instances = values

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeOwner:
	var values: Dictionary

	func _init(source: Dictionary) -> void:
		values = source

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)


class FutureHammerConfig:
	var live_contract: bool
	var runtime_multiplier := 1.0
	var item_multiplier := 1.0

	func _init(is_live: bool) -> void:
		live_contract = is_live

	func get_snapshot() -> Dictionary:
		return {
			"cooldown_reduction_eligible": live_contract,
			"cooldown_reduction_skill_ids": ["hammer_shock"],
			"cooldown_seconds": {"hammer_shock": get_cooldown_seconds("hammer_shock")},
		}

	func get_cooldown_seconds(skill_id: String) -> float:
		if skill_id != "hammer_shock":
			return 0.0
		return 7.0 * runtime_multiplier * item_multiplier

	func set_runtime_cooldown_multiplier(value: float) -> void:
		runtime_multiplier = max(0.0, value)

	func set_item_cooldown_multiplier(value: float) -> void:
		item_multiplier = max(0.0, value)


class UndeclaredCooldownConfig:
	func get_snapshot() -> Dictionary:
		return {
			"cooldown_reduction_skill_ids": ["hammer_shock"],
			"cooldown_seconds": {"hammer_shock": 7.0},
		}

	func get_cooldown_seconds(skill_id: String) -> float:
		return 7.0 if skill_id == "hammer_shock" else 0.0

	func set_runtime_cooldown_multiplier(_value: float) -> void:
		pass

	func set_item_cooldown_multiplier(_value: float) -> void:
		pass


class SnapshotOnlyLiveConfig:
	func get_snapshot() -> Dictionary:
		return {
			"cooldown_reduction_eligible": true,
			"cooldown_reduction_skill_ids": ["hammer_shock"],
			"cooldown_seconds": {"hammer_shock": 7.0},
		}


class RawOnlyCooldownState:
	func trigger_cooldown(_skill_id: String, _time_now: int, _cooldown_seconds: float) -> void:
		pass

	func get_cooldown_remaining(_skill_id: String, _time_now: int, _fallback_seconds: float) -> float:
		return 0.0

	func get_cooldown_total_seconds(_skill_id: String) -> float:
		return 0.0


class FakeMythicRuntime:
	var multiplier: float

	func _init(value: float) -> void:
		multiplier = value

	func get_player_skill_cooldown_multiplier() -> float:
		return multiplier

	func get_heavenly_cape_skill_slot_bonus() -> int:
		return 0

	func _get_instance(registry: Object, key: String) -> Object:
		return registry.get_instance(key) if registry != null and registry.has_method("get_instance") else null
