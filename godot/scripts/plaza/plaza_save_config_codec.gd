extends RefCounted

const SAVE_SCHEMA_VERSION := 6
const BASE_AP := 3
const MAX_AP := 10
const MAX_CHANCE_GEMS := 3
const MAX_DECODER_LEVEL := 5

const META_SECTION := "meta"
const META_SCHEMA_VERSION_KEY := "schema_version"
const LEGACY_META_VERSION_KEY := "version"
const WALLET_SECTION := "wallet"
const BANK_SECTION := "bank"
const PROGRESSION_SECTION := "progression"
const TAVERN_SECTION := "tavern"
const AP_AWARDED_STAGES_SECTION := "ap_awarded_stages"
const BANK_INTEREST_CLAIMED_STAGES_SECTION := "bank_interest_claimed_stages"
const TAVERN_ACCEPTED_STAGES_SECTION := "tavern_accepted_stages"
const TAVERN_COMPLETED_QUESTS_SECTION := "tavern_completed_quests"
const STAGE_MAP_SEEDS_SECTION := "stage_map_seeds"
const PLAZA_GOLD_KEY := "plaza_gold"
const AP_CURRENT_KEY := "ap_current"
const AP_IS_FIRST_STAGE_KEY := "ap_is_first_stage"
const CHANCE_GEMS_KEY := "chance_gems"
const DECODER_LEVEL_KEY := "decoder_level"
const BANK_DEPOSIT_GOLD_KEY := "bank_deposit_gold"
const TAVERN_ACTIVE_QUEST_ID_KEY := "active_quest_id"
const TAVERN_ACTIVE_QUEST_NAME_KEY := "active_quest_name"
const TAVERN_ACTIVE_QUEST_DESCRIPTION_KEY := "active_quest_description"
const TAVERN_ACTIVE_QUEST_STAGE_KEY := "active_quest_stage"
const TAVERN_ACTIVE_QUEST_REWARD_GOLD_KEY := "active_quest_reward_gold"


func encode(snapshot: Dictionary) -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value(META_SECTION, META_SCHEMA_VERSION_KEY, SAVE_SCHEMA_VERSION)
	config.set_value(WALLET_SECTION, PLAZA_GOLD_KEY, sanitize_gold(snapshot.get("plaza_gold", 0)))
	config.set_value(WALLET_SECTION, CHANCE_GEMS_KEY, sanitize_chance_gems(snapshot.get("chance_gems", MAX_CHANCE_GEMS)))
	config.set_value(WALLET_SECTION, AP_CURRENT_KEY, clampi(int(snapshot.get("ap_current", BASE_AP)), 0, MAX_AP))
	config.set_value(WALLET_SECTION, AP_IS_FIRST_STAGE_KEY, bool(snapshot.get("ap_is_first_stage", true)))
	config.set_value(PROGRESSION_SECTION, DECODER_LEVEL_KEY, sanitize_decoder_level(snapshot.get("decoder_level", 0)))
	config.set_value(BANK_SECTION, BANK_DEPOSIT_GOLD_KEY, sanitize_gold(snapshot.get("bank_deposit_gold", 0)))
	var active_quest := _as_dictionary(snapshot.get("tavern_active_quest", {}))
	if not active_quest.is_empty():
		config.set_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_ID_KEY, str(active_quest.get("id", "")))
		config.set_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_NAME_KEY, str(active_quest.get("name", "")))
		config.set_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_DESCRIPTION_KEY, str(active_quest.get("description", "")))
		config.set_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_STAGE_KEY, maxi(1, int(active_quest.get("accepted_stage", 1))))
		config.set_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_REWARD_GOLD_KEY, sanitize_gold(active_quest.get("reward_gold", 0)))
	_write_bool_section(config, AP_AWARDED_STAGES_SECTION, _as_dictionary(snapshot.get("ap_awarded_stages", {})))
	_write_bool_section(config, BANK_INTEREST_CLAIMED_STAGES_SECTION, _as_dictionary(snapshot.get("bank_interest_claimed_stages", {})))
	_write_bool_section(config, TAVERN_ACCEPTED_STAGES_SECTION, _as_dictionary(snapshot.get("tavern_accepted_stages", {})))
	_write_bool_section(config, TAVERN_COMPLETED_QUESTS_SECTION, _as_dictionary(snapshot.get("tavern_completed_quests", {})))
	_write_int_section(config, STAGE_MAP_SEEDS_SECTION, _as_dictionary(snapshot.get("stage_map_seeds", {})))
	return config


func decode(config: ConfigFile) -> Dictionary:
	return {
		"schema_version": read_schema_version(config),
		"plaza_gold": sanitize_gold(config.get_value(WALLET_SECTION, PLAZA_GOLD_KEY, 0)),
		"chance_gems": sanitize_chance_gems(config.get_value(WALLET_SECTION, CHANCE_GEMS_KEY, MAX_CHANCE_GEMS)),
		"decoder_level": sanitize_decoder_level(config.get_value(PROGRESSION_SECTION, DECODER_LEVEL_KEY, 0)),
		"ap_current": clampi(int(config.get_value(WALLET_SECTION, AP_CURRENT_KEY, BASE_AP)), 0, MAX_AP),
		"ap_is_first_stage": bool(config.get_value(WALLET_SECTION, AP_IS_FIRST_STAGE_KEY, true)),
		"bank_deposit_gold": sanitize_gold(config.get_value(BANK_SECTION, BANK_DEPOSIT_GOLD_KEY, 0)),
		"tavern_active_quest": read_tavern_active_quest(config),
		"ap_awarded_stages": load_bool_section(config, AP_AWARDED_STAGES_SECTION),
		"bank_interest_claimed_stages": load_bool_section(config, BANK_INTEREST_CLAIMED_STAGES_SECTION),
		"tavern_accepted_stages": load_bool_section(config, TAVERN_ACCEPTED_STAGES_SECTION),
		"tavern_completed_quests": load_bool_section(config, TAVERN_COMPLETED_QUESTS_SECTION),
		"stage_map_seeds": load_int_section(config, STAGE_MAP_SEEDS_SECTION),
	}


func read_tavern_active_quest(config: ConfigFile) -> Dictionary:
	if not config.has_section(TAVERN_SECTION):
		return {}
	var quest_id := str(config.get_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_ID_KEY, "")).strip_edges()
	if quest_id.is_empty():
		return {}
	var accepted_stage := int(config.get_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_STAGE_KEY, 1))
	return normalize_tavern_quest({
		"id": quest_id,
		"name": str(config.get_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_NAME_KEY, "")),
		"description": str(config.get_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_DESCRIPTION_KEY, "")),
		"accepted_stage": accepted_stage,
		"reward_gold": int(config.get_value(TAVERN_SECTION, TAVERN_ACTIVE_QUEST_REWARD_GOLD_KEY, 0)),
	}, accepted_stage)


func normalize_tavern_quest(quest: Dictionary, stage_id: int) -> Dictionary:
	var normalized_stage := maxi(1, stage_id)
	var quest_id := str(quest.get("id", "")).strip_edges()
	var quest_name := str(quest.get("name", "")).strip_edges()
	if quest_name.is_empty():
		quest_name = quest_id
	return {
		"id": quest_id,
		"name": quest_name,
		"description": str(quest.get("description", "")),
		"accepted_stage": maxi(1, int(quest.get("accepted_stage", normalized_stage))),
		"reward_gold": sanitize_gold(quest.get("reward_gold", 0)),
	}


func load_bool_section(config: ConfigFile, section: String) -> Dictionary:
	var values := {}
	if not config.has_section(section):
		return values
	for raw_key in config.get_section_keys(section):
		var key := str(raw_key).strip_edges()
		if not key.is_empty() and bool(config.get_value(section, raw_key, false)):
			values[key] = true
	return values


func load_int_section(config: ConfigFile, section: String) -> Dictionary:
	var values := {}
	if not config.has_section(section):
		return values
	for raw_key in config.get_section_keys(section):
		var key := str(raw_key).strip_edges()
		var value := maxi(0, int(config.get_value(section, raw_key, 0)))
		if not key.is_empty() and value > 0:
			values[key] = value
	return values


func read_schema_version(config: ConfigFile) -> int:
	var raw_version: Variant = config.get_value(
		META_SECTION,
		META_SCHEMA_VERSION_KEY,
		config.get_value(META_SECTION, LEGACY_META_VERSION_KEY, 1)
	)
	return maxi(1, int(raw_version))


static func sanitize_gold(value: Variant) -> int:
	return maxi(0, int(value))


static func sanitize_chance_gems(value: Variant) -> int:
	return clampi(int(value), 0, MAX_CHANCE_GEMS)


static func sanitize_decoder_level(value: Variant) -> int:
	return clampi(int(value), 0, MAX_DECODER_LEVEL)


static func has_obvious_config_parse_break(text: String) -> bool:
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("[") and line.find("]") < 0:
			return true
	return false


func _write_bool_section(config: ConfigFile, section: String, values: Dictionary) -> void:
	for raw_key in values.keys():
		var key := str(raw_key).strip_edges()
		if not key.is_empty() and bool(values.get(raw_key, false)):
			config.set_value(section, key, true)


func _write_int_section(config: ConfigFile, section: String, values: Dictionary) -> void:
	for raw_key in values.keys():
		var key := str(raw_key).strip_edges()
		var value := maxi(1, int(values.get(raw_key, 0)))
		if not key.is_empty() and value > 0:
			config.set_value(section, key, value)


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
