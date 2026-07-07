extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const OFFER_SCAN_COUNT := 500
const VIPER_ONLY_CONVERTED_PERK := "venom_mist_gauntlet"

var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_flag_off_offer_isolation()
	_verify_flag_on_regular_offer_exposure()
	_verify_converted_apply_choice_levels_and_caps()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_offer_exposure_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_flag_off_offer_isolation() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var catalog := RuntimePerkCatalog.new()
	for character_type in _representative_characters():
		for exclude_instant in [true, false]:
			var choices: Array = catalog.get_choices(character_type, {}, bool(exclude_instant), OFFER_SCAN_COUNT)
			for perk_id in _regular_converted_ids():
				_expect(
					not _has_choice_id(choices, str(perk_id)),
					"flag-OFF %s offers should keep regular converted perk %s hidden" % [character_type, str(perk_id)]
				)
			for perk_id in _mythic_converted_ids():
				_expect(
					not _has_choice_id(choices, str(perk_id)),
					"flag-OFF %s offers should keep mythic converted perk %s hidden" % [character_type, str(perk_id)]
				)


func _verify_flag_on_regular_offer_exposure() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var catalog := RuntimePerkCatalog.new()
	for character_type in _representative_characters():
		var choices: Array = catalog.get_choices(character_type, {}, true, OFFER_SCAN_COUNT)
		for perk_id in _regular_converted_ids():
			var id := str(perk_id)
			if id == VIPER_ONLY_CONVERTED_PERK:
				_expect(
					_has_choice_id(choices, id) == (character_type == "viper"),
					"flag-ON %s offers should expose %s only to Viper" % [character_type, id]
				)
			else:
				_expect(
					_has_choice_id(choices, id),
					"flag-ON %s offers should expose regular converted perk %s" % [character_type, id]
				)
		for perk_id in _mythic_converted_ids():
			_expect(
				not _has_choice_id(choices, str(perk_id)),
				"flag-ON %s general offers should not expose mythic converted perk %s" % [character_type, str(perk_id)]
			)


func _verify_converted_apply_choice_levels_and_caps() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var perk_id := "star_detector"

	var first_choice := _choice_by_id(catalog.get_choices("smasher", state.runtime_skill_levels, true, OFFER_SCAN_COUNT), perk_id)
	_expect(not first_choice.is_empty(), "flag-ON offers should include star_detector for apply_choice")
	_expect(int(first_choice.get("current_level", -1)) == 0, "first star_detector choice should start at level 0")
	_expect(int(first_choice.get("next_level", -1)) == 1, "first star_detector choice should advance to level 1")
	_expect(state.apply_choice(first_choice, null, null), "converted star_detector choice should apply through runtime state")
	_expect(int(state.runtime_skill_levels.get(perk_id, 0)) == 1, "converted star_detector should apply as level 1")

	var second_choice := _choice_by_id(catalog.get_choices("smasher", state.runtime_skill_levels, true, OFFER_SCAN_COUNT), perk_id)
	_expect(not second_choice.is_empty(), "star_detector should remain offerable below max level")
	_expect(int(second_choice.get("current_level", -1)) == 1, "second star_detector choice should read current level 1")
	_expect(int(second_choice.get("next_level", -1)) == 2, "second star_detector choice should advance to level 2")
	_expect(state.apply_choice(second_choice, null, null), "duplicate converted star_detector choice should apply")
	_expect(int(state.runtime_skill_levels.get(perk_id, 0)) == 2, "duplicate converted star_detector should level up to 2")

	var max_level := int(RuntimePerkCatalog.CONVERTED_PERKS[perk_id].get("max_level", 0))
	state.runtime_skill_levels[perk_id] = max_level - 1
	var final_choice := _choice_by_id(catalog.get_choices("smasher", state.runtime_skill_levels, true, OFFER_SCAN_COUNT), perk_id)
	_expect(not final_choice.is_empty(), "star_detector should be offerable at one level below max")
	_expect(state.apply_choice(final_choice, null, null), "final star_detector level should apply")
	_expect(int(state.runtime_skill_levels.get(perk_id, 0)) == max_level, "star_detector should reach max level")
	_expect(state.apply_choice(final_choice, null, null), "stale max-level star_detector choice should not crash")
	_expect(int(state.runtime_skill_levels.get(perk_id, 0)) == max_level, "stale star_detector choice should clamp at max level")

	var capped_choices: Array = catalog.get_choices("smasher", state.runtime_skill_levels, true, OFFER_SCAN_COUNT)
	_expect(not _has_choice_id(capped_choices, perk_id), "maxed star_detector should be excluded from offers")


func _representative_characters() -> Array[String]:
	return ["smasher", "viper", "soldier", "commando"]


func _regular_converted_ids() -> Array:
	return RuntimePerkCatalog.CONVERTED_PERKS.keys()


func _mythic_converted_ids() -> Array:
	return RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys()


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for choice in choices:
		if choice is Dictionary and str((choice as Dictionary).get("id", "")) == choice_id:
			return (choice as Dictionary).duplicate(true)
	return {}


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	return not _choice_by_id(choices, choice_id).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
