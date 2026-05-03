extends RefCounted

const DEFAULT_COOLDOWN_MSEC := 10000
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 220.0

const GAUGE_CHARGE_ICON_PATH := "res://assets/sprites/items/gauge_200.png"
const GRENADE_ICON_PATH := "res://assets/sprites/items/grenade.png"
const FLARE_ICON_PATH := "res://assets/sprites/items/flare.png"
const LONG_BOOST_ICON_PATH := "res://assets/sprites/items/long_boost_icon.png"
const REGENERATION_POTION_ICON_PATH := "res://assets/sprites/items/regeneration_potion.png"
const BOOMERANG_ICON_PATH := "res://assets/sprites/items/boomerang.png"

const FIELD_SPAWN_ORDER := [
	"gauge_charge",
	"grenade",
	"flare",
	"long_boost",
	"regeneration_potion",
	"boomerang",
]


func build_item_by_name(item_name: String) -> Dictionary:
	match item_name:
		"gauge_charge":
			return _build_gauge_charge()
		"grenade":
			return _build_grenade()
		"flare":
			return _build_flare()
		"long_boost":
			return _build_long_boost()
		"regeneration_potion":
			return _build_regeneration_potion()
		"boomerang":
			return _build_boomerang()
	return {}


func build_random_spawn_item() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for item_name in FIELD_SPAWN_ORDER:
		var candidate: Dictionary = build_item_by_name(str(item_name))
		if not candidate.is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return {}

	var total_weight: float = 0.0
	for candidate in candidates:
		total_weight += max(0.0, float(candidate.get("chance", 0.0)))
	var roll: float = randf() * max(0.001, total_weight)
	for candidate in candidates:
		roll -= max(0.0, float(candidate.get("chance", 0.0)))
		if roll <= 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func get_display_name(item_name: String) -> String:
	var item_data: Dictionary = build_item_by_name(item_name)
	return str(item_data.get("display_name", item_name))


func _build_gauge_charge() -> Dictionary:
	return {
		"name": "gauge_charge",
		"display_name": "Energy Drink",
		"type": "active",
		"effect": "gauge_charge",
		"chance": 0.042,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_CHARGE_AMOUNT,
		"gauge_max": GAUGE_MAX,
		"icon_path": GAUGE_CHARGE_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_grenade() -> Dictionary:
	return {
		"name": "grenade",
		"display_name": "Grenade",
		"type": "active",
		"effect": "grenade",
		"chance": 0.018,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": GRENADE_ICON_PATH,
		"color": Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_flare() -> Dictionary:
	return {
		"name": "flare",
		"display_name": "Flare",
		"type": "active",
		"effect": "flare",
		"chance": 0.020,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": FLARE_ICON_PATH,
		"color": Color(1.0, 1.0, 200.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_long_boost() -> Dictionary:
	return {
		"name": "long_boost",
		"display_name": "Giant Potion",
		"type": "active",
		"effect": "long_boost",
		"chance": 0.028,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": LONG_BOOST_ICON_PATH,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_regeneration_potion() -> Dictionary:
	return {
		"name": "regeneration_potion",
		"display_name": "Regeneration Potion",
		"type": "active",
		"effect": "regeneration_potion",
		"chance": 0.008,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": REGENERATION_POTION_ICON_PATH,
		"color": Color(1.0, 230.0 / 255.0, 80.0 / 255.0),
		"consumable": true,
	}


func _build_boomerang() -> Dictionary:
	return {
		"name": "boomerang",
		"display_name": "Boomerang",
		"type": "active",
		"effect": "boomerang",
		"chance": 0.015,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": BOOMERANG_ICON_PATH,
		"color": Color(200.0 / 255.0, 130.0 / 255.0, 60.0 / 255.0),
		"consumable": true,
		"count": 1,
	}
