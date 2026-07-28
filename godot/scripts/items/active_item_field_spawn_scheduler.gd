extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const SPAWN_DELAY_MIN_MSEC := 20000
const SPAWN_DELAY_MAX_MSEC := 50000

var last_item_spawn_msec: int = 0
var next_item_spawn_delay_msec: int = 0


func reset() -> void:
	reset_spawn_timer()


func reset_spawn_timer() -> void:
	last_item_spawn_msec = Time.get_ticks_msec()
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()


func mark_spawn_now() -> void:
	last_item_spawn_msec = Time.get_ticks_msec()
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()


func consume_regular_spawn_due(
	owner: Object,
	registry: Object,
	has_spawned_items: bool,
	has_pending_spawn_or_portals: bool
) -> bool:
	if is_item_spawn_blocked(owner):
		reset_spawn_timer()
		return false
	if has_spawned_items:
		return false
	if has_pending_spawn_or_portals:
		return false

	var now_msec: int = Time.get_ticks_msec()
	if last_item_spawn_msec <= 0:
		last_item_spawn_msec = now_msec
		return false
	if now_msec - last_item_spawn_msec < _get_effective_spawn_delay_msec(next_item_spawn_delay_msec, registry):
		return false

	last_item_spawn_msec = now_msec
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()
	return true


func is_item_spawn_blocked(owner: Object) -> bool:
	if int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1)) == 50:
		return true
	if bool(BattleSceneOwnerReader.get_value(owner, "arena_mode_enabled", false)):
		return true
	if bool(BattleSceneOwnerReader.get_value(owner, "victory_loot_phase_active", false)):
		# 승리 전리품 페이즈 중에는 새 필드 아이템 스폰을 막는다(상자 픽업과 경합 방지).
		return true
	return false


func _get_effective_spawn_delay_msec(base_delay_msec: int, registry: Object) -> int:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_item_spawn_delay_msec"):
		return int(runtime_perk_state.get_item_spawn_delay_msec(base_delay_msec))
	return max(1, base_delay_msec)


func _roll_spawn_delay_msec() -> int:
	return randi_range(SPAWN_DELAY_MIN_MSEC, SPAWN_DELAY_MAX_MSEC)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
