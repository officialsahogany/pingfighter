extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const DEFAULT_BOSS_MAX_HEALTH := 15
const HEALTH_STAGE_MAX_HEALTH := {
	11: DEFAULT_BOSS_MAX_HEALTH,
	16: DEFAULT_BOSS_MAX_HEALTH,
	21: DEFAULT_BOSS_MAX_HEALTH,
}

var _character_runtime: Object = PlayerCharacterRuntime.new()


func build_stage_health_snapshot(current_stage: int) -> Dictionary:
	var max_health: int = get_stage_max_health(current_stage)
	return {
		"boss_max_health": max_health,
		"boss_current_health": max_health if max_health > 0 else 0,
		"boss_health_damage_units": 0,
		"boss_last_damage_source": "",
		"boss_defeated_by_health": false,
	}


func get_stage_max_health(current_stage: int) -> int:
	if HEALTH_STAGE_MAX_HEALTH.has(current_stage):
		return max(0, int(HEALTH_STAGE_MAX_HEALTH[current_stage]))
	return 0


func consume_defeat_score_event(owner: Object, score_callback: Callable) -> bool:
	if not is_defeat_pending(owner):
		return false
	owner.set("boss_defeated_by_health", false)
	if score_callback.is_valid():
		score_callback.call("player")
	return true


func reset_round_health(owner: Object) -> void:
	if owner == null:
		return
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var stage_max_health: int = get_stage_max_health(current_stage)
	var max_health: int = stage_max_health
	if max_health <= 0 and _uses_configured_owner_health(owner):
		max_health = max(0, int(_get_owner_value(owner, "boss_max_health", 0)))
	if max_health <= 0 and not _has_any_health_state(owner):
		return
	_apply_snapshot(owner, {
		"boss_max_health": max_health,
		"boss_current_health": max_health if max_health > 0 else 0,
		"boss_health_damage_units": 0,
		"boss_last_damage_source": "",
		"boss_defeated_by_health": false,
	})


func is_defeat_pending(owner: Object) -> bool:
	if owner == null:
		return false
	if not bool(_get_owner_value(owner, "boss_defeated_by_health", false)):
		return false
	var max_health: int = max(0, int(_get_owner_value(owner, "boss_max_health", 0)))
	var current_health: int = int(_get_owner_value(owner, "boss_current_health", max_health))
	return max_health > 0 and current_health <= 0


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _has_any_health_state(owner: Object) -> bool:
	for key in ["boss_max_health", "boss_current_health", "boss_health_damage_units", "boss_defeated_by_health"]:
		if owner.get(key) != null:
			return true
	return false


func _uses_configured_owner_health(owner: Object) -> bool:
	return _character_runtime.is_commando(_get_owner_value(owner, "selected_character_type", ""))


func _apply_snapshot(owner: Object, snapshot: Dictionary) -> void:
	for key in snapshot.keys():
		owner.set(str(key), snapshot[key])
