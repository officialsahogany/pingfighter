extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")

const TARGET_CHOICES := 3
const SLOT_FILLER_IDS := [
	"dash_lightweight",
	"dash_module_control",
	"dash_jump",
	"dash_acceleration",
	"item_luck",
	"item_cooldown_mastery",
	"item_gauge_mastery",
	"common_swiftness",
	"common_bulk_up",
	"common_training",
	"perk_boost_charge",
	"perk_laurel_shield",
]

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


class FakeRegistry:
	extends RefCounted
	var skill_config: Object

	func _init(next_skill_config: Object) -> void:
		skill_config = next_skill_config

	func get_instance(key: String) -> Object:
		if key == "smasher_skill_config":
			return skill_config
		return null


func _init() -> void:
	_run()


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_unowned_mythic_builder()
	_verify_jackpot_reserves_all_mythic_cards()
	_verify_jackpot_bypasses_open_chosik_reservation()
	_verify_jackpot_candidate_shortage_fills_regular_pool()
	_verify_full_slots_suppress_mythic_offer()
	_verify_chance_zero_suppresses_mythic_offer()
	_verify_flag_off_suppresses_mythic_offer()
	_verify_mythic_choice_applies_through_runtime_state()
	_verify_source_contracts()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("mythic_perk_offer_chance_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_unowned_mythic_builder() -> void:
	var catalog := RuntimePerkCatalog.new()
	var candidates: Array[String] = catalog._get_unowned_mythic_perk_ids({}, "smasher")
	_expect(candidates.size() >= TARGET_CHOICES, "unowned mythic builder should expose enough mythic candidates")
	for perk_id in candidates:
		_expect(_is_mythic_id(perk_id), "unowned mythic builder should return valid mythic ids")

	var all_owned := {}
	for perk_id_value in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		all_owned[str(perk_id_value)] = 1
	_expect_eq(
		catalog._get_unowned_mythic_perk_ids(all_owned, "smasher").size(),
		0,
		"all-owned mythic builder should return zero candidate ids"
	)
	_expect_eq(
		catalog._build_unowned_mythic_choices(all_owned, "smasher", TARGET_CHOICES).size(),
		0,
		"all-owned mythic builder should return zero reserved choices"
	)

	var built: Array = catalog._build_unowned_mythic_choices({}, "smasher", TARGET_CHOICES)
	_expect_eq(built.size(), TARGET_CHOICES, "mythic builder should cut shuffled candidates to the requested count")
	_expect_unique_ids(built, "mythic builder should not duplicate ids")
	for value in built:
		var choice: Dictionary = value as Dictionary
		_expect(_is_mythic_id(str(choice.get("id", ""))), "mythic builder should return mythic choices")
		_expect_eq(int(choice.get("current_level", -1)), 0, "reserved mythic card should be a new Lv.0 -> Lv.1 choice")
		_expect_eq(int(choice.get("next_level", -1)), 1, "reserved mythic card should advance to Lv.1")
		_expect(RuntimePerkCatalog.is_slot_consuming_perk(choice), "reserved mythic card should consume a perk slot")


func _verify_jackpot_reserves_all_mythic_cards() -> void:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0
	var levels := _one_open_slot_levels()
	_expect(catalog.has_open_perk_slot(levels), "one-open fixture should leave one perk slot free")

	for _trial in range(6):
		var choices: Array = catalog.get_choices("smasher", levels, true, TARGET_CHOICES)
		var offer_slots := _offer_slots(choices)
		var mythic_choices := _mythic_choices(offer_slots)
		_expect_eq(offer_slots.size(), TARGET_CHOICES, "jackpot offer should keep the requested non-gold card count")
		_expect_eq(mythic_choices.size(), TARGET_CHOICES, "jackpot=1.0 offer should reserve every non-gold card as mythic")
		_expect_unique_ids(mythic_choices, "jackpot offer should not duplicate mythic ids")


func _verify_jackpot_bypasses_open_chosik_reservation() -> void:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0
	var open_chosik_probe := RollProbe.new(0.0)
	catalog.set_open_chosik_offer_roll_for_tests(Callable(open_chosik_probe, "next_roll"))
	var skill_config := SmasherSkillConfig.new()
	skill_config.equipped_skills = ["drive", "power_smashing"]
	_expect(not skill_config.is_shared_slot_full(), "jackpot regression fixture should have open Chosik slots")

	var choices: Array = catalog.get_choices(
		"smasher",
		_one_open_slot_levels(),
		true,
		TARGET_CHOICES,
		null,
		FakeRegistry.new(skill_config)
	)
	var offer_slots := _offer_slots(choices)
	_expect_eq(open_chosik_probe.call_count, 0, "jackpot screen must not consume the open-slot Chosik roll")
	_expect_eq(offer_slots.size(), TARGET_CHOICES, "jackpot screen should keep exactly three offer cards")
	_expect_eq(_mythic_choices(offer_slots).size(), TARGET_CHOICES, "jackpot screen should contain only three Peerless Martial Arts")
	_expect_eq(_chosik_choices(offer_slots).size(), 0, "jackpot screen must not mix in a Chosik card")
	catalog.clear_open_chosik_offer_roll_for_tests()


func _verify_jackpot_candidate_shortage_fills_regular_pool() -> void:
	var catalog := RuntimePerkCatalog.new()
	var shortage_levels := _all_mythics_owned_except(2)
	var shortage_reserved: Array = catalog._build_unowned_mythic_choices(shortage_levels, "smasher", TARGET_CHOICES)
	_expect_eq(shortage_reserved.size(), 2, "mythic builder should reserve only the available unowned mythics")
	_expect_unique_ids(shortage_reserved, "shortage mythic builder should not duplicate ids")

	catalog.mythic_jackpot_offer_chance = 1.0
	var oversized_target := RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size() + 1
	var choices: Array = catalog.get_choices("smasher", {}, true, oversized_target)
	var offer_slots := _offer_slots(choices)
	var mythic_choices := _mythic_choices(offer_slots)
	_expect_eq(offer_slots.size(), oversized_target, "jackpot shortage should fill the remaining target slots from the regular pool")
	_expect_eq(mythic_choices.size(), RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size(), "jackpot shortage should reserve each available mythic once")
	_expect_unique_ids(mythic_choices, "jackpot shortage fill should keep mythic ids unique")


func _verify_full_slots_suppress_mythic_offer() -> void:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0
	var levels := _full_slot_levels()
	_expect(not catalog.has_open_perk_slot(levels), "full-slot fixture should have no open perk slots")
	var choices: Array = catalog.get_choices("smasher", levels, true, TARGET_CHOICES)
	_expect_eq(_mythic_choices(choices).size(), 0, "full slots plus forced chances should still expose zero mythic cards")


func _verify_chance_zero_suppresses_mythic_offer() -> void:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 0.0
	var choices: Array = catalog.get_choices("smasher", _one_open_slot_levels(), true, TARGET_CHOICES)
	_expect_eq(_mythic_choices(choices).size(), 0, "zero jackpot chance should expose zero mythic cards")


func _verify_flag_off_suppresses_mythic_offer() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0
	var choices: Array = catalog.get_choices("smasher", _one_open_slot_levels(), true, TARGET_CHOICES)
	_expect_eq(_mythic_choices(choices).size(), 0, "flag OFF plus forced chances should expose zero mythic cards")
	PerkConversionFlags.debug_set_enabled(true)


func _verify_mythic_choice_applies_through_runtime_state() -> void:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = _one_open_slot_levels()
	var choices: Array = catalog.get_choices("smasher", state.runtime_skill_levels, true, TARGET_CHOICES)
	var mythic_choices := _mythic_choices(choices)
	_expect_eq(mythic_choices.size(), TARGET_CHOICES, "apply fixture should expose a jackpot of mythic cards")
	if mythic_choices.is_empty():
		return
	var mythic_choice: Dictionary = mythic_choices[0] as Dictionary
	var mythic_id := str(mythic_choice.get("id", ""))
	_expect(state.apply_choice(mythic_choice, null, null), "mythic offer choice should apply through RuntimePerkState.apply_choice")
	_expect_eq(int(state.runtime_skill_levels.get(mythic_id, 0)), 1, "applied mythic offer should write raw runtime_skill_levels Lv.1")


func _verify_source_contracts() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(source.find("mythic_single_offer_chance") < 0, "catalog should no longer keep any single-card mythic offer seam")
	_expect(source.find("var mythic_jackpot_offer_chance := 0.05") >= 0, "catalog should expose a jackpot mythic offer seam at 5%")
	_expect(source.find("var mythic_offer_chance :=") < 0, "catalog should not keep the old single mythic_offer_chance seam")
	_expect(source.find("func _get_mythic_offer_chance(") < 0, "catalog should not keep the old single chance helper")
	_expect(source.find("func _pick_random_unowned_mythic_perk_id") < 0, "catalog should not keep the old single mythic picker")
	_expect(source.find("func _get_mythic_offer_chances") >= 0, "catalog should route the mythic offer probability through the jackpot helper")
	_expect(source.find("if randf() >= jackpot_chance") >= 0, "jackpot helper should roll once against the jackpot band")
	_expect(source.find("single_chance") < 0, "get_choices should no longer reference a single mythic band")
	_expect(source.find("func _try_build_mythic_jackpot_offer(") >= 0, "catalog should isolate jackpot-only offer construction")
	_expect(source.find("ring-core") < 0, "retired ring-core reservation language should not remain in the catalog")
	var jackpot_call := source.find("var mythic_jackpot_choices := _try_build_mythic_jackpot_offer(")
	var unlock_filter := source.find("choices = _filter_unlock_slot_budget(", jackpot_call)
	var guardian_append := source.find("_append_lingpet_guardian_enhance_choice(", jackpot_call)
	_expect(
		jackpot_call >= 0 and unlock_filter > jackpot_call and guardian_append > jackpot_call,
		"jackpot branch must run before Chosik and guardian reservation evaluation"
	)
	var boss_vision_fill := source.find("for vision_choice in boss_vision_reserved:")
	var guardian_fill := source.find("for guardian_choice in guardian_enhance_reserved:")
	var swap_fill := source.find("for swap_choice in full_chosik_swap_reserved:")
	var dash_fill := source.find("for dash_token_choice in dash_token_reserved:")
	var owned_fill := source.find("for owned_upgrade_choice in owned_upgrade_reserved:")
	var shuffle_fill := source.find("for choice in choices:")
	_expect(
		boss_vision_fill >= 0
		and guardian_fill > boss_vision_fill
		and swap_fill > guardian_fill
		and dash_fill > swap_fill
		and owned_fill > dash_fill
		and shuffle_fill > owned_fill,
		"ordinary get_choices fill order should match the post-jackpot reservation chain"
	)


func _one_open_slot_levels() -> Dictionary:
	return _slot_levels_for_count(RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT - 1)


func _full_slot_levels() -> Dictionary:
	return _slot_levels_for_count(RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT)


func _slot_levels_for_count(target_slots: int) -> Dictionary:
	var catalog := RuntimePerkCatalog.new()
	var levels: Dictionary = {}
	for perk_id in SLOT_FILLER_IDS:
		if catalog.count_owned_slot_perks(levels) >= target_slots:
			break
		levels[str(perk_id)] = 1
	return levels


func _all_mythics_owned_except(remaining_unowned_count: int) -> Dictionary:
	var levels: Dictionary = {}
	var mythic_ids: Array = RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys()
	var owned_cutoff := maxi(0, mythic_ids.size() - max(0, remaining_unowned_count))
	for index in range(owned_cutoff):
		levels[str(mythic_ids[index])] = 1
	return levels


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


func _mythic_choices(choices: Array) -> Array:
	var result: Array = []
	for value in choices:
		if value is Dictionary and _is_mythic_id(str((value as Dictionary).get("id", ""))):
			result.append(value)
	return result


func _chosik_choices(choices: Array) -> Array:
	var result: Array = []
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("unlocks_skill", "")).strip_edges() != "":
			result.append(value)
	return result


func _is_mythic_id(perk_id: String) -> bool:
	return RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(perk_id)


func _expect_unique_ids(choices: Array, message: String) -> void:
	var seen := {}
	for value in choices:
		if not (value is Dictionary):
			continue
		var choice: Dictionary = value as Dictionary
		var choice_id := str(choice.get("id", ""))
		_expect(choice_id != "", "%s should not include empty ids" % message)
		_expect(not bool(seen.get(choice_id, false)), "%s (duplicate %s)" % [message, choice_id])
		seen[choice_id] = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
