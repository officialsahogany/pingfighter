extends RefCounted


func apply_item_effect(
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	effect_controller: Object,
	throw_controller: Object
) -> bool:
	var item_name: String = _get_item_identity(item_data)
	var effect_name: String = str(item_data.get("effect", item_name))
	if _matches(item_name, effect_name, "gauge_charge"):
		return _call_bool(effect_controller, "apply_gauge_charge", [item_data, owner, registry])
	if _matches(item_name, effect_name, "life_elixir"):
		return _call_bool(effect_controller, "apply_life_elixir", [item_data, owner, registry])
	if _matches(item_name, effect_name, "lingpet_feed"):
		return _call_bool(effect_controller, "apply_lingpet_feed", [item_data, owner, registry])
	if _matches(item_name, effect_name, "lingpet_spirit_water"):
		return _call_bool(effect_controller, "apply_lingpet_spirit_water", [item_data, owner, registry])
	if _matches(item_name, effect_name, "lingpet_egg"):
		return _call_bool(effect_controller, "activate_lingpet_egg", [owner, registry])
	if _matches(item_name, effect_name, "ammo_box"):
		return _call_bool(effect_controller, "apply_ammo_box", [item_data, owner, registry])
	if _matches(item_name, effect_name, "doping_potion"):
		return _call_bool(effect_controller, "activate_doping_potion", [item_data, owner, registry])
	if _matches(item_name, effect_name, "vitamin_pill"):
		return _call_bool(effect_controller, "activate_vitamin_pill", [owner, registry])
	if _matches(item_name, effect_name, "strange_vial"):
		return _call_bool(effect_controller, "activate_strange_vial", [owner, registry])
	if _matches(item_name, effect_name, "aipill"):
		return _call_bool(effect_controller, "activate_aipill", [owner, registry])
	if _matches(item_name, effect_name, "grenade"):
		return _call_bool(throw_controller, "activate_grenade", [owner, registry])
	if _matches(item_name, effect_name, "flare"):
		return _call_bool(throw_controller, "activate_flare", [owner, registry])
	if _matches(item_name, effect_name, "tear_gas"):
		return _call_bool(throw_controller, "activate_tear_gas", [owner, registry])
	if _matches(item_name, effect_name, "dynamite"):
		return _call_bool(throw_controller, "activate_dynamite", [owner, registry])
	if _matches(item_name, effect_name, "molotov"):
		return _call_bool(throw_controller, "activate_molotov", [owner, registry])
	if _matches(item_name, effect_name, "boomerang"):
		return _call_bool(throw_controller, "activate_boomerang", [owner, registry])
	if _matches(item_name, effect_name, "banana"):
		return _call_bool(throw_controller, "activate_banana", [owner, registry])
	if _matches(item_name, effect_name, "soap"):
		return _call_bool(throw_controller, "activate_soap", [owner, registry])
	if _matches(item_name, effect_name, "spider_mine"):
		return _call_bool(throw_controller, "activate_spider_mine", [owner, registry])
	if _matches(item_name, effect_name, "stopwatch"):
		return _call_bool(effect_controller, "activate_stopwatch", [owner, registry])
	if _matches(item_name, effect_name, "magnet_field"):
		return _call_bool(effect_controller, "activate_magnet_field", [owner, registry])
	if _matches(item_name, effect_name, "hologram_disk"):
		return _call_bool(effect_controller, "activate_hologram_disk", [owner, registry])
	if _matches(item_name, effect_name, "long_boost"):
		return _call_bool(effect_controller, "activate_long_boost", [owner, registry])
	if _matches(item_name, effect_name, "milk_bottle"):
		return _call_bool(effect_controller, "activate_milk_bottle", [item_data, owner, registry])
	if _matches(item_name, effect_name, "cheese"):
		return _call_bool(effect_controller, "activate_cheese", [item_data, owner, registry])
	if _matches(item_name, effect_name, "regeneration_potion"):
		return _call_bool(effect_controller, "apply_regeneration_potion", [owner, registry])
	if _matches(item_name, effect_name, "holy_barrier"):
		return _call_bool(effect_controller, "activate_holy_barrier", [owner, registry])
	if _matches(item_name, effect_name, "dash_boost"):
		return _call_bool(effect_controller, "activate_dash_boost", [owner, registry])
	if _matches(item_name, effect_name, "wall"):
		return _call_bool(effect_controller, "activate_wall", [owner, registry])
	if _matches(item_name, effect_name, "trampoline"):
		return _call_bool(effect_controller, "activate_trampoline", [owner, registry])
	if _matches(item_name, effect_name, "elixir_of_mastery"):
		return _call_bool(effect_controller, "activate_elixir_of_mastery", [owner, registry])
	return false


func _matches(item_name: String, effect_name: String, expected: String) -> bool:
	return item_name == expected or effect_name == expected


func _call_bool(target: Object, method_name: String, args: Array) -> bool:
	if target == null or not target.has_method(method_name):
		return false
	return bool(target.callv(method_name, args))


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var raw_value: Variant = item_data.get(str(key), "")
		if raw_value == null:
			continue
		var value: String = str(raw_value)
		if value != "":
			return value
	return ""
