extends RefCounted

const OPTION_COLOR_LOW := Color(230.0 / 255.0, 230.0 / 255.0, 230.0 / 255.0)
const OPTION_COLOR_MID := Color(120.0 / 255.0, 170.0 / 255.0, 1.0)
const OPTION_COLOR_HIGH := Color(180.0 / 255.0, 130.0 / 255.0, 1.0)
const OPTION_COLOR_TOP := Color(1.0, 80.0 / 255.0, 80.0 / 255.0)
const RARITY_COLOR_MYTHIC := Color(1.0, 215.0 / 255.0, 75.0 / 255.0)
const RARITY_COLOR_LEGENDARY := Color(1.0, 130.0 / 255.0, 92.0 / 255.0)

const QUALITY_PREFIXES := {
	"top": ["절대적인", "궁극의", "초신성의", "신화적인", "절대무쌍한", "고대영웅의"],
	"high": ["고급", "장인의", "고품질의", "신성한", "명장의", "완벽한", "영롱한", "찬란한", "비범한", "고성능의"],
	"mid": ["세련된", "괜찮은", "평범한", "무난한", "실용적인", "준수한", "보강된", "균형 잡힌"],
	"low": ["낡은", "오래된", "녹슨", "손상된", "떼묻은", "싸구려", "저급의", "부실한", ""],
}

const QUALITY_TIER_COLORS := {
	"top": OPTION_COLOR_TOP,
	"high": OPTION_COLOR_HIGH,
	"mid": OPTION_COLOR_MID,
	"low": OPTION_COLOR_LOW,
}


static func decorate_roll_option(option: Dictionary) -> Dictionary:
	var result: Dictionary = option.duplicate(true)
	result["color"] = get_roll_option_color(result)
	result["text"] = format_roll_option_text(result)
	return result


static func assign_item_prefix(item_data: Dictionary, force: bool = false) -> Dictionary:
	var result: Dictionary = item_data.duplicate(true)
	if not _is_passive_item(result):
		return result

	var rolled: Array = _get_array(result.get("rolled_options", []))
	if rolled.is_empty():
		result["qualified_display_name"] = format_item_display_name(result)
		return result

	var existing_tier := str(result.get("quality_tier", ""))
	if not force and result.has("name_prefix") and existing_tier != "":
		if not result.has("quality_color"):
			result["quality_color"] = get_quality_color(existing_tier)
		result["qualified_display_name"] = format_item_display_name(result)
		return result

	var percents: Array[float] = []
	for option_value in rolled:
		var option: Dictionary = _get_dict(option_value)
		if option.is_empty() or not option.has("min") or not option.has("max"):
			continue
		percents.append(_get_option_percent(option))
	if percents.is_empty():
		result["qualified_display_name"] = format_item_display_name(result)
		return result

	var total := 0.0
	for percent in percents:
		total += percent
	var average := total / float(percents.size())
	var tier := "low"
	if average >= 0.99:
		tier = "top"
	elif average >= 2.0 / 3.0:
		tier = "high"
	elif average >= 1.0 / 3.0:
		tier = "mid"

	var prefixes: Array = _get_array(QUALITY_PREFIXES.get(tier, [""]))
	var prefix := ""
	if not prefixes.is_empty():
		prefix = str(prefixes[randi() % prefixes.size()])
	result["name_prefix"] = prefix
	result["quality_tier"] = tier
	result["quality_color"] = get_quality_color(tier)
	result["qualified_display_name"] = format_item_display_name(result)
	return result


static func format_item_display_name(item_data: Dictionary) -> String:
	var base_name := str(item_data.get("display_name", item_data.get("korean_name", item_data.get("name", "장비"))))
	var prefix := str(item_data.get("name_prefix", "")).strip_edges()
	if prefix == "":
		return base_name
	return "%s %s" % [prefix, base_name]


static func get_item_quality_color(item_data: Dictionary, fallback: Color = Color.WHITE) -> Color:
	var rarity_color: Variant = get_rarity_title_color(item_data, null)
	if rarity_color is Color:
		return rarity_color
	var raw_color: Variant = item_data.get("quality_color", null)
	if raw_color is Color:
		return raw_color
	var tier := str(item_data.get("quality_tier", ""))
	if tier != "":
		return get_quality_color(tier, fallback)
	return fallback


static func get_rarity_title_color(item_data: Dictionary, fallback: Variant = null) -> Variant:
	var item_type := str(item_data.get("type", "")).to_lower()
	var rarity := str(item_data.get("rarity", item_type)).to_lower()
	if item_type == "mythic" or rarity == "mythic":
		return RARITY_COLOR_MYTHIC
	if item_type == "legendary" or rarity == "legendary":
		return RARITY_COLOR_LEGENDARY
	return fallback


static func get_quality_color(tier: String, fallback: Color = OPTION_COLOR_LOW) -> Color:
	var raw_color: Variant = QUALITY_TIER_COLORS.get(tier, fallback)
	return raw_color if raw_color is Color else fallback


static func get_roll_option_color(option: Dictionary) -> Color:
	if _is_top_roll(option):
		return OPTION_COLOR_TOP
	var percent := _get_option_percent(option)
	if percent <= 1.0 / 3.0:
		return OPTION_COLOR_LOW
	if percent <= 2.0 / 3.0:
		return OPTION_COLOR_MID
	return OPTION_COLOR_HIGH


static func format_roll_option_text(option: Dictionary) -> String:
	var label := str(option.get("label", option.get("key", "")))
	var prefix := str(option.get("prefix", ""))
	var unit := str(option.get("unit", ""))
	var value := float(option.get("value", option.get("default", option.get("min", 0.0))))
	var step := float(option.get("step", 1.0))
	var value_text := "%.1f" % value if step > 0.0 and step < 1.0 else "%d" % int(round(value))
	return "%s %s%s%s" % [label, prefix, value_text, unit]


static func _is_passive_item(item_data: Dictionary) -> bool:
	var item_type := str(item_data.get("type", "")).to_lower()
	var rarity := str(item_data.get("rarity", "")).to_lower()
	return item_type == "passive" or rarity == "passive"


static func _get_option_percent(option: Dictionary) -> float:
	var minimum := float(option.get("min", 0.0))
	var maximum := float(option.get("max", minimum))
	var value := float(option.get("value", option.get("default", minimum)))
	if is_equal_approx(maximum, minimum):
		return 1.0
	var raw: float = clamp((value - minimum) / (maximum - minimum), 0.0, 1.0)
	return 1.0 - raw if bool(option.get("reverse", false)) else raw


static func _is_top_roll(option: Dictionary) -> bool:
	var minimum := float(option.get("min", 0.0))
	var maximum := float(option.get("max", minimum))
	var value := float(option.get("value", option.get("default", minimum)))
	if bool(option.get("reverse", false)):
		return is_equal_approx(value, minimum)
	return is_equal_approx(value, maximum)


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
