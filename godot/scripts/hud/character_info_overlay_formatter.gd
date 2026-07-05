extends RefCounted

static func frames_to_seconds(frames: float) -> float:
	return max(0.0, float(frames)) / 60.0


static func item_part_subtitle(slot_key: String) -> String:
	var label: String = slot_display_label(slot_key)
	if label == "":
		return ""
	return "부위 : %s" % label


static func format_roll_option_value(value: float, option: Dictionary) -> String:
	var step: float = float(option.get("step", 1.0))
	var unit: String = str(option.get("unit", ""))
	var prefix: String = str(option.get("prefix", ""))
	var value_text: String = "%.1f" % value if step > 0.0 and step < 1.0 else "%d" % int(round(value))
	if unit == "+":
		return "+%s" % value_text
	return "%s%s%s" % [prefix, value_text, unit]


static func format_roll_effective_delta(base_value: float, effective_value: float, option: Dictionary) -> String:
	var raw_delta: float = effective_value - base_value
	var prefix: String = str(option.get("prefix", ""))
	var reverse := bool(option.get("reverse", false))
	var delta: float = raw_delta
	if reverse and prefix == "-":
		delta = base_value - effective_value
	elif not reverse and prefix == "-":
		delta = base_value - effective_value
	if abs(delta) < 0.01:
		return ""
	var step: float = float(option.get("step", 1.0))
	if step >= 1.0 and int(round(abs(delta))) == 0:
		return ""
	var unit: String = str(option.get("unit", ""))
	@warning_ignore("shadowed_global_identifier")
	var sign := "+" if delta > 0.0 else "-"
	var absolute_delta: float = abs(delta)
	var value_text: String = "%.1f" % absolute_delta if step > 0.0 and step < 1.0 else "%d" % int(round(absolute_delta))
	if unit == "+":
		return " (%s%s)" % [sign, value_text]
	return " (%s%s%s)" % [sign, value_text, unit]


static func slot_display_label(slot_key: String) -> String:
	match slot_key:
		"":
			return ""
		"head":
			return "머리"
		"top":
			return "상의"
		"torso":
			return "상의"
		"arm":
			return "팔"
		"left_arm":
			return "팔"
		"right_arm":
			return "팔"
		"belt":
			return "벨트"
		"belt2":
			return "등"
		"back":
			return "등"
		"등":
			return "등"
		"knee":
			return "무릎"
		"shoes":
			return "신발"
		"accessory":
			return "장신구"
		"accessory1":
			return "장신구"
		"accessory2":
			return "장신구"
		"accessory3":
			return "장신구"
		"accessory4":
			return "장신구"
		_:
			return slot_key


static func character_type_label(character_type: String) -> String:
	if character_type == "viper":
		return "바이퍼"
	if character_type == "soldier":
		return "코만도"
	if character_type == "blacksmith":
		return "발토르"
	if character_type == "optimus":
		return "옵티머스"
	return "스매셔"


static func character_color(character_type: String) -> Color:
	if character_type == "viper":
		return Color(190.0 / 255.0, 80.0 / 255.0, 1.0)
	if character_type == "soldier":
		return Color(120.0 / 255.0, 180.0 / 255.0, 82.0 / 255.0)
	return Color(70.0 / 255.0, 190.0 / 255.0, 1.0)


static func skill_fallback_color(character_type: String, accent_blue: Color) -> Color:
	if character_type == "viper":
		return Color(190.0 / 255.0, 80.0 / 255.0, 1.0)
	if character_type == "soldier":
		return Color(120.0 / 255.0, 180.0 / 255.0, 82.0 / 255.0)
	return accent_blue


static func short_skill_name(data: Dictionary, skill_id: String) -> String:
	var name := str(data.get("korean", skill_id))
	return trim_label(name, 7)


static func trim_label(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max(1, max_len - 1)) + "."


static func format_int_pair(current: int, maximum: int) -> String:
	return str(current) + " / " + str(maximum)


static func format_seconds_text(seconds: float) -> String:
	if is_equal_approx(seconds, round(seconds)):
		return "%d초" % int(round(seconds))
	return "%.1f초" % seconds


static func format_percent_text(percent: float) -> String:
	if is_equal_approx(percent, round(percent)):
		return "%d%%" % int(round(percent))
	return "%.1f%%" % percent


static func format_plain_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.1f" % value


static func perk_level_text(perk: Dictionary) -> String:
	if int(perk.get("max_level", 1)) == 1 and str(perk.get("character_restriction", "")) != "":
		return "해금"
	return "Lv.%d" % int(perk.get("level", 1))


static func perk_level_color(perk: Dictionary, accent_gold: Color) -> Color:
	if int(perk.get("max_level", 1)) == 1 and str(perk.get("character_restriction", "")) != "":
		return Color(120.0 / 255.0, 1.0, 210.0 / 255.0)
	return accent_gold


static func item_color(item_data: Dictionary, visuals: Object, fallback_color: Color) -> Color:
	if visuals != null and visuals.has_method("get_item_color"):
		var value: Variant = visuals.get_item_color(item_data)
		if value is Color:
			return value
	var raw: Variant = item_data.get("color", fallback_color)
	if raw is Color:
		return raw
	return fallback_color


static func equipment_empty_color_for_base(
	base: String,
	head_color: Color,
	top_color: Color,
	arm_color: Color,
	belt_color: Color,
	back_color: Color,
	knee_color: Color,
	shoes_color: Color,
	accessory_color: Color
) -> Color:
	match base:
		"head":
			return head_color
		"top":
			return top_color
		"arm":
			return arm_color
		"belt":
			return belt_color
		"back":
			return back_color
		"knee":
			return knee_color
		"shoes":
			return shoes_color
		_:
			return accessory_color


static func equipment_item_display_name_hash(item_data: Dictionary) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("display_name", ""),
		item_data.get("korean", ""),
		item_data.get("korean_name", ""),
		item_data.get("name_prefix", ""),
		item_data.get("qualified_display_name", ""),
	])


static func item_quality_color_hash(item_data: Dictionary, fallback: Color) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("type", ""),
		item_data.get("rarity", ""),
		item_data.get("quality_tier", ""),
		item_data.get("quality_color", ""),
		fallback,
	])


static func equipment_slot_label(label: String, key: String, cell_size: float) -> String:
	if cell_size >= 42.0:
		return label
	if key.begins_with("accessory"):
		return "장신%s" % key.substr("accessory".length(), 1)
	return trim_label(label, 4)
