extends SceneTree

const MythicItemAiAssistRuntime := preload("res://scripts/items/mythic_item_ai_assist_runtime.gd")
const MythicItemStatBonusRuntime := preload("res://scripts/items/mythic_item_stat_bonus_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class ItemRuntimeStub:
	extends RefCounted

	var runtime_perk_state_ref: Object = null

	func _init(perk_state: Object) -> void:
		runtime_perk_state_ref = perk_state

	func get_converted_perk_effect_level(perk_id: String) -> int:
		if runtime_perk_state_ref == null:
			return 0
		return int(runtime_perk_state_ref.runtime_skill_levels.get(perk_id, 0))

	func is_horn_strawberry_control_locked() -> bool:
		return false

	func is_horn_strawberry_skills_locked() -> bool:
		return false

	func is_odins_eye_control_locked() -> bool:
		return false

	func is_odins_eye_skills_locked() -> bool:
		return false

	func is_horn_strawberry_transformed() -> bool:
		return false


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_new_fusion_ownership_drives_both_effects()
	_verify_legacy_levels_project_as_owned_byproducts()
	_verify_normal_mugong_catalog_removal()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_fusion_promoted_mugong_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_new_fusion_ownership_drives_both_effects() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["gravitybelt", "smartphone"]},
		catalog
	)
	_expect(not record.is_empty(), "promoted-Mugong fixture should commit a real fusion record")
	_expect(state.has_perk_fusion_byproduct("gravitybelt"), "찰나신법 should be owned through the fusion record")
	_expect(state.has_perk_fusion_byproduct("smartphone"), "응변결 should be owned through the fusion record")

	var item_runtime := ItemRuntimeStub.new(state)
	var stat_runtime := MythicItemStatBonusRuntime.new()
	var ai_runtime := MythicItemAiAssistRuntime.new()
	_expect(stat_runtime.is_gravitybelt_effect_active(item_runtime), "찰나신법 byproduct should activate instant movement")
	_expect(stat_runtime.is_gravitybelt_active(item_runtime), "찰나신법 byproduct should reach owner/snapshot active state")
	var movement_config: Dictionary = {}
	stat_runtime.apply_player_movement_config(item_runtime, movement_config)
	_expect(bool(movement_config.get("gravitybelt_instant_movement", false)), "찰나신법 should reach the production movement config")
	_expect(ai_runtime.is_smartphone_effect_active(item_runtime), "응변결 byproduct should activate emergency item automation")
	_expect(ai_runtime.is_smartphone_active(item_runtime), "응변결 byproduct should reach owner/snapshot active state")


func _verify_legacy_levels_project_as_owned_byproducts() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"gravitybelt": 1, "smartphone": 1}
	var owned: Array[String] = state.get_perk_fusion_owned_byproduct_ids()
	_expect("gravitybelt" in owned and "smartphone" in owned, "legacy ordinary-Mugong levels should migrate into the owned-byproduct projection")
	var item_runtime := ItemRuntimeStub.new(state)
	_expect(MythicItemStatBonusRuntime.new().is_gravitybelt_effect_active(item_runtime), "legacy 찰나신법 saves should retain their effect")
	_expect(MythicItemAiAssistRuntime.new().is_smartphone_effect_active(item_runtime), "legacy 응변결 saves should retain their effect")


func _verify_normal_mugong_catalog_removal() -> void:
	var catalog := RuntimePerkCatalog.new()
	var byproduct_catalog := PerkFusionByproductCatalog.new()
	for perk_id: String in ["gravitybelt", "smartphone"]:
		_expect(catalog.get_perk_data(perk_id).is_empty(), "%s should no longer resolve as an ordinary Mugong" % perk_id)
		_expect(bool(byproduct_catalog.get_data(perk_id).get("runtime_enabled", false)), "%s should resolve as a live Superior Martial Art" % perk_id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
