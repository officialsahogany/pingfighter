extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

const RETIRED_IDS := ["lingpet_ring_core_upgrade", "lingpet_affinity_chip"]
const RETIRED_APIS := [
	"get_run_ring_core_tier",
	"get_run_ring_core_cap",
	"set_run_ring_core_tier",
	"upgrade_run_ring_core_tier",
	"get_ring_core_offer_cooldown_screens",
	"tick_ring_core_offer_cooldown",
	"get_enhancement_chips",
	"set_enhancement_chips",
	"add_enhancement_chip",
	"get_enhancement_chip_multiplier",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_offer_ids_are_retired()
	_verify_runtime_apis_are_retired_and_cap_is_fixed()
	_verify_legacy_snapshot_keys_are_ignored()
	_verify_surfaces_and_assets_are_absent()
	if _failures.is_empty():
		print("lingpet_ring_core_chip_retirement_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_offer_ids_are_retired() -> void:
	var catalog := RuntimePerkCatalog.new()
	for retired_id in RETIRED_IDS:
		_expect(catalog.get_perk_data(retired_id).is_empty(), "retired perk id must have no catalog data: %s" % retired_id)
	var choices: Array = catalog.get_choices("smasher", {}, false, 500)
	for choice in choices:
		var choice_id := str((choice as Dictionary).get("id", "")) if choice is Dictionary else ""
		_expect(not RETIRED_IDS.has(choice_id), "retired perk id must never enter offers: %s" % choice_id)


func _verify_runtime_apis_are_retired_and_cap_is_fixed() -> void:
	var affinity := LingpetAffinityState.new()
	var runtime := LingpetEggRuntime.new()
	for retired_api in RETIRED_APIS:
		_expect(not affinity.has_method(retired_api), "affinity owner must not expose retired API: %s" % retired_api)
		_expect(not runtime.has_method(retired_api), "egg runtime must not expose retired API: %s" % retired_api)
	affinity.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true)
	for _i in range(60):
		affinity.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect(affinity.get_level("maribo") == 6, "affinity must advance beyond the retired tier-1 cap without a ring-core gate")
	_expect(LingpetAffinityState.MAX_LEVEL == 30, "affinity cap must remain the fixed Lv30 contract")
	runtime.reset_for_tests()


func _verify_legacy_snapshot_keys_are_ignored() -> void:
	var affinity := LingpetAffinityState.new()
	var legacy_pet := {
		"affinity_level": 2,
		"affinity_points": 17.0,
		"ring_core_cap": 5,
	}
	affinity.import_run_state({
		"pets": {"maribo": legacy_pet},
		"run_ring_core_tier": 6,
		"enhancement_chips": 5,
		"ring_core_offer_cooldown_screens": 3,
	})
	var exported := affinity.export_run_state()
	var pet: Dictionary = (exported.get("pets", {}) as Dictionary).get("maribo", {}) as Dictionary
	_expect(not pet.has("ring_core_cap"), "legacy per-pet ring-core cap must be discarded on import")
	for retired_key in ["run_ring_core_tier", "enhancement_chips", "ring_core_offer_cooldown_screens"]:
		_expect(not exported.has(retired_key), "legacy run key must not be re-exported: %s" % retired_key)


func _verify_surfaces_and_assets_are_absent() -> void:
	var source_paths := [
		"res://scripts/core/battle_scene_state.gd",
		"res://scripts/characters/runtime_perk_catalog.gd",
		"res://scripts/characters/runtime_perk_state.gd",
		"res://scripts/hud/runtime_perk_icon_renderer.gd",
		"res://scripts/hud/character_info_overlay_lingpet_presenter.gd",
		"res://scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd",
		"res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd",
		"res://scripts/plaza/plaza_lingpet_store_transactions.gd",
		"res://scripts/plaza/plaza_scene.gd",
	]
	for source_path in source_paths:
		var source := FileAccess.get_file_as_string(source_path)
		for retired_needle in ["lingpet_ring_core_tier", "ringpet_ring_core_tier", "lingpet_affinity_chip_count", "ringpet_affinity_chip_count", "lingpet_ring_core_upgrade", "lingpet_affinity_chip"]:
			_expect(source.find(retired_needle) < 0, "%s must omit retired surface %s" % [source_path, retired_needle])
	var runtime_state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(runtime_state_source.find("runtime_perk_lingpet_rewards") < 0 and runtime_state_source.find("_lingpet_rewards") < 0, "runtime perk state must not preload or instantiate the retired Lingpet reward bridge")
	var character_select_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	_expect(character_select_source.find("ring_core") < 0, "character select must not retain ring-core state, prewarm, label, or draw paths")
	for retired_path in [
		"res://scripts/lingpet/lingpet_ring_core_rules.gd",
		"res://scripts/lingpet/lingpet_affinity_run_upgrade_controller.gd",
		"res://scripts/characters/runtime_perk_lingpet_rewards.gd",
		"res://scripts/hud/character_info_overlay_lingpet_ring_core_projection.gd",
		"res://scripts/hud/character_info_overlay_pendulum_interior.gd",
		"res://assets/sprites/perks/lingpet_affinity_chip_perk_icon.png",
		"res://assets/sprites/perks/lingpet_ring_core_standard_perk_icon.png",
	]:
		_expect(not FileAccess.file_exists(retired_path), "retired file must stay absent: %s" % retired_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
