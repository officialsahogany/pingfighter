extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const OFFER_SCAN_COUNT := 500
const CAPTURE_PATH := "res://../.tmp/perk_slot_limit/perk_slot_limit_choice_modal.png"

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var selected_character_type := "smasher"
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class ChoiceModalProbe:
	extends Control

	var runtime_state: Object = null
	var catalog: Object = null
	var icon_renderer: Object = null
	var overlay_renderer: Object = RuntimePerkOverlayRenderer.new()

	func _draw() -> void:
		overlay_renderer.draw(self, runtime_state, catalog, Vector2(960.0, 720.0), icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_slot_classifier_and_count()
	_verify_offer_budget_at_five_slots()
	_verify_offer_budget_at_six_slots()
	_verify_non_consuming_choices_survive_full_slots()
	_verify_mythic_grant_respects_slots()
	_verify_slot_status_data()
	await _capture_choice_modal_slot_status()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_slot_limit_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_slot_classifier_and_count() -> void:
	var catalog := RuntimePerkCatalog.new()
	var star_detector := catalog.get_perk_data("star_detector")
	var odins_eye := catalog.get_perk_data("odins_eye")
	var unlock_plasma := catalog.get_perk_data("unlock_plasma")
	var instant := catalog.get_perk_data("instant_gauge_full")
	var gold := catalog.get_perk_data("convert_to_gold")
	var chip := catalog.get_perk_data("lingpet_affinity_chip")
	var ring_core := catalog.get_perk_data("lingpet_ring_core_upgrade")

	_expect(RuntimePerkCatalog.is_slot_consuming_perk(star_detector), "converted regular perks should consume one perk slot")
	_expect(RuntimePerkCatalog.is_slot_consuming_perk(odins_eye), "converted mythic perks should consume one perk slot")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(unlock_plasma), "unlock_* active-skill cards should not consume the perk-slot budget")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(instant), "instant cards should not consume the perk-slot budget")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(gold), "gold conversion should not consume the perk-slot budget")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(chip), "lingpet affinity chips should not consume the perk-slot budget")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(ring_core), "lingpet ring-core upgrades should not consume the perk-slot budget")

	var mixed_levels := _full_slot_levels()
	mixed_levels["unlock_plasma"] = 1
	mixed_levels["instant_gauge_full"] = 1
	mixed_levels["convert_to_gold"] = 1
	mixed_levels["lingpet_affinity_chip"] = 1
	_expect_eq(catalog.count_owned_slot_perks(mixed_levels), RuntimePerkCatalog.PERK_SLOT_LIMIT, "slot count should ignore unlock/instant/lingpet/gold levels")


func _verify_offer_budget_at_five_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var levels := _five_slot_levels()
	var choices: Array = catalog.get_choices("smasher", levels, true, OFFER_SCAN_COUNT)
	_expect(_has_choice_id(choices, "fuel_pouch"), "with five occupied slots, a new slot-consuming perk should still be offerable")
	_expect(_has_choice_id(choices, "dash_lightweight"), "with five occupied slots, owned slot-consuming perks should still level up")


func _verify_offer_budget_at_six_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var levels := _full_slot_levels()
	var choices: Array = catalog.get_choices("smasher", levels, true, OFFER_SCAN_COUNT)
	_expect(not _has_choice_id(choices, "fuel_pouch"), "with six occupied slots, new slot-consuming perks should be filtered out")
	_expect(_has_choice_id(choices, "dash_lightweight"), "with six occupied slots, owned slot-consuming level-ups should remain offerable")


func _verify_non_consuming_choices_survive_full_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	runtime._affinity_state.set_run_ring_core_tier(1)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var full_levels := _full_slot_levels()

	var choices_with_instant: Array = catalog.get_choices("smasher", full_levels, false, OFFER_SCAN_COUNT, owner, registry)
	_expect(_has_choice_id(choices_with_instant, "instant_gauge_full"), "full slots should not suppress instant choices")
	_expect(_has_choice_id(choices_with_instant, "convert_to_gold"), "full slots should not suppress gold conversion")

	var choices_without_instant: Array = catalog.get_choices("smasher", full_levels, true, OFFER_SCAN_COUNT, owner, registry)
	_expect(_has_choice_id(choices_without_instant, "unlock_plasma"), "full slots should not suppress unlock_* active-skill choices")
	_expect(_has_choice_id(choices_without_instant, "lingpet_affinity_chip"), "full slots should not suppress lingpet affinity chip choices")
	_expect(_has_choice_id(choices_without_instant, "lingpet_ring_core_upgrade"), "full slots should not suppress lingpet ring-core upgrade choices")


func _verify_mythic_grant_respects_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	var five_state := RuntimePerkState.new()
	five_state.runtime_skill_levels = _five_slot_levels()
	var five_registry := FakeRegistry.new({
		"runtime_perk_state": five_state,
		"runtime_perk_catalog": catalog,
	})
	var mythic_reward: Dictionary = MythicPerkGrantHelper.build_reward(owner, five_registry)
	_expect(str(mythic_reward.get("type", "")) == MythicPerkGrantHelper.REWARD_MYTHIC_PERK, "five occupied slots should allow a new mythic perk reward")
	var mythic_result: Dictionary = MythicPerkGrantHelper.grant_reward(mythic_reward, owner, five_registry)
	_expect(bool(mythic_result.get("granted", false)), "five occupied slots should grant the mythic perk through runtime perk state")
	_expect_eq(catalog.count_owned_slot_perks(five_state.runtime_skill_levels), RuntimePerkCatalog.PERK_SLOT_LIMIT, "mythic grant at five slots should fill the sixth slot")

	var full_state := RuntimePerkState.new()
	full_state.runtime_skill_levels = _full_slot_levels()
	var full_registry := FakeRegistry.new({
		"runtime_perk_state": full_state,
		"runtime_perk_catalog": catalog,
	})
	var fallback_reward: Dictionary = MythicPerkGrantHelper.build_reward(owner, full_registry)
	_expect(str(fallback_reward.get("type", "")) == MythicPerkGrantHelper.REWARD_STARPOINT, "six occupied slots should roll mythic perk rewards into starpoints")
	var fallback_result: Dictionary = MythicPerkGrantHelper.grant_reward(fallback_reward, owner, full_registry)
	_expect(bool(fallback_result.get("fallback_starpoint", false)), "six occupied slots should grant the mythic fallback as starpoints")
	_expect_eq(catalog.count_owned_slot_perks(full_state.runtime_skill_levels), RuntimePerkCatalog.PERK_SLOT_LIMIT, "starpoint fallback should not add a seventh slot-consuming perk")
	owner.free()


func _verify_slot_status_data() -> void:
	var catalog := RuntimePerkCatalog.new()
	var five_status: Dictionary = catalog.get_perk_slot_status(_five_slot_levels())
	var full_status: Dictionary = catalog.get_perk_slot_status(_full_slot_levels())
	_expect_eq(int(five_status.get("count", 0)), 5, "slot status should report five occupied slots")
	_expect_eq(int(five_status.get("limit", 0)), RuntimePerkCatalog.PERK_SLOT_LIMIT, "slot status should expose the fixed slot limit")
	_expect(not bool(five_status.get("is_full", false)), "slot status should not mark five slots as full")
	_expect_eq(int(full_status.get("count", 0)), RuntimePerkCatalog.PERK_SLOT_LIMIT, "slot status should report six occupied slots")
	_expect(bool(full_status.get("is_full", false)), "slot status should mark six slots as full")


func _capture_choice_modal_slot_status() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("perk_slot_limit_smoke: screenshot skipped under headless display server")
		return
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = _full_slot_levels()
	state.pending_skill_choices = 1
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({
		"runtime_perk_state": state,
		"runtime_perk_catalog": catalog,
	})
	state.open_next_choice("smasher", catalog, false, owner, registry)
	var probe := ChoiceModalProbe.new()
	probe.size = Vector2(960.0, 720.0)
	probe.runtime_state = state
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	root.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture != null:
		var image: Image = viewport_texture.get_image()
		if image != null and not image.is_empty():
			var output_path := ProjectSettings.globalize_path(CAPTURE_PATH)
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var save_error: int = image.save_png(output_path)
			_expect(save_error == OK, "slot-limit choice modal screenshot should save to %s" % output_path)
	probe.free()
	owner.free()


func _five_slot_levels() -> Dictionary:
	return {
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"dash_acceleration": 1,
		"item_luck": 1,
	}


func _full_slot_levels() -> Dictionary:
	var levels := _five_slot_levels()
	levels["star_detector"] = 1
	return levels


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	return not _choice_by_id(choices, choice_id).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])
