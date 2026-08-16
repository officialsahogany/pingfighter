extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const SPAWN_DELAY_MIN_MSEC := 20000
const SPAWN_DELAY_MAX_MSEC := 50000

var last_item_spawn_msec: int = 0
var next_item_spawn_delay_msec: int = 0
var regular_spawn_budget: int = -1
var regular_spawns_consumed: int = 0
var regular_spawn_budget_generation: int = 0


func _init() -> void:
	reset()


func reset() -> void:
	_reset_regular_spawn_budget()
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
	if _is_regular_spawn_budget_exhausted():
		return false
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
	if regular_spawn_budget >= 0:
		regular_spawns_consumed += 1
	return true


func get_regular_spawn_budget_state() -> Dictionary:
	return {
		"budget": regular_spawn_budget,
		"consumed": regular_spawns_consumed,
		"remaining": (
			maxi(0, regular_spawn_budget - regular_spawns_consumed)
			if regular_spawn_budget >= 0
			else -1
		),
		"generation": regular_spawn_budget_generation,
		"unlimited": regular_spawn_budget < 0,
	}


func debug_set_regular_spawn_budget_for_test(value: int) -> void:
	regular_spawn_budget = maxi(0, value)
	regular_spawns_consumed = 0


func _reset_regular_spawn_budget() -> void:
	regular_spawns_consumed = 0
	regular_spawn_budget_generation += 1
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		regular_spawn_budget = -1
		return
	regular_spawn_budget = randi_range(
		TowerAscentTuning.TEMP_REGULAR_SPAWN_BUDGET_MIN,
		TowerAscentTuning.TEMP_REGULAR_SPAWN_BUDGET_MAX
	)


func _is_regular_spawn_budget_exhausted() -> bool:
	return (
		regular_spawn_budget >= 0
		and regular_spawns_consumed >= regular_spawn_budget
	)


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
