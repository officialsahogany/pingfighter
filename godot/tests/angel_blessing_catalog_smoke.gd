extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")

const ANGEL_PERK_ID := "angel_blessing"
const EXPECTED_MYTHIC_COUNT := 13
const EXPECTED_CONVERSION_SOURCE_COUNT := 39

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_catalog_contract()
	_verify_conversion_value_contract()
	_verify_forced_jackpot_candidate()
	_verify_guaranteed_mythic_candidate()
	PerkConversionFlags.debug_set_enabled(false)
	_finish()


func _verify_catalog_contract() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data(ANGEL_PERK_ID)
	_expect_eq(RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size(), EXPECTED_MYTHIC_COUNT, "converted mythic catalog should expose 13 perks")
	_expect(not data.is_empty(), "Angel should be queryable from the runtime perk catalog")
	_expect_eq(str(data.get("name", "")), "천운삼괘", "Angel should expose the adopted peerless-martial-art name")
	_expect_eq(int(data.get("max_level", 0)), 1, "Angel should be a max-level-1 perk")
	_expect_eq(str(data.get("tree", "")), "mythic", "Angel should use the mythic tree")
	_expect_eq(str(data.get("rarity", "")), "mythic", "Angel should use mythic rarity")
	_expect(bool(data.get("effective_level_exempt", false)), "Angel should ignore effective-level bonus sources")
	_expect_eq(str(data.get("conversion_source", "")), ANGEL_PERK_ID, "Angel should use its identity conversion source")
	data["id"] = ANGEL_PERK_ID
	_expect_eq(RuntimePerkCatalog.get_slot_cost_for_level(data, 0), 0, "unowned Angel should consume no slot")
	_expect_eq(RuntimePerkCatalog.get_slot_cost_for_level(data, 1), 1, "owned Angel should consume exactly one regular perk slot")


func _verify_conversion_value_contract() -> void:
	_expect_eq(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.size(), EXPECTED_CONVERSION_SOURCE_COUNT, "conversion source map should expose 39 active entries")
	_expect_eq(
		str(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get(ANGEL_PERK_ID, "")),
		ANGEL_PERK_ID,
		"Angel conversion source should map to itself"
	)
	_expect_eq(PerkConversionValues.CONVERTED_MYTHIC_VALUES.size(), EXPECTED_MYTHIC_COUNT, "converted mythic value table should expose 13 entries")
	var values: Dictionary = PerkConversionValues.CONVERTED_MYTHIC_VALUES.get(ANGEL_PERK_ID, {}) as Dictionary
	_expect_eq(float(values.get("buff_pct", 0.0)), 30.0, "Angel should use the locked 30 percent blessing strength")


func _verify_forced_jackpot_candidate() -> void:
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 1.0
	var choices: Array = catalog.get_choices(
		"smasher",
		{},
		true,
		RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size()
	)
	var angel_choice: Dictionary = _find_choice(choices, ANGEL_PERK_ID)
	_expect(not angel_choice.is_empty(), "forced regular jackpot should include Angel directly")
	_expect_eq(str(angel_choice.get("offer_lane", "")), "mythic_jackpot", "Angel jackpot card should use the protected mythic lane")
	_expect(bool(angel_choice.get("offer_protected", false)), "Angel jackpot card should remain protected from regular fill replacement")


func _verify_guaranteed_mythic_candidate() -> void:
	var catalog := RuntimePerkCatalog.new()
	_expect_eq(MythicPerkGrantHelper.MYTHIC_PERK_IDS.size(), EXPECTED_MYTHIC_COUNT, "guaranteed mythic helper should expose 13 ids")
	_expect(MythicPerkGrantHelper.is_mythic_perk_id(ANGEL_PERK_ID), "guaranteed mythic helper should classify Angel as mythic")
	var candidates: Array[String] = MythicPerkGrantHelper.get_available_mythic_perk_ids(null, null, catalog)
	_expect(candidates.has(ANGEL_PERK_ID), "guaranteed mythic choice candidate pool should include Angel")
	var cards: Array = MythicPerkGrantHelper.build_mythic_choice_cards(EXPECTED_MYTHIC_COUNT, null, null, catalog)
	var angel_card: Dictionary = _find_choice(cards, ANGEL_PERK_ID)
	_expect(not angel_card.is_empty(), "guaranteed mythic choice card builder should materialize Angel")
	_expect_eq(str(angel_card.get("rarity", "")), "mythic", "guaranteed Angel card should retain mythic rarity")


func _find_choice(choices: Array, perk_id: String) -> Dictionary:
	for value: Variant in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == perk_id:
			return value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_catalog_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
