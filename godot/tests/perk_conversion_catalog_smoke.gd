extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

const CONVERTED_PERK_IDS := [
	"star_detector",
	"adversity_armor",
	"reinforced_boomerang_gauntlet",
	"sensor",
	"gravitybelt",
	"dowsing_pendulum",
	"dowsing_goggles",
	"chargebag",
	"battery",
	"revival",
	"master",
	"gold_digger",
	"lucky_coin",
	"shrapnel_armor",
	"fuel_pouch",
	"bluetooth_ring",
	"foul_whistle",
	"smartphone",
	"neural_helmet",
	"commando_arm",
	"rainbow_fur_glove",
	"knee_pads",
	"soul_burst",
	"bulletproof_hat",
	"spiked_helmet",
	"venom_mist_gauntlet",
	"speedgear",
	"sage_ring",
]
const CONVERTED_MYTHIC_PERK_IDS := [
	"megingjord",
	"transcendent_crown",
	"ragnarok_hammer",
	"hermes_shoes",
	"poseidon_trident",
	"sacred_laurel",
	"heavenly_cape",
	"horn_strawberry_mask",
	"odins_eye",
	"celestial_armor",
	"baal_boots",
	"pandora_legacy",
]

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)

	_verify_catalog_lookup_and_schema()
	_verify_mythic_schema()
	_verify_localization_maps()
	_verify_offer_pool_block()
	_verify_debug_visibility()

	_restore_language_settings_snapshot()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_catalog_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _all_converted_ids() -> Array:
	var ids: Array = CONVERTED_PERK_IDS.duplicate()
	ids.append_array(CONVERTED_MYTHIC_PERK_IDS)
	return ids


func _verify_catalog_lookup_and_schema() -> void:
	var catalog := RuntimePerkCatalog.new()
	var all_data: Dictionary = catalog.get_all_perk_data()
	for perk_id in _all_converted_ids():
		var id := str(perk_id)
		_expect(all_data.has(id), "get_all_perk_data should include converted perk %s" % id)
		var data: Dictionary = catalog.get_perk_data(id)
		_expect(not data.is_empty(), "get_perk_data should return converted perk %s" % id)
		_expect(str(data.get("id", "")) == id, "converted perk %s should preserve id" % id)
		_expect(str(data.get("conversion_source", "")) == id, "converted perk %s should track conversion_source" % id)
		_expect(str(data.get("name", "")).strip_edges() != "", "converted perk %s should expose a name" % id)
		_expect(str(data.get("detail", "")).strip_edges() != "", "converted perk %s should expose detail text" % id)
		_expect(data.get("icon_color", null) is Color, "converted perk %s should copy an item icon color" % id)
		var max_level := int(data.get("max_level", 0))
		_expect(max_level > 0, "converted perk %s should have positive max_level" % id)
		var descriptions_value: Variant = data.get("descriptions", {})
		_expect(descriptions_value is Dictionary, "converted perk %s should expose level descriptions" % id)
		if descriptions_value is Dictionary:
			var descriptions: Dictionary = descriptions_value
			for level in range(1, max_level + 1):
				_expect(
					str(descriptions.get(level, "")).strip_edges() != "",
					"converted perk %s should have description for Lv.%d" % [id, level]
				)

	var venom: Dictionary = catalog.get_perk_data("venom_mist_gauntlet")
	_expect(str(venom.get("tree", "")) == "viper", "venom_mist_gauntlet should live in the viper tree")
	_expect(str(venom.get("character_restriction", "")) == "viper", "venom_mist_gauntlet should stay Viper-only")


func _verify_mythic_schema() -> void:
	var catalog := RuntimePerkCatalog.new()
	for perk_id in CONVERTED_MYTHIC_PERK_IDS:
		var id := str(perk_id)
		var data: Dictionary = catalog.get_perk_data(id)
		_expect(int(data.get("max_level", 0)) == 1, "mythic converted perk %s should be max_level 1" % id)
		_expect(str(data.get("rarity", "")) == "mythic", "mythic converted perk %s should carry rarity mythic" % id)
		_expect(bool(data.get("effective_level_exempt", false)), "mythic converted perk %s should be effective-level exempt" % id)


func _verify_localization_maps() -> void:
	for language in _get_non_korean_languages():
		LanguageSettings.set_language(language)
		var catalog := RuntimePerkCatalog.new()
		for perk_id in _all_converted_ids():
			var id := str(perk_id)
			var data: Dictionary = catalog.get_perk_data(id)
			_expect_no_hangul(str(data.get("name", "")), "localized name %s[%s]" % [id, language])
			_expect_no_hangul(str(data.get("description", "")), "localized description %s[%s]" % [id, language])
			_expect_no_hangul(str(data.get("detail", "")), "localized detail %s[%s]" % [id, language])
			_expect(str(data.get("name", "")).strip_edges() != "", "localized name %s[%s] should not be empty" % [id, language])
			_expect(str(data.get("description", "")).strip_edges() != "", "localized summary %s[%s] should not be empty" % [id, language])
			_expect(str(data.get("detail", "")).strip_edges() != "", "localized detail %s[%s] should not be empty" % [id, language])


func _verify_offer_pool_block() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := RuntimePerkCatalog.new()
	for pool_spec in [
		{"name": "COMMON_PERKS", "pool": RuntimePerkCatalog.COMMON_PERKS},
		{"name": "SMASHER_PERKS", "pool": RuntimePerkCatalog.SMASHER_PERKS},
		{"name": "VIPER_PERKS", "pool": RuntimePerkCatalog.VIPER_PERKS},
		{"name": "SOLDIER_PERKS", "pool": RuntimePerkCatalog.SOLDIER_PERKS},
		{"name": "INSTANT_PERKS", "pool": RuntimePerkCatalog.INSTANT_PERKS},
	]:
		var pool_name := str(pool_spec.get("name", ""))
		var pool: Dictionary = pool_spec.get("pool", {})
		for perk_id in _all_converted_ids():
			_expect(not pool.has(str(perk_id)), "%s should not contain flag-gated converted perk %s" % [pool_name, str(perk_id)])

	for character_type in ["smasher", "viper", "soldier", "commando"]:
		for exclude_instant in [true, false]:
			var choices: Array = catalog.get_choices(character_type, {}, bool(exclude_instant), 300)
			for perk_id in _all_converted_ids():
				_expect(
					not _has_choice_id(choices, str(perk_id)),
					"flag-OFF get_choices(%s, exclude_instant=%s) should not offer converted perk %s" % [character_type, str(exclude_instant), str(perk_id)]
				)


func _verify_debug_visibility() -> void:
	var catalog := RuntimePerkCatalog.new()
	var debug_entries: Array = catalog.get_debug_perk_entries()
	for perk_id in _all_converted_ids():
		_expect(_has_choice_id(debug_entries, str(perk_id)), "debug entries should expose converted perk %s" % str(perk_id))


func _get_non_korean_languages() -> Array[String]:
	return [
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	for choice in choices:
		if choice is Dictionary and str((choice as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect_no_hangul(text: String, context: String) -> void:
	_expect(text.strip_edges() != "", "%s should not be empty" % context)
	if _has_hangul(text):
		_failures.append("%s leaked Korean text: %s" % [context, text])


func _has_hangul(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x1100 and code <= 0x11FF:
			return true
		if code >= 0x3130 and code <= 0x318F:
			return true
		if code >= 0xAC00 and code <= 0xD7AF:
			return true
	return false


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	if bool(_language_settings_snapshot.get("had", false)):
		var file := FileAccess.open(LanguageSettings.SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_language_settings_snapshot.get("bytes", PackedByteArray()))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
