extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DEFAULT_ITEM_COLOR := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
const ITEM_NAME_KO := {
	"flare": "Flare",
	"gauge_charge": "에너지드링크",
	"grenade": "수류탄",
	"long_boost": "거대화포션",
	"regeneration_potion": "재생물약",
	"boomerang": "부메랑",
}

var item_catalog: Object = ActiveItemCatalog.new()


func trigger_pickup_effect(field_item: Dictionary, effect_controller: Object, registry: Object) -> void:
	if effect_controller == null or not effect_controller.has_method("trigger_pickup_effect"):
		return

	var item_data: Dictionary = _get_dictionary(field_item, "item_data").duplicate(true)
	var item_name: String = str(item_data.get("name", ""))
	effect_controller.trigger_pickup_effect(
		field_item,
		_get_korean_item_name(item_name),
		_get_item_color(item_data),
		registry
	)


func _get_korean_item_name(item_name: String) -> String:
	if item_name == "long_boost":
		return "거대화포션"
	return str(ITEM_NAME_KO.get(item_name, item_catalog.get_display_name(item_name)))


func _get_item_color(item_data: Dictionary) -> Color:
	return _get_color(item_data.get("color", DEFAULT_ITEM_COLOR), DEFAULT_ITEM_COLOR)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}
