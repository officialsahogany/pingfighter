extends RefCounted

const INCOME_LOG_ENV := "PINGFIGHTER_LINGPET_AFFINITY_INCOME_LOG"
const INCOME_LOG_FLAG_PATH := "res://lingpet_affinity_income_log.flag"

var battle_total := 0.0
var battle_level_ups := 0
var battle_by_source: Dictionary = {}
var battle_by_pet: Dictionary = {}
var _log_enabled_checked := false
var _log_enabled := false


func reset_battle() -> void:
	battle_total = 0.0
	battle_level_ups = 0
	battle_by_source.clear()
	battle_by_pet.clear()


func reset_all() -> void:
	reset_battle()
	_log_enabled_checked = false
	_log_enabled = false


func record(pet_id: String, source: String, result: Dictionary, registry: Object = null) -> void:
	var granted_points := float(result.get("granted_points", 0.0))
	var levels_gained := int(result.get("levels_gained", 0))
	if granted_points <= 0.0 and levels_gained <= 0:
		return
	if granted_points > 0.0:
		battle_total += granted_points
		battle_by_source[source] = float(battle_by_source.get(source, 0.0)) + granted_points
		battle_by_pet[pet_id] = float(battle_by_pet.get(pet_id, 0.0)) + granted_points
	if levels_gained > 0:
		battle_level_ups += levels_gained
	var perf_logger := _get_perf_logger(registry)
	if perf_logger != null and perf_logger.has_method("record_counter_sample"):
		if granted_points > 0.0:
			perf_logger.record_counter_sample("lingpet.affinity.income.%s" % source, granted_points)
			perf_logger.record_counter_sample("lingpet.affinity.income.total", granted_points)
		if levels_gained > 0:
			perf_logger.record_counter_sample("lingpet.affinity.level_ups", float(levels_gained))


func flush_battle_log(reason: String = "battle_reset") -> void:
	if battle_total > 0.0 and _is_log_enabled():
		print("[LingpetAffinity-Income] reason=%s total=%.1f level_ups=%d by_source=%s by_pet=%s" % [
			reason,
			battle_total,
			battle_level_ups,
			str(battle_by_source),
			str(battle_by_pet),
		])
	reset_battle()


func get_summary() -> Dictionary:
	return {
		"total": battle_total,
		"level_ups": battle_level_ups,
		"by_source": battle_by_source.duplicate(true),
		"by_pet": battle_by_pet.duplicate(true),
	}


func _get_perf_logger(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Object = registry.get_instance("battle_perf_logger")
	return value


func _is_log_enabled() -> bool:
	if _log_enabled_checked:
		return _log_enabled
	_log_enabled_checked = true
	var env_value := OS.get_environment(INCOME_LOG_ENV).strip_edges().to_lower()
	_log_enabled = env_value in ["1", "true", "yes", "on"] or FileAccess.file_exists(INCOME_LOG_FLAG_PATH)
	return _log_enabled
