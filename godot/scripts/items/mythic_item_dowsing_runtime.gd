extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_DOWSING_PENDULUM := "dowsing_pendulum"
const ITEM_DOWSING_GOGGLES := "dowsing_goggles"


func reset_bonus_trigger(runtime: Object) -> void:
	runtime.dowsing_goggles_bonus_triggered = false


func is_pendulum_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_DOWSING_PENDULUM)


func get_pendulum_range(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_DOWSING_PENDULUM, "attraction_range")
	if not runtime.equipped_items.has(ITEM_DOWSING_PENDULUM):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_DOWSING_PENDULUM, "attraction_range"), 0.0, 600.0)


func get_pendulum_context(runtime: Object, constants: Dictionary) -> Dictionary:
	return runtime.context_builder.get_dowsing_pendulum_context(runtime, constants)


func is_goggles_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_DOWSING_GOGGLES)


func is_goggles_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_DOWSING_GOGGLES, "bonus_perk_chance") > 0.0
	return is_goggles_equipped(runtime)


func get_goggles_bonus_perk_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return clamp(_get_converted_perk_value(runtime, ITEM_DOWSING_GOGGLES, "bonus_perk_chance"), 0.0, 100.0)
	if not is_goggles_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_DOWSING_GOGGLES, "bonus_perk_chance"), 0.0, 100.0)


func get_runtime_perk_choice_count_bonus(
	runtime: Object,
	owner: Object = null,
	registry: Object = null
) -> int:
	runtime.dowsing_goggles_bonus_triggered = false
	var chance_pct: float = get_goggles_bonus_perk_chance_pct(runtime)
	if chance_pct <= 0.0:
		runtime._sync_owner(owner, registry)
		return 0
	if randf() * 100.0 >= chance_pct:
		runtime._sync_owner(owner, registry)
		return 0
	runtime.dowsing_goggles_bonus_triggered = true
	runtime._sync_owner(owner, registry)
	return 1


func was_goggles_bonus_triggered(runtime: Object) -> bool:
	return bool(runtime.dowsing_goggles_bonus_triggered)


func clear_goggles_bonus_trigger(runtime: Object, owner: Object = null, registry: Object = null) -> void:
	runtime.dowsing_goggles_bonus_triggered = false
	runtime._sync_owner(owner, registry)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := 0
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		level = max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime.runtime_perk_state_ref if runtime != null else null)
