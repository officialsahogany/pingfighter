extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")

var _failures: Array[String] = []


class RollProbe:
	extends RefCounted
	var value := 1.0
	var call_count := 0

	func _init(next_value: float) -> void:
		value = next_value

	func next_roll() -> float:
		call_count += 1
		return value


class FakeOwner:
	extends RefCounted
	var data: Dictionary = {
		"selected_character_type": "smasher",
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_pos": Vector2(300.0, 700.0),
		"smasher_skills_unlocked": {
			"plasma": true,
			"recovery": true,
			"magnum_grip": true,
		},
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted
	var config: Object

	func _init(next_config: Object) -> void:
		config = next_config

	func get_instance(key: String) -> Object:
		if key == "smasher_skill_config":
			return config
		return null


func _init() -> void:
	_verify_full_budget_success_reserves_exactly_one()
	_verify_full_budget_failure_keeps_unlocks_out()
	_verify_open_budget_bypasses_roll()
	_verify_soul_summon_exception_survives_failed_roll()
	_verify_soldier_bypasses_filter_and_roll()
	_verify_swap_cancel_is_a_true_noop()
	if _failures.is_empty():
		print("chosik_slot_full_swap_offer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_full_budget_success_reserves_exactly_one() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(0.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var filtered: Array = catalog._filter_unlock_slot_budget(_ordinary_unlock_choices(catalog), "smasher", _full_smasher_unlock_levels())
	var unlocks := _ordinary_unlock_entries(filtered)
	_expect(is_equal_approx(RuntimePerkCatalog.FULL_CHOSIK_SWAP_OFFER_CHANCE, 0.15), "full-slot swap offer chance must remain the single 0.15 tuning constant")
	_expect(probe.call_count == 1, "a full screen with several unlock candidates must roll exactly once")
	_expect(unlocks.size() == 1, "a successful full-slot roll must retain exactly one ordinary Chosik unlock")
	if unlocks.size() == 1:
		_expect(bool((unlocks[0] as Dictionary).get(RuntimePerkCatalog.FULL_CHOSIK_SWAP_PRIORITY_KEY, false)), "the one successful candidate must enter the protected full-slot swap lane")

	# Production get_choices must preserve the successful card through the
	# later general shuffle; otherwise the visible chance is lower than 0.15.
	var production_probe := RollProbe.new(0.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(production_probe, "next_roll"))
	var screen_choices: Array = catalog.get_choices("smasher", _full_smasher_unlock_levels(), true, 3)
	var reserved_on_screen := screen_choices.filter(func(choice: Dictionary) -> bool:
		return str(choice.get("offer_lane", "")) == "full_chosik_swap_reserved"
	)
	_expect(production_probe.call_count == 1, "production get_choices must perform one full-slot roll per screen")
	_expect(reserved_on_screen.size() == 1, "a successful production screen must show exactly one protected Chosik swap card")
	if reserved_on_screen.size() == 1:
		_expect(bool((reserved_on_screen[0] as Dictionary).get("offer_protected", false)), "the visible swap card must survive later offer post-processing")
	catalog.clear_full_chosik_swap_offer_roll_for_tests()


func _verify_full_budget_failure_keeps_unlocks_out() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(1.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var filtered: Array = catalog._filter_unlock_slot_budget(_ordinary_unlock_choices(catalog), "smasher", _full_smasher_unlock_levels())
	_expect(probe.call_count == 1, "failed full-slot screen must still consume only one gate roll")
	_expect(_ordinary_unlock_entries(filtered).is_empty(), "failed full-slot roll must preserve the old zero-unlock behavior")


func _verify_open_budget_bypasses_roll() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(1.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var open_levels := _full_smasher_unlock_levels()
	open_levels.erase("unlock_magnum_grip")
	var source_choices := _ordinary_unlock_choices(catalog)
	var filtered: Array = catalog._filter_unlock_slot_budget(source_choices, "smasher", open_levels)
	_expect(probe.call_count == 0, "open unlock budget must return before the rare-offer RNG gate")
	_expect(filtered.size() == source_choices.size(), "open unlock budget must preserve every existing choice")


func _verify_soul_summon_exception_survives_failed_roll() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(1.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var choices := _ordinary_unlock_choices(catalog)
	var soul_choice := CommonSkillCatalog.get_unlock_perk_data()
	soul_choice["id"] = CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	choices.append(soul_choice)
	var filtered: Array = catalog._filter_unlock_slot_budget(choices, "smasher", _full_smasher_unlock_levels())
	_expect(_has_choice_id(filtered, CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID), "Soul Summoning Art must bypass the rare full-slot gate")
	_expect(_ordinary_unlock_entries(filtered).is_empty(), "failed roll must not leak an ordinary unlock beside the Soul Summoning exception")


func _verify_soldier_bypasses_filter_and_roll() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(0.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var source_choices := _ordinary_unlock_choices(catalog)
	var filtered: Array = catalog._filter_unlock_slot_budget(source_choices, "soldier", {
		"soldier_unlock_net_gun": 1,
		"soldier_unlock_bazooka": 1,
		"soldier_pistol_perk": 1,
	})
	_expect(probe.call_count == 0, "Soldier must retain its early return without touching the Chosik swap roll")
	_expect(filtered == source_choices, "Soldier choices must remain byte-for-byte equivalent at this filter boundary")


func _verify_swap_cancel_is_a_true_noop() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var config := SmasherSkillConfig.new()
	config.equipped_skills = ["drive", "power_smashing", "plasma", "recovery", "magnum_grip"]
	state.runtime_skill_levels = _full_smasher_unlock_levels()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(config)
	var before_levels := state.runtime_skill_levels.duplicate(true)
	var before_equipped := config.equipped_skills.duplicate(true)
	var before_unlock_flags: Dictionary = (owner.data.get("smasher_skills_unlocked", {}) as Dictionary).duplicate(true)
	var choice := _choice(catalog, "unlock_cleanse")
	_expect(not state.apply_choice(choice, owner, registry), "full Smasher slots must defer the rare unlock into the existing swap dialog")
	_expect(state.has_pending_unlock_swap(), "rare full-slot unlock must create a pending production swap")
	_expect(state.runtime_skill_levels == before_levels, "opening the swap dialog must not commit runtime levels")
	_expect(config.equipped_skills == before_equipped, "opening the swap dialog must not change equipped skills")
	_expect((owner.data.get("smasher_skills_unlocked", {}) as Dictionary) == before_unlock_flags, "opening the swap dialog must not change unlock flags")
	_expect(state.cancel_pending_unlock_swap(owner), "pending rare-offer swap must be cancelable")
	_expect(not state.has_pending_unlock_swap(), "cancel must clear only the pending swap")
	_expect(state.runtime_skill_levels == before_levels, "cancel must leave runtime levels untouched")
	_expect(config.equipped_skills == before_equipped, "cancel must leave equipped skills untouched")
	_expect((owner.data.get("smasher_skills_unlocked", {}) as Dictionary) == before_unlock_flags, "cancel must leave unlock flags untouched")


func _ordinary_unlock_choices(catalog: Object) -> Array:
	return [
		_choice(catalog, "unlock_cleanse"),
		_choice(catalog, "unlock_shield_kiting"),
		_choice(catalog, "unlock_warp_gate"),
	]


func _full_smasher_unlock_levels() -> Dictionary:
	return {
		"unlock_magnum_grip": 1,
		"unlock_plasma": 1,
		"unlock_recovery_skill": 1,
	}


func _choice(catalog: Object, choice_id: String) -> Dictionary:
	var choice: Dictionary = catalog.get_perk_data(choice_id)
	choice["id"] = choice_id
	return choice


func _ordinary_unlock_entries(choices: Array) -> Array:
	return choices.filter(func(choice: Dictionary) -> bool:
		return (
			str(choice.get("unlocks_skill", "")) != ""
			and str(choice.get("id", "")) != CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
		)
	)


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
