extends SceneTree

# Seals the loading-screen gameplay-tip system:
#   - every supported language stays index-aligned and the SAME length as the
#     Korean base (localization-sync contract; a dropped translation fails here)
#   - no tip entry is left blank
#   - the "TIP" label prefix exists for every language and formatting is correct
#   - the basic/advanced tier partition exactly covers every tip (no orphan,
#     no overlap) and league ids map to the right tier
#   - character control tips stay key-aligned across all 7 languages, runtime
#     aliases (soldier/baltor) normalize, and the character adds exactly one
#     rotation slot
#   - slot_for_elapsed rotates and wraps correctly (incl. negative-safe)

const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_tip_count()
	_verify_language_parity_and_non_blank()
	_verify_localization_actually_differs()
	_verify_labels_present()
	_verify_format_tip()
	_verify_tier_partition()
	_verify_tier_league_mapping()
	_verify_character_tips()
	_verify_character_rotation()
	_verify_slot_rotation()

	if _failures.is_empty():
		print("battle_loading_tips_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_tip_count() -> void:
	_expect(BattleLoadingTips.get_tip_count() > 0, "there should be at least one loading tip")


func _verify_language_parity_and_non_blank() -> void:
	var base_count: int = BattleLoadingTips.get_tip_count()
	for language in LanguageSettings.SUPPORTED_LANGUAGES:
		var tips: Array = BattleLoadingTips.tips_for_language(str(language))
		_expect(
			tips.size() == base_count,
			"language '%s' should have %d tips (localization parity), got %d" % [language, base_count, tips.size()]
		)
		for i in range(tips.size()):
			_expect(
				str(tips[i]).strip_edges() != "",
				"language '%s' tip #%d should not be blank" % [language, i]
			)


func _verify_localization_actually_differs() -> void:
	# Guard against an English (or other) array accidentally left as a copy of Korean.
	_expect(
		BattleLoadingTips.tip_text_for_language(0, "en") != BattleLoadingTips.tip_text_for_language(0, "ko"),
		"English tip #0 should be an actual translation, not the Korean string"
	)
	_expect(
		BattleLoadingTips.tip_text_for_language(0, "ja") != BattleLoadingTips.tip_text_for_language(0, "ko"),
		"Japanese tip #0 should be an actual translation, not the Korean string"
	)


func _verify_labels_present() -> void:
	for language in LanguageSettings.SUPPORTED_LANGUAGES:
		_expect(
			BattleLoadingTips.label_for_language(str(language)).strip_edges() != "",
			"language '%s' should have a non-blank TIP label" % language
		)


func _verify_format_tip() -> void:
	var en := BattleLoadingTips.format_tip_for_language(0, "en")
	_expect(en.begins_with("TIP: "), "English formatted tip should start with the 'TIP: ' label, got '%s'" % en)
	_expect(
		en.ends_with(BattleLoadingTips.tip_text_for_language(0, "en")),
		"English formatted tip should end with the tip text"
	)
	var ko := BattleLoadingTips.format_tip_for_language(0, "ko")
	_expect(ko.begins_with("도움말: "), "Korean formatted tip should start with the '도움말: ' label, got '%s'" % ko)


func _verify_tier_partition() -> void:
	var count: int = BattleLoadingTips.get_tip_count()
	var basic: Array = BattleLoadingTips.BASIC_TIP_INDICES
	var advanced: Array = BattleLoadingTips.ADVANCED_TIP_INDICES
	var seen := {}
	for index_value in basic + advanced:
		var index := int(index_value)
		_expect(index >= 0 and index < count, "tier index %d should be inside 0..%d" % [index, count - 1])
		_expect(not seen.has(index), "tip index %d should belong to exactly one tier" % index)
		seen[index] = true
	_expect(
		seen.size() == count,
		"tier partition should cover every tip: covered %d of %d" % [seen.size(), count]
	)
	_expect(basic.size() > 0, "basic tier should have at least one tip")
	_expect(advanced.size() > 0, "advanced tier should have at least one tip")
	_expect(
		BattleLoadingTips.get_tier_tip_count(BattleLoadingTips.TIER_BASIC) == basic.size(),
		"basic tier tip count should match its index list"
	)


func _verify_tier_league_mapping() -> void:
	_expect(
		BattleLoadingTips.tier_for_league("junior") == BattleLoadingTips.TIER_BASIC,
		"테스트(junior) league should show the basic tip tier"
	)
	_expect(
		BattleLoadingTips.tier_for_league("champion") == BattleLoadingTips.TIER_ADVANCED,
		"실전(champion) league should show the advanced tip tier"
	)
	_expect(
		BattleLoadingTips.tier_for_league("mythic") == BattleLoadingTips.TIER_ADVANCED,
		"오버클럭(mythic) league should show the advanced tip tier"
	)
	# Tier tips must resolve to actual formatted text for both tiers.
	_expect(
		BattleLoadingTips.format_tier_tip(BattleLoadingTips.TIER_BASIC, 0).contains(": "),
		"basic tier slot 0 should format to a labeled tip"
	)
	_expect(
		BattleLoadingTips.format_tier_tip(BattleLoadingTips.TIER_ADVANCED, 0).contains(": "),
		"advanced tier slot 0 should format to a labeled tip"
	)


func _verify_character_tips() -> void:
	var keys: Array = BattleLoadingTips.CHARACTER_TIP_KEYS
	_expect(keys.size() == 5, "there should be a control tip key for each of the 5 playable characters")
	for language in LanguageSettings.SUPPORTED_LANGUAGES:
		var tips: Dictionary = BattleLoadingTips.character_tips_for_language(str(language))
		_expect(
			tips.size() == keys.size(),
			"language '%s' should have %d character tips (localization parity), got %d" % [language, keys.size(), tips.size()]
		)
		for key_value in keys:
			var key := str(key_value)
			_expect(
				str(tips.get(key, "")).strip_edges() != "",
				"language '%s' character tip '%s' should exist and not be blank" % [language, key]
			)
	_expect(
		BattleLoadingTips.character_tip_text_for_language("smasher", "en")
			!= BattleLoadingTips.character_tip_text_for_language("smasher", "ko"),
		"English smasher tip should be an actual translation, not the Korean string"
	)
	# Runtime alias normalization must track the canonical normalizer
	# (player_character_runtime.gd): soldier/commando, io, kohaku/baltor,
	# and unknown values fall back to smasher exactly like the rest of the game.
	_expect(
		BattleLoadingTips.character_tip_text_for_language("soldier", "ko")
			== BattleLoadingTips.character_tip_text_for_language("commando", "ko"),
		"'soldier' should normalize to the commando control tip"
	)
	_expect(
		BattleLoadingTips.character_tip_text_for_language("baltor", "ko")
			== BattleLoadingTips.character_tip_text_for_language("blacksmith", "ko"),
		"'baltor' should normalize to the blacksmith control tip"
	)
	_expect(
		BattleLoadingTips.character_tip_text_for_language("kohaku", "ko")
			== BattleLoadingTips.character_tip_text_for_language("blacksmith", "ko"),
		"'kohaku' should normalize to the blacksmith control tip"
	)
	_expect(
		BattleLoadingTips.character_tip_text_for_language("io", "ko")
			== BattleLoadingTips.character_tip_text_for_language("optimus", "ko"),
		"'io' should normalize to the optimus control tip"
	)
	_expect(
		BattleLoadingTips.character_tip_text_for_language("maribo", "ko")
			== BattleLoadingTips.character_tip_text_for_language("smasher", "ko"),
		"unknown character types should fall back to the smasher tip like the canonical normalizer"
	)
	_expect(not BattleLoadingTips.has_character_tip(""), "empty character type should not add a control tip")


func _verify_character_rotation() -> void:
	var tier: String = BattleLoadingTips.TIER_BASIC
	var tier_count: int = BattleLoadingTips.get_tier_tip_count(tier)
	_expect(
		BattleLoadingTips.get_rotation_tip_count(tier, "viper") == tier_count + 1,
		"a known character should add exactly one rotation slot"
	)
	_expect(
		BattleLoadingTips.get_rotation_tip_count(tier, "") == tier_count,
		"no character should leave the rotation at the tier tip count"
	)
	# format_rotation_tip resolves through the SAVED global language, so
	# compare against the same language to stay hermetic on non-Korean setups.
	var current_language: String = LanguageSettings.get_language()
	var character_slot_text: String = BattleLoadingTips.format_rotation_tip(tier, "viper", tier_count)
	_expect(
		character_slot_text.ends_with(BattleLoadingTips.character_tip_text_for_language("viper", current_language)),
		"the extra rotation slot should render the selected character's control tip"
	)
	_expect(character_slot_text.contains(": "), "the character rotation slot should keep the TIP label prefix")
	_expect(
		BattleLoadingTips.format_rotation_tip(tier, "viper", 0) == BattleLoadingTips.format_tier_tip(tier, 0),
		"rotation slots before the character slot should render the tier tips unchanged"
	)
	_expect(
		BattleLoadingTips.format_rotation_tip(tier, "viper", tier_count + 1) == BattleLoadingTips.format_tier_tip(tier, 0),
		"rotation should wrap past the character slot back to the first tier tip"
	)


func _verify_slot_rotation() -> void:
	var count: int = BattleLoadingTips.get_tier_tip_count(BattleLoadingTips.TIER_ADVANCED)
	var period: float = BattleLoadingTips.TIP_ROTATE_SECONDS
	_expect(BattleLoadingTips.slot_for_elapsed(0, 0.0, count) == 0, "elapsed 0 should show the start slot")
	_expect(
		BattleLoadingTips.slot_for_elapsed(0, period * 0.5, count) == 0,
		"before one full rotation period the start slot should stay put"
	)
	_expect(
		BattleLoadingTips.slot_for_elapsed(0, period * 1.5, count) == 1 % count,
		"after one rotation period the next slot should show"
	)
	_expect(
		BattleLoadingTips.slot_for_elapsed(0, period * float(count) + 0.1, count) == 0,
		"a full cycle of periods should wrap back to the start slot"
	)
	_expect(
		BattleLoadingTips.slot_for_elapsed(count - 1, period * 1.5, count) == 0,
		"rotation past the last slot should wrap to the first"
	)
	_expect(
		BattleLoadingTips.slot_for_elapsed(-1, 0.0, count) == count - 1,
		"a negative start slot should wrap into range"
	)
	_expect(
		BattleLoadingTips.slot_for_elapsed(0, -5.0, count) == 0,
		"negative elapsed time should clamp to the start slot"
	)
	_expect(BattleLoadingTips.slot_for_elapsed(3, 10.0, 0) == 0, "zero slot count should clamp to slot 0")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
