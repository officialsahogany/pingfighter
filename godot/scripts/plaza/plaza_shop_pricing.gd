extends RefCounted

const GOLD_BAR_SELL_PRICE := 2000
const DEFAULT_BASE_PRICE := 500
const SELL_RATE := 0.30

const PASSIVE_BASE_PRICES := {
	"speedboots": 750,
	"speedgear": 550,
	"battery": 900,
	"revival": 2000,
	"master": 700,
	"cooltime": 500,
	"chargebag": 1000,
	"spikeboots": 800,
	"dashgear": 800,
	"bulkup": 750,
	"sensor": 1200,
	"gravitybelt": 1900,
	"dashholder": 1200,
	"dowsing_pendulum": 700,
	"smartphone": 1000,
	"commando_arm": 750,
	"fuel_pouch": 500,
	"slot_add": 600,
	"bluetooth_ring": 800,
	"star_detector": 600,
	"foul_whistle": 900,
	"bulletproof_hat": 550,
	"spiked_helmet": 700,
	"dowsing_goggles": 650,
	"knee_pads": 550,
	"lucky_coin": 800,
	"adversity_armor": 1100,
	"shrapnel_armor": 900,
	"soul_burst": 750,
	"sage_ring": 1800,
	"venom_mist_gauntlet": 700,
}

const LEGENDARY_BASE_PRICES := {
	"ragnarok_hammer": 3600,
	"hermes_shoes": 3000,
	"poseidon_trident": 3000,
	"sacred_laurel": 3360,
	"transcendent_crown": 4560,
	"odins_eye": 3750,
	"pandora_legacy": 4200,
	"megingjord": 3900,
	"horn_strawberry_mask": 4200,
	"heavenly_cape": 4350,
}

const QUALITY_MULTIPLIERS := {
	"top": 1.9,
	"high": 1.6,
	"mid": 1.35,
	"low": 1.0,
}

const ROLL_BONUS_RANGES := {
	"top": 0.15,
	"high": 0.12,
	"mid": 0.10,
	"low": 0.08,
}

const ACTIVE_BASE_PRICES := {
	"lingpet_feed": 240,
	"lingpet_special_feed": 700,
}


static func get_base_price(item_name: String) -> int:
	if ACTIVE_BASE_PRICES.has(item_name):
		return int(ACTIVE_BASE_PRICES[item_name])
	if PASSIVE_BASE_PRICES.has(item_name):
		return int(PASSIVE_BASE_PRICES[item_name])
	if LEGENDARY_BASE_PRICES.has(item_name):
		return int(LEGENDARY_BASE_PRICES[item_name])
	return DEFAULT_BASE_PRICE


static func is_shop_priced_item(item_name: String) -> bool:
	return ACTIVE_BASE_PRICES.has(item_name) or PASSIVE_BASE_PRICES.has(item_name) or LEGENDARY_BASE_PRICES.has(item_name)


static func is_legacy_legendary(item_name: String) -> bool:
	return LEGENDARY_BASE_PRICES.has(item_name)


static func get_buy_price(item_data: Dictionary) -> int:
	var item_name := _get_item_name(item_data)
	var base_price := get_base_price(item_name)
	var bonus := get_quality_and_roll_bonus(item_data, base_price)
	return maxi(1, base_price + bonus)


static func get_sell_price(item_data: Dictionary) -> int:
	var item_name := _get_item_name(item_data)
	if item_name == "gold_bar":
		return GOLD_BAR_SELL_PRICE
	var base_price := get_base_price(item_name)
	var bonus := get_quality_and_roll_bonus(item_data, base_price)
	var enhancement_level := maxi(0, int(item_data.get("enhancement_level", item_data.get("enhancement", 0))))
	var enhancement_bonus := int(float(base_price + bonus) * float(enhancement_level) * 0.20)
	return maxi(1, int(float(base_price + bonus + enhancement_bonus) * SELL_RATE))


static func get_quality_and_roll_bonus(item_data: Dictionary, base_price: int) -> int:
	if _is_legendary(item_data):
		var legendary_mult := lerpf(0.85, 1.25, _calculate_roll_percentile(item_data))
		return int(float(base_price) * (legendary_mult - 1.0))
	var quality_tier := str(item_data.get("quality_tier", "low"))
	var base_mult := float(QUALITY_MULTIPLIERS.get(quality_tier, 1.0))
	var roll_range := float(ROLL_BONUS_RANGES.get(quality_tier, 0.0))
	var final_mult := base_mult + roll_range * _calculate_roll_percentile(item_data)
	return int(float(base_price) * (final_mult - 1.0))


static func _calculate_roll_percentile(item_data: Dictionary) -> float:
	var rolled_options := _get_array(item_data.get("rolled_options", []))
	if rolled_options.is_empty():
		return 0.0
	var total := 0.0
	var count := 0
	for option_value in rolled_options:
		var option := _get_dict(option_value)
		if option.is_empty() or not option.has("value"):
			continue
		var minimum := float(option.get("min", 0.0))
		var maximum := float(option.get("max", minimum))
		var percent := 1.0
		if not is_equal_approx(maximum, minimum):
			percent = clampf((float(option.get("value", minimum)) - minimum) / (maximum - minimum), 0.0, 1.0)
			if bool(option.get("reverse", false)):
				percent = 1.0 - percent
		total += percent
		count += 1
	if count <= 0:
		return 0.0
	return clampf(total / float(count), 0.0, 1.0)


static func _is_legendary(item_data: Dictionary) -> bool:
	var item_name := _get_item_name(item_data)
	var item_type := str(item_data.get("type", "")).to_lower()
	var rarity := str(item_data.get("rarity", item_type)).to_lower()
	return is_legacy_legendary(item_name) or item_type == "legendary" or rarity == "legendary"


static func _get_item_name(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var value := str(item_data.get(str(key), "")).strip_edges()
		if value != "":
			return value
	return ""


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
