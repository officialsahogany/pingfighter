extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DEFAULT_ITEM_COLOR := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
const ITEM_NAME_KO := {
	"aipill": "AI 알약",
	"banana": "바나나",
	"boomerang": "부메랑",
	"dynamite": "다이너마이트",
	"flare": "조명탄",
	"tear_gas": "최루탄",
	"gauge_charge": "에너지드링크",
	"grenade": "수류탄",
	"holy_barrier": "홀리베리어",
	"long_boost": "거대화포션",
	"vitamin_pill": "비타민드링크",
	"strange_vial": "기묘한 약병",
	"magnet_field": "자기장",
	"molotov": "화염병",
	"pandora_box": "판도라의 상자",
	"regeneration_potion": "재생물약",
	"soap": "비누",
	"spider_mine": "스파이더지뢰",
	"stopwatch": "스탑워치",
	"wall": "벽돌",
}

var item_catalog: Object = ActiveItemCatalog.new()


func trigger_pickup_effect(field_item: Dictionary, effect_controller: Object, registry: Object) -> void:
	if effect_controller == null or not effect_controller.has_method("trigger_pickup_effect"):
		return

	var item_data: Dictionary = _get_dictionary(field_item, "item_data").duplicate(true)
	var item_name: String = str(item_data.get("name", ""))
	var display_name: String = str(item_data.get("display_name", ""))
	effect_controller.trigger_pickup_effect(
		field_item,
		LanguageSettings.translate_text(display_name) if display_name != "" else _get_item_display_name(item_name),
		_get_item_color(item_data),
		registry
	)


func _get_item_display_name(item_name: String) -> String:
	return str(ITEM_NAME_KO.get(item_name, item_catalog.get_display_name(item_name))) if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN else item_catalog.get_display_name(item_name)


func _get_item_color(item_data: Dictionary) -> Color:
	if _is_passive_or_mythic_item(item_data):
		return PassiveItemQuality.get_item_quality_color(item_data, _get_color(item_data.get("color", DEFAULT_ITEM_COLOR), DEFAULT_ITEM_COLOR))
	return _get_color(item_data.get("color", DEFAULT_ITEM_COLOR), DEFAULT_ITEM_COLOR)


func _is_passive_or_mythic_item(item_data: Dictionary) -> bool:
	var item_type: String = str(item_data.get("type", "")).to_lower()
	var rarity: String = str(item_data.get("rarity", "")).to_lower()
	return item_type == "passive" or rarity == "passive" or item_type == "mythic" or rarity == "mythic" or item_type == "legendary" or rarity == "legendary"


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
