extends RefCounted


func apply_item_effect(
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	effect_controller: Object,
	throw_controller: Object
) -> bool:
	var item_name: String = str(item_data.get("name", ""))
	var effect_name: String = str(item_data.get("effect", item_name))
	if _matches(item_name, effect_name, "gauge_charge"):
		return _call_bool(effect_controller, "apply_gauge_charge", [item_data, owner, registry])
	if _matches(item_name, effect_name, "grenade"):
		return _call_bool(throw_controller, "activate_grenade", [owner, registry])
	if _matches(item_name, effect_name, "flare"):
		return _call_bool(throw_controller, "activate_flare", [owner, registry])
	if _matches(item_name, effect_name, "long_boost"):
		return _call_bool(effect_controller, "activate_long_boost", [owner, registry])
	if _matches(item_name, effect_name, "regeneration_potion"):
		return _call_bool(effect_controller, "apply_regeneration_potion", [owner, registry])
	return false


func _matches(item_name: String, effect_name: String, expected: String) -> bool:
	return item_name == expected or effect_name == expected


func _call_bool(target: Object, method_name: String, args: Array) -> bool:
	if target == null or not target.has_method(method_name):
		return false
	return bool(target.callv(method_name, args))
