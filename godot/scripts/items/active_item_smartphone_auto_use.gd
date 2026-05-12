extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const SMARTPHONE_RECOVERY_PRIORITY := ["life_elixir", "gauge_charge"]
const SMARTPHONE_DEFENSE_PRIORITY := ["stopwatch", "holy_barrier"]


func try_auto_recovery(
	owner: Object,
	registry: Object,
	gauge_threshold: float,
	slot_controller: Object,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable
) -> String:
	if owner == null:
		return ""
	var current_gauge: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0))
	if current_gauge > gauge_threshold:
		return ""
	return _try_auto_use(
		SMARTPHONE_RECOVERY_PRIORITY,
		owner,
		registry,
		slot_controller,
		apply_item_effect_callback,
		pending_use_backup_callback
	)


func try_auto_defense(
	owner: Object,
	registry: Object,
	slot_controller: Object,
	effect_controller: Object,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable
) -> String:
	var used_item: String = _try_auto_use(
		SMARTPHONE_DEFENSE_PRIORITY,
		owner,
		registry,
		slot_controller,
		apply_item_effect_callback,
		pending_use_backup_callback
	)
	if used_item == "stopwatch" and effect_controller != null and effect_controller.has_method("force_stopwatch_recovery_upward"):
		effect_controller.force_stopwatch_recovery_upward()
	return used_item


func _try_auto_use(
	priority_names: Array,
	owner: Object,
	registry: Object,
	slot_controller: Object,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable
) -> String:
	if owner == null or priority_names.is_empty() or slot_controller == null:
		return ""
	return str(slot_controller.use_first_matching_item(
		priority_names,
		owner,
		registry,
		false,
		apply_item_effect_callback,
		pending_use_backup_callback,
		true
	))
