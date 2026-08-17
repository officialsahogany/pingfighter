extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
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
	var config_key := "smasher_skill_config"

	func _init(next_config: Object, next_config_key: String = "smasher_skill_config") -> void:
		config = next_config
		config_key = next_config_key

	func get_instance(key: String) -> Object:
		if key == config_key:
			return config
		return null


class SlotConfigProbe:
	extends RefCounted
	var full := false

	func _init(is_full: bool) -> void:
		full = is_full

	func is_shared_slot_full() -> bool:
		return full


func _init() -> void:
	_verify_full_budget_success_reserves_exactly_one()
	_verify_full_budget_failure_keeps_unlocks_out()
	_verify_open_budget_bypasses_roll()
	_verify_live_open_slots_gate_success_reserves_exactly_one()
	_verify_live_open_slots_gate_failure_removes_manuals()
	_verify_live_fullness_counts_common_chosik()
	_verify_soul_summon_respects_full_slot_gate()
	_verify_all_character_configs_drive_fullness()
	_verify_soldier_respects_live_full_slot_gate()
	_verify_blacksmith_does_not_inherit_smasher_chosik_pool()
	_verify_full_slot_miss_can_be_replaced_by_training()
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
	var probe := RollProbe.new(0.049999)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var filtered: Array = catalog._filter_unlock_slot_budget(_ordinary_unlock_choices(catalog), "smasher", _full_smasher_unlock_levels())
	var unlocks := _ordinary_unlock_entries(filtered)
	_expect(is_equal_approx(RuntimePerkCatalog.FULL_CHOSIK_SWAP_OFFER_CHANCE, 0.05), "full-slot swap offer chance must remain the single 0.05 tuning constant")
	_expect(probe.call_count == 1, "a full screen with several unlock candidates must roll exactly once")
	_expect(unlocks.size() == 1, "a successful full-slot roll must retain exactly one ordinary Chosik unlock")
	if unlocks.size() == 1:
		_expect(bool((unlocks[0] as Dictionary).get(RuntimePerkCatalog.FULL_CHOSIK_SWAP_PRIORITY_KEY, false)), "the one successful candidate must enter the protected full-slot swap lane")

	# Production get_choices must preserve the successful card through the
	# later general shuffle; otherwise the visible chance is lower than 0.05.
	var production_probe := RollProbe.new(0.049999)
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
	var probe := RollProbe.new(0.05)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var filtered: Array = catalog._filter_unlock_slot_budget(_ordinary_unlock_choices(catalog), "smasher", _full_smasher_unlock_levels())
	_expect(probe.call_count == 1, "failed full-slot screen must still consume only one gate roll")
	_expect(_ordinary_unlock_entries(filtered).is_empty(), "failed full-slot roll must preserve the old zero-unlock behavior")


func _verify_open_budget_bypasses_roll() -> void:
	# 레거시 폴백(레지스트리 없음) 전용 계약: 여유 예산은 굴림 없이 전량 통과.
	# 라이브 개방 게이트는 아래 두 레그가 봉인한다.
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(1.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var open_probe := RollProbe.new(1.0)
	catalog.set_open_chosik_offer_roll_for_tests(Callable(open_probe, "next_roll"))
	var open_levels := _full_smasher_unlock_levels()
	open_levels.erase("unlock_magnum_grip")
	var source_choices := _ordinary_unlock_choices(catalog)
	var filtered: Array = catalog._filter_unlock_slot_budget(source_choices, "smasher", open_levels)
	_expect(probe.call_count == 0, "fallback open unlock budget must return before the rare-offer RNG gate")
	_expect(open_probe.call_count == 0, "fallback open unlock budget must not consult the live open-slot gate")
	_expect(filtered.size() == source_choices.size(), "fallback open unlock budget must preserve every existing choice")


func _verify_live_open_slots_gate_success_reserves_exactly_one() -> void:
	var catalog := RuntimePerkCatalog.new()
	var full_probe := RollProbe.new(1.0)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(full_probe, "next_roll"))
	var open_probe := RollProbe.new(0.349999)
	catalog.set_open_chosik_offer_roll_for_tests(Callable(open_probe, "next_roll"))
	var config := SmasherSkillConfig.new()
	config.equipped_skills = ["drive", "power_smashing"]
	_expect(not config.is_shared_slot_full(), "the fresh Smasher fixture must really have open combat orbs")
	var choices: Array = catalog.get_choices("smasher", {}, true, 3, null, FakeRegistry.new(config))
	_expect(is_equal_approx(RuntimePerkCatalog.OPEN_CHOSIK_OFFER_CHANCE, 0.35), "open-slot Chosik chance must remain the single 0.35 tuning constant")
	_expect(open_probe.call_count == 1, "a live open-slot screen must roll the open Chosik gate exactly once")
	_expect(full_probe.call_count == 0, "a live open-slot screen must not consume the full-slot swap roll")
	var unlock_cards := _all_unlock_entries(choices)
	_expect(unlock_cards.size() == 1, "a successful live open-slot roll must surface exactly one Chosik manual")
	if unlock_cards.size() == 1:
		_expect(bool((unlock_cards[0] as Dictionary).get("offer_protected", false)), "the visible open-slot manual must survive later offer post-processing")
	catalog.clear_open_chosik_offer_roll_for_tests()
	catalog.clear_full_chosik_swap_offer_roll_for_tests()


func _verify_live_open_slots_gate_failure_removes_manuals() -> void:
	var catalog := RuntimePerkCatalog.new()
	var open_probe := RollProbe.new(0.35)
	catalog.set_open_chosik_offer_roll_for_tests(Callable(open_probe, "next_roll"))
	var config := SmasherSkillConfig.new()
	config.equipped_skills = ["drive", "power_smashing"]
	var choices: Array = catalog.get_choices("smasher", {}, true, 3, null, FakeRegistry.new(config))
	_expect(open_probe.call_count == 1, "a failed live open-slot screen must still consume only one gate roll")
	_expect(_all_unlock_entries(choices).is_empty(), "a failed live open-slot roll must keep every Chosik manual off the screen")
	_expect(choices.size() == 3, "a failed live open-slot roll must still fill the screen with non-Chosik offers")
	catalog.clear_open_chosik_offer_roll_for_tests()


func _verify_live_fullness_counts_common_chosik() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(0.05)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var config := SmasherSkillConfig.new()
	config.equipped_skills = [
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		CommonSkillCatalog.SOUL_SUMMON_ART_ID,
	]
	_expect(config.is_shared_slot_full(), "the production Smasher config fixture must really be full")
	var runtime_levels := {
		"unlock_plasma": 1,
		"unlock_recovery_skill": 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1,
	}
	var choices: Array = catalog.get_choices(
		"smasher",
		runtime_levels,
		true,
		500,
		null,
		FakeRegistry.new(config)
	)
	_expect(probe.call_count == 1, "a live full config must enter the rare Chosik gate even when only two character manuals are owned")
	_expect(_ordinary_unlock_entries(choices).is_empty(), "common Chosik occupancy must stop ordinary manuals from bypassing the full-slot miss")


func _verify_soul_summon_respects_full_slot_gate() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(0.05)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var choices := _ordinary_unlock_choices(catalog)
	var soul_choice := CommonSkillCatalog.get_unlock_perk_data()
	soul_choice["id"] = CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	choices.append(soul_choice)
	var filtered: Array = catalog._filter_unlock_slot_budget(choices, "smasher", _full_smasher_unlock_levels())
	_expect(not _has_choice_id(filtered, CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID), "Soul Summoning Art occupies a combat orb and must not bypass a failed full-slot gate")
	_expect(_ordinary_unlock_entries(filtered).is_empty(), "a failed full-slot roll must remove every ordinary and common Chosik manual")

	var success_catalog := RuntimePerkCatalog.new()
	var success_probe := RollProbe.new(0.049999)
	success_catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(success_probe, "next_roll"))
	var successful: Array = success_catalog._filter_unlock_slot_budget(
		[soul_choice],
		"smasher",
		_full_smasher_unlock_levels()
	)
	_expect(successful.size() == 1, "the rare full-slot success must still allow Soul Summoning Art as the one swap candidate")
	if successful.size() == 1:
		_expect(bool((successful[0] as Dictionary).get(RuntimePerkCatalog.FULL_CHOSIK_SWAP_PRIORITY_KEY, false)), "the rare common Chosik must use the same protected swap lane")


func _verify_all_character_configs_drive_fullness() -> void:
	var routes := [
		["smasher", "smasher_skill_config"],
		["viper", "viper_skill_config"],
		["soldier", "commando_skill_config"],
		["blacksmith", "blacksmith_skill_config"],
		["optimus", "optimus_skill_config"],
	]
	for route_value: Variant in routes:
		var route: Array = route_value as Array
		var character_type := str(route[0])
		var catalog := RuntimePerkCatalog.new()
		var probe := RollProbe.new(0.05)
		catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
		var choices: Array = catalog.get_choices(
			character_type,
			{},
			true,
			500,
			null,
			FakeRegistry.new(SlotConfigProbe.new(true), str(route[1]))
		)
		_expect(probe.call_count == 1, "%s must consult its live full Chosik config exactly once" % character_type)
		_expect(_all_unlock_entries(choices).is_empty(), "%s must suppress every random Chosik manual after the five-percent miss" % character_type)


func _verify_soldier_respects_live_full_slot_gate() -> void:
	var catalog := RuntimePerkCatalog.new()
	var probe := RollProbe.new(0.05)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(probe, "next_roll"))
	var choices: Array = catalog.get_choices(
		"soldier",
		{
			CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1,
			CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1,
		},
		true,
		500,
		null,
		FakeRegistry.new(SlotConfigProbe.new(true), "commando_skill_config")
	)
	_expect(probe.call_count == 1, "a live full Soldier config must use the same screen-level Chosik gate")
	_expect(_ordinary_unlock_entries(choices).is_empty(), "full Soldier slots must not leak firearm manuals after a failed rare roll")


func _verify_blacksmith_does_not_inherit_smasher_chosik_pool() -> void:
	var catalog := RuntimePerkCatalog.new()
	for alias: String in ["blacksmith", "baltor", "kohaku"]:
		var choices: Array = catalog.get_choices(alias, {}, true, 500)
		var leaked_smasher_manuals := choices.filter(func(choice: Dictionary) -> bool:
			return (
				str(choice.get("character_restriction", "")) == "smasher"
				and str(choice.get("unlocks_skill", "")) != ""
			)
		)
		_expect(leaked_smasher_manuals.is_empty(), "%s must not inherit Smasher Chosik manuals" % alias)


func _verify_full_slot_miss_can_be_replaced_by_training() -> void:
	var previous_flag := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 0.0
	catalog.dash_token_boost_chances = [0.0, 0.0, 0.0]
	catalog.owned_upgrade_partial_chance = 0.0
	var full_slot_probe := RollProbe.new(0.05)
	catalog.set_full_chosik_swap_offer_roll_for_tests(Callable(full_slot_probe, "next_roll"))
	var config := SmasherSkillConfig.new()
	config.equipped_skills = [
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		CommonSkillCatalog.SOUL_SUMMON_ART_ID,
	]
	var registry := FakeRegistry.new(config)
	var runtime_levels := {
		"unlock_plasma": 1,
		"unlock_recovery_skill": 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1,
	}
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = runtime_levels.duplicate(true)
	state.current_choices = catalog.get_choices("smasher", runtime_levels, true, 3, null, registry)
	state.current_choice_context = {"source": "battle_starpoint"}
	var training_result: Dictionary = state._try_inject_physique_training_offer(
		false,
		false,
		0.0,
		0.0,
		0.0,
		registry
	)
	_expect(_ordinary_unlock_entries(state.current_choices).is_empty(), "a full-slot miss must leave no Chosik manual before training replacement")
	_expect(bool(training_result.get("appeared", false)), "the forced 60 percent training roll must replace an ordinary lane after the Chosik miss")
	var training_count := state.current_choices.filter(func(choice: Dictionary) -> bool:
		return bool(choice.get("is_physique_training", false))
	).size()
	_expect(
		training_count == 1,
		"the resulting full-slot screen must contain exactly one training card",
	)
	PerkConversionFlags.debug_set_enabled(previous_flag)


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


func _all_unlock_entries(choices: Array) -> Array:
	return choices.filter(func(choice: Dictionary) -> bool:
		return str(choice.get("unlocks_skill", "")) != ""
	)


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
