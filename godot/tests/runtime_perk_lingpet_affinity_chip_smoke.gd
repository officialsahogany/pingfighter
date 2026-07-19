extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_state := ""
	var lingpet_id := ""
	var selected_character_type := "smasher"


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_run()


func _run() -> void:
	_verify_chip_card_gate_and_cap()
	_verify_chip_pick_updates_affinity_state_only()
	_verify_runtime_multiplier_and_reset_boundary()
	_verify_chip_source_contracts()

	if _failures.is_empty():
		print("runtime_perk_lingpet_affinity_chip_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_chip_card_gate_and_cap() -> void:
	var catalog := RuntimePerkCatalog.new()
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var empty_owner := FakeOwner.new()
	var empty_choices: Array = catalog.get_choices("smasher", {}, true, 200, empty_owner, registry)
	_expect(_choice_by_id(empty_choices, "lingpet_affinity_chip").is_empty(), "owned-empty owner should not see the affinity chip card")

	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	var tier0_choices: Array = catalog.get_choices("smasher", {}, true, 200, owned_owner, registry)
	_expect(_choice_by_id(tier0_choices, "lingpet_affinity_chip").is_empty(), "owned lingpet owner should not see the affinity chip card before acquiring ring core")

	runtime._affinity_state.set_run_ring_core_tier(1)
	var choices: Array = catalog.get_choices("smasher", {}, true, 200, owned_owner, registry)
	var chip_choice := _choice_by_id(choices, "lingpet_affinity_chip")
	_expect(not chip_choice.is_empty(), "owned lingpet owner should see the affinity chip card after acquiring ring core")
	_expect_eq(int(chip_choice.get("current_level", -1)), 0, "first affinity chip card should read current chip count 0")
	_expect_eq(int(chip_choice.get("next_level", -1)), 1, "first affinity chip card should advance to chip 1")
	_expect_eq(int(chip_choice.get("max_level", -1)), LingpetAffinityState.MAX_ENHANCEMENT_CHIPS, "chip card max should mirror affinity-state cap")

	for _i in range(4):
		runtime.add_enhancement_chip(owned_owner, registry)
	var fourth_choices: Array = catalog.get_choices("smasher", {}, true, 200, owned_owner, registry)
	var fourth_chip := _choice_by_id(fourth_choices, "lingpet_affinity_chip")
	_expect_eq(int(fourth_chip.get("current_level", -1)), 4, "fifth chip card should read current chip count 4")
	_expect_eq(int(fourth_chip.get("next_level", -1)), 5, "fifth chip card should advance to chip 5")
	runtime.add_enhancement_chip(owned_owner, registry)
	var capped_choices: Array = catalog.get_choices("smasher", {}, true, 200, owned_owner, registry)
	_expect(_choice_by_id(capped_choices, "lingpet_affinity_chip").is_empty(), "five chips should suppress further affinity chip cards")


func _verify_chip_pick_updates_affinity_state_only() -> void:
	var catalog := RuntimePerkCatalog.new()
	var runtime := LingpetEggRuntime.new()
	var perk_state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	runtime._affinity_state.set_run_ring_core_tier(1)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_affinity_chip")
	_expect(not choice.is_empty(), "fixture should expose an affinity chip choice")
	_expect(perk_state.apply_choice(choice, owner, registry), "affinity chip choice should apply through runtime perk state")
	_expect_eq(runtime.get_enhancement_chips(), 1, "affinity chip pick should increment the lingpet affinity-state chip count")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_affinity_chip"), "affinity chip pick should not write a runtime_skill_levels tally")


func _verify_runtime_multiplier_and_reset_boundary() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	for _i in range(5):
		runtime.add_enhancement_chip(owner, registry)
	_expect_eq(runtime.get_enhancement_chips(), 5, "runtime should expose five stacked chips")
	_expect_float(runtime.get_enhancement_chip_multiplier(), 2.0, "runtime should expose the doubled five-chip multiplier")
	var gain: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
	_expect_float(float(gain.get("granted_points", 0.0)), 10.0, "five chips should double affinity points through the runtime chokepoint")
	var defense_gain: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_BALL_HIT, {"defense_intercept": true}, registry)
	_expect_float(float(defense_gain.get("granted_points", 0.0)), 26.0, "five chips should double the full defense-tagged affinity grant")
	_expect_float(float(defense_gain.get("bonus_points", 0.0)), 10.0, "five chips should double the reported defense bonus points")
	var ring_core_gain: Dictionary = runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_RING_CORE_UPGRADE, {}, registry)
	_expect_float(float(ring_core_gain.get("granted_points", 0.0)), 50.0, "ring-core upgrade grant should be chip-EXEMPT (flat 50 even with five chips)")
	runtime.reset_affinity_for_new_battle()
	_expect_eq(runtime.get_enhancement_chips(), 5, "new battle affinity reset should preserve run-scoped chips")
	runtime.reset_for_tests()
	_expect_eq(runtime.get_enhancement_chips(), 0, "new run/test reset should clear run-scoped chips")


func _verify_chip_source_contracts() -> void:
	var affinity_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	_expect(affinity_source.find("SOURCE_FEED") < 0, "affinity state should not keep the superseded feed affinity source")
	_expect(affinity_source.find("var enhancement_multiplier := 1.0 if source == SOURCE_RING_CORE_UPGRADE else get_enhancement_chip_multiplier()") >= 0, "affinity state should exempt only ring-core-upgrade while keeping the chip multiplier at the point-grant chokepoint")
	_expect(affinity_source.find("granted_points *= enhancement_multiplier") >= 0, "affinity state should multiply granted_points at the single chokepoint")
	_expect(affinity_source.find("bonus_points *= enhancement_multiplier") >= 0, "affinity state should keep reported bonus_points scaled with granted_points")
	# 배선 소스씰(모듈 분리 구조 — 2026-07-20 씰 갱신): 특수 적용은
	# choice dispatch → action runner 콜백 → state 위임 → rewards 실적용
	# 사슬로 흐른다(구 인라인 분기 소스씰은 모듈 분리로 이동된 실코드를
	# 못 찾는 낡은 계약).
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var dispatch_call := flow_source.find("choice_action_runner.run_dispatch(")
	var standard_call := flow_source.find("choice_standard_path.apply_level_choice_to_runtime_state(")
	_expect(dispatch_call >= 0 and standard_call > dispatch_call, "special dispatch must run before the generic standard path (chip must never fall into a runtime_skill_levels tally)")
	var dispatch_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_dispatch.gd")
	_expect(dispatch_source.find("ACTION_LINGPET_AFFINITY_CHIP") >= 0, "choice dispatch must resolve the affinity chip special action")
	var runner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_action_runner.gd")
	_expect(runner_source.find("Callable(state, \"_apply_lingpet_affinity_chip\")") >= 0, "the action runner must bind the affinity chip state callback")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(state_source.find("_lingpet_rewards.apply_affinity_chip_from_runtime_state(") >= 0, "state must delegate the chip apply to the lingpet rewards module")
	var rewards_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_lingpet_rewards.gd")
	_expect(rewards_source.find("runtime.add_enhancement_chip(owner, registry)") >= 0, "rewards must route through lingpet_egg_runtime.add_enhancement_chip")
	_expect(RuntimePerkIconRenderer.new().covered_ids().has("lingpet_affinity_chip"), "affinity chip card should have a PNG icon renderer path")
	var catalog_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(catalog_source.find("LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER := 1") >= 0, "affinity chip catalog gate should require at least ring-core tier 1")
	_expect(catalog_source.find("ring_core_tier < LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER") >= 0, "affinity chip append should suppress cards before ring-core acquisition")


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
