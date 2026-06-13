extends RefCounted

const SAVE_PATH := "user://plaza_save.cfg"
const SAVE_SCHEMA_VERSION := 2
const BASE_AP := 3
const MAX_AP := 10
const BANK_TRANSACTION_AMOUNT := 100
const BANK_INTEREST_BPS := 500
const META_SECTION := "meta"
const META_SCHEMA_VERSION_KEY := "schema_version"
const LEGACY_META_VERSION_KEY := "version"
const WALLET_SECTION := "wallet"
const BANK_SECTION := "bank"
const AP_AWARDED_STAGES_SECTION := "ap_awarded_stages"
const BANK_INTEREST_CLAIMED_STAGES_SECTION := "bank_interest_claimed_stages"
const PLAZA_GOLD_KEY := "plaza_gold"
const AP_CURRENT_KEY := "ap_current"
const AP_IS_FIRST_STAGE_KEY := "ap_is_first_stage"
const BANK_DEPOSIT_GOLD_KEY := "bank_deposit_gold"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _loaded := false
var _schema_version := SAVE_SCHEMA_VERSION
var _recovery_blocked := false
var _plaza_gold := 0
var _ap_current := BASE_AP
var _ap_is_first_stage := true
var _bank_deposit_gold := 0
var _ap_awarded_stages: Dictionary = {}
var _bank_interest_claimed_stages: Dictionary = {}
var _last_load_stripped_bom := false


func set_save_path(path: String) -> void:
	if path.strip_edges() == "":
		return
	save_path = path
	_reset_runtime_state()


func get_backup_path() -> String:
	return save_path.trim_suffix(".cfg") + ".last_good.cfg"


func load() -> bool:
	_reset_runtime_state()
	_loaded = true
	if not FileAccess.file_exists(save_path):
		last_load_summary = "missing"
		return true
	var config := ConfigFile.new()
	_last_load_stripped_bom = false
	var result := _load_config_file(config, save_path)
	if result != OK:
		if _try_recover_from_backup():
			return true
		_recovery_blocked = true
		last_load_summary = "load_error_%d" % result
		return false
	_read_from_config(config)
	var stored_version := _schema_version
	var stripped_bom := _last_load_stripped_bom
	last_load_summary = "migrated_v%d" % stored_version if stored_version < SAVE_SCHEMA_VERSION else "ok"
	_schema_version = SAVE_SCHEMA_VERSION
	if stripped_bom or stored_version < SAVE_SCHEMA_VERSION:
		save()
	else:
		_build_save_config().save(get_backup_path())
	return true


func save() -> bool:
	_ensure_loaded()
	var config := _build_save_config()
	var result: int = config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	if result == OK and not _recovery_blocked:
		config.save(get_backup_path())
	return result == OK


func clear() -> bool:
	_reset_runtime_state()
	_loaded = true
	var backup_path := get_backup_path()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	if not FileAccess.file_exists(save_path):
		last_save_summary = "cleared"
		return true
	var result: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = "cleared" if result == OK else "clear_error_%d" % result
	return result == OK


func get_plaza_gold() -> int:
	_ensure_loaded()
	return _plaza_gold


func get_ap_current() -> int:
	_ensure_loaded()
	return _ap_current


func get_ap_is_first_stage() -> bool:
	_ensure_loaded()
	return _ap_is_first_stage


func get_bank_deposit_gold() -> int:
	_ensure_loaded()
	return _bank_deposit_gold


func add_plaza_gold(amount: int) -> Dictionary:
	_ensure_loaded()
	var safe_amount := maxi(0, amount)
	if safe_amount <= 0:
		last_save_summary = "skipped_non_positive_gold"
		return _build_apply_summary(0, 0, false, "skipped_non_positive_gold")
	_plaza_gold = _sanitize_gold(_plaza_gold + safe_amount)
	save()
	return _build_apply_summary(safe_amount, 0, false, last_save_summary)


func grant_stage_clear_ap(stage_id: int) -> Dictionary:
	_ensure_loaded()
	var normalized_stage := maxi(1, stage_id)
	var stage_key := str(normalized_stage)
	if bool(_ap_awarded_stages.get(stage_key, false)):
		last_save_summary = "skipped_ap_stage_already_awarded"
		return _build_apply_summary(0, 0, false, last_save_summary)
	var granted_ap := 0
	if _ap_current < MAX_AP:
		_ap_current = clampi(_ap_current + 1, 0, MAX_AP)
		granted_ap = 1
	_ap_is_first_stage = false
	_ap_awarded_stages[stage_key] = true
	save()
	return _build_apply_summary(0, granted_ap, true, last_save_summary)


func apply_stage_clear_progress(stage_id: int, gold_amount: int, grant_ap: bool) -> Dictionary:
	_ensure_loaded()
	var transferred_gold := 0
	var granted_ap := 0
	var ap_recorded := false
	var safe_gold := maxi(0, gold_amount)
	if safe_gold > 0:
		_plaza_gold = _sanitize_gold(_plaza_gold + safe_gold)
		transferred_gold = safe_gold
	if grant_ap:
		var normalized_stage := maxi(1, stage_id)
		var stage_key := str(normalized_stage)
		if not bool(_ap_awarded_stages.get(stage_key, false)):
			if _ap_current < MAX_AP:
				_ap_current = clampi(_ap_current + 1, 0, MAX_AP)
				granted_ap = 1
			_ap_is_first_stage = false
			_ap_awarded_stages[stage_key] = true
			ap_recorded = true
	if transferred_gold > 0 or ap_recorded:
		save()
	else:
		last_save_summary = "skipped_no_progress_delta"
	return _build_apply_summary(transferred_gold, granted_ap, ap_recorded, last_save_summary)


func perform_bank_transaction(action_id: String, stage_id: int, amount: int = BANK_TRANSACTION_AMOUNT, consume_ap: bool = true) -> Dictionary:
	_ensure_loaded()
	var normalized_action := action_id.strip_edges().to_lower()
	var requested_amount := maxi(1, amount)
	var normalized_stage := maxi(1, stage_id)
	var delta_gold := 0
	var delta_deposit := 0
	var interest_gold := 0
	var reason := ""

	match normalized_action:
		"deposit":
			delta_gold = -mini(requested_amount, _plaza_gold)
			delta_deposit = -delta_gold
			if delta_deposit <= 0:
				reason = "no_plaza_gold"
		"withdraw":
			delta_deposit = -mini(requested_amount, _bank_deposit_gold)
			delta_gold = -delta_deposit
			if delta_gold <= 0:
				reason = "no_bank_deposit"
		"interest":
			var stage_key := str(normalized_stage)
			if bool(_bank_interest_claimed_stages.get(stage_key, false)):
				reason = "interest_already_claimed"
			elif _bank_deposit_gold <= 0:
				reason = "no_bank_deposit"
			else:
				interest_gold = maxi(1, int(floor(float(_bank_deposit_gold) * float(BANK_INTEREST_BPS) / 10000.0)))
				delta_gold = interest_gold
		_:
			reason = "unknown_bank_action"

	if reason != "":
		last_save_summary = "skipped_%s" % reason
		return _build_bank_summary(normalized_action, 0, 0, interest_gold, false, reason)

	if consume_ap and _ap_current <= 0:
		last_save_summary = "skipped_no_ap"
		return _build_bank_summary(normalized_action, 0, 0, interest_gold, false, "no_ap")

	var ap_spent := 0
	if consume_ap:
		_ap_current = maxi(0, _ap_current - 1)
		ap_spent = 1
	_plaza_gold = _sanitize_gold(_plaza_gold + delta_gold)
	_bank_deposit_gold = _sanitize_gold(_bank_deposit_gold + delta_deposit)
	if normalized_action == "interest":
		_bank_interest_claimed_stages[str(normalized_stage)] = true
	save()
	return _build_bank_summary(normalized_action, delta_gold, delta_deposit, interest_gold, true, "ok", ap_spent)


func perform_shop_wallet_transaction(action_id: String, gold_amount: int, consume_ap: bool = true) -> Dictionary:
	_ensure_loaded()
	var normalized_action := action_id.strip_edges().to_lower()
	var safe_amount := maxi(1, gold_amount)
	var delta_gold := 0
	var reason := ""

	match normalized_action:
		"purchase":
			if _plaza_gold < safe_amount:
				reason = "not_enough_gold"
			else:
				delta_gold = -safe_amount
		"sale":
			delta_gold = safe_amount
		_:
			reason = "unknown_shop_action"

	if reason != "":
		last_save_summary = "skipped_%s" % reason
		return _build_shop_summary(normalized_action, 0, false, reason)

	if consume_ap and _ap_current <= 0:
		last_save_summary = "skipped_no_ap"
		return _build_shop_summary(normalized_action, 0, false, "no_ap")

	var ap_spent := 0
	if consume_ap:
		_ap_current = maxi(0, _ap_current - 1)
		ap_spent = 1
	_plaza_gold = _sanitize_gold(_plaza_gold + delta_gold)
	save()
	return _build_shop_summary(normalized_action, delta_gold, true, "ok", ap_spent)


func perform_gacha_pull_payment(cost: int, consume_ap: bool = true) -> Dictionary:
	_ensure_loaded()
	var safe_cost := maxi(1, cost)
	if _plaza_gold < safe_cost:
		last_save_summary = "skipped_not_enough_gold"
		return _build_gacha_summary(-safe_cost, false, "not_enough_gold")
	if consume_ap and _ap_current <= 0:
		last_save_summary = "skipped_no_ap"
		return _build_gacha_summary(-safe_cost, false, "no_ap")

	var ap_spent := 0
	if consume_ap:
		_ap_current = maxi(0, _ap_current - 1)
		ap_spent = 1
	_plaza_gold = _sanitize_gold(_plaza_gold - safe_cost)
	save()
	return _build_gacha_summary(-safe_cost, true, "ok", ap_spent)


func perform_lingpet_egg_payment(cost: int, consume_ap: bool = true) -> Dictionary:
	_ensure_loaded()
	var safe_cost := maxi(1, cost)
	if _plaza_gold < safe_cost:
		last_save_summary = "skipped_not_enough_gold"
		return _build_lingpet_store_summary(-safe_cost, false, "not_enough_gold")
	if consume_ap and _ap_current <= 0:
		last_save_summary = "skipped_no_ap"
		return _build_lingpet_store_summary(-safe_cost, false, "no_ap")

	var ap_spent := 0
	if consume_ap:
		_ap_current = maxi(0, _ap_current - 1)
		ap_spent = 1
	_plaza_gold = _sanitize_gold(_plaza_gold - safe_cost)
	save()
	return _build_lingpet_store_summary(-safe_cost, true, "ok", ap_spent)


func perform_blacksmith_enhancement_payment(cost: int, consume_ap: bool = true) -> Dictionary:
	_ensure_loaded()
	var safe_cost := maxi(1, cost)
	if _plaza_gold < safe_cost:
		last_save_summary = "skipped_not_enough_gold"
		return _build_blacksmith_summary(-safe_cost, false, "not_enough_gold")
	if consume_ap and _ap_current <= 0:
		last_save_summary = "skipped_no_ap"
		return _build_blacksmith_summary(-safe_cost, false, "no_ap")

	var ap_spent := 0
	if consume_ap:
		_ap_current = maxi(0, _ap_current - 1)
		ap_spent = 1
	_plaza_gold = _sanitize_gold(_plaza_gold - safe_cost)
	save()
	return _build_blacksmith_summary(-safe_cost, true, "ok", ap_spent)


func get_summary() -> Dictionary:
	return {
		"save_path": save_path,
		"backup_path": get_backup_path(),
		"load": last_load_summary,
		"save": last_save_summary,
		"schema_version": get_schema_version(),
		"plaza_gold": get_plaza_gold(),
		"ap_current": get_ap_current(),
		"ap_is_first_stage": get_ap_is_first_stage(),
		"bank_deposit_gold": get_bank_deposit_gold(),
		"ap_awarded_stages": _get_ap_awarded_stages(),
		"bank_interest_claimed_stages": _get_bank_interest_claimed_stages(),
	}


func get_schema_version() -> int:
	_ensure_loaded()
	return _schema_version


func _ensure_loaded() -> void:
	if _loaded:
		return
	self.load()


func _reset_runtime_state() -> void:
	last_load_summary = "not_loaded"
	last_save_summary = "not_saved"
	_loaded = false
	_schema_version = SAVE_SCHEMA_VERSION
	_recovery_blocked = false
	_plaza_gold = 0
	_ap_current = BASE_AP
	_ap_is_first_stage = true
	_bank_deposit_gold = 0
	_last_load_stripped_bom = false
	_ap_awarded_stages.clear()
	_bank_interest_claimed_stages.clear()


func _try_recover_from_backup() -> bool:
	if not FileAccess.file_exists(get_backup_path()):
		return false
	var backup := ConfigFile.new()
	if _load_config_file(backup, get_backup_path()) != OK:
		return false
	_read_from_config(backup)
	last_load_summary = "recovered_last_good"
	save()
	return true


func _load_config_file(config: ConfigFile, path: String) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		bytes = bytes.slice(3)
		_last_load_stripped_bom = true
	var text := bytes.get_string_from_utf8()
	if _has_obvious_config_parse_break(text):
		return ERR_PARSE_ERROR
	return config.parse(text)


func _build_save_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value(META_SECTION, META_SCHEMA_VERSION_KEY, SAVE_SCHEMA_VERSION)
	config.set_value(WALLET_SECTION, PLAZA_GOLD_KEY, _sanitize_gold(_plaza_gold))
	config.set_value(WALLET_SECTION, AP_CURRENT_KEY, clampi(_ap_current, 0, MAX_AP))
	config.set_value(WALLET_SECTION, AP_IS_FIRST_STAGE_KEY, _ap_is_first_stage)
	config.set_value(BANK_SECTION, BANK_DEPOSIT_GOLD_KEY, _sanitize_gold(_bank_deposit_gold))
	for raw_stage in _ap_awarded_stages.keys():
		var stage_key := str(raw_stage).strip_edges()
		if stage_key != "" and bool(_ap_awarded_stages.get(raw_stage, false)):
			config.set_value(AP_AWARDED_STAGES_SECTION, stage_key, true)
	for raw_stage in _bank_interest_claimed_stages.keys():
		var stage_key := str(raw_stage).strip_edges()
		if stage_key != "" and bool(_bank_interest_claimed_stages.get(raw_stage, false)):
			config.set_value(BANK_INTEREST_CLAIMED_STAGES_SECTION, stage_key, true)
	return config


func _read_from_config(config: ConfigFile) -> void:
	_schema_version = _read_schema_version(config)
	_plaza_gold = _sanitize_gold(config.get_value(WALLET_SECTION, PLAZA_GOLD_KEY, 0))
	_ap_current = clampi(int(config.get_value(WALLET_SECTION, AP_CURRENT_KEY, BASE_AP)), 0, MAX_AP)
	_ap_is_first_stage = bool(config.get_value(WALLET_SECTION, AP_IS_FIRST_STAGE_KEY, true))
	_bank_deposit_gold = _sanitize_gold(config.get_value(BANK_SECTION, BANK_DEPOSIT_GOLD_KEY, 0))
	_ap_awarded_stages.clear()
	_bank_interest_claimed_stages.clear()
	_load_bool_section(config, AP_AWARDED_STAGES_SECTION, _ap_awarded_stages)
	_load_bool_section(config, BANK_INTEREST_CLAIMED_STAGES_SECTION, _bank_interest_claimed_stages)


func _load_bool_section(config: ConfigFile, section: String, target: Dictionary) -> void:
	if not config.has_section(section):
		return
	for raw_key in config.get_section_keys(section):
		var stage_key := str(raw_key).strip_edges()
		if stage_key == "":
			continue
		if bool(config.get_value(section, raw_key, false)):
			target[stage_key] = true


func _read_schema_version(config: ConfigFile) -> int:
	var raw_version: Variant = config.get_value(
		META_SECTION,
		META_SCHEMA_VERSION_KEY,
		config.get_value(META_SECTION, LEGACY_META_VERSION_KEY, 1)
	)
	return maxi(1, int(raw_version))


func _sanitize_gold(value: Variant) -> int:
	return maxi(0, int(value))


func _has_obvious_config_parse_break(text: String) -> bool:
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("[") and line.find("]") < 0:
			return true
	return false


func _get_ap_awarded_stages() -> Dictionary:
	_ensure_loaded()
	return _ap_awarded_stages.duplicate(true)


func _get_bank_interest_claimed_stages() -> Dictionary:
	_ensure_loaded()
	return _bank_interest_claimed_stages.duplicate(true)


func _build_apply_summary(transferred_gold: int, granted_ap: int, ap_recorded: bool, save_summary: String) -> Dictionary:
	return {
		"save_path": save_path,
		"transferred_gold": transferred_gold,
		"granted_ap": granted_ap,
		"ap_recorded": ap_recorded,
		"plaza_gold": _plaza_gold,
		"ap_current": _ap_current,
		"ap_is_first_stage": _ap_is_first_stage,
		"bank_deposit_gold": _bank_deposit_gold,
		"save": save_summary,
		"load": last_load_summary,
	}


func _build_bank_summary(
	action_id: String,
	delta_gold: int,
	delta_deposit: int,
	interest_gold: int,
	changed: bool,
	reason: String,
	ap_spent: int = 0
) -> Dictionary:
	return {
		"save_path": save_path,
		"action": action_id,
		"handled": ["deposit", "withdraw", "interest"].has(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"delta_deposit": delta_deposit,
		"interest_gold": interest_gold,
		"ap_spent": ap_spent,
		"plaza_gold": _plaza_gold,
		"bank_deposit_gold": _bank_deposit_gold,
		"ap_current": _ap_current,
		"save": last_save_summary,
		"load": last_load_summary,
	}


func _build_shop_summary(
	action_id: String,
	delta_gold: int,
	changed: bool,
	reason: String,
	ap_spent: int = 0
) -> Dictionary:
	return {
		"save_path": save_path,
		"action": action_id,
		"handled": ["purchase", "sale"].has(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"ap_spent": ap_spent,
		"plaza_gold": _plaza_gold,
		"ap_current": _ap_current,
		"save": last_save_summary,
		"load": last_load_summary,
	}


func _build_gacha_summary(
	delta_gold: int,
	changed: bool,
	reason: String,
	ap_spent: int = 0
) -> Dictionary:
	return {
		"save_path": save_path,
		"action": "pull",
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold if changed else 0,
		"ap_spent": ap_spent,
		"plaza_gold": _plaza_gold,
		"ap_current": _ap_current,
		"save": last_save_summary,
		"load": last_load_summary,
	}


func _build_lingpet_store_summary(
	delta_gold: int,
	changed: bool,
	reason: String,
	ap_spent: int = 0
) -> Dictionary:
	return {
		"save_path": save_path,
		"action": "buy_egg",
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold if changed else 0,
		"ap_spent": ap_spent,
		"plaza_gold": _plaza_gold,
		"ap_current": _ap_current,
		"save": last_save_summary,
		"load": last_load_summary,
	}


func _build_blacksmith_summary(
	delta_gold: int,
	changed: bool,
	reason: String,
	ap_spent: int = 0
) -> Dictionary:
	return {
		"save_path": save_path,
		"action": "enhance",
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold if changed else 0,
		"ap_spent": ap_spent,
		"plaza_gold": _plaza_gold,
		"ap_current": _ap_current,
		"save": last_save_summary,
		"load": last_load_summary,
	}
