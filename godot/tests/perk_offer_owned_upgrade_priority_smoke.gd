extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

const TARGET_CHOICES := 3
const OFFER_TRIALS := 24
const OWNED_UPGRADE_IDS := [
	"dash_acceleration",
	"item_luck",
	"item_gauge_mastery",
	"item_caffeine",
	"item_polish",
	"item_recycle",
	"perk_boost_charge",
	"perk_laurel_shield",
]

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_full_slots_reserve_owned_upgrades()
	_verify_reserved_upgrades_rotate_across_offers()
	_verify_dash_token_boost_extracts_existing_choices()
	_verify_dash_token_boost_skips_absent_pool_card()
	_verify_partial_owned_upgrade_reservation()
	_verify_dash_token_excluded_from_owned_upgrade_reservation()
	_verify_mythic_jackpot_coexists_with_dash_and_owned_reservations()
	_verify_one_open_slot_keeps_normal_offer_pool()
	_verify_no_upgrade_candidates_falls_back_to_diversity()
	_verify_offer_chain_source_contract()
	_verify_flag_off_does_not_enter_slot_reservation()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_offer_owned_upgrade_priority_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_full_slots_reserve_owned_upgrades() -> void:
	var catalog := _catalog_without_random_reservations()
	var levels := _full_slot_upgrade_levels()
	for _trial in range(OFFER_TRIALS):
		var choices: Array = catalog.get_choices("smasher", levels, false, TARGET_CHOICES)
		var offer_slots := _offer_slots(choices)
		_expect_eq(offer_slots.size(), TARGET_CHOICES, "full-slot offer should keep the requested non-gold choice count")
		_expect_eq(_gold_count(choices), 0, "full-slot offer should not append the retired gold conversion lane")
		_expect(_is_owned_upgrade(offer_slots[0], levels), "full-slot offer first card should be a reserved owned slot-perk upgrade")
		_expect(_is_owned_upgrade(offer_slots[1], levels), "full-slot offer second card should be a reserved owned slot-perk upgrade")
		_expect(_owned_upgrade_count(offer_slots, levels) >= 2, "full-slot offer should reserve at least two owned upgrades")
		_expect(TARGET_CHOICES - _owned_upgrade_count(offer_slots, levels) <= 1, "full-slot offer should leave at most one diversity slot")


func _verify_reserved_upgrades_rotate_across_offers() -> void:
	var catalog := _catalog_without_random_reservations()
	var levels := _full_slot_upgrade_levels()
	var seen_upgrade_ids := {}
	for _trial in range(OFFER_TRIALS):
		var offer_slots := _offer_slots(catalog.get_choices("smasher", levels, false, TARGET_CHOICES))
		for index in range(offer_slots.size()):
			var choice: Dictionary = offer_slots[index] as Dictionary
			if _is_owned_upgrade(choice, levels):
				seen_upgrade_ids[str(choice.get("id", ""))] = true
	_expect(seen_upgrade_ids.size() > 2, "reserved owned upgrades should rotate across repeated offers")


func _verify_dash_token_boost_extracts_existing_choices() -> void:
	for level in [0, 1, 2]:
		var catalog := _catalog_without_random_reservations()
		catalog.dash_token_boost_chances = [1.0, 1.0, 1.0]
		var levels := {}
		if int(level) > 0:
			levels["dash_amplification"] = int(level)
		var offer_slots := _offer_slots(catalog.get_choices("smasher", levels, false, TARGET_CHOICES))
		_expect_eq(
			_choice_id_count(offer_slots, "dash_amplification"),
			1,
			"dash boost should extract exactly one existing dash token card at Lv.%d" % int(level)
		)
		var dash_choice := _first_choice_by_id(offer_slots, "dash_amplification")
		if not dash_choice.is_empty():
			_expect_eq(
				int(dash_choice.get("current_level", -1)),
				int(level),
				"dash boost should preserve the extracted card current level at Lv.%d" % int(level)
			)
			_expect_eq(
				int(dash_choice.get("next_level", -1)),
				int(level) + 1,
				"dash boost should preserve the extracted card next level at Lv.%d" % int(level)
			)

	var maxed_catalog := _catalog_without_random_reservations()
	maxed_catalog.dash_token_boost_chances = [1.0, 1.0, 1.0]
	var maxed_slots := _offer_slots(maxed_catalog.get_choices("smasher", {"dash_amplification": 3}, false, TARGET_CHOICES))
	_expect_eq(_choice_id_count(maxed_slots, "dash_amplification"), 0, "maxed dash token should stay absent even when dash boost chance is forced")


func _verify_dash_token_boost_skips_absent_pool_card() -> void:
	var catalog := _catalog_without_random_reservations()
	catalog.dash_token_boost_chances = [1.0, 1.0, 1.0]
	var levels := _full_slot_upgrade_levels()
	_expect(not catalog.has_open_perk_slot(levels), "full-slot fixture should have no open perk slot for dash extraction")
	var offer_slots := _offer_slots(catalog.get_choices("smasher", levels, false, TARGET_CHOICES))
	_expect_eq(_choice_id_count(offer_slots, "dash_amplification"), 0, "full-slot filter should remove dash before boost extraction, so forced boost skips cleanly")


func _verify_partial_owned_upgrade_reservation() -> void:
	var catalog := _catalog_without_random_reservations()
	catalog.owned_upgrade_partial_chance = 1.0
	var levels := _one_open_slot_upgrade_levels()
	_expect(catalog.has_open_perk_slot(levels), "partial-reservation fixture should leave one slot open")
	var offer_slots := _offer_slots(catalog.get_choices("smasher", levels, false, TARGET_CHOICES))
	_expect(_owned_upgrade_count(offer_slots, levels) >= 1, "forced partial reservation should keep one owned upgrade after the guaranteed soul-summon lane")


func _verify_dash_token_excluded_from_owned_upgrade_reservation() -> void:
	# 대쉬토큰(dash_amplification) owns a dedicated per-level boost lane, so it must
	# NOT double-dip through the generic owned-upgrade reservation once owned.
	# Otherwise reaching Lv.1 makes dash appear in almost every offer ("너무 자주").
	var catalog := _catalog_without_random_reservations()
	var levels := {
		"dash_amplification": 1,
		"common_swiftness": 1,
	}
	var manual_choices := [
		_build_upgrade_choice(catalog, "dash_amplification", 1),
		_build_upgrade_choice(catalog, "common_swiftness", 1),
	]
	# reserve_limit high enough to take BOTH if both were eligible.
	var owned_result: Dictionary = catalog.call(
		"_extract_owned_slot_upgrade_reserved_choices",
		manual_choices,
		levels,
		2
	) as Dictionary
	var reserved: Array = owned_result.get("reserved", []) as Array
	var remaining: Array = owned_result.get("remaining", []) as Array
	_expect(not _has_choice_id(reserved, "dash_amplification"), "owned dash token must not be reserved via the generic owned-upgrade lane")
	_expect(_has_choice_id(remaining, "dash_amplification"), "owned dash token must fall through to the normal pool instead of the owned-upgrade reservation")
	_expect(_has_choice_id(reserved, "common_swiftness"), "non-dash owned upgrades should still reserve normally")


func _verify_mythic_jackpot_coexists_with_dash_and_owned_reservations() -> void:
	var catalog := _catalog_without_random_reservations()
	catalog.mythic_jackpot_offer_chance = 1.0
	catalog.dash_token_boost_chances = [1.0, 1.0, 1.0]
	catalog.owned_upgrade_partial_chance = 1.0
	var levels := _one_open_slot_upgrade_levels()
	var choices: Array = catalog.get_choices("smasher", levels, false, TARGET_CHOICES)
	var offer_slots := _offer_slots(choices)
	_expect_eq(offer_slots.size(), TARGET_CHOICES, "jackpot plus dash/owned reservations should not exceed the target offer count")
	_expect_eq(_choice_id_count(offer_slots, "unlock_soul_summon_art"), 0, "a full mythic jackpot should occupy all three target lanes")
	_expect_eq(_mythic_choice_count(offer_slots), TARGET_CHOICES, "jackpot should fill the complete target offer")
	_expect_eq(_choice_id_count(offer_slots, "dash_amplification"), 0, "jackpot-filled offers should naturally push out dash reservation")
	_expect_eq(_gold_count(choices), 0, "jackpot coexistence should not revive the retired gold conversion lane")


func _verify_one_open_slot_keeps_normal_offer_pool() -> void:
	var catalog := _catalog_without_random_reservations()
	var levels := _one_open_slot_upgrade_levels()
	_expect(catalog.has_open_perk_slot(levels), "one-open fixture should report an open perk slot")
	var scan_choices: Array = catalog.get_choices("smasher", levels, true, 500)
	_expect(not _has_choice_id(scan_choices, "common_training"), "one-open offers should exclude the training-migrated common_training")
	_expect(_has_choice_id(scan_choices, "item_gauge_mastery"), "one-open offers should still include current slot-consuming perks")
	var all_trials_started_with_reserved_upgrades := true
	for _trial in range(OFFER_TRIALS):
		var offer_slots := _offer_slots(catalog.get_choices("smasher", levels, false, TARGET_CHOICES))
		var starts_reserved := (
			offer_slots.size() >= 2
			and _is_owned_upgrade(offer_slots[0], levels)
			and _is_owned_upgrade(offer_slots[1], levels)
		)
		if not starts_reserved:
			all_trials_started_with_reserved_upgrades = false
			break
	_expect(not all_trials_started_with_reserved_upgrades, "one-open offers should not force the owned-upgrade reservation tier")


func _verify_no_upgrade_candidates_falls_back_to_diversity() -> void:
	var catalog := _catalog_without_random_reservations()
	var levels := _full_slot_maxed_levels()
	_expect(not catalog.has_open_perk_slot(levels), "maxed fixture should still fill the slot budget")
	var choices: Array = catalog.get_choices("smasher", levels, false, TARGET_CHOICES)
	var offer_slots := _offer_slots(choices)
	_expect_eq(_owned_upgrade_count(offer_slots, levels), 0, "full slots with only maxed owned perks should reserve no upgrades")
	_expect_eq(_gold_count(choices), 0, "no-upgrade fallback should not append the retired gold conversion lane")


func _verify_offer_chain_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(source.find("var dash_token_boost_chances: Array = [0.25, 0.10, 0.05]") >= 0, "catalog should expose the dash-token boost chance seam")
	_expect(source.find("var owned_upgrade_partial_chance := 0.5") >= 0, "catalog should expose the partial owned-upgrade chance seam")
	_expect(source.find("func _extract_choice_by_id") >= 0, "catalog should use a generic extract-by-id helper for promoted cards")
	_expect(source.find("dash_token_reserved = _extract_choice_by_id(choices, \"dash_amplification\")") >= 0, "dash boost should promote an existing dash card instead of building a new one")
	_expect(source.find("owned_reserve_limit = 1") >= 0, "open-slot owned partial reservation should reserve exactly one card")
	var mythic_fill := source.find("for mythic_choice in mythic_reserved:")
	var dash_fill := source.find("for dash_token_choice in dash_token_reserved:")
	var owned_fill := source.find("for owned_upgrade_choice in owned_upgrade_reserved:")
	var shuffle_fill := source.find("for choice in choices:", owned_fill)
	_expect(mythic_fill >= 0 and dash_fill > mythic_fill and owned_fill > dash_fill and shuffle_fill > owned_fill, "ordinary fill order should remain mythic -> dash token -> owned upgrades -> shuffled choices")


func _verify_flag_off_does_not_enter_slot_reservation() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var catalog := _catalog_without_random_reservations()
	var levels := _full_slot_upgrade_levels()
	var scan_choices: Array = catalog.get_choices("smasher", levels, true, 500)
	_expect(_has_choice_id(scan_choices, "item_caffeine"), "flag-OFF full-slot offers should keep legacy new common perk choices")
	var all_trials_started_with_reserved_upgrades := true
	for _trial in range(OFFER_TRIALS):
		var offer_slots := _offer_slots(catalog.get_choices("smasher", levels, false, TARGET_CHOICES))
		var starts_reserved := (
			offer_slots.size() >= 2
			and _is_owned_upgrade(offer_slots[0], levels)
			and _is_owned_upgrade(offer_slots[1], levels)
		)
		if not starts_reserved:
			all_trials_started_with_reserved_upgrades = false
			break
	_expect(not all_trials_started_with_reserved_upgrades, "flag-OFF offers should not force the owned-upgrade reservation tier")
	PerkConversionFlags.debug_set_enabled(true)


func _catalog_without_random_reservations() -> RuntimePerkCatalog:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 0.0
	catalog.dash_token_boost_chances = [0.0, 0.0, 0.0]
	catalog.owned_upgrade_partial_chance = 0.0
	return catalog


func _full_slot_upgrade_levels() -> Dictionary:
	var levels := {}
	for index in range(RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT):
		levels[str(OWNED_UPGRADE_IDS[index])] = 1
	return levels


func _one_open_slot_upgrade_levels() -> Dictionary:
	var levels := {}
	for index in range(RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT - 1):
		levels[str(OWNED_UPGRADE_IDS[index])] = 1
	return levels


func _full_slot_maxed_levels() -> Dictionary:
	return {
		"dash_amplification": 5,
		"common_expansion": 5,
		"perk_laurel_shield": 5,
		"common_swiftness": 5,
		"item_luck": 5,
		"dash_lightweight": 5,
		"dash_module_control": 5,
		"dash_jump": 5,
		"dash_acceleration": 5,
	}


func _build_upgrade_choice(catalog: Object, perk_id: String, current_level: int) -> Dictionary:
	var choice: Dictionary = catalog.get_perk_data(perk_id)
	choice["id"] = perk_id
	choice["current_level"] = current_level
	choice["next_level"] = current_level + 1
	return choice


func _offer_slots(choices: Array) -> Array:
	var slots: Array = []
	for value in choices:
		if not (value is Dictionary):
			continue
		var choice: Dictionary = value as Dictionary
		if str(choice.get("id", "")) == "convert_to_gold":
			continue
		slots.append(choice)
	return slots


func _owned_upgrade_count(choices: Array, levels: Dictionary) -> int:
	var count := 0
	for value in choices:
		if value is Dictionary and _is_owned_upgrade(value as Dictionary, levels):
			count += 1
	return count


func _mythic_choice_count(choices: Array) -> int:
	var count := 0
	for value in choices:
		if value is Dictionary and RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(str((value as Dictionary).get("id", ""))):
			count += 1
	return count


func _choice_id_count(choices: Array, choice_id: String) -> int:
	var count := 0
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			count += 1
	return count


func _first_choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return value as Dictionary
	return {}


func _is_owned_upgrade(choice: Dictionary, levels: Dictionary) -> bool:
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	return RuntimePerkCatalog.is_slot_consuming_perk(choice) and int(levels.get(choice_id, choice.get("current_level", 0))) > 0


func _gold_count(choices: Array) -> int:
	var count := 0
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == "convert_to_gold":
			count += 1
	return count


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])
