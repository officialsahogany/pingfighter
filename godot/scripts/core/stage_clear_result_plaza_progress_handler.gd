extends RefCounted

var _gold_transfer_consumed: bool = false
var _ap_grant_consumed: bool = false
var _last_progress_summary: Dictionary = {}


func reset() -> void:
	_gold_transfer_consumed = false
	_ap_grant_consumed = false
	_last_progress_summary = {}


func get_cached_summary() -> Dictionary:
	return _last_progress_summary.duplicate(true) if not _last_progress_summary.is_empty() else {}


func apply_stage_clear_progress_once(
	owner: Object,
	plaza_save_store: Object,
	current_stage: int,
	grant_ap: bool
) -> Dictionary:
	if not _owner_has_runtime_perk_gold(owner):
		_last_progress_summary = {
			"transferred_gold": 0,
			"granted_ap": 0,
			"save": "skipped_missing_runtime_perk_gold_owner",
		}
		return _last_progress_summary.duplicate(true)
	if plaza_save_store == null or not plaza_save_store.has_method("apply_stage_clear_progress"):
		_last_progress_summary = {
			"transferred_gold": 0,
			"granted_ap": 0,
			"save": "missing_plaza_save_store",
		}
		return _last_progress_summary.duplicate(true)

	var gold_amount := 0
	if not _gold_transfer_consumed:
		gold_amount = _get_owner_runtime_perk_gold(owner)
		_gold_transfer_consumed = true
		_set_owner_runtime_perk_gold(owner, 0)
	var should_grant_ap := grant_ap and not _ap_grant_consumed
	if should_grant_ap:
		_ap_grant_consumed = true

	var summary_value: Variant = plaza_save_store.apply_stage_clear_progress(max(1, current_stage), gold_amount, should_grant_ap)
	if summary_value is Dictionary:
		_last_progress_summary = (summary_value as Dictionary).duplicate(true)
	else:
		_last_progress_summary = {
			"transferred_gold": gold_amount,
			"granted_ap": 1 if should_grant_ap else 0,
			"save": "missing_plaza_progress_summary",
		}
	return _last_progress_summary.duplicate(true)


func apply_stage_clear_progress_from_callback(
	grant_ap: bool,
	owner: Object,
	plaza_save_store: Object,
	current_stage: int
) -> Dictionary:
	return apply_stage_clear_progress_once(owner, plaza_save_store, current_stage, grant_ap)


static func get_plaza_save_path(plaza_save_store: Object) -> String:
	if plaza_save_store == null or not plaza_save_store.has_method("get_summary"):
		return ""
	var summary_value: Variant = plaza_save_store.get_summary()
	if not (summary_value is Dictionary):
		return ""
	return str((summary_value as Dictionary).get("save_path", ""))


func _get_owner_runtime_perk_gold(owner: Object) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("runtime_perk_gold")
	if value == null:
		return 0
	return maxi(0, int(value))


func _set_owner_runtime_perk_gold(owner: Object, value: int) -> void:
	if not _owner_has_runtime_perk_gold(owner):
		return
	owner.set("runtime_perk_gold", maxi(0, value))


func _owner_has_runtime_perk_gold(owner: Object) -> bool:
	return owner != null and owner.get("runtime_perk_gold") != null
