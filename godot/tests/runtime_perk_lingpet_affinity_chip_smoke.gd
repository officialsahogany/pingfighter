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
	var choices: Array = catalog.get_choices("smasher", {}, true, 200, owned_owner, registry)
	var chip_choice := _choice_by_id(choices, "lingpet_affinity_chip")
	_expect(not chip_choice.is_empty(), "owned lingpet owner should see the affinity chip card")
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
	runtime.reset_affinity_for_new_battle()
	_expect_eq(runtime.get_enhancement_chips(), 5, "new battle affinity reset should preserve run-scoped chips")
	runtime.reset_for_tests()
	_expect_eq(runtime.get_enhancement_chips(), 0, "new run/test reset should clear run-scoped chips")


func _verify_chip_source_contracts() -> void:
	var affinity_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	_expect(affinity_source.find("var enhancement_multiplier := 1.0 if source == SOURCE_FEED else get_enhancement_chip_multiplier()") >= 0, "affinity state should exempt feed while keeping the chip multiplier at the point-grant chokepoint")
	_expect(affinity_source.find("granted_points *= enhancement_multiplier") >= 0, "affinity state should multiply granted_points at the single chokepoint")
	_expect(affinity_source.find("bonus_points *= enhancement_multiplier") >= 0, "affinity state should keep reported bonus_points scaled with granted_points")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var chip_branch := runtime_source.find("if choice_id == LINGPET_AFFINITY_CHIP_CHOICE_ID")
	var generic_level := runtime_source.find("var old_level: int = int(runtime_skill_levels.get(choice_id, 0))")
	_expect(chip_branch >= 0 and generic_level > chip_branch, "affinity chip special branch should run before generic runtime_skill_levels level-up")
	_expect(runtime_source.find("runtime.add_enhancement_chip(owner, registry)") >= 0, "affinity chip branch should route through lingpet_egg_runtime.add_enhancement_chip")
	_expect(RuntimePerkIconRenderer.new().covered_ids().has("lingpet_affinity_chip"), "affinity chip card should have a PNG icon renderer path")


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
