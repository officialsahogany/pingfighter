extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

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
	_verify_ring_core_card_gate_next_tier_and_pick()
	_verify_ring_core_max_and_owned_empty_suppression()
	_verify_ring_core_monotonic_debug_and_icon_contracts()
	_verify_ring_core_run_reset_clears_purchased_tier()

	if _failures.is_empty():
		print("runtime_perk_lingpet_ring_core_upgrade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ring_core_card_gate_next_tier_and_pick() -> void:
	# R5 / per-run: the ring-core perk reads/upgrades the RUN tier (real
	# egg_runtime run-state), NOT a fake store. A fake store that "works" used to
	# mask the real R3 store no-op -- that was the false-green this slice broke.
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	runtime._affinity_state.set_run_ring_core_tier(2)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_ring_core_upgrade")
	_expect(not choice.is_empty(), "owned lingpet owner should see the ring-core upgrade card below max tier")
	_expect_eq(int(choice.get("current_tier", -1)), 2, "ring-core card should read the current RUN tier")
	_expect_eq(int(choice.get("next_tier", -1)), 3, "ring-core card should target the next tier only")
	_expect_eq(int(choice.get("next_level", -1)), 3, "ring-core card next_level should mirror next_tier for legacy UI")
	_expect_eq(str(choice.get("icon_id", "")), "lingpet_ring_core_upgrade_tier_3", "ring-core card should resolve the next-tier icon id")

	_expect(perk_state.apply_choice(choice, owner, registry), "ring-core upgrade choice should apply through runtime perk state")
	_expect_eq(runtime.get_run_ring_core_tier(), 3, "ring-core perk pick should upgrade THIS run's tier")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_ring_core_upgrade"), "ring-core upgrade should not write runtime_skill_levels")

	var next_choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_ring_core_upgrade")
	_expect_eq(int(next_choice.get("next_tier", -1)), 4, "ring-core card should advance to the next tier after a successful pick")
	_expect_eq(str(next_choice.get("icon_id", "")), "lingpet_ring_core_upgrade_tier_4", "ring-core icon should follow the newly exposed next tier")


func _verify_ring_core_max_and_owned_empty_suppression() -> void:
	var catalog := RuntimePerkCatalog.new()
	var owner := _owned_owner()

	var max_runtime := LingpetEggRuntime.new()
	max_runtime._affinity_state.set_run_ring_core_tier(6)
	var max_registry := FakeRegistry.new({"lingpet_egg_runtime": max_runtime})
	var max_choices := catalog.get_choices("smasher", {}, true, 200, owner, max_registry)
	_expect(_choice_by_id(max_choices, "lingpet_ring_core_upgrade").is_empty(), "max-tier ring core should suppress further upgrade cards")

	var tier2_runtime := LingpetEggRuntime.new()
	tier2_runtime._affinity_state.set_run_ring_core_tier(2)
	var tier2_registry := FakeRegistry.new({"lingpet_egg_runtime": tier2_runtime})
	var empty_owner := FakeOwner.new()
	var empty_choices := catalog.get_choices("smasher", {}, true, 200, empty_owner, tier2_registry)
	_expect(_choice_by_id(empty_choices, "lingpet_ring_core_upgrade").is_empty(), "owned-empty owner should not see ring-core upgrade cards")

	var missing_runtime_choices := catalog.get_choices("smasher", {}, true, 200, owner, FakeRegistry.new({}))
	_expect(_choice_by_id(missing_runtime_choices, "lingpet_ring_core_upgrade").is_empty(), "missing lingpet runtime should not expose a dead ring-core card")


func _verify_ring_core_monotonic_debug_and_icon_contracts() -> void:
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	runtime._affinity_state.set_run_ring_core_tier(3)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var stale_choice := catalog.get_perk_data("lingpet_ring_core_upgrade")
	stale_choice["next_tier"] = 2
	_expect(not perk_state.apply_choice(stale_choice, owner, registry), "stale lower-tier ring-core choices should not apply")
	_expect_eq(runtime.get_run_ring_core_tier(), 3, "stale lower-tier ring-core choices should not lower the run tier")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_ring_core_upgrade"), "failed ring-core choices should not create runtime_skill_levels state")

	_expect(perk_state.debug_set_perk_level("lingpet_ring_core_upgrade", 5, owner, registry, catalog), "debug setter should recognize the non-level ring-core id")
	_expect_eq(runtime.get_run_ring_core_tier(), 5, "debug setter should route ring-core through the run-state upgrade path")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_ring_core_upgrade"), "debug ring-core upgrade should still avoid runtime_skill_levels")

	var icon_renderer := RuntimePerkIconRenderer.new()
	for tier in range(1, 7):
		var icon_id := "lingpet_ring_core_upgrade_tier_%d" % tier
		_expect(icon_renderer.covered_ids().has(icon_id), "%s should be covered by the runtime perk icon renderer" % icon_id)
		_expect(icon_renderer.has_icon(icon_id), "%s should load a tier-specific PNG icon" % icon_id)

	var catalog_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(catalog_source.find("_append_lingpet_ring_core_upgrade_choice") >= 0, "catalog should append the dynamic ring-core upgrade card")
	_expect(catalog_source.find("icon_id") >= 0 and catalog_source.find("LINGPET_RING_CORE_ICON_ID_PREFIX") >= 0, "catalog should emit a tier-aware icon id")
	_expect(catalog_source.find("get_run_ring_core_tier()") >= 0, "catalog ring-core card should read the run-state tier, not the permanent store")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var ring_branch := state_source.find("if choice_id == LINGPET_RING_CORE_UPGRADE_CHOICE_ID")
	var generic_level := state_source.find("var old_level: int = int(runtime_skill_levels.get(choice_id, 0))")
	_expect(ring_branch >= 0 and generic_level > ring_branch, "ring-core special branch should run before generic runtime_skill_levels level-up")
	_expect(state_source.find("upgrade_run_ring_core_tier(target_tier") >= 0, "ring-core branch should route through the run-state upgrade")
	_expect(state_source.find("store.upgrade_ring_core_tier") < 0, "ring-core apply must not call the dropped permanent store upgrade")
	_expect(state_source.find("LingpetAffinityStore.MAX_RING_CORE_TIER") >= 0, "ring-core apply should use the affinity-store class max tier constant")
	_expect(state_source.find("LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN") >= 0, "ring-core feedback tier names should avoid leaking Korean into non-Korean locales")

	# R5 / per-run: localize_perk_data overrides description with PERK_SUMMARY_* for
	# non-KR, so those summaries must NOT still claim a permanent/shared upgrade.
	var lang_source := FileAccess.get_file_as_string("res://scripts/core/language_settings_data.gd")
	_expect(lang_source.find("Permanently upgrades the shared Ring Core") < 0, "non-KR ring-core perk summary must not describe a permanent shared upgrade (EN/ZH/JA/RU)")
	_expect(lang_source.find("permanentemente el Ring Core compartido") < 0, "non-KR ring-core perk summary must not describe a permanent shared upgrade (ES)")
	_expect(lang_source.find("permanentemente o Ring Core compartilhado") < 0, "non-KR ring-core perk summary must not describe a permanent shared upgrade (PT)")


func _verify_ring_core_run_reset_clears_purchased_tier() -> void:
	# R5 / per-run seal: a perk-purchased ring-core tier must not survive a new run.
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_ring_core_upgrade")
	_expect(not choice.is_empty(), "fresh run should still offer the ring-core upgrade card")
	_expect(perk_state.apply_choice(choice, owner, registry), "ring-core perk should apply from a fresh run")
	_expect_eq(runtime.get_run_ring_core_tier(), 1, "ring-core perk should raise the fresh run tier to 1")
	runtime._affinity_state.reset_for_new_run()
	_expect_eq(runtime.get_run_ring_core_tier(), 0, "a new run should reset the perk-purchased ring-core tier to 0")


func _owned_owner() -> FakeOwner:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	return owner


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
