extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")

const DASH_TOKEN_ID := "dash_amplification"
const OFFER_SCAN_COUNT := 600
const DASH_TOKEN_ICON_PATH := "res://assets/sprites/perks/dash_amplification_perk_icon.png"

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var selected_character_type := "smasher"
	var starting_dash_tokens := 1
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(302.5, 700.0)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_catalog_copy_and_icon()
	_verify_slot_cost_counts_level()
	_verify_dash_capacity_still_uses_base_plus_level()
	_verify_offer_filter_requires_one_open_slot_per_dash_level()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("dash_token_slot_cost_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_copy_and_icon() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data(DASH_TOKEN_ID)
	_expect(str(data.get("name", "")) == "대쉬토큰", "dash amplification should be renamed to 대쉬토큰 in the catalog")
	_expect(str(data.get("detail", "")).find("퍽 슬롯") >= 0, "dash token detail should explain that levels consume perk slots")

	var renderer := RuntimePerkIconRenderer.new()
	_expect(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(DASH_TOKEN_ID, "") == DASH_TOKEN_ICON_PATH, "dash token should keep the PNG-first perk icon path")
	_expect(renderer.has_icon(DASH_TOKEN_ID), "dash token icon should be drawable through RuntimePerkIconRenderer")
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(DASH_TOKEN_ICON_PATH))
	if load_error != OK:
		load_error = image.load(DASH_TOKEN_ICON_PATH)
	_expect(load_error == OK, "dash token source PNG should load for icon QA")
	if load_error == OK:
		_expect(image.get_width() == 128 and image.get_height() == 128, "dash token source PNG should be 128x128")
		_expect(_image_has_visible_alpha(image), "dash token source PNG should contain visible alpha pixels")
		_expect(_image_outer_edge_is_clear(image), "dash token source PNG should keep transparent outer edges")


func _verify_slot_cost_counts_level() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data(DASH_TOKEN_ID)
	_expect(RuntimePerkCatalog.get_slot_cost_for_level(data, 0) == 0, "dash token Lv0 should consume no slots")
	_expect(RuntimePerkCatalog.get_slot_cost_for_level(data, 1) == 1, "dash token Lv1 should consume one slot")
	_expect(RuntimePerkCatalog.get_slot_cost_for_level(data, 2) == 2, "dash token Lv2 should consume two slots")
	_expect(RuntimePerkCatalog.get_slot_cost_for_level(data, 3) == 3, "dash token Lv3 should consume three slots")
	_expect(catalog.count_owned_slot_perks({DASH_TOKEN_ID: 3}) == 3, "owned dash token Lv3 should count as three occupied perk slots")

	var normal_data: Dictionary = catalog.get_perk_data("dash_lightweight")
	_expect(RuntimePerkCatalog.get_slot_cost_for_level(normal_data, 5) == 1, "normal multi-level perks should still consume one slot total")


func _verify_dash_capacity_still_uses_base_plus_level() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var dash_state := SmasherDashState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"smasher_dash_state": dash_state, "runtime_perk_catalog": catalog})
	var choice: Dictionary = catalog.get_perk_data(DASH_TOKEN_ID)

	for _i in range(3):
		_expect(state.apply_choice(choice, owner, registry), "dash token choice should apply successfully")

	_expect(int(state.runtime_skill_levels.get(DASH_TOKEN_ID, 0)) == 3, "dash token should reach Lv3 after three picks")
	_expect(int(state.get_runtime_skill_bonus(DASH_TOKEN_ID)) == 3, "dash token runtime bonus should remain +1 token per level")
	var snapshot: Dictionary = dash_state.get_snapshot()
	_expect(int(snapshot.get("max_tokens", 0)) == owner.starting_dash_tokens + 3, "dash token capacity should remain base + level")
	owner.free()


func _verify_offer_filter_requires_one_open_slot_per_dash_level() -> void:
	var catalog := RuntimePerkCatalog.new()
	var open_levels := _filled_levels_with_dash_level(2, RuntimePerkCatalog.PERK_SLOT_LIMIT - 1)
	var open_choices: Array = catalog.get_choices("smasher", open_levels, true, OFFER_SCAN_COUNT)
	_expect(_has_choice_id(open_choices, DASH_TOKEN_ID), "dash token Lv2->Lv3 should be offerable when one perk slot is still open")

	var full_levels := _filled_levels_with_dash_level(2, RuntimePerkCatalog.PERK_SLOT_LIMIT)
	_expect(catalog.count_owned_slot_perks(full_levels) == RuntimePerkCatalog.PERK_SLOT_LIMIT, "test fixture should fill the current perk-slot limit")
	var full_choices: Array = catalog.get_choices("smasher", full_levels, true, OFFER_SCAN_COUNT)
	_expect(not _has_choice_id(full_choices, DASH_TOKEN_ID), "dash token Lv2->Lv3 should be suppressed when all perk slots are full")
	_expect(_has_choice_id(full_choices, "dash_lightweight"), "ordinary owned perk level-ups should remain offerable when slots are full")


func _filled_levels_with_dash_level(dash_level: int, target_slots: int) -> Dictionary:
	var catalog := RuntimePerkCatalog.new()
	var levels := {DASH_TOKEN_ID: dash_level}
	for perk_id in [
		"dash_lightweight",
		"dash_module_control",
		"dash_jump",
		"dash_acceleration",
		"item_luck",
		"item_cooldown_mastery",
		"item_gauge_mastery",
		"item_bag_expansion",
		"common_swiftness",
		"common_bulk_up",
	]:
		if catalog.count_owned_slot_perks(levels) >= target_slots:
			break
		levels[perk_id] = 1
	return levels


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _image_has_visible_alpha(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false


func _image_outer_edge_is_clear(image: Image) -> bool:
	for x in range(image.get_width()):
		if image.get_pixel(x, 0).a > 0.0 or image.get_pixel(x, image.get_height() - 1).a > 0.0:
			return false
	for y in range(image.get_height()):
		if image.get_pixel(0, y).a > 0.0 or image.get_pixel(image.get_width() - 1, y).a > 0.0:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
