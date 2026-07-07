extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

const PANDORA_LEGACY := "pandora_legacy"

const PASSIVE_ITEM_NAMES := {
	"speedboots": true,
	"speedgear": true,
	"battery": true,
	"slot_add": true,
	"revival": true,
	"master": true,
	"cooltime": true,
	"chargebag": true,
	"spikeboots": true,
	"dashgear": true,
	"bulkup": true,
	"sensor": true,
	"dashholder": true,
	"gravitybelt": true,
	"timer_belt": true,
	"dowsing_pendulum": true,
	"dowsing_goggles": true,
	"commando_arm": true,
	"fuel_pouch": true,
	"bluetooth_ring": true,
	"foul_whistle": true,
	"star_detector": true,
	"smartphone": true,
	"knee_pads": true,
	"bulletproof_hat": true,
	"spiked_helmet": true,
	"gold_bar": true,
	"gold_digger": true,
	"lucky_coin": true,
	"shrapnel_armor": true,
	"soul_burst": true,
	"sage_ring": true,
	"venom_mist_gauntlet": true,
	"neural_helmet": true,
	"reinforced_boomerang_gauntlet": true,
	"rainbow_fur_glove": true,
	PANDORA_LEGACY: true,
}

const MYTHIC_ITEM_NAMES := {
	"ragnarok_hammer": true,
	"hermes_shoes": true,
	"poseidon_trident": true,
	"sacred_laurel": true,
	"transcendent_crown": true,
	"megingjord": true,
	"heavenly_cape": true,
	"celestial_armor": true,
	"baal_boots": true,
}

const EXCLUDED_ACTIVE_ITEM_NAMES := {
	"ammo_box": true,
	"fire_support": true,
	"doping_potion": true,
}

const BLACKSMITH_ONLY_ACTIVE_NAMES := {
	"repair_kit": true,
	"berserk_potion": true,
}

const VIPER_ONLY_PASSIVE_NAMES := {
	"venom_mist_gauntlet": true,
}


func build_active_pool(owner: Object = null) -> Array:
	var result: Array = []
	var active_catalog: Object = ActiveItemCatalog.new()
	var character_type: String = _get_selected_character_type(owner)
	for item_name_value in ActiveItemCatalog.FIELD_SPAWN_ORDER:
		var item_name: String = str(item_name_value)
		if EXCLUDED_ACTIVE_ITEM_NAMES.has(item_name):
			continue
		if BLACKSMITH_ONLY_ACTIVE_NAMES.has(item_name) and character_type != "blacksmith":
			continue
		var item_data: Dictionary = active_catalog.build_item_by_name(item_name)
		if item_data.is_empty() or float(item_data.get("chance", 0.0)) <= 0.0:
			continue
		result.append(item_data)
	return result


func build_passive_pool(mythic_catalog: Object, owner: Object = null) -> Array:
	var result: Array = []
	if PerkConversionFlags.is_enabled():
		return result
	if mythic_catalog == null or not mythic_catalog.has_method("get_field_spawn_items"):
		return result
	var character_type: String = _get_selected_character_type(owner)
	for item_value in mythic_catalog.get_field_spawn_items():
		var item_data: Dictionary = _get_dict(item_value)
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "" or item_name == PANDORA_LEGACY:
			continue
		if MYTHIC_ITEM_NAMES.has(item_name):
			continue
		if VIPER_ONLY_PASSIVE_NAMES.has(item_name) and character_type != "viper":
			continue
		if not PASSIVE_ITEM_NAMES.has(item_name) and str(item_data.get("type", "")) != "passive":
			continue
		if float(item_data.get("chance", 0.0)) <= 0.0:
			continue
		result.append(item_data)
	return result


func build_mythic_pool(mythic_catalog: Object) -> Array:
	var result: Array = []
	if PerkConversionFlags.is_enabled():
		return result
	if mythic_catalog == null or not mythic_catalog.has_method("get_field_spawn_items"):
		return result
	for item_value in mythic_catalog.get_field_spawn_items():
		var item_data: Dictionary = _get_dict(item_value)
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "" or item_name == PANDORA_LEGACY:
			continue
		if not MYTHIC_ITEM_NAMES.has(item_name):
			continue
		if float(item_data.get("chance", 0.0)) <= 0.0:
			continue
		result.append(item_data)
	return result


func _get_selected_character_type(owner: Object = null) -> String:
	if owner == null:
		return "smasher"
	for key in ["selected_character_type", "runtime_character_id", "character_id"]:
		var value: String = str(_safe_owner_get(owner, key, ""))
		if value != "":
			return value.strip_edges().to_lower()
	return "smasher"


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
