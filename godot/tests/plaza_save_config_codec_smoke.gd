extends SceneTree

const PlazaSaveConfigCodec := preload("res://scripts/plaza/plaza_save_config_codec.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_encode_decode_and_sanitization()
	_verify_legacy_defaults_and_quest_normalization()
	_verify_parse_break_detection()
	_verify_store_boundary_contract()
	if _failures.is_empty():
		print("plaza_save_config_codec_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_encode_decode_and_sanitization() -> void:
	var codec := PlazaSaveConfigCodec.new()
	var config := codec.encode({
		"plaza_gold": -50,
		"chance_gems": 99,
		"decoder_level": 99,
		"ap_current": 99,
		"ap_is_first_stage": false,
		"bank_deposit_gold": 725,
		"tavern_active_quest": {
			"id": " tavern_quest_1 ",
			"name": "Quest One",
			"description": "Clear a stage",
			"accepted_stage": 0,
			"reward_gold": -1,
		},
		"ap_awarded_stages": {"1": true, "2": false, " ": true},
		"bank_interest_claimed_stages": {"3": true},
		"tavern_accepted_stages": {"4": true},
		"tavern_completed_quests": {"quest_a": true},
		"stage_map_seeds": {"5": 913, "6": 0, " ": 17},
	})
	var decoded: Dictionary = codec.decode(config)
	_expect(int(decoded.get("schema_version", 0)) == PlazaSaveConfigCodec.SAVE_SCHEMA_VERSION, "codec should stamp the current schema")
	_expect(int(decoded.get("plaza_gold", -1)) == 0, "codec should clamp negative plaza gold")
	_expect(int(decoded.get("chance_gems", -1)) == PlazaSaveConfigCodec.MAX_CHANCE_GEMS, "codec should clamp chance gems")
	_expect(int(decoded.get("decoder_level", -1)) == PlazaSaveConfigCodec.MAX_DECODER_LEVEL, "codec should clamp decoder level")
	_expect(int(decoded.get("ap_current", -1)) == PlazaSaveConfigCodec.MAX_AP, "codec should clamp AP")
	_expect(not bool(decoded.get("ap_is_first_stage", true)), "codec should preserve the first-stage AP flag")
	_expect(int(decoded.get("bank_deposit_gold", -1)) == 725, "codec should preserve bank gold")
	var quest := _as_dictionary(decoded.get("tavern_active_quest", {}))
	_expect(str(quest.get("id", "")) == "tavern_quest_1", "codec should trim the active quest id when decoding")
	_expect(int(quest.get("accepted_stage", 0)) == 1, "codec should clamp the active quest stage")
	_expect(int(quest.get("reward_gold", -1)) == 0, "codec should clamp active quest reward gold")
	_expect(_as_dictionary(decoded.get("ap_awarded_stages", {})) == {"1": true}, "codec should retain only enabled nonblank AP-stage keys")
	_expect(_as_dictionary(decoded.get("bank_interest_claimed_stages", {})) == {"3": true}, "codec should roundtrip bank-interest stages")
	_expect(_as_dictionary(decoded.get("tavern_accepted_stages", {})) == {"4": true}, "codec should roundtrip tavern accepted stages")
	_expect(_as_dictionary(decoded.get("tavern_completed_quests", {})) == {"quest_a": true}, "codec should roundtrip completed quests")
	_expect(_as_dictionary(decoded.get("stage_map_seeds", {})) == {"5": 913, "6": 1}, "codec should preserve the existing minimum-one map-seed write behavior")


func _verify_legacy_defaults_and_quest_normalization() -> void:
	var codec := PlazaSaveConfigCodec.new()
	var legacy := ConfigFile.new()
	legacy.set_value(PlazaSaveConfigCodec.META_SECTION, PlazaSaveConfigCodec.LEGACY_META_VERSION_KEY, 4)
	legacy.set_value(PlazaSaveConfigCodec.WALLET_SECTION, PlazaSaveConfigCodec.PLAZA_GOLD_KEY, 77)
	var decoded: Dictionary = codec.decode(legacy)
	_expect(int(decoded.get("schema_version", 0)) == 4, "codec should read the legacy meta version key")
	_expect(int(decoded.get("chance_gems", -1)) == PlazaSaveConfigCodec.MAX_CHANCE_GEMS, "missing legacy chance gems should default to full")
	_expect(int(decoded.get("plaza_gold", 0)) == 77, "legacy decode should preserve known wallet values")
	var normalized := codec.normalize_tavern_quest({
		"id": "quest_without_name",
		"name": " ",
		"accepted_stage": -3,
		"reward_gold": -10,
	}, 0)
	_expect(str(normalized.get("name", "")) == "quest_without_name", "blank quest names should fall back to the quest id")
	_expect(int(normalized.get("accepted_stage", 0)) == 1, "quest normalization should clamp accepted stage")
	_expect(int(normalized.get("reward_gold", -1)) == 0, "quest normalization should clamp reward gold")


func _verify_parse_break_detection() -> void:
	_expect(PlazaSaveConfigCodec.has_obvious_config_parse_break("[wallet\nplaza_gold=1\n"), "codec should reject an unterminated ConfigFile section")
	_expect(not PlazaSaveConfigCodec.has_obvious_config_parse_break("[wallet]\nplaza_gold=1\n"), "codec should accept a closed ConfigFile section")


func _verify_store_boundary_contract() -> void:
	var store_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_save_store.gd")
	var codec_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_save_config_codec.gd")
	_expect(store_source.find("var _save_config_codec: PlazaSaveConfigCodec") >= 0, "save store should keep one typed ConfigFile codec")
	_expect(_function_body(store_source, "func _build_save_config(").find("_save_config_codec.encode") >= 0, "save store encode facade should delegate to the codec")
	_expect(_function_body(store_source, "func _read_from_config(").find("_save_config_codec.decode") >= 0, "save store decode facade should delegate to the codec")
	var load_body := _function_body(store_source, "func _load_config_file(")
	_expect(load_body.find("FileAccess.get_file_as_bytes") >= 0, "save store should retain raw-byte loading for BOM recovery")
	_expect(load_body.find("0xEF") >= 0 and load_body.find("config.parse(text)") >= 0, "save store should retain BOM stripping and ConfigFile parsing")
	var recovery_body := _function_body(store_source, "func _try_recover_from_backup(")
	_expect(recovery_body.find("_read_from_config(backup)") >= 0, "save store should retain last-good recovery through the decode facade")
	_expect(codec_source.find("FileAccess") < 0 and codec_source.find("DirAccess") < 0, "ConfigFile codec should stay independent of filesystem I/O")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
