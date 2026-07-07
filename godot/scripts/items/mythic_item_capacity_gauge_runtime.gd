extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SLOT_ADD := "slot_add"
const ITEM_CHARGEBAG := "chargebag"
const ITEM_BATTERY := "battery"


func is_slot_add_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_SLOT_ADD)


func get_slot_add_active_item_slot_bonus(runtime: Object) -> int:
	if not runtime.equipped_items.has(ITEM_SLOT_ADD):
		return 0
	var item_data: Dictionary = runtime._get_dict(runtime.equipped_items[ITEM_SLOT_ADD])
	var rolls: Dictionary = runtime._get_dict(item_data.get("rolls", {}))
	var value: float = float(rolls.get(
		"slot_add_count",
		runtime.catalog.get_default_roll_value(ITEM_SLOT_ADD, "slot_add_count")
	))
	var enhancement_bonus_pct: float = max(0.0, float(item_data.get("enhancement_bonus_pct", 0.0)))
	if enhancement_bonus_pct > 0.0:
		value *= 1.0 + enhancement_bonus_pct / 100.0
	return max(0, int(floor(value)))


func get_active_item_slot_capacity(runtime: Object, base_slots: int = 3) -> int:
	return max(1, int(base_slots) + get_slot_add_active_item_slot_bonus(runtime))


func is_chargebag_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_CHARGEBAG)


func get_chargebag_wall_bounce_gauge_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_CHARGEBAG, "chargebag_pct")
	if not is_chargebag_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_CHARGEBAG, "chargebag_pct"), 0.0, 500.0)


func apply_chargebag_wall_bounce_gauge(
	runtime: Object,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> float:
	if _is_aipill_active_from_deps(runtime, deps):
		return special_gauge
	var bonus_pct: float = get_chargebag_wall_bounce_gauge_pct(runtime)
	if bonus_pct <= 0.0:
		return special_gauge
	var base_gain: float = resolve_chargebag_base_wall_gauge_gain(context)
	if base_gain <= 0.0:
		return special_gauge
	var gain: float = floor(base_gain * bonus_pct / 100.0)
	gain = runtime.apply_gold_digger_gauge_bonus(gain)
	if gain <= 0.0:
		return special_gauge
	var gauge_max: float = max(0.0, float(context.get("gauge_max", context.get("special_gauge_max", 500.0))))
	var next_gauge: float = min(gauge_max, special_gauge + gain)
	if next_gauge > special_gauge:
		runtime.gauge_feedback.trigger_gauge_flash(runtime, deps)
	return next_gauge


func resolve_chargebag_base_wall_gauge_gain(context: Dictionary) -> float:
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	match character_type:
		"optimus":
			return 0.0
		"soldier", "commando":
			return 50.0
		"blacksmith", "baltor":
			if bool(context.get("blacksmith_umbrella_open", false)):
				return max(0.0, float(context.get("blacksmith_umbrella_gauge_gain", 60.0)))
			return 30.0
	var fallback_gain: float = float(context.get("gauge_charge_per_hit", 50.0))
	return max(0.0, fallback_gain)


func is_battery_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_BATTERY)


func get_battery_gauge_preserve_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_BATTERY, "gauge_preserve_pct")
	if not is_battery_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_BATTERY, "gauge_preserve_pct"), 0.0, 100.0)


func get_stage_transition_gauge(
	runtime: Object,
	current_gauge: float,
	gauge_max: float = 500.0,
	aipill_active: bool = false
) -> float:
	var safe_max: float = max(0.0, gauge_max)
	var safe_gauge: float = clamp(float(current_gauge), 0.0, safe_max)
	if aipill_active:
		return safe_gauge
	var preserve_pct: float = get_battery_gauge_preserve_pct(runtime)
	if preserve_pct <= 0.0:
		return 0.0
	return clamp(floor(safe_gauge * preserve_pct / 100.0), 0.0, safe_max)


func _is_aipill_active_from_deps(runtime: Object, deps: Dictionary) -> bool:
	var active_item_runtime: Object = runtime._get_dict(deps).get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_aipill_active"):
		return bool(active_item_runtime.is_aipill_active())
	return false


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := 0
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		level = max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level)
